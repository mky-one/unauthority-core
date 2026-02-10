// Network Status Service - Monitors blockchain connection and sync status
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'api_service.dart';

enum ConnectionStatus {
  connected,
  disconnected,
  connecting,
  error,
}

class NetworkStatusService extends ChangeNotifier {
  final ApiService _apiService;

  ConnectionStatus _status = ConnectionStatus.disconnected;
  String _networkType = 'Unknown';
  int _blockHeight = 0;
  int _peerCount = 0;
  String _nodeVersion = '0.0.0';
  DateTime? _lastSyncTime;
  String? _errorMessage;

  Timer? _statusCheckTimer;

  NetworkStatusService(this._apiService) {
    _startStatusChecking();
  }

  // Getters
  ConnectionStatus get status => _status;
  String get networkType => _networkType;
  int get blockHeight => _blockHeight;
  int get peerCount => _peerCount;
  String get nodeVersion => _nodeVersion;
  DateTime? get lastSyncTime => _lastSyncTime;
  String? get errorMessage => _errorMessage;

  bool get isConnected => _status == ConnectionStatus.connected;
  bool get isDisconnected => _status == ConnectionStatus.disconnected;
  bool get isConnecting => _status == ConnectionStatus.connecting;
  bool get hasError => _status == ConnectionStatus.error;

  String get statusText {
    switch (_status) {
      case ConnectionStatus.connected:
        return 'Connected';
      case ConnectionStatus.disconnected:
        return 'Disconnected';
      case ConnectionStatus.connecting:
        return 'Connecting...';
      case ConnectionStatus.error:
        return 'Error';
    }
  }

  void _startStatusChecking() {
    // Check immediately
    _checkNetworkStatus();

    // Then check every 10 seconds
    _statusCheckTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _checkNetworkStatus(),
    );
  }

  Future<void> _checkNetworkStatus() async {
    try {
      _status = ConnectionStatus.connecting;
      notifyListeners();

      // Check health endpoint
      final health = await _apiService.getHealth();

      if (health['status'] == 'healthy' || health['status'] == 'degraded') {
        _status = ConnectionStatus.connected;
        _errorMessage = null;
        _lastSyncTime = DateTime.now();

        // Extract network info
        if (health['chain'] != null) {
          _blockHeight = health['chain']['blocks'] ?? 0;
        }

        // Get node info for more details
        try {
          final nodeInfo = await _apiService.getNodeInfo();
          _networkType = _extractNetworkType(nodeInfo['chain_id'] ?? 'unknown');
          _nodeVersion = nodeInfo['version'] ?? '0.0.0';
          _peerCount = nodeInfo['peer_count'] ?? 0;
          _blockHeight = nodeInfo['block_height'] ?? _blockHeight;
        } catch (e) {
          // Node info failed but health passed, still connected
          debugPrint('⚠️ Node info failed: $e');
        }
      } else {
        _status = ConnectionStatus.error;
        _errorMessage = 'Node unhealthy';
      }

      notifyListeners();
    } catch (e) {
      _status = ConnectionStatus.disconnected;
      _errorMessage = 'Connection failed: ${e.toString()}';
      notifyListeners();
    }
  }

  String _extractNetworkType(String chainId) {
    if (chainId.contains('mainnet')) {
      return 'Mainnet';
    } else if (chainId.contains('testnet')) {
      return 'Testnet';
    } else {
      return 'Unknown';
    }
  }

  /// Manually trigger a status check
  Future<void> refresh() async {
    await _checkNetworkStatus();
  }

  @override
  void dispose() {
    _statusCheckTimer?.cancel();
    super.dispose();
  }
}
