import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

/// Bundled Tor Service — Zero-intervention Tor connectivity
///
/// Priority chain (no user action required):
/// 1. Detect existing Tor (port 9150/9052/9050) → use it
/// 2. Find system `tor` binary in PATH / common locations → start on port 9250
/// 3. Check cached Tor download in app support dir → start
/// 4. Auto-install via package manager (brew/apt) → start
/// 5. Auto-download Tor Expert Bundle from torproject.org → start
///
/// The user and their friend NEVER need to manually install anything.
class TorService {
  Process? _torProcess;
  String? _torDataDir;

  // ── Named constants (no magic numbers) ────────────────────────────
  /// SOCKS port used when we start our own bundled Tor process.
  static const int bundledSocksPort = 9250;

  /// Well-known SOCKS ports to probe for existing Tor instances.
  static const int torBrowserPort = 9150;
  static const int testnetTorPort = 9052;
  static const int systemTorPort = 9050;

  /// Timeout for Tor to finish bootstrapping (100% circuit established).
  static const Duration bootstrapTimeout = Duration(seconds: 120);

  /// Timeout for package-manager install (brew/apt).
  static const Duration installTimeout = Duration(minutes: 5);

  /// Timeout for downloading the Tor Expert Bundle tarball.
  static const Duration downloadTimeout = Duration(minutes: 10);

  /// Interval between health-check probes while waiting for bootstrap.
  static const Duration bootstrapPollInterval = Duration(milliseconds: 500);

  final int _socksPort = bundledSocksPort;
  bool _isRunning = false;
  String? _activeProxy; // "host:port" of the active SOCKS proxy

  bool get isRunning => _isRunning;
  String get proxyAddress => _activeProxy ?? 'localhost:$_socksPort';
  int get activeSocksPort {
    if (_activeProxy != null) {
      return int.tryParse(_activeProxy!.split(':').last) ?? _socksPort;
    }
    return _socksPort;
  }

  /// Start Tor with full auto-detection/installation chain.
  /// Returns true if a SOCKS proxy is available, false if all methods failed.
  Future<bool> start() async {
    if (_isRunning) {
      debugPrint('🔵 Tor already running on $_activeProxy');
      return true;
    }

    // 1. Detect existing Tor instances
    final existing = await detectExistingTor();
    if (existing['found'] == true) {
      _activeProxy = existing['proxy'] as String;
      _isRunning = true;
      debugPrint('✅ Using existing ${existing['type']}: $_activeProxy');
      return true;
    }

    // 2. Find or install Tor binary
    String? torBinary = await _findTorBinary();

    if (torBinary == null) {
      debugPrint('🔍 No Tor binary found, attempting auto-install...');
      torBinary = await _autoInstallTor();
    }

    if (torBinary == null) {
      debugPrint('📥 Auto-install failed, attempting download...');
      torBinary = await _downloadAndCacheTor();
    }

    if (torBinary == null) {
      debugPrint('❌ Could not find, install, or download Tor');
      debugPrint('   The wallet will not be able to connect to .onion nodes');
      return false;
    }

    // 3. Start Tor process
    return await _startTorProcess(torBinary);
  }

  /// Stop Tor daemon
  Future<void> stop() async {
    if (_torProcess != null) {
      debugPrint('🛑 Stopping Tor daemon...');
      _torProcess!.kill(ProcessSignal.sigterm);
      await Future.delayed(bootstrapPollInterval);
      _torProcess = null;
      _isRunning = false;
      _activeProxy = null;
      debugPrint('✅ Tor stopped');
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  // BINARY DISCOVERY — Find Tor on the system
  // ════════════════════════════════════════════════════════════════════════

  /// Search for tor binary in PATH and common locations
  Future<String?> _findTorBinary() async {
    // Check PATH using 'which' (Unix) or 'where' (Windows)
    try {
      final cmd = Platform.isWindows ? 'where' : 'which';
      final result = await Process.run(cmd, ['tor']);
      if (result.exitCode == 0) {
        final torPath = result.stdout.toString().trim().split('\n').first;
        if (torPath.isNotEmpty && await File(torPath).exists()) {
          debugPrint('✅ Found system tor: $torPath');
          return torPath;
        }
      }
    } catch (e) {
      debugPrint('⚠️ _findTorBinary PATH check failed: $e');
    }

    // Check common installation locations
    final commonPaths = <String>[];
    if (Platform.isMacOS) {
      commonPaths.addAll([
        '/opt/homebrew/bin/tor', // Apple Silicon Homebrew
        '/usr/local/bin/tor', // Intel Homebrew
        '/opt/local/bin/tor', // MacPorts
      ]);
    } else if (Platform.isLinux) {
      commonPaths.addAll([
        '/usr/bin/tor',
        '/usr/local/bin/tor',
        '/snap/bin/tor',
      ]);
    } else if (Platform.isWindows) {
      commonPaths.addAll([
        r'C:\Program Files\Tor\tor.exe',
        r'C:\Program Files (x86)\Tor Browser\Browser\TorBrowser\Tor\tor.exe',
      ]);
    }

    for (final torPath in commonPaths) {
      if (await File(torPath).exists()) {
        debugPrint('✅ Found tor at: $torPath');
        return torPath;
      }
    }

    // Check bundled binary in app assets
    final bundled = await _getBundledTorBinary();
    if (bundled != null) return bundled;

    // Check cached download
    final cached = await _getCachedTorBinary();
    if (cached != null) return cached;

    return null;
  }

  /// Check for bundled Tor binary in Flutter assets
  Future<String?> _getBundledTorBinary() async {
    String? binaryName;
    if (Platform.isMacOS) {
      binaryName = 'tor/macos/tor';
    } else if (Platform.isWindows) {
      binaryName = 'tor/windows/tor.exe';
    } else if (Platform.isLinux) {
      binaryName = 'tor/linux/tor';
    } else {
      return null;
    }

    final executableDir = path.dirname(Platform.resolvedExecutable);
    final locations = [
      path.join(Directory.current.path, binaryName),
      path.join(executableDir, '..', 'Resources', 'flutter_assets', binaryName),
      path.join(executableDir, 'data', 'flutter_assets', binaryName),
    ];

    for (final location in locations) {
      final file = File(location);
      if (await file.exists()) {
        if (!Platform.isWindows) {
          await Process.run('chmod', ['+x', location]);
        }
        debugPrint('✅ Found bundled tor: $location');
        return location;
      }
    }
    return null;
  }

  /// Check for previously downloaded & cached Tor binary
  Future<String?> _getCachedTorBinary() async {
    try {
      final appDir = await getApplicationSupportDirectory();
      final torBinDir = path.join(appDir.path, 'tor_bin');

      final binaryName = Platform.isWindows ? 'tor.exe' : 'tor';
      final cachedPath = path.join(torBinDir, binaryName);

      if (await File(cachedPath).exists()) {
        debugPrint('✅ Found cached tor: $cachedPath');
        return cachedPath;
      }
    } catch (e) {
      debugPrint('⚠️ _getCachedTorBinary check failed: $e');
    }
    return null;
  }

  // ════════════════════════════════════════════════════════════════════════
  // AUTO-INSTALL — Package manager installation
  // ════════════════════════════════════════════════════════════════════════

  /// Try to install Tor via system package manager (silent, no user input)
  Future<String?> _autoInstallTor() async {
    try {
      if (Platform.isMacOS) {
        // Check if Homebrew is available
        final brewCheck = await Process.run('which', ['brew']);
        if (brewCheck.exitCode == 0) {
          debugPrint(
              '📦 Installing Tor via Homebrew (this may take a minute)...');
          final installResult = await Process.run(
            'brew',
            ['install', 'tor'],
            runInShell: true,
          ).timeout(installTimeout);

          if (installResult.exitCode == 0) {
            // Find the installed binary
            final whichResult = await Process.run('which', ['tor']);
            if (whichResult.exitCode == 0) {
              final torPath = whichResult.stdout.toString().trim();
              debugPrint('✅ Tor installed via Homebrew: $torPath');
              return torPath;
            }
            // Try common Homebrew paths
            for (final p in ['/opt/homebrew/bin/tor', '/usr/local/bin/tor']) {
              if (await File(p).exists()) return p;
            }
          } else {
            debugPrint('⚠️  brew install tor failed: ${installResult.stderr}');
          }
        }
      } else if (Platform.isLinux) {
        // Try apt (Debian/Ubuntu)
        final aptCheck = await Process.run('which', ['apt-get']);
        if (aptCheck.exitCode == 0) {
          debugPrint('📦 Installing Tor via apt...');
          // Note: This might need sudo, which won't work non-interactively
          // unless the user has passwordless sudo for apt
          final result = await Process.run(
            'apt-get',
            ['install', '-y', 'tor'],
            runInShell: true,
          ).timeout(installTimeout);

          if (result.exitCode == 0) {
            return '/usr/bin/tor';
          }
        }

        // Try dnf (Fedora/RHEL)
        final dnfCheck = await Process.run('which', ['dnf']);
        if (dnfCheck.exitCode == 0) {
          debugPrint('📦 Installing Tor via dnf...');
          final result = await Process.run(
            'dnf',
            ['install', '-y', 'tor'],
            runInShell: true,
          ).timeout(installTimeout);

          if (result.exitCode == 0) {
            return '/usr/bin/tor';
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️  Auto-install failed: $e');
    }
    return null;
  }

  // ════════════════════════════════════════════════════════════════════════
  // AUTO-DOWNLOAD — Download Tor Expert Bundle from torproject.org
  // ════════════════════════════════════════════════════════════════════════

  /// Download Tor Expert Bundle and cache it locally
  Future<String?> _downloadAndCacheTor() async {
    try {
      final url = await _getTorDownloadUrl();
      if (url == null) {
        debugPrint('❌ No Tor download URL for ${Platform.operatingSystem}');
        return null;
      }

      final appDir = await getApplicationSupportDirectory();
      final torBinDir = path.join(appDir.path, 'tor_bin');
      await Directory(torBinDir).create(recursive: true);

      final downloadPath = path.join(torBinDir, 'tor-expert-bundle.tar.gz');

      debugPrint('📥 Downloading Tor Expert Bundle...');
      debugPrint('   URL: $url');

      // Download using system curl (more reliable for HTTPS)
      final curlResult = await Process.run(
        'curl',
        ['-L', '-o', downloadPath, '--connect-timeout', '30', url],
        runInShell: true,
      ).timeout(downloadTimeout);

      if (curlResult.exitCode != 0) {
        debugPrint('❌ Download failed: ${curlResult.stderr}');
        return null;
      }

      final downloadFile = File(downloadPath);
      if (!await downloadFile.exists() || await downloadFile.length() < 1000) {
        debugPrint('❌ Download appears incomplete or empty');
        return null;
      }

      debugPrint('📦 Extracting Tor binary...');

      // Extract the tarball
      final extractResult = await Process.run(
        'tar',
        ['xzf', downloadPath, '-C', torBinDir],
        runInShell: true,
      );

      if (extractResult.exitCode != 0) {
        debugPrint('❌ Extraction failed: ${extractResult.stderr}');
        return null;
      }

      // Find the tor binary in the extracted files
      final torBinary = await _findExtractedTorBinary(torBinDir);
      if (torBinary != null) {
        // Make executable
        if (!Platform.isWindows) {
          await Process.run('chmod', ['+x', torBinary]);
        }

        // Copy to a stable location
        final stableName = Platform.isWindows ? 'tor.exe' : 'tor';
        final stablePath = path.join(torBinDir, stableName);
        if (torBinary != stablePath) {
          await File(torBinary).copy(stablePath);
          await Process.run('chmod', ['+x', stablePath]);
        }

        // Clean up tarball
        try {
          await downloadFile.delete();
        } catch (e) {
          debugPrint('⚠️ Tarball cleanup failed: $e');
        }

        debugPrint('✅ Tor downloaded and cached: $stablePath');
        return stablePath;
      }

      debugPrint('❌ Could not find tor binary in extracted archive');
      return null;
    } catch (e) {
      debugPrint('❌ Download/extract failed: $e');
      return null;
    }
  }

  /// Get platform-specific Tor Expert Bundle download URL
  Future<String?> _getTorDownloadUrl() async {
    // Tor Expert Bundle 14.0.4 (stable as of early 2026)
    const version = '14.0.4';
    const base =
        'https://archive.torproject.org/tor-package-archive/torbrowser/$version';

    if (Platform.isMacOS) {
      // Detect ARM (Apple Silicon) vs Intel via uname -m
      String arch = 'aarch64'; // default to Apple Silicon
      try {
        final result = await Process.run('uname', ['-m']);
        if (result.exitCode == 0) {
          final uname = result.stdout.toString().trim();
          if (uname == 'x86_64') {
            arch = 'x86_64';
          }
        }
      } catch (_) {
        // Fallback to aarch64 (most common modern Mac)
      }
      return '$base/tor-expert-bundle-macos-$arch-$version.tar.gz';
    } else if (Platform.isLinux) {
      return '$base/tor-expert-bundle-linux-x86_64-$version.tar.gz';
    } else if (Platform.isWindows) {
      return '$base/tor-expert-bundle-windows-x86_64-$version.tar.gz';
    }
    return null;
  }

  /// Search for tor binary in extracted archive directory
  Future<String?> _findExtractedTorBinary(String dir) async {
    final binaryName = Platform.isWindows ? 'tor.exe' : 'tor';

    // Search recursively using find
    try {
      final result = await Process.run(
        'find',
        [dir, '-name', binaryName, '-type', 'f'],
      );
      if (result.exitCode == 0) {
        final paths = result.stdout.toString().trim().split('\n');
        for (final p in paths) {
          if (p.isNotEmpty && await File(p).exists()) {
            return p;
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ _findTorBinaryInDir find failed: $e');
    }

    // Manual search of common subdirectories
    final candidates = [
      path.join(dir, 'tor', binaryName),
      path.join(dir, binaryName),
      path.join(dir, 'tor-expert-bundle', 'tor', binaryName),
    ];

    for (final candidate in candidates) {
      if (await File(candidate).exists()) return candidate;
    }

    return null;
  }

  // ════════════════════════════════════════════════════════════════════════
  // TOR PROCESS MANAGEMENT — Start/stop with custom torrc
  // ════════════════════════════════════════════════════════════════════════

  /// Start a Tor process with custom configuration
  Future<bool> _startTorProcess(String torBinary) async {
    try {
      debugPrint('🚀 Starting Tor daemon...');
      debugPrint('   Binary: $torBinary');
      debugPrint('   SOCKS: localhost:$_socksPort');

      // Setup data directory
      final appDir = await getApplicationSupportDirectory();
      _torDataDir = path.join(appDir.path, 'tor_data');
      await Directory(_torDataDir!).create(recursive: true);

      // Create torrc
      final torrcPath = await _createTorrc();

      // Start Tor process
      _torProcess = await Process.start(
        torBinary,
        ['-f', torrcPath],
        runInShell: false,
      );

      // Monitor output for bootstrap completion
      _torProcess!.stdout.listen((data) {
        final output = String.fromCharCodes(data);
        if (output.contains('Bootstrapped 100%') ||
            output.contains('Tor has successfully opened a circuit')) {
          _isRunning = true;
          _activeProxy = 'localhost:$_socksPort';
          debugPrint('✅ Tor ready! SOCKS proxy: $_activeProxy');
        }
      });

      _torProcess!.stderr.listen((data) {
        final error = String.fromCharCodes(data);
        if (error.contains('error') || error.contains('Error')) {
          debugPrint('⚠️  Tor: $error');
        }
      });

      // Handle process exit
      _torProcess!.exitCode.then((code) {
        if (code != 0 && _isRunning) {
          debugPrint('⚠️  Tor process exited with code $code');
        }
        _isRunning = false;
      });

      // Wait for bootstrap (allow enough time for slow connections)
      final deadline = DateTime.now().add(bootstrapTimeout);
      while (!_isRunning && DateTime.now().isBefore(deadline)) {
        await Future.delayed(bootstrapPollInterval);
        // Also check if process died
        if (_torProcess == null) return false;
      }

      if (!_isRunning) {
        debugPrint('❌ Tor failed to bootstrap within 120 seconds');
        await stop();
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('❌ Failed to start Tor: $e');
      return false;
    }
  }

  /// Create torrc configuration file
  Future<String> _createTorrc() async {
    final torrcPath = path.join(_torDataDir!, 'torrc');
    final torrc = File(torrcPath);

    final config = '''
# LOS Wallet — Auto-managed Tor Configuration
# Generated automatically — do not edit manually

DataDirectory $_torDataDir
SocksPort $_socksPort
Log notice stdout

# Performance tuning for wallet
MaxCircuitDirtiness 600
MaxClientCircuitsPending 48
ConstrainedSockets 1

# Client-only mode (no relay)
DisableNetwork 0
ClientOnly 1
ExitRelay 0
ExitPolicy reject *:*

# Fast bootstrap
UseBridges 0
''';

    await torrc.writeAsString(config);
    return torrcPath;
  }

  // ════════════════════════════════════════════════════════════════════════
  // DETECTION — Find running Tor instances
  // ════════════════════════════════════════════════════════════════════════

  /// Detect existing Tor SOCKS proxies
  Future<Map<String, dynamic>> detectExistingTor() async {
    // Check LOS bundled Tor
    if (await _isPortOpen('localhost', bundledSocksPort)) {
      return {
        'found': true,
        'type': 'LOS Bundled Tor',
        'proxy': 'localhost:$bundledSocksPort'
      };
    }

    // Check Tor Browser
    if (await _isPortOpen('localhost', torBrowserPort)) {
      return {
        'found': true,
        'type': 'Tor Browser',
        'proxy': 'localhost:$torBrowserPort'
      };
    }

    // Check LOS testnet Tor
    if (await _isPortOpen('localhost', testnetTorPort)) {
      return {
        'found': true,
        'type': 'LOS Testnet Tor',
        'proxy': 'localhost:$testnetTorPort'
      };
    }

    // Check system Tor
    if (await _isPortOpen('localhost', systemTorPort)) {
      return {
        'found': true,
        'type': 'System Tor',
        'proxy': 'localhost:$systemTorPort'
      };
    }

    return {'found': false};
  }

  /// Check if a port is open (for detecting existing Tor)
  Future<bool> _isPortOpen(String host, int port) async {
    try {
      final socket = await Socket.connect(
        host,
        port,
        timeout: const Duration(seconds: 2),
      );
      socket.destroy();
      return true;
    } catch (e) {
      return false;
    }
  }
}
