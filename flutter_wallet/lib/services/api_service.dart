import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:socks5_proxy/socks_client.dart';
import '../models/account.dart';
import 'tor_service.dart';

enum NetworkEnvironment { testnet, mainnet, local }

class ApiService {
  // Testnet .onion (online) — matches testnet_config.dart
  static const String testnetOnionUrl =
      'http://ozpxrb6t5qvvfpa6ejuflmogipmmvwazxdlxckwi6oiubywj6drmhiqd.onion';

  // Mainnet (coming soon - offline)
  static const String mainnetOnionUrl = 'http://mainnet-coming-soon.onion';

  // Local development
  static const String defaultLocalUrl = 'http://localhost:3030';

  /// Default timeout for API calls
  static const Duration _defaultTimeout = Duration(seconds: 30);

  /// Longer timeout for Tor connections
  static const Duration _torTimeout = Duration(seconds: 60);

  late String baseUrl;
  late http.Client _client;
  NetworkEnvironment environment;
  final TorService _torService = TorService();

  ApiService({
    String? customUrl,
    this.environment = NetworkEnvironment.testnet,
  }) {
    if (customUrl != null) {
      baseUrl = customUrl;
    } else {
      baseUrl = _getBaseUrl(environment);
    }
    _initializeClient();
    print('🔗 UAT ApiService initialized with baseUrl: $baseUrl');
  }

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
      // Local/direct connection — no SOCKS proxy needed
      _client = http.Client();
      print('✅ Direct HTTP client (no Tor proxy needed for $baseUrl)');
    }
  }

  /// Create Tor-enabled HTTP client
  /// Priority: 1. Bundled Tor (port 9250) → 2. Existing Tor → 3. Tor Browser (9150)
  Future<http.Client> _createTorClient() async {
    final httpClient = HttpClient();
    int socksPort = 9250; // Default: bundled Tor

    // Try to detect existing Tor or start bundled Tor
    final existing = await _torService.detectExistingTor();
    if (existing['found'] == true) {
      final proxy = existing['proxy'] as String;
      socksPort = int.parse(proxy.split(':').last);
      print('✅ Using existing Tor: ${existing['type']} ($proxy)');
    } else {
      // Start bundled Tor daemon
      final started = await _torService.start();
      if (started) {
        socksPort = 9250; // Bundled Tor port
        print('✅ Bundled Tor started on port $socksPort');
      } else {
        // Fallback: try Tor Browser port
        socksPort = 9150;
        print('⚠️ Bundled Tor failed, trying Tor Browser on port $socksPort');
      }
    }

    SocksTCPClient.assignToHttpClient(
      httpClient,
      [
        ProxySettings(InternetAddress.loopbackIPv4, socksPort),
      ],
    );

    httpClient.connectionTimeout = const Duration(seconds: 30);
    httpClient.idleTimeout = const Duration(seconds: 30);

    print('✅ Tor SOCKS5 proxy configured (localhost:$socksPort)');
    return IOClient(httpClient);
  }

  // Switch network environment
  void switchEnvironment(NetworkEnvironment newEnv) {
    environment = newEnv;
    baseUrl = _getBaseUrl(newEnv);
    _initializeClient(); // Re-initialize client for new environment
    print('🔄 Switched to ${newEnv.name.toUpperCase()}: $baseUrl');
  }

  // Node Info
  Future<Map<String, dynamic>> getNodeInfo() async {
    try {
      final response =
          await _client.get(Uri.parse('$baseUrl/node-info')).timeout(_timeout);
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      throw Exception('Failed to get node info: ${response.statusCode}');
    } catch (e) {
      print('❌ getNodeInfo error: $e');
      rethrow;
    }
  }

  // Health Check
  Future<Map<String, dynamic>> getHealth() async {
    try {
      final response =
          await _client.get(Uri.parse('$baseUrl/health')).timeout(_timeout);
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      throw Exception('Failed to get health: ${response.statusCode}');
    } catch (e) {
      print('❌ getHealth error: $e');
      rethrow;
    }
  }

  // Get Balance
  Future<Account> getBalance(String address) async {
    try {
      final response = await _client
          .get(Uri.parse('$baseUrl/balance/$address'))
          .timeout(_timeout);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return Account(
          address: address,
          balance: data['balance'] ?? 0,
          voidBalance: data['void_balance'] ?? 0,
          history: [],
        );
      }
      throw Exception('Failed to get balance: ${response.statusCode}');
    } catch (e) {
      print('❌ getBalance error: $e');
      rethrow;
    }
  }

  // Get Account (with history)
  Future<Account> getAccount(String address) async {
    try {
      final response = await _client
          .get(Uri.parse('$baseUrl/account/$address'))
          .timeout(_timeout);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return Account.fromJson(data);
      }
      throw Exception('Failed to get account: ${response.statusCode}');
    } catch (e) {
      print('❌ getAccount error: $e');
      rethrow;
    }
  }

  // Request Faucet
  Future<Map<String, dynamic>> requestFaucet(String address) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl/faucet'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'address': address}),
          )
          .timeout(_timeout);

      final data = json.decode(response.body);

      // Critical: Check BOTH status code AND response body status
      if (response.statusCode != 200 || data['status'] == 'error') {
        throw Exception(data['msg'] ?? 'Faucet request failed');
      }

      return data;
    } catch (e) {
      print('❌ requestFaucet error: $e');
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
  }) async {
    try {
      final body = <String, dynamic>{
        'from': from,
        'target': to,
        'amount': amount,
      };
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

      final response = await _client
          .post(
            Uri.parse('$baseUrl/send'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(body),
          )
          .timeout(_timeout);

      final data = json.decode(response.body);

      // Critical: Check BOTH status code AND response body status
      if (response.statusCode != 200 || data['status'] == 'error') {
        throw Exception(data['msg'] ?? 'Transaction failed');
      }

      return data;
    } catch (e) {
      print('❌ sendTransaction error: $e');
      rethrow;
    }
  }

  // Proof-of-Burn — matches backend BurnRequest { coin_type, txid, recipient_address }
  Future<Map<String, dynamic>> submitBurn({
    required String coinType, // "btc" or "eth"
    required String txid,
    String? recipientAddress,
  }) async {
    try {
      final body = <String, dynamic>{
        'coin_type': coinType,
        'txid': txid,
      };
      if (recipientAddress != null) {
        body['recipient_address'] = recipientAddress;
      }

      final response = await _client
          .post(
            Uri.parse('$baseUrl/burn'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(body),
          )
          .timeout(_timeout);

      final data = json.decode(response.body);

      // Critical: Check BOTH status code AND response body status
      if (response.statusCode != 200 || data['status'] == 'error') {
        throw Exception(data['msg'] ?? 'Burn submission failed');
      }

      return data;
    } catch (e) {
      print('❌ submitBurn error: $e');
      rethrow;
    }
  }

  // Get Validators
  Future<List<ValidatorInfo>> getValidators() async {
    try {
      final response =
          await _client.get(Uri.parse('$baseUrl/validators')).timeout(_timeout);
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((v) => ValidatorInfo.fromJson(v)).toList();
      }
      throw Exception('Failed to get validators: ${response.statusCode}');
    } catch (e) {
      print('❌ getValidators error: $e');
      rethrow;
    }
  }

  // Get Latest Block
  Future<BlockInfo> getLatestBlock() async {
    try {
      final response =
          await _client.get(Uri.parse('$baseUrl/block')).timeout(_timeout);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return BlockInfo.fromJson(data);
      }
      throw Exception('Failed to get latest block: ${response.statusCode}');
    } catch (e) {
      print('❌ getLatestBlock error: $e');
      rethrow;
    }
  }

  // Get Recent Blocks
  Future<List<BlockInfo>> getRecentBlocks() async {
    try {
      final response = await _client
          .get(Uri.parse('$baseUrl/blocks/recent'))
          .timeout(_timeout);
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((b) => BlockInfo.fromJson(b)).toList();
      }
      throw Exception('Failed to get recent blocks: ${response.statusCode}');
    } catch (e) {
      print('❌ getRecentBlocks error: $e');
      rethrow;
    }
  }

  // Get Peers
  Future<List<String>> getPeers() async {
    try {
      final response =
          await _client.get(Uri.parse('$baseUrl/peers')).timeout(_timeout);
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.cast<String>();
      }
      throw Exception('Failed to get peers: ${response.statusCode}');
    } catch (e) {
      print('❌ getPeers error: $e');
      rethrow;
    }
  }

  // Get Transaction History for address
  Future<List<Transaction>> getHistory(String address) async {
    try {
      final response = await _client
          .get(Uri.parse('$baseUrl/history/$address'))
          .timeout(_timeout);
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((tx) => Transaction.fromJson(tx)).toList();
      }
      throw Exception('Failed to get history: ${response.statusCode}');
    } catch (e) {
      print('❌ getHistory error: $e');
      rethrow;
    }
  }

  /// Cleanup: stop bundled Tor when no longer needed
  Future<void> dispose() async {
    await _torService.stop();
  }
}
