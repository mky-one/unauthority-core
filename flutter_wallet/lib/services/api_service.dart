import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:socks5_proxy/socks_client.dart';
import '../models/account.dart';
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
  // FIX H-01: Initialize with safe default to prevent LateInitializationError
  // _initializeClient() replaces with Tor client asynchronously when needed
  http.Client _client = http.Client();
  NetworkEnvironment environment;
  final TorService _torService;

  /// All available bootstrap URLs for round-robin failover
  List<String> _bootstrapUrls = [];

  /// Index of the currently active bootstrap node
  int _currentNodeIndex = 0;

  /// FIX C11-08: Track client initialization future so callers can await
  /// readiness before making requests. Prevents DNS leaks from using
  /// the default http.Client on .onion URLs before Tor is ready.
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
    TorService? torService,
  }) : _torService = torService ?? TorService() {
    _loadBootstrapUrls(environment);
    if (customUrl != null) {
      baseUrl = customUrl;
    } else {
      baseUrl = _bootstrapUrls.isNotEmpty
          ? _bootstrapUrls.first
          : _getBaseUrl(environment);
    }
    _clientReady = _initializeClient();
    debugPrint('🔗 UAT ApiService initialized with baseUrl: $baseUrl '
        '(${_bootstrapUrls.length} bootstrap nodes available)');
  }

  /// Await Tor/HTTP client initialization before first request.
  /// Safe to call multiple times — resolves immediately after first init.
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
  Future<void> _loadSavedPeers() async {
    final savedPeers = await PeerDiscoveryService.loadSavedPeers();
    if (savedPeers.isNotEmpty) {
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
      // Local/direct connection — no SOCKS proxy needed
      _client = http.Client();
      _hasTor = false;
      debugPrint('✅ Direct HTTP client (no Tor proxy needed for $baseUrl)');
    }
    // After client is ready, load saved peers into bootstrap list
    await _loadSavedPeers();
  }

  /// Create Tor-enabled HTTP client.
  /// Uses the shared TorService.start() so _isRunning is properly synced.
  Future<http.Client> _createTorClient() async {
    final httpClient = HttpClient();

    // Always go through start() — it detects existing Tor internally
    // AND sets _isRunning=true, which is critical for shared TorService state.
    final started = await _torService.start();
    final socksPort = started
        ? _torService.activeSocksPort
        : 9150; // Last resort: Tor Browser
    if (!started) {
      debugPrint('⚠️ TorService.start() failed, trying Tor Browser on port $socksPort');
    }

    SocksTCPClient.assignToHttpClient(
      httpClient,
      [
        ProxySettings(InternetAddress.loopbackIPv4, socksPort),
      ],
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

  /// Fetch dynamic fee estimate for the NEXT transaction from [address].
  /// Returns the estimated fee in VOID, accounting for anti-whale scaling.
  /// Wallet MUST call this before constructing a signed block.
  Future<Map<String, dynamic>> getFeeEstimate(String address) async {
    try {
      final response = await _requestWithFailover(
        (url) => _client.get(Uri.parse('$url/fee-estimate/$address')),
        '/fee-estimate/$address',
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      throw Exception('Failed to get fee estimate: ${response.statusCode}');
    } catch (e) {
      debugPrint('⚠️ getFeeEstimate error (falling back to base fee): $e');
      // Fallback: return base fee so wallet still works if endpoint is unreachable
      return {
        'base_fee_void': 100000,
        'estimated_fee_void': 100000,
        'fee_multiplier': 1,
        'tx_count_in_window': 0,
      };
    }
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

  // Get Balance
  Future<Account> getBalance(String address) async {
    try {
      final response = await _requestWithFailover(
        (url) => _client.get(Uri.parse('$url/bal/$address')),
        '/bal/$address',
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return Account(
          address: address,
          balance: data['balance_void'] ?? 0,
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
        // Backend /account/:address may not include 'address' field — inject it
        if (data is Map<String, dynamic> && !data.containsKey('address')) {
          data['address'] = address;
        }
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
    debugPrint('🚠 [API] requestFaucet -> $baseUrl/faucet  address=$address');
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
        debugPrint('🚠 [API] faucet FAILED: ${data['msg']}');
        throw Exception(data['msg'] ?? 'Faucet request failed');
      }

      debugPrint('🚠 [API] faucet SUCCESS: $data');
      return data;
    } catch (e) {
      debugPrint('❌ requestFaucet error: $e');
      rethrow;
    }
  }

  // Send Transaction
  // Supports optional Dilithium5 signature + public_key for L2+/mainnet
  // Supports optional previous (frontier) + work (PoW nonce) for client-signed blocks
  Future<Map<String, dynamic>> sendTransaction({
    required String from,
    required String to,
    required int amount,
    String? signature,
    String? publicKey,
    String? previous,
    int? work,
    int? timestamp,
    int? fee,
    String?
        amountVoid, // Amount already in VOID (for sub-UAT precision), as string to avoid overflow
  }) async {
    debugPrint(
        '💸 [API] sendTransaction -> $baseUrl/send  from=$from to=$to amount=$amount sig=${signature != null}');
    try {
      final body = <String, dynamic>{
        'from': from,
        'target': to,
        'amount': amount,
      };
      // If amount_void is provided, backend uses it directly (skips ×VOID_PER_UAT)
      if (amountVoid != null) {
        body['amount_void'] = int.parse(amountVoid);
      }
      // Attach Dilithium5 signature + public key if available (L2+/mainnet)
      if (signature != null && publicKey != null) {
        body['signature'] = signature;
        body['public_key'] = publicKey;
      }
      // Attach frontier hash + PoW nonce if client-constructed
      if (previous != null) {
        body['previous'] = previous;
      }
      if (work != null) {
        body['work'] = work;
      }
      // Attach timestamp and fee for client-signed blocks (part of signing_hash)
      if (timestamp != null) {
        body['timestamp'] = timestamp;
      }
      if (fee != null) {
        body['fee'] = fee;
      }

      final response = await _requestWithFailover(
        (url) => _client.post(
          Uri.parse('$url/send'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(body),
        ),
        '/send',
      );

      final data = json.decode(response.body);

      // Critical: Check BOTH status code AND response body status
      if (response.statusCode != 200 || data['status'] == 'error') {
        debugPrint('💸 [API] send FAILED: ${data['msg']}');
        throw Exception(data['msg'] ?? 'Transaction failed');
      }

      debugPrint('💸 [API] send SUCCESS: ${data['tx_hash'] ?? data['txid']}');
      return data;
    } catch (e) {
      debugPrint('❌ sendTransaction error: $e');
      rethrow;
    }
  }

  // Proof-of-Burn — matches backend BurnRequest { coin_type, txid, recipient_address }
  Future<Map<String, dynamic>> submitBurn({
    required String coinType, // "btc" or "eth"
    required String txid,
    String? recipientAddress,
  }) async {
    debugPrint(
        '🔥 [API] submitBurn -> $baseUrl/burn  coin=$coinType txid=$txid');
    try {
      final body = <String, dynamic>{
        'coin_type': coinType,
        'txid': txid,
      };
      if (recipientAddress != null) {
        body['recipient_address'] = recipientAddress;
      }

      final response = await _requestWithFailover(
        (url) => _client.post(
          Uri.parse('$url/burn'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(body),
        ),
        '/burn',
      );

      final data = json.decode(response.body);

      // Critical: Check BOTH status code AND response body status
      if (response.statusCode != 200 || data['status'] == 'error') {
        debugPrint('🔥 [API] burn FAILED: ${data['msg']}');
        throw Exception(data['msg'] ?? 'Burn submission failed');
      }

      debugPrint('🔥 [API] burn SUCCESS: $data');
      return data;
    } catch (e) {
      debugPrint('❌ submitBurn error: $e');
      rethrow;
    }
  }

  // Get Validators
  Future<List<ValidatorInfo>> getValidators() async {
    try {
      final response = await _requestWithFailover(
        (url) => _client.get(Uri.parse('$url/validators')),
        '/validators',
      );
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        // Handle both {"validators": [...]} wrapper and bare [...]
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
        // Handle both {"blocks": [...]} wrapper and bare [...]
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
  // Get Peers
  // Backend returns {"peers": [{...}], "peer_count": N, ...}
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

  // Get Transaction History for address
  Future<List<Transaction>> getHistory(String address) async {
    try {
      final response = await _requestWithFailover(
        (url) => _client.get(Uri.parse('$url/history/$address')),
        '/history/$address',
      );
      if (response.statusCode == 200) {
        // FIX C11-04: Backend returns {"transactions": [...]} wrapper,
        // not a bare array. Handle both formats for resilience.
        final decoded = json.decode(response.body);
        final List<dynamic> data = decoded is List
            ? decoded
            : (decoded['transactions'] as List<dynamic>?) ?? [];
        return data.map((tx) => Transaction.fromJson(tx)).toList();
      }
      throw Exception('Failed to get history: ${response.statusCode}');
    } catch (e) {
      debugPrint('❌ getHistory error: $e');
      rethrow;
    }
  }

  /// Cleanup: stop bundled Tor when no longer needed
  Future<void> dispose() async {
    _disposed = true;
    _client.close();
    await _torService.stop();
  }

  /// Discover new validator endpoints from the network and save locally.
  /// Call this periodically (e.g., after balance check) to build up
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
      debugPrint('⚠️ Peer discovery failed (non-critical): $e');
    }
  }
}
