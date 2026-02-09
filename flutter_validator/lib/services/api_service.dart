import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:socks5_proxy/socks_client.dart';
import '../models/account.dart';
import '../constants/blockchain.dart';
import 'tor_service.dart';

enum NetworkEnvironment { testnet, mainnet, local }

class ApiService {
  // Testnet bootstrap .onion — same nodes as flutter_wallet.
  // Updated by setup_tor_testnet.sh when you run your own testnet.
  static const String testnetOnionUrl = 'http://uat-testnet-bootstrap1.onion';

  // Mainnet .onion — populated before mainnet launch
  static const String mainnetOnionUrl = 'http://uat-mainnet-pending.onion';

  // Local development (ONLY for localhost debugging, NOT for real testnet)
  static const String defaultLocalUrl = 'http://localhost:3030';

  /// Default timeout for API calls
  static const Duration _defaultTimeout = Duration(seconds: 30);

  /// Longer timeout for Tor connections
  static const Duration _torTimeout = Duration(seconds: 60);

  late String baseUrl;
  http.Client _client = http.Client();
  NetworkEnvironment environment;
  final TorService _torService = TorService();

  /// Track client initialization so callers can await readiness
  late Future<void> _clientReady;

  ApiService({
    String? customUrl,
    this.environment = NetworkEnvironment.testnet,
  }) {
    if (customUrl != null) {
      baseUrl = customUrl;
    } else {
      baseUrl = _getBaseUrl(environment);
    }
    _clientReady = _initializeClient();
    debugPrint(
        '🔗 UAT Validator ApiService initialized with baseUrl: $baseUrl');
  }

  /// Await Tor/HTTP client initialization before first request.
  Future<void> ensureReady() => _clientReady;

  String _getBaseUrl(NetworkEnvironment env) {
    switch (env) {
      case NetworkEnvironment.testnet:
        return testnetOnionUrl;
      case NetworkEnvironment.mainnet:
        return mainnetOnionUrl;
      case NetworkEnvironment.local:
        return defaultLocalUrl;
    }
  }

  /// Get appropriate timeout based on whether using Tor
  Duration get _timeout =>
      baseUrl.contains('.onion') ? _torTimeout : _defaultTimeout;

  /// Initialize HTTP client — tries bundled Tor first, then existing Tor, then direct
  Future<void> _initializeClient() async {
    if (baseUrl.contains('.onion')) {
      _client = await _createTorClient();
    } else {
      _client = http.Client();
      debugPrint('✅ Direct HTTP client (no Tor proxy needed for $baseUrl)');
    }
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
    baseUrl = _getBaseUrl(newEnv);
    _clientReady = _initializeClient();
    debugPrint('🔄 Switched to ${newEnv.name.toUpperCase()}: $baseUrl');
  }

  // Node Info
  Future<Map<String, dynamic>> getNodeInfo() async {
    try {
      final response = await _client.get(Uri.parse('$baseUrl/node-info'));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      throw Exception('Failed to get node info: ${response.statusCode}');
    } catch (e) {
      debugPrint('❌ getNodeInfo error: $e');
      rethrow;
    }
  }

  // Health Check
  Future<Map<String, dynamic>> getHealth() async {
    try {
      final response = await _client.get(Uri.parse('$baseUrl/health'));
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
      final response = await _client.get(
        Uri.parse('$baseUrl/balance/$address'),
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
      final response = await _client.get(
        Uri.parse('$baseUrl/account/$address'),
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
      final response = await _client.post(
        Uri.parse('$baseUrl/faucet'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'address': address}),
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
      final response = await _client.post(
        Uri.parse('$baseUrl/send'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'from': from,
          'target': to,
          'amount': amount,
          'signature': signature,
          'public_key': publicKey,
        }),
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
      final response = await _client.post(
        Uri.parse('$baseUrl/burn'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'uat_address': uatAddress,
          'btc_txid': btcTxid,
          'eth_txid': ethTxid,
          'amount': amount,
        }),
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
      final response = await _client.get(Uri.parse('$baseUrl/validators'));
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

  // Get Latest Block
  Future<BlockInfo> getLatestBlock() async {
    try {
      final response = await _client.get(Uri.parse('$baseUrl/block'));
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
      final response = await _client.get(Uri.parse('$baseUrl/blocks/recent'));
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
  // FIX C12-02: Backend returns HashMap<String,String> → JSON object {"addr":"url",...}
  // NOT a List or {peers: [...]}.
  Future<List<String>> getPeers() async {
    try {
      final response = await _client.get(Uri.parse('$baseUrl/peers'));
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded is List) {
          // Future-proof: if backend ever returns a plain array
          return decoded.whereType<String>().toList();
        } else if (decoded is Map) {
          // Current backend: HashMap<String, String> → JSON object
          // Keys are peer addresses/IDs, values are URLs
          if (decoded.containsKey('peers') && decoded['peers'] is List) {
            return (decoded['peers'] as List).whereType<String>().toList();
          }
          // Extract keys (peer addresses) from the map
          return decoded.keys.cast<String>().toList();
        }
        return [];
      }
      throw Exception('Failed to get peers: ${response.statusCode}');
    } catch (e) {
      debugPrint('❌ getPeers error: $e');
      rethrow;
    }
  }

  /// Release HTTP client resources. Called by Provider.dispose.
  void dispose() {
    _client.close();
  }
}
