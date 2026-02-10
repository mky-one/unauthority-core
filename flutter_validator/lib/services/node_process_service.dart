import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

/// Manages the uat-node validator process lifecycle.
///
/// Responsibilities:
/// - Locate the uat-node binary (auto-detect or user-specified path)
/// - Start/stop the validator node process
/// - Stream stdout/stderr logs
/// - Monitor node health via REST API
/// - Persist configuration across app restarts
class NodeProcessService extends ChangeNotifier {
  // ── Persistent config keys ─────────────────────────────────────────
  static const _keyBinaryPath = 'node_binary_path';
  static const _keyNodeId = 'node_id';
  static const _keyRestPort = 'node_rest_port';
  static const _keyP2pPort = 'node_p2p_port';
  static const _keyBootstrapNodes = 'node_bootstrap_nodes';
  static const _keyDataDir = 'node_data_dir';
  static const _keySetupComplete = 'node_setup_complete';
  static const _keyTestnetLevel = 'node_testnet_level';
  static const _keyTorSocksPort = 'node_tor_socks_port';

  // ── State ──────────────────────────────────────────────────────────
  NodeStatus _status = NodeStatus.stopped;
  NodeStatus get status => _status;

  String? _binaryPath;
  String? get binaryPath => _binaryPath;

  String _nodeId = 'my-validator';
  String get nodeId => _nodeId;

  int _restPort = 3535;
  int get restPort => _restPort;

  int _p2pPort = 4005;
  int get p2pPort => _p2pPort;

  String _bootstrapNodes = '';
  String get bootstrapNodes => _bootstrapNodes;

  String _dataDir = '';
  String get dataDir => _dataDir;

  String _testnetLevel = 'functional';
  String get testnetLevel => _testnetLevel;

  int _torSocksPort = 9050;
  int get torSocksPort => _torSocksPort;

  bool _setupComplete = false;
  bool get setupComplete => _setupComplete;

  String? _nodeAddress;
  String? get nodeAddress => _nodeAddress;

  int? _nodePid;
  int? get nodePid => _nodePid;

  final List<String> _logs = [];
  List<String> get logs => List.unmodifiable(_logs);

  String? _lastError;
  String? get lastError => _lastError;

  // ── Internal ───────────────────────────────────────────────────────
  Process? _process;
  Timer? _healthTimer;
  StreamSubscription? _stdoutSub;
  StreamSubscription? _stderrSub;

  // ── Default testnet bootstrap nodes (.onion via Tor) ───────────────
  static const defaultBootstrapNodes = [
    '/ip4/127.0.0.1/tcp/4001',
    '/ip4/127.0.0.1/tcp/4002',
    '/ip4/127.0.0.1/tcp/4003',
    '/ip4/127.0.0.1/tcp/4004',
  ];

  // ══════════════════════════════════════════════════════════════════
  // INITIALIZATION
  // ══════════════════════════════════════════════════════════════════

  /// Load persisted configuration from SharedPreferences.
  Future<void> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    _binaryPath = prefs.getString(_keyBinaryPath);
    _nodeId = prefs.getString(_keyNodeId) ?? 'my-validator';
    _restPort = prefs.getInt(_keyRestPort) ?? 3535;
    _p2pPort = prefs.getInt(_keyP2pPort) ?? 4005;
    _bootstrapNodes = prefs.getString(_keyBootstrapNodes) ?? '';
    _dataDir = prefs.getString(_keyDataDir) ?? '';
    _testnetLevel = prefs.getString(_keyTestnetLevel) ?? 'functional';
    _torSocksPort = prefs.getInt(_keyTorSocksPort) ?? 9050;
    _setupComplete = prefs.getBool(_keySetupComplete) ?? false;

    // Auto-detect binary if not set
    if (_binaryPath == null || _binaryPath!.isEmpty) {
      _binaryPath = await _autoDetectBinary();
    }

    // Set default data dir
    if (_dataDir.isEmpty) {
      final home = Platform.environment['HOME'] ?? '/tmp';
      _dataDir = p.join(home, '.uat-validator');
    }

    // Set default bootstrap nodes
    if (_bootstrapNodes.isEmpty) {
      _bootstrapNodes = defaultBootstrapNodes.join(',');
    }

    debugPrint(
        '🟢 [NodeProcess] Config loaded: binary=$_binaryPath, port=$_restPort, p2p=$_p2pPort');
    notifyListeners();
  }

  /// Persist current configuration.
  Future<void> saveConfig() async {
    final prefs = await SharedPreferences.getInstance();
    if (_binaryPath != null) prefs.setString(_keyBinaryPath, _binaryPath!);
    prefs.setString(_keyNodeId, _nodeId);
    prefs.setInt(_keyRestPort, _restPort);
    prefs.setInt(_keyP2pPort, _p2pPort);
    prefs.setString(_keyBootstrapNodes, _bootstrapNodes);
    prefs.setString(_keyDataDir, _dataDir);
    prefs.setString(_keyTestnetLevel, _testnetLevel);
    prefs.setInt(_keyTorSocksPort, _torSocksPort);
    debugPrint('💾 [NodeProcess] Config saved');
  }

  Future<void> markSetupComplete() async {
    _setupComplete = true;
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool(_keySetupComplete, true);
    notifyListeners();
  }

  // ══════════════════════════════════════════════════════════════════
  // CONFIGURATION SETTERS
  // ══════════════════════════════════════════════════════════════════

  void setBinaryPath(String path) {
    _binaryPath = path;
    notifyListeners();
  }

  void setNodeId(String id) {
    _nodeId = id;
    notifyListeners();
  }

  void setRestPort(int port) {
    _restPort = port;
    notifyListeners();
  }

  void setP2pPort(int port) {
    _p2pPort = port;
    notifyListeners();
  }

  void setBootstrapNodes(String nodes) {
    _bootstrapNodes = nodes;
    notifyListeners();
  }

  void setTestnetLevel(String level) {
    _testnetLevel = level;
    notifyListeners();
  }

  void setTorSocksPort(int port) {
    _torSocksPort = port;
    notifyListeners();
  }

  // ══════════════════════════════════════════════════════════════════
  // BINARY DETECTION
  // ══════════════════════════════════════════════════════════════════

  /// Search common locations for the uat-node binary.
  Future<String?> _autoDetectBinary() async {
    final candidates = <String>[
      // Relative to workspace (if running from project root)
      'target/release/uat-node',
      '../target/release/uat-node',
      '../../target/release/uat-node',
      // Home directory
      '${Platform.environment['HOME']}/.uat/bin/uat-node',
      '${Platform.environment['HOME']}/.cargo/bin/uat-node',
      // System paths
      '/usr/local/bin/uat-node',
      '/usr/bin/uat-node',
      // macOS app bundle
      '${Platform.resolvedExecutable.replaceAll(RegExp(r'/[^/]+$'), '')}/uat-node',
    ];

    for (final path in candidates) {
      final file = File(path);
      if (await file.exists()) {
        debugPrint('🔍 [NodeProcess] Found binary at: $path');
        return file.absolute.path;
      }
    }

    // Try `which uat-node`
    try {
      final result = await Process.run('which', ['uat-node']);
      if (result.exitCode == 0) {
        final path = (result.stdout as String).trim();
        if (path.isNotEmpty) {
          debugPrint('🔍 [NodeProcess] Found binary via which: $path');
          return path;
        }
      }
    } catch (_) {}

    debugPrint('⚠️ [NodeProcess] Binary not found in auto-detect paths');
    return null;
  }

  /// Check if a given path is a valid uat-node binary.
  Future<bool> validateBinary(String path) async {
    final file = File(path);
    if (!await file.exists()) return false;

    // Check if executable
    try {
      final stat = await file.stat();
      // On Unix, check execute permission
      if (Platform.isLinux || Platform.isMacOS) {
        final mode = stat.mode;
        if (mode & 0x49 == 0) return false; // No execute bits
      }
    } catch (_) {
      return false;
    }

    return true;
  }

  /// Attempt to build the binary from source using cargo.
  Future<bool> buildBinary({required String projectRoot}) async {
    _addLog('🔨 Building uat-node binary from source...');
    _addLog('   This may take several minutes on first build.');
    _status = NodeStatus.building;
    notifyListeners();

    try {
      final result = await Process.run(
        'cargo',
        ['build', '--release', '-p', 'uat-node'],
        workingDirectory: projectRoot,
        environment: {'CARGO_TERM_COLOR': 'never'},
      );

      if (result.exitCode == 0) {
        final builtPath = p.join(projectRoot, 'target', 'release', 'uat-node');
        if (await File(builtPath).exists()) {
          _binaryPath = builtPath;
          _addLog('✅ Build successful: $builtPath');
          _status = NodeStatus.stopped;
          notifyListeners();
          return true;
        }
      }

      _addLog('❌ Build failed: ${result.stderr}');
      _status = NodeStatus.stopped;
      _lastError = 'Build failed. Is Rust/Cargo installed?';
      notifyListeners();
      return false;
    } catch (e) {
      _addLog('❌ Build error: $e');
      _status = NodeStatus.stopped;
      _lastError = 'Cargo not found. Install Rust: https://rustup.rs';
      notifyListeners();
      return false;
    }
  }

  // ══════════════════════════════════════════════════════════════════
  // NODE LIFECYCLE
  // ══════════════════════════════════════════════════════════════════

  /// Start the validator node process.
  Future<bool> startNode() async {
    if (_status == NodeStatus.running) {
      _addLog('⚠️ Node already running');
      return true;
    }

    if (_binaryPath == null || !await validateBinary(_binaryPath!)) {
      _lastError = 'uat-node binary not found or not executable';
      _addLog('❌ $_lastError');
      notifyListeners();
      return false;
    }

    _status = NodeStatus.starting;
    _lastError = null;
    notifyListeners();

    // Ensure data directory exists
    final dataDir = Directory(p.join(_dataDir, _nodeId));
    if (!await dataDir.exists()) {
      await dataDir.create(recursive: true);
    }

    // Build environment variables
    final env = <String, String>{
      'UAT_NODE_ID': _nodeId,
      'UAT_P2P_PORT': _p2pPort.toString(),
      'UAT_TESTNET_LEVEL': _testnetLevel,
    };

    if (_bootstrapNodes.isNotEmpty) {
      env['UAT_BOOTSTRAP_NODES'] = _bootstrapNodes;
    }

    if (_torSocksPort > 0) {
      env['UAT_TOR_SOCKS5'] = '127.0.0.1:$_torSocksPort';
    }

    _addLog('▶️ Starting node: $_binaryPath $_restPort');
    _addLog('   Node ID: $_nodeId');
    _addLog('   P2P Port: $_p2pPort');
    _addLog('   REST Port: $_restPort');
    _addLog('   Testnet Level: $_testnetLevel');
    _addLog(
        '   Bootstrap: ${_bootstrapNodes.isNotEmpty ? _bootstrapNodes.split(",").length : 0} peers');
    _addLog('   Data Dir: ${dataDir.path}');
    _addLog('');

    try {
      // Find the project root (parent of the binary's target/release dir)
      final binaryDir = p.dirname(_binaryPath!);
      String workingDir;
      if (binaryDir.endsWith('target/release') ||
          binaryDir.endsWith('target\\release')) {
        workingDir = p.dirname(p.dirname(binaryDir)); // Go up to project root
      } else {
        workingDir = _dataDir;
      }

      _process = await Process.start(
        _binaryPath!,
        [_restPort.toString()],
        environment: env,
        workingDirectory: workingDir,
      );

      _nodePid = _process!.pid;
      _addLog('   PID: $_nodePid');

      // Stream stdout
      _stdoutSub = _process!.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        _addLog(line);

        // Capture node address from startup logs
        if (line.contains('Address:') || line.contains('UAT address:')) {
          final match = RegExp(r'UAT[A-Za-z0-9]{20,}').firstMatch(line);
          if (match != null) {
            _nodeAddress = match.group(0);
            debugPrint('📍 [NodeProcess] Node address: $_nodeAddress');
            notifyListeners();
          }
        }
      });

      // Stream stderr
      _stderrSub = _process!.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        _addLog('⚠ $line');
      });

      // Watch for process exit
      _process!.exitCode.then((code) {
        _addLog('');
        _addLog('⏹ Node process exited with code: $code');
        _status = NodeStatus.stopped;
        _process = null;
        _nodePid = null;
        _healthTimer?.cancel();
        notifyListeners();
      });

      // Start health monitoring (check every 5 seconds)
      _startHealthMonitor();

      return true;
    } catch (e) {
      _lastError = 'Failed to start node: $e';
      _addLog('❌ $_lastError');
      _status = NodeStatus.stopped;
      notifyListeners();
      return false;
    }
  }

  /// Stop the validator node process.
  Future<void> stopNode() async {
    _healthTimer?.cancel();
    _stdoutSub?.cancel();
    _stderrSub?.cancel();

    if (_process != null) {
      _addLog('');
      _addLog('⏹ Stopping node (PID: $_nodePid)...');
      _process!.kill(ProcessSignal.sigterm);

      // Wait up to 5 seconds for graceful shutdown
      bool exited = false;
      for (int i = 0; i < 10; i++) {
        await Future.delayed(const Duration(milliseconds: 500));
        try {
          // Check if process is still running
          final result = Process.killPid(_nodePid!, ProcessSignal.sigcont);
          if (!result) {
            exited = true;
            break;
          }
        } catch (_) {
          exited = true;
          break;
        }
      }

      if (!exited) {
        _addLog('⚠ Force killing node...');
        _process!.kill(ProcessSignal.sigkill);
      }

      _addLog('✅ Node stopped');
    }

    _process = null;
    _nodePid = null;
    _status = NodeStatus.stopped;
    _nodeAddress = null;
    notifyListeners();
  }

  /// Health monitoring — polls REST API to confirm node is responsive.
  void _startHealthMonitor() {
    _healthTimer?.cancel();
    _healthTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      await _checkHealth();
    });
    // Immediate first check after short delay
    Future.delayed(const Duration(seconds: 3), _checkHealth);
  }

  Future<void> _checkHealth() async {
    try {
      final resp = await http
          .get(
            Uri.parse('http://127.0.0.1:$_restPort/health'),
          )
          .timeout(const Duration(seconds: 3));

      if (resp.statusCode == 200) {
        if (_status != NodeStatus.running) {
          _status = NodeStatus.running;
          _addLog('');
          _addLog('✅ Node is HEALTHY and responding on port $_restPort');

          // Fetch node address from API
          await _fetchNodeAddress();
          notifyListeners();
        }
      }
    } catch (_) {
      // Node not yet responding — still starting
      if (_status == NodeStatus.starting) {
        // Still waiting for startup
      }
    }
  }

  Future<void> _fetchNodeAddress() async {
    try {
      final resp = await http
          .get(
            Uri.parse('http://127.0.0.1:$_restPort/node-info'),
          )
          .timeout(const Duration(seconds: 3));

      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        _nodeAddress = data['address'] ?? data['my_address'];
        if (_nodeAddress != null) {
          _addLog('📍 Node address: $_nodeAddress');
          notifyListeners();
        }
      }
    } catch (_) {}
  }

  /// Request faucet tokens for the node's address.
  /// Can target a bootstrap node or the local node.
  Future<Map<String, dynamic>> requestFaucet({String? targetHost}) async {
    final host = targetHost ?? 'http://127.0.0.1:$_restPort';
    final address = _nodeAddress;

    if (address == null) {
      return {'error': 'Node address not yet known. Wait for node to start.'};
    }

    _addLog('💰 Requesting faucet for $address from $host...');

    try {
      final resp = await http
          .post(
            Uri.parse('$host/faucet'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'address': address}),
          )
          .timeout(const Duration(seconds: 10));

      final data = json.decode(resp.body);
      if (resp.statusCode == 200 && data['status'] == 'success') {
        _addLog('✅ Faucet success: ${data['amount']} UAT');
      } else {
        _addLog('⚠ Faucet response: ${resp.body}');
      }
      notifyListeners();
      return data;
    } catch (e) {
      _addLog('❌ Faucet error: $e');
      return {'error': e.toString()};
    }
  }

  /// Get the node's current balance.
  Future<int> getNodeBalance() async {
    if (_nodeAddress == null) return 0;

    try {
      final resp = await http
          .get(
            Uri.parse('http://127.0.0.1:$_restPort/balance/$_nodeAddress'),
          )
          .timeout(const Duration(seconds: 3));

      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        // Balance is in VOID, convert to UAT
        final balance = data['balance'] ?? data['balance_void'] ?? 0;
        if (balance is int) {
          return balance ~/ 100000000000; // VOID_PER_UAT = 10^11
        }
      }
    } catch (_) {}
    return 0;
  }

  // ══════════════════════════════════════════════════════════════════
  // LOG MANAGEMENT
  // ══════════════════════════════════════════════════════════════════

  void _addLog(String line) {
    _logs.add(line);

    // Keep last 2000 lines to prevent memory bloat
    if (_logs.length > 2000) {
      _logs.removeRange(0, _logs.length - 1500);
    }

    // Notify periodically (not every single line for performance)
    // The UI will refresh on notifyListeners calls in health check / status changes
  }

  void clearLogs() {
    _logs.clear();
    notifyListeners();
  }

  // ══════════════════════════════════════════════════════════════════
  // CLEANUP
  // ══════════════════════════════════════════════════════════════════

  @override
  void dispose() {
    _healthTimer?.cancel();
    _stdoutSub?.cancel();
    _stderrSub?.cancel();
    if (_process != null) {
      _process!.kill(ProcessSignal.sigterm);
    }
    super.dispose();
  }
}

// ── Node Status Enum ──────────────────────────────────────────────────
enum NodeStatus {
  stopped,
  starting,
  running,
  building,
  error;

  String get label {
    switch (this) {
      case NodeStatus.stopped:
        return 'Stopped';
      case NodeStatus.starting:
        return 'Starting...';
      case NodeStatus.running:
        return 'Running';
      case NodeStatus.building:
        return 'Building...';
      case NodeStatus.error:
        return 'Error';
    }
  }

  bool get isActive =>
      this == NodeStatus.running || this == NodeStatus.starting;
}
