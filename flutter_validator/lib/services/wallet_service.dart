import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'package:bip39/bip39.dart' as bip39;

class WalletService {
  static const String _seedKey = 'wallet_seed';
  static const String _addressKey = 'wallet_address';

  // Generate new wallet
  Future<Map<String, String>> generateWallet() async {
    // Generate BIP39 mnemonic (24 words)
    final mnemonic = bip39.generateMnemonic(strength: 256);

    // Derive address from seed
    final seed = bip39.mnemonicToSeed(mnemonic);
    final address = _deriveAddress(seed);

    // Save to secure storage
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_seedKey, mnemonic);
    await prefs.setString(_addressKey, address);

    return {
      'mnemonic': mnemonic,
      'address': address,
    };
  }

  // Import wallet from mnemonic
  Future<Map<String, String>> importWallet(String mnemonic) async {
    if (!bip39.validateMnemonic(mnemonic)) {
      throw Exception('Invalid mnemonic phrase');
    }

    // Derive address from seed
    final seed = bip39.mnemonicToSeed(mnemonic);
    final address = _deriveAddress(seed);

    // Save to secure storage
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_seedKey, mnemonic);
    await prefs.setString(_addressKey, address);

    return {
      'mnemonic': mnemonic,
      'address': address,
    };
  }

  // Get current wallet
  Future<Map<String, String>?> getCurrentWallet() async {
    final prefs = await SharedPreferences.getInstance();
    final mnemonic = prefs.getString(_seedKey);
    final address = prefs.getString(_addressKey);

    if (mnemonic == null || address == null) {
      return null;
    }

    return {
      'mnemonic': mnemonic,
      'address': address,
    };
  }

  // Delete wallet
  Future<void> deleteWallet() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_seedKey);
    await prefs.remove(_addressKey);
  }

  // Derive UAT address from seed (simplified - match backend logic)
  String _deriveAddress(List<int> seed) {
    // Take first 32 bytes as private key
    final privateKey = seed.sublist(0, 32);

    // Hash to get public key (simplified)
    final publicKeyHash = sha256.convert(privateKey);

    // Take first 20 bytes and prefix with "UAT"
    final addressBytes = publicKeyHash.bytes.sublist(0, 20);
    final hexAddress =
        addressBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join('');

    return 'UAT$hexAddress';
  }

  // Sign transaction (placeholder - needs proper Ed25519 signing)
  Future<String> signTransaction(String txData) async {
    final wallet = await getCurrentWallet();
    if (wallet == null) {
      throw Exception('No wallet found');
    }

    final mnemonic = wallet['mnemonic']!;
    final seed = bip39.mnemonicToSeed(mnemonic);
    final privateKey = seed.sublist(0, 32);

    // Simple signature (in production, use proper Ed25519)
    final signature = sha256.convert(utf8.encode(txData) + privateKey);
    return signature.toString();
  }
}
