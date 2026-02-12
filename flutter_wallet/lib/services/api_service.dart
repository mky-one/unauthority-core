import 'dart:async';
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
import 'wallet_service.dart';

enum NetworkEnvironment { testnet, mainnet }

/// Tracks per-node health metrics for latency-based selection and cooldown.
class _NodeHealth {
  /// Last measured round-trip time in milliseconds. null = never probed.
  int? latencyMs;

  /// Timestamp of last successful response from this node.
  DateTime? lastSuccess;

  /// Timestamp of last failure. Used for cooldown logic.
  DateTime? lastFailure;

  /// Consecutive failure count. Reset on success.
  int consecutiveFailures = 0;

  /// Whether this node is currently in cooldown (recently failed).
  bool get isInCooldown {
    if (lastFailure == null || consecutiveFailures == 0) return false;
    // Exponential backoff: 10s × 2^(failures-1), capped at 5 minutes
    final cooldownMs =
        (10000 * (1 << (consecutiveFailures - 1).clamp(0, 5))).clamp(0, 300000);
    return DateTime.now().difference(lastFailure!).inMilliseconds < cooldownMs;
  }

  void recordSuccess(int rttMs) {
    latencyMs = rttMs;
    lastSuccess = DateTime.now();
    consecutiveFailures = 0;
  }

  void recordFailure() {
    lastFailure = DateTime.now();
    consecutiveFailures++;
  }
}

class ApiService {
  // Bootstrap node addresses are loaded from assets/network_config.json
  // via NetworkConfig. NEVER hardcode .onion addresses here.
  // Use: scripts/update_network_config.sh to update addresses.

  /// Default timeout for API calls
  static const Duration _defaultTimeout = Duration(seconds: 30);

  /// Longer timeout for Tor connections (45s — .onion routing can be slow on first circuit)
  static const Duration _torTimeout = Duration(seconds: 45);

  /// Timeout for latency probes (short — just checking reachability)
  static const Duration _probeTimeout = Duration(seconds: 15);

  /// Tor-specific probe timeout (Tor circuits need more time)
  static const Duration _torProbeTimeout = Duration(seconds: 30);

  /// Max retry attempts across bootstrap nodes before giving up
  static const int _maxRetries = 4;

  /// Interval between periodic peer re-discovery runs
  static const Duration _rediscoveryInterval = Duration(minutes: 5);

  /// Interval between background latency probes
  static const Duration _latencyProbeInterval = Duration(minutes: 3);

  late String baseUrl;
  // Initialize with safe default to prevent LateInitializationError.
  // _initializeClient() replaces with Tor client asynchronously when needed.
  http.Client _client = http.Client();
  NetworkEnvironment environment;
  final TorService _torService;

  /// All available bootstrap URLs for failover
  List<String> _bootstrapUrls = [];

  /// Index of the currently active bootstrap node
  int _currentNodeIndex = 0;

  /// Per-node health tracking: URL → _NodeHealth
  final Map<String, _NodeHealth> _nodeHealthMap = {};

  /// Track client initialization future so callers can await
  /// readiness before making requests. Prevents DNS leaks from using
  /// the default http.Client on .onion URLs before Tor is ready.
  late Future<void> _clientReady;

  /// Whether we've completed the initial peer discovery + latency probe
  bool _initialDiscoveryDone = false;

  /// Whether this instance has been disposed (client closed).
  /// Prevents fire-and-forget tasks from using a closed client.
  bool _disposed = false;

  /// Whether the HTTP client can reach .onion addresses (Tor SOCKS5 configured).
  /// When false, failover skips .onion URLs entirely — they'll never work.
  bool _hasTor = false;

  /// Periodic timers for background maintenance
  Timer? _rediscoveryTimer;
  Timer? _latencyProbeTimer;

  /// Callback for external health monitor integration (e.g. NetworkStatusService).
  /// When set, this is called whenever a proactive failover occurs.
  void Function(String newBaseUrl)? onNodeSwitched;

  /// Optional: the local validator's own .onion address.
  /// When set, this node is EXCLUDED from the peer list to prevent
  /// self-connection (spec: "flutter_validator MUST NOT use its own
  /// local onion address for API consumption").
  String? _excludedOnionUrl;

  ApiService({
    String? customUrl,
    this.environment = NetworkEnvironment.testnet,
    TorService? torService,
    String? excludeOwnOnion,
  }) : _torService = torService ?? TorService() {
    _excludedOnionUrl = excludeOwnOnion;
    _loadBootstrapUrls(environment);
    if (customUrl != null) {
      baseUrl = customUrl;
    } else {
      baseUrl = _bootstrapUrls.isNotEmpty
          ? _bootstrapUrls.first
          : _getBaseUrl(environment);
    }
    _clientReady = _initializeClient();
    debugPrint('🔗 LOS ApiService initialized with baseUrl: $baseUrl '
        '(${_bootstrapUrls.length} bootstrap nodes available)');
  }

  /// Await Tor/HTTP client initialization before first request.
  /// Safe to call multiple times — resolves immediately after first init.
  Future<void> ensureReady() => _clientReady;

  /// Load all bootstrap URLs for the given environment.
  /// Filters out the validator's own .onion address if excluded.
  /// SECURITY FIX M-06: On mainnet, only .onion URLs are permitted.
  void _loadBootstrapUrls(NetworkEnvironment env) {
    final nodes = env == NetworkEnvironment.testnet
        ? NetworkConfig.testnetNodes
        : NetworkConfig.mainnetNodes;
    _bootstrapUrls = nodes
        .map((n) => n.restUrl)
        .where((url) => url != _excludedOnionUrl)
        .where((url) {
      // SECURITY: Mainnet requires .onion-only connections (Tor network)
      if (env == NetworkEnvironment.mainnet && !url.contains('.onion')) {
        debugPrint('🚫 Rejected non-.onion URL for mainnet: $url');
        return false;
      }
      return true;
    }).toList();
    _currentNodeIndex = 0;
  }

  /// Async initialization: load saved peers, prepend to bootstrap list,
  /// then run initial latency probes to select the best node.
  Future<void> _loadSavedPeers() async {
    final savedPeers = await PeerDiscoveryService.loadSavedPeers();
    if (savedPeers.isNotEmpty) {
      final newPeers = savedPeers
          .where((p) => !_bootstrapUrls.contains(p) && p != _excludedOnionUrl)
          .toList();
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

  // ══════════════════════════════════════════════════════════════════
  //  LATENCY-BASED PEER SELECTION
  // ══════════════════════════════════════════════════════════════════

  /// Probe all known peers for latency, then select the fastest responsive one.
  /// Called on startup and periodically in the background.
  Future<void> probeAndSelectBestNode() async {
    if (_disposed || _bootstrapUrls.isEmpty) return;
    debugPrint(
        '📡 [Probe] Starting latency probe across ${_bootstrapUrls.length} node(s)...');

    final results = <String, int>{};

    // Probe all nodes in parallel
    final futures = _bootstrapUrls.map((url) async {
      // Skip nodes in cooldown
      final health = _nodeHealthMap[url];
      if (health != null && health.isInCooldown) {
        debugPrint(
            '📡 [Probe] $url — skipped (cooldown, ${health.consecutiveFailures} failures)');
        return;
      }
      try {
        final timeout =
            url.contains('.onion') ? _torProbeTimeout : _probeTimeout;
        final sw = Stopwatch()..start();
        final response =
            await _client.get(Uri.parse('$url/health')).timeout(timeout);
        sw.stop();

        if (response.statusCode == 200) {
          results[url] = sw.elapsedMilliseconds;
          _getHealth(url).recordSuccess(sw.elapsedMilliseconds);
          debugPrint('📡 [Probe] $url — ${sw.elapsedMilliseconds}ms ✓');
        } else {
          _getHealth(url).recordFailure();
          debugPrint('📡 [Probe] $url — HTTP ${response.statusCode} ✗');
        }
      } catch (e) {
        _getHealth(url).recordFailure();
        debugPrint('📡 [Probe] $url — unreachable ($e) ✗');
      }
    });

    await Future.wait(futures);

    if (results.isEmpty) {
      debugPrint(
          '📡 [Probe] No responsive nodes found — keeping current: $baseUrl');
      return;
    }

    // Sort by latency ascending, pick the fastest
    final sorted = results.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    final bestUrl = sorted.first.key;
    final bestLatency = sorted.first.value;

    if (bestUrl != baseUrl) {
      final oldUrl = baseUrl;
      baseUrl = bestUrl;
      _currentNodeIndex =
          _bootstrapUrls.indexOf(bestUrl).clamp(0, _bootstrapUrls.length - 1);
      debugPrint(
          '🏆 [Probe] Best node: $bestUrl (${bestLatency}ms) — switched from $oldUrl');
      onNodeSwitched?.call(baseUrl);
    } else {
      debugPrint(
          '🏆 [Probe] Best node unchanged: $baseUrl (${bestLatency}ms) — '
          '${sorted.length}/${_bootstrapUrls.length} responsive');
    }
  }

  /// Get or create health tracker for a URL.
  _NodeHealth _getHealth(String url) {
    return _nodeHealthMap.putIfAbsent(url, () => _NodeHealth());
  }

  // ══════════════════════════════════════════════════════════════════
  //  FAILOVER
  // ══════════════════════════════════════════════════════════════════

  /// Switch to the next available node, skipping nodes in cooldown
  /// and .onion URLs when Tor is unavailable.
  bool _switchToNextNode() {
    if (_bootstrapUrls.length <= 1) return false;
    final startIndex = _currentNodeIndex;
    do {
      _currentNodeIndex = (_currentNodeIndex + 1) % _bootstrapUrls.length;
      final candidate = _bootstrapUrls[_currentNodeIndex];
      // Skip .onion URLs if we don't have a Tor client
      if (!_hasTor && candidate.contains('.onion')) continue;
      // Skip nodes in cooldown (recently failed, exponential backoff)
      if (_getHealth(candidate).isInCooldown) continue;
      if (candidate != baseUrl) {
        baseUrl = candidate;
        debugPrint(
            '🔄 Failover: switched to node ${_currentNodeIndex + 1}/${_bootstrapUrls.length}: $baseUrl');
        onNodeSwitched?.call(baseUrl);
        return true;
      }
    } while (_currentNodeIndex != startIndex);
    // All nodes in cooldown — reset cooldowns and try round-robin
    if (_allNodesInCooldown()) {
      debugPrint(
          '⚠️ All nodes in cooldown — resetting cooldowns for fresh retry');
      for (final h in _nodeHealthMap.values) {
        h.consecutiveFailures = 0;
      }
      return _switchToNextNodeNoCooldown();
    }
    return false;
  }

  /// Check if all candidate nodes are in cooldown.
  bool _allNodesInCooldown() {
    for (final url in _bootstrapUrls) {
      if (!_hasTor && url.contains('.onion')) continue;
      if (!_getHealth(url).isInCooldown) return false;
    }
    return true;
  }

  /// Simple round-robin switch — no cooldown checks. Used as last resort.
  bool _switchToNextNodeNoCooldown() {
    if (_bootstrapUrls.length <= 1) return false;
    final startIndex = _currentNodeIndex;
    do {
      _currentNodeIndex = (_currentNodeIndex + 1) % _bootstrapUrls.length;
      final candidate = _bootstrapUrls[_currentNodeIndex];
      if (!_hasTor && candidate.contains('.onion')) continue;
      if (candidate != baseUrl) {
        baseUrl = candidate;
        onNodeSwitched?.call(baseUrl);
        return true;
      }
    } while (_currentNodeIndex != startIndex);
    return false;
  }

  /// Execute an HTTP request with intelligent failover.
  /// Handles: timeouts, connection errors, AND HTTP 5xx server errors.
  Future<http.Response> _requestWithFailover(
    Future<http.Response> Function(String url) requestFn,
    String endpoint,
  ) async {
    await ensureReady();
    int attempts = 0;
    final maxAttempts = _bootstrapUrls.length.clamp(1, _maxRetries);
    while (attempts < maxAttempts) {
      try {
        final sw = Stopwatch()..start();
        final response = await requestFn(baseUrl).timeout(_timeout);
        sw.stop();

        // Record successful RTT for this node
        _getHealth(baseUrl).recordSuccess(sw.elapsedMilliseconds);

        // HTTP 5xx = server error → treat as node failure, try next
        if (response.statusCode >= 500) {
          debugPrint(
              '⚠️ Node ${_currentNodeIndex + 1} returned HTTP ${response.statusCode} for $endpoint');
          _getHealth(baseUrl).recordFailure();
          final isLastAttempt = attempts >= maxAttempts - 1;
          if (isLastAttempt) return response; // Return as-is, let caller handle
          _switchToNextNode();
          attempts++;
          continue;
        }

        // Trigger initial discovery + latency probes (once)
        if (!_initialDiscoveryDone) {
          _initialDiscoveryDone = true;
          Future.microtask(() => _runInitialDiscovery());
        }

        return response;
      } on Exception catch (e) {
        _getHealth(baseUrl).recordFailure();
        final isLastAttempt = attempts >= maxAttempts - 1;
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

  /// Runs once after first successful API response:
  /// 1. Discover peers from network
  /// 2. Probe all nodes for latency
  /// 3. Select the best (fastest) node
  /// 4. Start periodic background timers
  Future<void> _runInitialDiscovery() async {
    if (_disposed) return;
    try {
      await discoverAndSavePeers();
      await probeAndSelectBestNode();
    } catch (e) {
      debugPrint('⚠️ Initial discovery/probe failed (non-critical): $e');
    }
    // Start periodic background timers
    _startBackgroundTimers();
  }

  /// Start recurring background tasks:
  /// - Re-discover peers every 5 minutes
  /// - Re-probe latency every 3 minutes
  void _startBackgroundTimers() {
    _rediscoveryTimer?.cancel();
    _latencyProbeTimer?.cancel();

    _rediscoveryTimer = Timer.periodic(_rediscoveryInterval, (_) {
      if (!_disposed) discoverAndSavePeers();
    });

    _latencyProbeTimer = Timer.periodic(_latencyProbeInterval, (_) {
      if (!_disposed) probeAndSelectBestNode();
    });

    debugPrint('⏰ Background timers started: '
        'discovery every ${_rediscoveryInterval.inMinutes}m, '
        'latency probe every ${_latencyProbeInterval.inMinutes}m');
  }

  /// Called by NetworkStatusService when health check detects degradation.
  /// Proactively switches to a better node before the user's next request fails.
  void onHealthDegraded() {
    if (_disposed) return;
    debugPrint('🔌 Health degraded — proactively switching node...');
    _getHealth(baseUrl).recordFailure();
    _switchToNextNode();
    // Trigger a fresh latency probe in background
    Future.microtask(() => probeAndSelectBestNode());
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
      debugPrint(
          '⚠️ TorService.start() failed, trying Tor Browser on port $socksPort');
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
    // SECURITY FIX M-06: Sync mainnet mode to WalletService so Ed25519
    // fallback crypto is refused on mainnet.
    WalletService.mainnetMode = (newEnv == NetworkEnvironment.mainnet);
    _nodeHealthMap.clear();
    _initialDiscoveryDone = false;
    _rediscoveryTimer?.cancel();
    _latencyProbeTimer?.cancel();
    _loadBootstrapUrls(newEnv);
    baseUrl =
        _bootstrapUrls.isNotEmpty ? _bootstrapUrls.first : _getBaseUrl(newEnv);
    _clientReady = _initializeClient();
    debugPrint('🔄 Switched to ${newEnv.name.toUpperCase()}: $baseUrl '
        '(${_bootstrapUrls.length} nodes)');
  }

  // Node Info
  Future<Map<String, dynamic>> getNodeInfo() async {
    debugPrint('🌐 [ApiService.getNodeInfo] Fetching node info...');
    try {
      final response = await _requestWithFailover(
        (url) => _client.get(Uri.parse('$url/node-info')),
        '/node-info',
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint(
            '🌐 [ApiService.getNodeInfo] SUCCESS block_height=${data['block_height'] ?? data['protocol']?['block_height'] ?? 'N/A'}');
        return data;
      }
      throw Exception('Failed to get node info: ${response.statusCode}');
    } catch (e) {
      debugPrint('❌ getNodeInfo error: $e');
      rethrow;
    }
  }

  /// Fetch dynamic fee estimate for the NEXT transaction from [address].
  /// Returns the estimated fee in CILD, accounting for anti-whale scaling.
  /// Wallet MUST call this before constructing a signed block.
  Future<Map<String, dynamic>> getFeeEstimate(String address) async {
    debugPrint(
        '🌐 [ApiService.getFeeEstimate] Fetching fee estimate for $address...');
    try {
      final response = await _requestWithFailover(
        (url) => _client.get(Uri.parse('$url/fee-estimate/$address')),
        '/fee-estimate/$address',
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint(
            '🌐 [ApiService.getFeeEstimate] SUCCESS fee=${data['estimated_fee_cil']} CILD');
        return data;
      }
      throw Exception('Failed to get fee estimate: ${response.statusCode}');
    } catch (e) {
      debugPrint('⚠️ getFeeEstimate error (falling back to base fee): $e');
      // Fallback: return base fee so wallet still works if endpoint is unreachable
      return {
        'base_fee_cil': 100000,
        'estimated_fee_cil': 100000,
        'fee_multiplier': 1,
        'tx_count_in_window': 0,
      };
    }
  }

  // Health Check
  Future<Map<String, dynamic>> getHealth() async {
    debugPrint('🌐 [ApiService.getHealth] Fetching health...');
    try {
      final response = await _requestWithFailover(
        (url) => _client.get(Uri.parse('$url/health')),
        '/health',
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('🌐 [ApiService.getHealth] SUCCESS');
        return data;
      }
      throw Exception('Failed to get health: ${response.statusCode}');
    } catch (e) {
      debugPrint('❌ getHealth error: $e');
      rethrow;
    }
  }

  // Get Balance
  Future<Account> getBalance(String address) async {
    debugPrint('🌐 [ApiService.getBalance] Fetching balance for $address...');
    try {
      final response = await _requestWithFailover(
        (url) => _client.get(Uri.parse('$url/bal/$address')),
        '/bal/$address',
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint(
            '🌐 [ApiService.getBalance] SUCCESS balance=${data['balance_cil'] ?? 0} CILD');
        return Account(
          address: address,
          balance: data['balance_cil'] ?? 0,
          cilBalance: 0,
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
    debugPrint('🌐 [ApiService.getAccount] Fetching account for $address...');
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
        debugPrint('🌐 [ApiService.getAccount] SUCCESS for $address');
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
        amountCil, // Amount already in CIL (for sub-LOS precision), as string to avoid overflow
  }) async {
    debugPrint(
        '💸 [API] sendTransaction -> $baseUrl/send  from=$from to=$to amount=$amount sig=${signature != null}');
    try {
      final body = <String, dynamic>{
        'from': from,
        'target': to,
        'amount': amount,
      };
      // If amount_cil is provided, backend uses it directly (skips ×CIL_PER_LOS)
      if (amountCil != null) {
        body['amount_cil'] = int.parse(amountCil);
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
    debugPrint('🌐 [ApiService.getValidators] Fetching validators...');
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
        final validators = data.map((v) => ValidatorInfo.fromJson(v)).toList();
        debugPrint(
            '🌐 [ApiService.getValidators] SUCCESS count=${validators.length}');
        return validators;
      }
      throw Exception('Failed to get validators: ${response.statusCode}');
    } catch (e) {
      debugPrint('❌ getValidators error: $e');
      rethrow;
    }
  }

  // Get Latest Block
  Future<BlockInfo> getLatestBlock() async {
    debugPrint('🌐 [ApiService.getLatestBlock] Fetching latest block...');
    try {
      final response = await _requestWithFailover(
        (url) => _client.get(Uri.parse('$url/block')),
        '/block',
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final block = BlockInfo.fromJson(data);
        debugPrint(
            '🌐 [ApiService.getLatestBlock] SUCCESS height=${block.height}');
        return block;
      }
      throw Exception('Failed to get latest block: ${response.statusCode}');
    } catch (e) {
      debugPrint('❌ getLatestBlock error: $e');
      rethrow;
    }
  }

  // Get Recent Blocks
  Future<List<BlockInfo>> getRecentBlocks() async {
    debugPrint('🌐 [ApiService.getRecentBlocks] Fetching recent blocks...');
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
        final blocks = data.map((b) => BlockInfo.fromJson(b)).toList();
        debugPrint(
            '🌐 [ApiService.getRecentBlocks] SUCCESS count=${blocks.length}');
        return blocks;
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
    debugPrint('🌐 [ApiService.getPeers] Fetching peers...');
    try {
      final response = await _requestWithFailover(
        (url) => _client.get(Uri.parse('$url/peers')),
        '/peers',
      );
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        List<String> peers;
        if (decoded is Map) {
          // New format: {"peers": [{"address": "...", ...}], "peer_count": N}
          if (decoded.containsKey('peers') && decoded['peers'] is List) {
            peers = (decoded['peers'] as List)
                .map((p) =>
                    p is Map ? (p['address'] ?? '').toString() : p.toString())
                .where((s) => s.isNotEmpty)
                .toList();
          } else {
            // Legacy fallback: flat HashMap<String, String>
            peers = decoded.keys.cast<String>().toList();
          }
        } else if (decoded is List) {
          peers = decoded.whereType<String>().toList();
        } else {
          peers = [];
        }
        debugPrint('🌐 [ApiService.getPeers] SUCCESS count=${peers.length}');
        return peers;
      }
      throw Exception('Failed to get peers: ${response.statusCode}');
    } catch (e) {
      debugPrint('❌ getPeers error: $e');
      rethrow;
    }
  }

  // Get Transaction History for address
  Future<List<Transaction>> getHistory(String address) async {
    debugPrint('🌐 [ApiService.getHistory] Fetching history for $address...');
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
        final txList = data.map((tx) => Transaction.fromJson(tx)).toList();
        debugPrint('🌐 [ApiService.getHistory] SUCCESS count=${txList.length}');
        return txList;
      }
      throw Exception('Failed to get history: ${response.statusCode}');
    } catch (e) {
      debugPrint('❌ getHistory error: $e');
      rethrow;
    }
  }

  /// Cleanup: stop bundled Tor and cancel background timers
  Future<void> dispose() async {
    debugPrint('🌐 [ApiService.dispose] Disposing...');
    _disposed = true;
    _rediscoveryTimer?.cancel();
    _latencyProbeTimer?.cancel();
    _client.close();
    await _torService.stop();
    debugPrint('🌐 [ApiService.dispose] Disposed');
  }

  /// Discover new validator endpoints from the network and save locally.
  /// Called periodically (every 5 minutes) to maintain an up-to-date peer table.
  /// Filters out the validator's own onion address if set.
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
              // Exclude own onion (validator self-connection prevention)
              if (url == _excludedOnionUrl) continue;
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

  /// Get the name of the currently connected bootstrap node
  String get connectedNodeName {
    final nodes = environment == NetworkEnvironment.testnet
        ? NetworkConfig.testnetNodes
        : NetworkConfig.mainnetNodes;
    if (_currentNodeIndex < nodes.length) {
      return nodes[_currentNodeIndex].name;
    }
    // Discovered peer — show short onion address
    if (_currentNodeIndex < _bootstrapUrls.length) {
      final url = _bootstrapUrls[_currentNodeIndex];
      final onion = url.replaceAll('http://', '');
      return onion.length > 16 ? '${onion.substring(0, 12)}...' : onion;
    }
    return 'unknown';
  }

  /// Get the current connected node index and total count
  String get connectionInfo =>
      'Node ${_currentNodeIndex + 1}/${_bootstrapUrls.length}';

  /// Expose current node health for UI display
  Map<String, Map<String, dynamic>> get nodeHealthSummary {
    final summary = <String, Map<String, dynamic>>{};
    for (final url in _bootstrapUrls) {
      final h = _nodeHealthMap[url];
      summary[url] = {
        'latency_ms': h?.latencyMs,
        'consecutive_failures': h?.consecutiveFailures ?? 0,
        'in_cooldown': h?.isInCooldown ?? false,
        'is_current': url == baseUrl,
      };
    }
    return summary;
  }
}
