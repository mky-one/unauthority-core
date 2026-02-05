import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/account.dart';

class ApiService {
  static const String defaultOnionUrl =
      'http://fhljoiopyz2eflttc7o5qwfj6l6skhtlkjpn4r6yw4atqpy2azydnnqd.onion';

  late String baseUrl;

  ApiService({String? customUrl}) {
    baseUrl = customUrl ?? defaultOnionUrl;
  }

  // Node Info
  Future<Map<String, dynamic>> getNodeInfo() async {
    final response = await http.get(Uri.parse('$baseUrl/node-info'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Failed to get node info: ${response.statusCode}');
  }

  // Health Check
  Future<Map<String, dynamic>> getHealth() async {
    final response = await http.get(Uri.parse('$baseUrl/health'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Failed to get health: ${response.statusCode}');
  }

  // Get Balance
  Future<Account> getBalance(String address) async {
    final response = await http.get(Uri.parse('$baseUrl/balance/$address'));
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
  }

  // Get Account (with history)
  Future<Account> getAccount(String address) async {
    final response = await http.get(Uri.parse('$baseUrl/account/$address'));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return Account.fromJson(data);
    }
    throw Exception('Failed to get account: ${response.statusCode}');
  }

  // Request Faucet
  Future<Map<String, dynamic>> requestFaucet(String address) async {
    final response = await http.post(
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
  }

  // Send Transaction
  Future<Map<String, dynamic>> sendTransaction({
    required String from,
    required String to,
    required int amount,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/send'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'from': from,
        'target': to,
        'amount': amount,
      }),
    );

    final data = json.decode(response.body);

    // Critical: Check BOTH status code AND response body status
    if (response.statusCode != 200 || data['status'] == 'error') {
      throw Exception(data['msg'] ?? 'Transaction failed');
    }

    return data;
  }

  // Proof-of-Burn
  Future<Map<String, dynamic>> submitBurn({
    required String uatAddress,
    required String btcTxid,
    required String ethTxid,
    required int amount,
  }) async {
    final response = await http.post(
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
  }

  // Get Validators
  Future<List<ValidatorInfo>> getValidators() async {
    final response = await http.get(Uri.parse('$baseUrl/validators'));
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((v) => ValidatorInfo.fromJson(v)).toList();
    }
    throw Exception('Failed to get validators: ${response.statusCode}');
  }

  // Get Latest Block
  Future<BlockInfo> getLatestBlock() async {
    final response = await http.get(Uri.parse('$baseUrl/block'));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return BlockInfo.fromJson(data);
    }
    throw Exception('Failed to get latest block: ${response.statusCode}');
  }

  // Get Recent Blocks
  Future<List<BlockInfo>> getRecentBlocks() async {
    final response = await http.get(Uri.parse('$baseUrl/blocks/recent'));
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((b) => BlockInfo.fromJson(b)).toList();
    }
    throw Exception('Failed to get recent blocks: ${response.statusCode}');
  }

  // Get Peers
  Future<List<String>> getPeers() async {
    final response = await http.get(Uri.parse('$baseUrl/peers'));
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.cast<String>();
    }
    throw Exception('Failed to get peers: ${response.statusCode}');
  }
}
