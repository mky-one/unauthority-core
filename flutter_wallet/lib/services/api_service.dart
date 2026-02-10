import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:socks5_proxy/socks_client.dart';
import '../models/account.dart';
import 'tor_service.dart';
import 'network_config.dart';

enum NetworkEnvironment { testnet, mainnet }

class ApiService {
  // Bootstrap node addresses are loaded from assets/network_config.json
  // via NetworkConfig. NEVER hardcode .onion addresses here.
  // Use: scripts/update_network_config.sh to update addresses.

  /// Default timeout for API calls
  static const Duration _defaultTimeout = Duration(seconds: 30);

  /// Longer timeout for Tor connections
  static const Duration _torTimeout = Duration(seconds: 60);

  late String baseUrl;
  // FIX H-01: Initialize with safe default to prevent LateInitializationError
  // _initializeClient() replaces with Tor client asynchronously when needed
  http.Client _client = http.Client();
  NetworkEnvironment environment;
  final TorService _torService = TorService();

  /// FIX C11-08: Track client initialization future so callers can await
  /// readiness before making requests. Prevents DNS leaks from using
  /// the default http.Client on .onion URLs before Tor is ready.
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
    debugPrint('🔗 UAT ApiService initialized with baseUrl: $baseUrl');
  }

  /// Await Tor/HTTP client initialization before first request.
  /// Safe to call multiple times — resolves immediately after first init.
  Future<void> ensureReady() => _clientReady;

  String _getBaseUrl(NetworkEnvironment env) {
    switch (env) {
      case NetworkEnvironment.testnet:
        return NetworkConfig.testnetUrl;
      case NetworkEnvironment.mainnet:
        return NetworkConfig.mainnetUrl;
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
      debugPrint('✅ Direct HTTP client (no Tor proxy needed for $baseUrl)');
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
      debugPrint('✅ Using existing Tor: ${existing['type']} ($proxy)');
    } else {
      // Start bundled Tor daemon
      final started = await _torService.start();
      if (started) {
        socksPort = 9250; // Bundled Tor port
        debugPrint('✅ Bundled Tor started on port $socksPort');
      } else {
        // Fallback: try Tor Browser port
        socksPort = 9150;
        debugPrint(
            '⚠️ Bundled Tor failed, trying Tor Browser on port $socksPort');
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

    debugPrint('✅ Tor SOCKS5 proxy configured (localhost:$socksPort)');
    return IOClient(httpClient);
  }

  // Switch network environment
  void switchEnvironment(NetworkEnvironment newEnv) {
    environment = newEnv;
    baseUrl = _getBaseUrl(newEnv);
    _clientReady = _initializeClient(); // Re-initialize and track readiness
    debugPrint('🔄 Switched to ${newEnv.name.toUpperCase()}: $baseUrl');
  }

  // Node Info
  Future<Map<String, dynamic>> getNodeInfo() async {
    await ensureReady();
    try {
      final response =
          await _client.get(Uri.parse('$baseUrl/node-info')).timeout(_timeout);
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
    await ensureReady();
    try {
      final response =
          await _client.get(Uri.parse('$baseUrl/health')).timeout(_timeout);
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
    await ensureReady();
    try {
      final response = await _client
          .get(Uri.parse('$baseUrl/bal/$address'))
          .timeout(_timeout);
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
    await ensureReady();
    try {
      final response = await _client
          .get(Uri.parse('$baseUrl/account/$address'))
          .timeout(_timeout);
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
    await ensureReady();
    debugPrint('🚠 [API] requestFaucet -> $baseUrl/faucet  address=$address');
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
  }) async {
    await ensureReady();
    debugPrint(
        '💸 [API] sendTransaction -> $baseUrl/send  from=$from to=$to amount=$amount sig=${signature != null}');
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
      // Attach timestamp and fee for client-signed blocks (part of signing_hash)
      if (timestamp != null) {
        body['timestamp'] = timestamp;
      }
      if (fee != null) {
        body['fee'] = fee;
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
    await ensureReady();
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
    await ensureReady();
    try {
      final response =
          await _client.get(Uri.parse('$baseUrl/validators')).timeout(_timeout);
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
    await ensureReady();
    try {
      final response =
          await _client.get(Uri.parse('$baseUrl/block')).timeout(_timeout);
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
    await ensureReady();
    try {
      final response = await _client
          .get(Uri.parse('$baseUrl/blocks/recent'))
          .timeout(_timeout);
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
  // FIX C12-03: Backend GET /peers returns HashMap<String,String> (JSON object),
  // not a JSON array. Handle both Map and List for resilience.
  Future<List<String>> getPeers() async {
    await ensureReady();
    try {
      final response =
          await _client.get(Uri.parse('$baseUrl/peers')).timeout(_timeout);
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded is Map) {
          // Backend returns {"addr1": "addr2", ...} — extract keys as peer list
          return decoded.keys.cast<String>().toList();
        } else if (decoded is List) {
          return decoded.cast<String>();
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
    await ensureReady();
    try {
      final response = await _client
          .get(Uri.parse('$baseUrl/history/$address'))
          .timeout(_timeout);
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
    _client.close();
    await _torService.stop();
  }
}
