import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

/// Node lifecycle states
enum NodeStatus {
  stopped, // Not running
  starting, // Process spawned, waiting for ready
  syncing, // Connected to peers, syncing blocks
  running, // Fully operational, participating in consensus
  stopping, // Graceful shutdown in progress
  error, // Crashed or failed to start
}

/// Manages the uat-node binary process lifecycle.
///
/// Responsibilities:
/// - Find or bundle the uat-node binary
/// - Launch with correct CLI args (--port, --data-dir, --json-log, etc.)
/// - Monitor process stdout for structured JSON events
/// - Track node status (starting → syncing → running)
/// - Graceful shutdown / restart
/// - Auto-restart on crash
class NodeProcessService extends ChangeNotifier {
  Process? _process;
  NodeStatus _status = NodeStatus.stopped;
  String? _nodeAddress; // Node's UATX... address
  String? _onionAddress; // .onion hidden service address
  int _apiPort = 3035;
  String? _dataDir;
  String? _errorMessage;
  final List<String> _logs = [];
  static const int _maxLogLines = 500;

  // Auto-restart
  int _crashCount = 0;
  static const int _maxAutoRestarts = 5;
  Timer? _restartTimer;

  // Getters
  NodeStatus get status => _status;
  String? get nodeAddress => _nodeAddress;
  String? get onionAddress => _onionAddress;
  int get apiPort => _apiPort;
  String? get dataDir => _dataDir;
  String? get errorMessage => _errorMessage;
  List<String> get logs => List.unmodifiable(_logs);
  bool get isRunning =>
      _status == NodeStatus.running || _status == NodeStatus.syncing;
  bool get isStopped =>
      _status == NodeStatus.stopped || _status == NodeStatus.error;

  String get localApiUrl => 'http://127.0.0.1:$_apiPort';

  /// Kill any orphaned uat-node that survived a Flutter hot-reload.
  /// Uses lsof to find the process occupying [port] and kills it.
  Future<void> _killOrphanedNode(int port) async {
    try {
      // Find PID listening on target port
      final result = await Process.run(
        'lsof',
        ['-ti', 'tcp:$port'],
      );
      final pids = (result.stdout as String)
          .trim()
          .split('\n')
          .where((s) => s.isNotEmpty);
      for (final pidStr in pids) {
        final pid = int.tryParse(pidStr.trim());
        if (pid != null) {
          debugPrint('🧹 Killing orphaned process on port $port (PID $pid)');
          Process.killPid(pid, ProcessSignal.sigterm);
        }
      }
      if (pids.isNotEmpty) {
        await Future.delayed(const Duration(seconds: 2));
      }
    } catch (e) {
      debugPrint('⚠️ _killOrphanedNode: $e');
    }
  }

  /// Find an available port starting from [preferred].
  /// Returns the first port that's not already in use.
  static Future<int> findAvailablePort({int preferred = 3035}) async {
    for (int port = preferred; port < preferred + 20; port++) {
      try {
        final socket = await ServerSocket.bind(
          InternetAddress.loopbackIPv4,
          port,
          shared: false,
        );
        await socket.close();
        return port;
      } catch (_) {
        // Port in use, try next
      }
    }
    return preferred; // Fallback
  }

  /// Start the uat-node process.
  ///
  /// [port] — REST API port (default 3035, auto-detects if occupied)
  /// [onionAddress] — Pre-configured .onion address (from Tor hidden service)
  /// [bootstrapNodes] — Comma-separated list of bootstrap node addresses
  /// [walletPassword] — Encryption password for the node wallet
  /// [testnetLevel] — Testnet level: 'functional', 'consensus', or 'production'
  ///                  Defaults to 'consensus' (Level 2) for real multi-node testing.
  ///                  Use 'functional' ONLY for local single-node dev.
  Future<bool> start({
    int port = 3035,
    String? onionAddress,
    String? bootstrapNodes,
    String? walletPassword,
    String testnetLevel = 'consensus',
  }) async {
    if (_status == NodeStatus.starting || _status == NodeStatus.running) {
      debugPrint('⚠️ Node already running or starting');
      return false;
    }

    _apiPort = port;
    _status = NodeStatus.starting;
    _errorMessage = null;
    notifyListeners();

    try {
      // 0. Kill any orphaned uat-node on the target port (survives hot-reload)
      await _killOrphanedNode(port);

      // 1. Find uat-node binary
      final binaryPath = await _findNodeBinary();
      if (binaryPath == null) {
        _setError(
            'uat-node binary not found. Please build with: cargo build --release -p uat-node');
        return false;
      }

      // 2. Setup data directory
      _dataDir = await _getDataDir();
      await Directory(_dataDir!).create(recursive: true);

      // 3. Build environment variables
      // testnetLevel controls security posture:
      //   'functional' = Level 1 (no consensus, no sig check — dev only)
      //   'consensus'  = Level 2 (real aBFT, real signatures — default)
      //   'production' = Level 3 (identical to mainnet — full security)
      final env = <String, String>{
        'UAT_TESTNET_LEVEL': testnetLevel,
      };
      if (onionAddress != null) {
        env['UAT_ONION_ADDRESS'] = onionAddress;
        _onionAddress = onionAddress;
      }
      if (bootstrapNodes != null) {
        env['UAT_BOOTSTRAP_NODES'] = bootstrapNodes;
      }
      if (walletPassword != null && walletPassword.isNotEmpty) {
        env['UAT_WALLET_PASSWORD'] = walletPassword;
      }

      // 4. Build CLI args
      final args = <String>[
        '--port',
        port.toString(),
        '--data-dir',
        _dataDir!,
        '--node-id',
        'flutter-validator',
        '--json-log',
      ];

      debugPrint('🚀 Starting uat-node: $binaryPath ${args.join(' ')}');
      _addLog('Starting uat-node on port $port...');

      // 5. Spawn process
      _process = await Process.start(
        binaryPath,
        args,
        environment: env,
        workingDirectory: await _getWorkingDir(),
      );

      // 6. Monitor stdout for JSON events + human-readable logs
      _process!.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
            _handleStdout,
            onError: (e) => debugPrint('⚠️ stdout error: $e'),
          );

      _process!.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
            _handleStderr,
            onError: (e) => debugPrint('⚠️ stderr error: $e'),
          );

      // 7. Monitor process exit
      _process!.exitCode.then(_handleProcessExit);

      // 8. Wait for node_ready event (max 60s)
      final ready = await _waitForReady(timeout: const Duration(seconds: 60));
      if (!ready) {
        _setError('Node failed to start within 60 seconds');
        await stop();
        return false;
      }

      _crashCount = 0; // Reset crash counter on successful start
      return true;
    } catch (e) {
      _setError('Failed to start node: $e');
      return false;
    }
  }

  /// Graceful shutdown
  Future<void> stop() async {
    if (_process == null) return;

    _restartTimer?.cancel();
    _status = NodeStatus.stopping;
    notifyListeners();
    _addLog('Stopping node...');

    try {
      // Send SIGTERM for graceful shutdown
      _process!.kill(ProcessSignal.sigterm);

      // Wait up to 10s for graceful exit
      final exitCode = await _process!.exitCode.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('⚠️ Node did not exit in 10s, sending SIGKILL');
          _process!.kill(ProcessSignal.sigkill);
          return -1;
        },
      );

      debugPrint('🛑 Node exited with code $exitCode');
      _addLog('Node stopped (exit code: $exitCode)');
    } catch (e) {
      debugPrint('⚠️ Error stopping node: $e');
      _process?.kill(ProcessSignal.sigkill);
    }

    _process = null;
    _status = NodeStatus.stopped;
    notifyListeners();
  }

  /// Force restart
  Future<bool> restart({
    String? onionAddress,
    String? bootstrapNodes,
    String? walletPassword,
  }) async {
    await stop();
    await Future.delayed(const Duration(seconds: 2));
    return start(
      port: _apiPort,
      onionAddress: onionAddress ?? _onionAddress,
      bootstrapNodes: bootstrapNodes,
      walletPassword: walletPassword,
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  // PROCESS OUTPUT HANDLING
  // ════════════════════════════════════════════════════════════════════════

  void _handleStdout(String line) {
    _addLog(line);

    // Try to parse as JSON event
    if (line.startsWith('{')) {
      try {
        final event = json.decode(line) as Map<String, dynamic>;
        _handleJsonEvent(event);
        return;
      } catch (_) {
        // Not JSON, treat as regular log
      }
    }

    // Fallback: detect key messages from human-readable output
    if (line.contains('API Server running at')) {
      _status = NodeStatus.running;
      notifyListeners();
    }
  }

  void _handleStderr(String line) {
    _addLog('[ERR] $line');
    if (line.contains('FATAL') || line.contains('❌')) {
      _setError(line);
    }
  }

  void _handleJsonEvent(Map<String, dynamic> event) {
    final type = event['event'] as String?;
    switch (type) {
      case 'init':
        _addLog('📂 Data dir: ${event['data_dir']}');
        break;
      case 'wallet_ready':
        _nodeAddress = event['address'] as String?;
        _addLog('🔑 Node address: $_nodeAddress');
        notifyListeners();
        break;
      case 'node_ready':
        _nodeAddress = event['address'] as String?;
        final onion = event['onion'] as String?;
        if (onion != null && onion != 'none') {
          _onionAddress = onion;
        }
        _status = NodeStatus.running;
        _addLog('✅ Node is running!');
        notifyListeners();
        break;
      default:
        debugPrint('Unknown JSON event: $type');
    }
  }

  void _handleProcessExit(int exitCode) {
    debugPrint('💀 uat-node exited with code $exitCode');
    _addLog('⚠️ Node process exited (code: $exitCode)');

    if (_status == NodeStatus.stopping || _status == NodeStatus.stopped) {
      // Intentional shutdown
      _status = NodeStatus.stopped;
    } else {
      // Unexpected crash — auto-restart
      _status = NodeStatus.error;
      _crashCount++;

      if (_crashCount <= _maxAutoRestarts) {
        final delay =
            Duration(seconds: _crashCount * 5); // Backoff: 5s, 10s, 15s...
        _addLog(
            '🔄 Auto-restart in ${delay.inSeconds}s (attempt $_crashCount/$_maxAutoRestarts)');
        _restartTimer = Timer(delay, () {
          start(port: _apiPort, onionAddress: _onionAddress);
        });
      } else {
        _setError(
            'Node crashed $_crashCount times. Stopped auto-restart. Check logs.');
      }
    }

    _process = null;
    notifyListeners();
  }

  Future<bool> _waitForReady({required Duration timeout}) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      if (_status == NodeStatus.running) return true;
      if (_status == NodeStatus.error) return false;
      await Future.delayed(const Duration(milliseconds: 500));
    }
    return false;
  }

  // ════════════════════════════════════════════════════════════════════════
  // BINARY DISCOVERY
  // ════════════════════════════════════════════════════════════════════════

  /// Find uat-node binary — checks bundled location, cargo build output, PATH
  Future<String?> _findNodeBinary() async {
    final binaryName = Platform.isWindows ? 'uat-node.exe' : 'uat-node';

    // 1. Check bundled in app (for distribution)
    final execDir = path.dirname(Platform.resolvedExecutable);
    final bundledPaths = [
      path.join(execDir, binaryName), // Linux/Windows: same dir as executable
      path.join(execDir, '..', 'Resources', binaryName), // macOS: Resources/
      path.join(execDir, '..', 'Resources', 'bin',
          binaryName), // macOS: Resources/bin/
      path.join(execDir, '..', 'MacOS', binaryName), // macOS: MacOS/ (alt)
    ];
    for (final p in bundledPaths) {
      if (await File(p).exists()) {
        debugPrint('✅ Found bundled uat-node: $p');
        return p;
      }
    }

    // 2. Check cargo build output (development mode)
    final workDir = await _getWorkingDir();
    final cargoPaths = [
      path.join(workDir, 'target', 'release', binaryName),
      path.join(workDir, 'target', 'debug', binaryName),
    ];
    for (final p in cargoPaths) {
      if (await File(p).exists()) {
        debugPrint('✅ Found cargo-built uat-node: $p');
        return p;
      }
    }

    // 3. Check PATH
    try {
      final cmd = Platform.isWindows ? 'where' : 'which';
      final result = await Process.run(cmd, [binaryName]);
      if (result.exitCode == 0) {
        final p = result.stdout.toString().trim().split('\n').first;
        if (p.isNotEmpty && await File(p).exists()) {
          debugPrint('✅ Found uat-node in PATH: $p');
          return p;
        }
      }
    } catch (_) {}

    debugPrint('❌ uat-node binary not found anywhere');
    return null;
  }

  /// Get the workspace root (for cargo builds in dev mode)
  Future<String> _getWorkingDir() async {
    // Walk up from the executable to find Cargo.toml
    var dir = Directory(path.dirname(Platform.resolvedExecutable));
    for (var i = 0; i < 6; i++) {
      final cargoToml = File(path.join(dir.path, 'Cargo.toml'));
      if (await cargoToml.exists()) {
        return dir.path;
      }
      dir = dir.parent;
    }

    // Fallback: check common dev paths
    final home = Platform.environment['HOME'] ?? '/tmp';
    final devPaths = [
      path.join(home, 'Documents', 'monkey-one', 'project', 'unauthority-core'),
      path.join(home, 'unauthority-core'),
      Directory.current.path,
    ];

    for (final p in devPaths) {
      if (await File(path.join(p, 'Cargo.toml')).exists()) {
        return p;
      }
    }

    return Directory.current.path;
  }

  /// Get persistent data directory for the node
  Future<String> _getDataDir() async {
    final appDir = await getApplicationSupportDirectory();
    return path.join(appDir.path, 'validator-node');
  }

  // ════════════════════════════════════════════════════════════════════════
  // LOG MANAGEMENT
  // ════════════════════════════════════════════════════════════════════════

  void _addLog(String msg) {
    final timestamp = DateTime.now().toIso8601String().substring(11, 19);
    _logs.add('[$timestamp] $msg');
    while (_logs.length > _maxLogLines) {
      _logs.removeAt(0);
    }
    // Don't notifyListeners() for every log line — batch via Timer
  }

  void _setError(String msg) {
    _errorMessage = msg;
    _status = NodeStatus.error;
    _addLog('❌ $msg');
    notifyListeners();
  }

  @override
  void dispose() {
    _restartTimer?.cancel();
    stop();
    super.dispose();
  }
}
