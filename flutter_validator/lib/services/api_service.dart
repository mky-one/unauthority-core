import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:socks5_proxy/socks_client.dart';
import '../models/account.dart';

enum NetworkEnvironment { testnet, mainnet }

class ApiService {
  // Testnet .onion (online)
  static const String testnetOnionUrl =
      'http://fhljoiopyz2eflttc7o5qwfj6l6skhtlkjpn4r6yw4atqpy2azydnnqd.onion';

  // Mainnet (coming soon - offline)
  static const String mainnetOnionUrl = 'http://mainnet-coming-soon.onion';

  // Local development
  static const String defaultLocalUrl = 'http://localhost:3030';

  late String baseUrl;
  late http.Client _client;
  NetworkEnvironment environment;

  ApiService({
    String? customUrl,
    this.environment = NetworkEnvironment.testnet, // Default to testnet
  }) {
    if (customUrl != null) {
      baseUrl = customUrl;
    } else {
      // Auto-select based on environment
      baseUrl = environment == NetworkEnvironment.testnet
          ? testnetOnionUrl
          : mainnetOnionUrl;
    }
    _client = _createHttpClient();
    print('🔗 UAT ApiService initialized with baseUrl: $baseUrl');
  }

  // Create HTTP client with Tor SOCKS proxy support (only for .onion)
  http.Client _createHttpClient() {
    final httpClient = HttpClient();

    // Only configure SOCKS5 proxy for .onion domains
    if (baseUrl.contains('.onion')) {
      SocksTCPClient.assignToHttpClient(httpClient, [
        ProxySettings(InternetAddress.loopbackIPv4, 9150), // Tor Browser
        ProxySettings(
          InternetAddress.loopbackIPv4,
          9050,
        ), // Fallback: tor daemon
      ]);

      // Longer timeout for Tor connections
      httpClient.connectionTimeout = Duration(seconds: 30);
      httpClient.idleTimeout = Duration(seconds: 30);

      print('✅ Tor SOCKS5 proxy configured (localhost:9150/9050)');
    } else {
      httpClient.connectionTimeout = Duration(seconds: 10);
      print('✅ Direct HTTP client (no Tor proxy for $baseUrl)');
    }

    return IOClient(httpClient);
  }

  // Switch network environment
  void switchEnvironment(NetworkEnvironment newEnv) {
    environment = newEnv;
    baseUrl = newEnv == NetworkEnvironment.testnet
        ? testnetOnionUrl
        : mainnetOnionUrl;
    // Recreate HTTP client so proxy settings match new baseUrl
    _client = _createHttpClient();
    print(
      '🔄 Switched to ${newEnv == NetworkEnvironment.testnet ? "TESTNET" : "MAINNET"}: $baseUrl',
    );
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
      print('❌ getNodeInfo error: $e');
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
      print('❌ getHealth error: $e');
      rethrow;
    }
  }

  // Get Balance
  Future<Account> getBalance(String address) async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/balance/$address'),
      );
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
      final response = await _client.get(
        Uri.parse('$baseUrl/account/$address'),
      );
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
      print('❌ requestFaucet error: $e');
      rethrow;
    }
  }

  // Send Transaction
  Future<Map<String, dynamic>> sendTransaction({
    required String from,
    required String to,
    required int amount,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/send'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'from': from, 'target': to, 'amount': amount}),
      );

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
      print('❌ submitBurn error: $e');
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
      print('❌ getValidators error: $e');
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
      print('❌ getLatestBlock error: $e');
      rethrow;
    }
  }

  // Get Recent Blocks
  Future<List<BlockInfo>> getRecentBlocks() async {
    try {
      final response = await _client.get(Uri.parse('$baseUrl/blocks/recent'));
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
      final response = await _client.get(Uri.parse('$baseUrl/peers'));
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

  /// Release HTTP client resources. Called by Provider.dispose.
  void dispose() {
    _client.close();
  }
}
