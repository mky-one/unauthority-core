import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:socks5_proxy/socks_client.dart';
import '../models/account.dart';
import '../constants/blockchain.dart';
import 'tor_service.dart';
import 'network_config.dart';
import 'peer_discovery_service.dart';

enum NetworkEnvironment { testnet, mainnet }

class ApiService {
  // Bootstrap node addresses are loaded from assets/network_config.json
  // via NetworkConfig. NEVER hardcode .onion addresses here.
  // Use: scripts/update_network_config.sh to update addresses.

  /// Default timeout for API calls
  static const Duration _defaultTimeout = Duration(seconds: 30);

  /// Longer timeout for Tor connections (15s is enough — Tor circuits complete in 5-10s)
  static const Duration _torTimeout = Duration(seconds: 15);

  /// Max retry attempts across bootstrap nodes before giving up
  static const int _maxRetries = 4;

  late String baseUrl;
  http.Client _client = http.Client();
  NetworkEnvironment environment;
  final TorService _torService = TorService();

  /// All available bootstrap URLs for round-robin failover
  List<String> _bootstrapUrls = [];

  /// Index of the currently active bootstrap node
  int _currentNodeIndex = 0;

  /// Track client initialization so callers can await readiness
  late Future<void> _clientReady;

  /// Whether we've already run peer discovery after first successful connection
  bool _peerDiscoveryDone = false;

  /// Whether this instance has been disposed (client closed).
  /// Prevents fire-and-forget tasks from using a closed client.
  bool _disposed = false;

  /// Whether the HTTP client can reach .onion addresses (Tor SOCKS5 configured).
  /// When false, failover skips .onion URLs entirely — they'll never work.
  bool _hasTor = false;

  ApiService({
    String? customUrl,
    this.environment = NetworkEnvironment.testnet,
  }) {
    _loadBootstrapUrls(environment);
    if (customUrl != null) {
      baseUrl = customUrl;
    } else {
      baseUrl = _bootstrapUrls.isNotEmpty
          ? _bootstrapUrls.first
          : _getBaseUrl(environment);
    }
    _clientReady = _initializeClient();
    debugPrint('🔗 UAT Validator ApiService initialized with baseUrl: $baseUrl '
        '(${_bootstrapUrls.length} bootstrap nodes available)');
  }

  /// Await Tor/HTTP client initialization before first request.
  Future<void> ensureReady() => _clientReady;

  /// Load all bootstrap URLs for the given environment.
  /// Includes saved peers from local storage (Bitcoin's peers.dat equivalent)
  /// BEFORE the hardcoded bootstrap nodes, so the app can survive
  /// even if all 4 bootstrap nodes go offline.
  void _loadBootstrapUrls(NetworkEnvironment env) {
    final nodes = env == NetworkEnvironment.testnet
        ? NetworkConfig.testnetNodes
        : NetworkConfig.mainnetNodes;
    _bootstrapUrls = nodes.map((n) => n.restUrl).toList();
    _currentNodeIndex = 0;
  }

  /// Async initialization: load saved peers and prepend to bootstrap list.
  /// Called during ensureReady() — before the first actual API request.
  Future<void> _loadSavedPeers() async {
    final savedPeers = await PeerDiscoveryService.loadSavedPeers();
    if (savedPeers.isNotEmpty) {
      // Prepend saved peers BEFORE bootstrap nodes (tried first)
      // Deduplicate: don't add if already in bootstrap list
      final newPeers =
          savedPeers.where((p) => !_bootstrapUrls.contains(p)).toList();
      if (newPeers.isNotEmpty) {
        _bootstrapUrls = [...newPeers, ..._bootstrapUrls];
        debugPrint('🔗 PeerDiscovery: added ${newPeers.length} saved peer(s) '
            '(total: ${_bootstrapUrls.length} endpoints)');
      }
    }
  }

  String _getBaseUrl(NetworkEnvironment env) {
    switch (env) {
      case NetworkEnvironment.testnet:
        return NetworkConfig.testnetUrl;
      case NetworkEnvironment.mainnet:
        return NetworkConfig.mainnetUrl;
    }
  }

  /// Switch to the next bootstrap node in round-robin fashion.
  /// Returns true if switched to a different node, false if only 1 node available.
  /// Skips .onion URLs when Tor is not available (_hasTor == false).
  bool _switchToNextNode() {
    if (_bootstrapUrls.length <= 1) return false;
    final startIndex = _currentNodeIndex;
    do {
      _currentNodeIndex = (_currentNodeIndex + 1) % _bootstrapUrls.length;
      final candidate = _bootstrapUrls[_currentNodeIndex];
      // Skip .onion URLs if we don't have a Tor client
      if (!_hasTor && candidate.contains('.onion')) continue;
      if (candidate != baseUrl) {
        baseUrl = candidate;
        debugPrint(
            '🔄 Failover: switched to node ${_currentNodeIndex + 1}/${_bootstrapUrls.length}: $baseUrl');
        return true;
      }
    } while (_currentNodeIndex != startIndex);
    return false;
  }

  /// Execute an HTTP request with round-robin failover across all bootstrap nodes.
  /// If the current node fails (timeout, connection error), tries the next one.
  Future<http.Response> _requestWithFailover(
    Future<http.Response> Function(String url) requestFn,
    String endpoint,
  ) async {
    await ensureReady();
    int attempts = 0;

    while (attempts < _bootstrapUrls.length.clamp(1, _maxRetries)) {
      try {
        final response = await requestFn(baseUrl).timeout(_timeout);
        // On first successful connection, trigger background peer discovery
        if (!_peerDiscoveryDone) {
          _peerDiscoveryDone = true;
          // Fire-and-forget — don't block the current request
          Future.microtask(() => discoverAndSavePeers());
        }
        return response;
      } on Exception catch (e) {
        final isLastAttempt = attempts >= _bootstrapUrls.length - 1 ||
            attempts >= _maxRetries - 1;
        debugPrint('⚠️ Node ${_currentNodeIndex + 1} failed for $endpoint: $e');

        if (isLastAttempt) {
          debugPrint(
              '❌ All ${attempts + 1} bootstrap nodes failed for $endpoint');
          rethrow;
        }

        _switchToNextNode();
        attempts++;
        debugPrint('🔄 Retrying $endpoint on node ${_currentNodeIndex + 1}...');
      }
    }
    // Should not reach here, but satisfy the compiler
    throw Exception('All bootstrap nodes unreachable for $endpoint');
  }

  /// Get appropriate timeout based on whether using Tor
  Duration get _timeout =>
      baseUrl.contains('.onion') ? _torTimeout : _defaultTimeout;

  /// Initialize HTTP client — tries bundled Tor first, then existing Tor, then direct
  Future<void> _initializeClient() async {
    if (baseUrl.contains('.onion')) {
      _client = await _createTorClient();
      _hasTor = true;
    } else {
      _client = http.Client();
      _hasTor = false;
      debugPrint('✅ Direct HTTP client (no Tor proxy needed for $baseUrl)');
    }
    // After client is ready, load saved peers into bootstrap list
    await _loadSavedPeers();
  }

  /// Create Tor-enabled HTTP client
  Future<http.Client> _createTorClient() async {
    final httpClient = HttpClient();
    int socksPort = 9250;

    final existing = await _torService.detectExistingTor();
    if (existing['found'] == true) {
      final proxy = existing['proxy'] as String;
      socksPort = int.parse(proxy.split(':').last);
      debugPrint('✅ Using existing Tor: ${existing['type']} ($proxy)');
    } else {
      final started = await _torService.start();
      if (started) {
        socksPort = 9250;
        debugPrint('✅ Bundled Tor started on port $socksPort');
      } else {
        socksPort = 9150;
        debugPrint(
            '⚠️ Bundled Tor failed, trying Tor Browser on port $socksPort');
      }
    }

    SocksTCPClient.assignToHttpClient(
      httpClient,
      [ProxySettings(InternetAddress.loopbackIPv4, socksPort)],
    );

    httpClient.connectionTimeout = const Duration(seconds: 30);
    httpClient.idleTimeout = const Duration(seconds: 30);

    debugPrint('✅ Tor SOCKS5 proxy configured (localhost:$socksPort)');
    return IOClient(httpClient);
  }

  // Switch network environment
  void switchEnvironment(NetworkEnvironment newEnv) {
    environment = newEnv;
    _loadBootstrapUrls(newEnv);
    baseUrl =
        _bootstrapUrls.isNotEmpty ? _bootstrapUrls.first : _getBaseUrl(newEnv);
    _clientReady = _initializeClient();
    debugPrint('🔄 Switched to ${newEnv.name.toUpperCase()}: $baseUrl '
        '(${_bootstrapUrls.length} nodes)');
  }

  // Node Info
  Future<Map<String, dynamic>> getNodeInfo() async {
    try {
      final response = await _requestWithFailover(
        (url) => _client.get(Uri.parse('$url/node-info')),
        '/node-info',
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      throw Exception('Failed to get node info: ${response.statusCode}');
    } catch (e) {
      debugPrint('❌ getNodeInfo error: $e');
      rethrow;
    }
  }

  /// Fetch node-info from a specific URL (used by NodeControlScreen for local node).
  Future<Map<String, dynamic>?> getNodeInfoFromUrl(String url) async {
    try {
      final response = await http
          .get(Uri.parse('$url/node-info'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      debugPrint('⚠️ getNodeInfoFromUrl($url) error: $e');
    }
    return null;
  }

  // Health Check
  Future<Map<String, dynamic>> getHealth() async {
    try {
      final response = await _requestWithFailover(
        (url) => _client.get(Uri.parse('$url/health')),
        '/health',
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      throw Exception('Failed to get health: ${response.statusCode}');
    } catch (e) {
      debugPrint('❌ getHealth error: $e');
      rethrow;
    }
  }

  /// Parse an int from a value that may be int, String, double, or null.
  static int _safeInt(dynamic v, [int fallback = 0]) {
    if (v == null) return fallback;
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse(v.toString()) ?? fallback;
  }

  // Get Balance
  // Backend: GET /balance/:address → {balance, balance_uat: string, balance_voi: u128-int}
  // Backend: GET /bal/:address     → {balance_uat: string, balance_void: u128-int}
  Future<Account> getBalance(String address) async {
    try {
      final response = await _requestWithFailover(
        (url) => _client.get(Uri.parse('$url/balance/$address')),
        '/balance/$address',
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // FIX C12-01: Backend /balance/:address sends "balance_voi" (no 'd'),
        // while /bal/:address sends "balance_void". Check both field names.
        // balance_voi / balance_void is the canonical VOID amount (u128).
        // balance_uat / balance are formatted UAT strings ("1000.00000000000").
        int balanceVoid;
        if (data['balance_voi'] != null) {
          balanceVoid = _safeInt(data['balance_voi']);
        } else if (data['balance_void'] != null) {
          balanceVoid = _safeInt(data['balance_void']);
        } else if (data['balance_uat'] != null) {
          final val = data['balance_uat'];
          if (val is int) {
            balanceVoid = val;
          } else if (val is String) {
            // FIX C12-03: balance_uat is a formatted decimal string like "1000.00000000000"
            // int.tryParse fails on decimal strings. Use uatStringToVoid for proper conversion.
            balanceVoid = BlockchainConstants.uatStringToVoid(val);
          } else {
            balanceVoid = 0;
          }
        } else if (data['balance'] != null) {
          final val = data['balance'];
          if (val is int) {
            balanceVoid = val;
          } else if (val is String) {
            balanceVoid = BlockchainConstants.uatStringToVoid(val);
          } else {
            balanceVoid = 0;
          }
        } else {
          balanceVoid = 0;
        }
        return Account(
          address: address,
          balance: balanceVoid,
          voidBalance: 0,
          history: [],
        );
      }
      throw Exception('Failed to get balance: ${response.statusCode}');
    } catch (e) {
      debugPrint('❌ getBalance error: $e');
      rethrow;
    }
  }

  // Get Account (with history)
  Future<Account> getAccount(String address) async {
    try {
      final response = await _requestWithFailover(
        (url) => _client.get(Uri.parse('$url/account/$address')),
        '/account/$address',
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return Account.fromJson(data);
      }
      throw Exception('Failed to get account: ${response.statusCode}');
    } catch (e) {
      debugPrint('❌ getAccount error: $e');
      rethrow;
    }
  }

  // Request Faucet
  Future<Map<String, dynamic>> requestFaucet(String address) async {
    try {
      final response = await _requestWithFailover(
        (url) => _client.post(
          Uri.parse('$url/faucet'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'address': address}),
        ),
        '/faucet',
      );

      final data = json.decode(response.body);

      // Critical: Check BOTH status code AND response body status
      if (response.statusCode != 200 || data['status'] == 'error') {
        throw Exception(data['msg'] ?? 'Faucet request failed');
      }

      return data;
    } catch (e) {
      debugPrint('❌ requestFaucet error: $e');
      rethrow;
    }
  }

  // Send Transaction
  // Backend POST /send requires: {from, target, amount (UAT int), signature, public_key}
  Future<Map<String, dynamic>> sendTransaction({
    required String from,
    required String to,
    required int amount,
    required String signature,
    required String publicKey,
  }) async {
    try {
      final response = await _requestWithFailover(
        (url) => _client.post(
          Uri.parse('$url/send'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'from': from,
            'target': to,
            'amount': amount,
            'signature': signature,
            'public_key': publicKey,
          }),
        ),
        '/send',
      );

      final data = json.decode(response.body);

      // Critical: Check BOTH status code AND response body status
      if (response.statusCode != 200 || data['status'] == 'error') {
        throw Exception(data['msg'] ?? 'Transaction failed');
      }

      return data;
    } catch (e) {
      debugPrint('❌ sendTransaction error: $e');
      rethrow;
    }
  }

  // Proof-of-Burn
  Future<Map<String, dynamic>> submitBurn({
    required String uatAddress,
    required String btcTxid,
    required String ethTxid,
    required int amount,
  }) async {
    try {
      final response = await _requestWithFailover(
        (url) => _client.post(
          Uri.parse('$url/burn'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'uat_address': uatAddress,
            'btc_txid': btcTxid,
            'eth_txid': ethTxid,
            'amount': amount,
          }),
        ),
        '/burn',
      );

      final data = json.decode(response.body);

      // Critical: Check BOTH status code AND response body status
      if (response.statusCode != 200 || data['status'] == 'error') {
        throw Exception(data['msg'] ?? 'Burn submission failed');
      }

      return data;
    } catch (e) {
      debugPrint('❌ submitBurn error: $e');
      rethrow;
    }
  }

  // Get Validators
  // FIX C-01: Backend wraps in {"validators": [...]}, not bare array
  Future<List<ValidatorInfo>> getValidators() async {
    try {
      final response = await _requestWithFailover(
        (url) => _client.get(Uri.parse('$url/validators')),
        '/validators',
      );
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        // Handle both {"validators": [...]} (backend) and bare [...] (future)
        final List<dynamic> data = decoded is List
            ? decoded
            : (decoded['validators'] as List<dynamic>?) ?? [];
        return data.map((v) => ValidatorInfo.fromJson(v)).toList();
      }
      throw Exception('Failed to get validators: ${response.statusCode}');
    } catch (e) {
      debugPrint('❌ getValidators error: $e');
      rethrow;
    }
  }

  /// Check if an address is an active genesis bootstrap validator.
  /// Returns true if the address is found in /validators with is_genesis=true and is_active=true.
  Future<bool> isActiveGenesisValidator(String address) async {
    try {
      final validators = await getValidators();
      return validators.any(
        (v) => v.address == address && v.isGenesis && v.isActive,
      );
    } catch (e) {
      debugPrint('⚠️ isActiveGenesisValidator check failed: $e');
      return false;
    }
  }

  // Get Latest Block
  Future<BlockInfo> getLatestBlock() async {
    try {
      final response = await _requestWithFailover(
        (url) => _client.get(Uri.parse('$url/block')),
        '/block',
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return BlockInfo.fromJson(data);
      }
      throw Exception('Failed to get latest block: ${response.statusCode}');
    } catch (e) {
      debugPrint('❌ getLatestBlock error: $e');
      rethrow;
    }
  }

  // Get Recent Blocks
  Future<List<BlockInfo>> getRecentBlocks() async {
    try {
      final response = await _requestWithFailover(
        (url) => _client.get(Uri.parse('$url/blocks/recent')),
        '/blocks/recent',
      );
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        // FIX C11-07: Handle both bare array and wrapped {"blocks": [...]}
        final List<dynamic> data = decoded is List
            ? decoded
            : (decoded['blocks'] as List<dynamic>?) ?? [];
        return data.map((b) => BlockInfo.fromJson(b)).toList();
      }
      throw Exception('Failed to get recent blocks: ${response.statusCode}');
    } catch (e) {
      debugPrint('❌ getRecentBlocks error: $e');
      rethrow;
    }
  }

  // Get Peers
  // Backend returns {"peers": [{"address":..., "is_validator":..., ...}], "peer_count": N, ...}
  Future<List<String>> getPeers() async {
    try {
      final response = await _requestWithFailover(
        (url) => _client.get(Uri.parse('$url/peers')),
        '/peers',
      );
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded is Map) {
          // New format: {"peers": [{"address": "...", ...}], "peer_count": N}
          if (decoded.containsKey('peers') && decoded['peers'] is List) {
            return (decoded['peers'] as List)
                .map((p) =>
                    p is Map ? (p['address'] ?? '').toString() : p.toString())
                .where((s) => s.isNotEmpty)
                .toList();
          }
          // Legacy fallback: flat HashMap<String, String>
          return decoded.keys.cast<String>().toList();
        } else if (decoded is List) {
          return decoded.whereType<String>().toList();
        }
        return [];
      }
      throw Exception('Failed to get peers: ${response.statusCode}');
    } catch (e) {
      debugPrint('❌ getPeers error: $e');
      rethrow;
    }
  }

  /// Register this node as an active validator on the local uat-node.
  /// Requires Dilithium5 signature proof of key ownership.
  /// The node will broadcast the registration to all peers via gossipsub.
  Future<Map<String, dynamic>> registerValidator({
    required String address,
    required String publicKey,
    required String signature,
    required int timestamp,
  }) async {
    try {
      final response = await _requestWithFailover(
        (url) => _client.post(
          Uri.parse('$url/register-validator'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'address': address,
            'public_key': publicKey,
            'signature': signature,
            'timestamp': timestamp,
          }),
        ),
        '/register-validator',
      );

      final data = json.decode(response.body);

      if (response.statusCode != 200 || data['status'] == 'error') {
        throw Exception(data['msg'] ?? 'Validator registration failed');
      }

      return data;
    } catch (e) {
      debugPrint('❌ registerValidator error: $e');
      rethrow;
    }
  }

  /// Get the name of the currently connected bootstrap node (e.g. "validator-1")
  String get connectedNodeName {
    final nodes = environment == NetworkEnvironment.testnet
        ? NetworkConfig.testnetNodes
        : NetworkConfig.mainnetNodes;
    if (_currentNodeIndex < nodes.length) {
      return nodes[_currentNodeIndex].name;
    }
    return 'unknown';
  }

  /// Get the current connected node index and total count
  String get connectionInfo =>
      'Node ${_currentNodeIndex + 1}/${_bootstrapUrls.length}';

  /// Fetch validator reward pool status from GET /reward-info.
  Future<Map<String, dynamic>> getRewardInfo() async {
    try {
      final response = await _requestWithFailover(
        (url) => _client.get(Uri.parse('$url/reward-info')),
        '/reward-info',
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      throw Exception('Failed to get reward info: ${response.statusCode}');
    } catch (e) {
      debugPrint('❌ getRewardInfo error: $e');
      rethrow;
    }
  }

  /// Discover new validator endpoints from the network and save locally.
  /// Call this periodically (e.g., every dashboard refresh) to build up
  /// the local peer database. Once saved, these peers persist across restarts.
  Future<void> discoverAndSavePeers() async {
    if (_disposed) return; // Client already closed — skip silently
    try {
      final response = await _requestWithFailover(
        (url) => _client.get(Uri.parse('$url/network/peers')),
        '/network/peers',
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final endpoints = (data['endpoints'] as List<dynamic>?)
                ?.map((e) => e as Map<String, dynamic>)
                .toList() ??
            [];
        if (endpoints.isNotEmpty) {
          await PeerDiscoveryService.savePeers(endpoints);
          // Also add newly discovered peers to current session's URL list
          for (final ep in endpoints) {
            final onion = ep['onion_address']?.toString() ?? '';
            if (onion.isNotEmpty && onion.endsWith('.onion')) {
              final url = 'http://$onion';
              if (!_bootstrapUrls.contains(url)) {
                _bootstrapUrls.add(url);
              }
            }
          }
          debugPrint('🌐 Discovery: ${endpoints.length} endpoint(s), '
              'total URLs: ${_bootstrapUrls.length}');
        }
      }
    } catch (e) {
      // Non-critical — silently fail, will retry on next refresh
      debugPrint('⚠️ Peer discovery failed (non-critical): $e');
    }
  }

  /// Release HTTP client resources. Called by Provider.dispose.
  void dispose() {
    _disposed = true;
    _client.close();
  }
}
