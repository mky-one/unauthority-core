import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'package:bip39/bip39.dart' as bip39;
import 'dilithium_service.dart';

/// Wallet Service for UAT Blockchain
///
/// SECURITY: All secret material (seed, private key) is stored in
/// platform Keychain/Keystore via flutter_secure_storage.
/// Only the address and crypto_mode are in SharedPreferences (non-sensitive).
///
/// Dilithium5 mode (native library available):
/// - Real CRYSTALS-Dilithium5 keypair (PK: 2592 bytes, SK: 4864 bytes)
/// - Deterministic from BIP39 seed via HMAC-SHA512 DRBG seeding
/// - Real UAT address: "UAT" + Base58Check(BLAKE2b-160(pubkey))
/// - Real post-quantum signatures for transactions
///
/// Fallback mode (native library not compiled):
/// - SHA256-based simplified derivation (testnet L1 compatible)
/// - Deterministic from BIP39 seed
///
/// Both modes use BIP39 24-word mnemonic for wallet creation/backup.
class WalletService {
  // Non-sensitive keys (SharedPreferences — survives app reinstall on some platforms)
  static const String _addressKey = 'wallet_address';
  static const String _importModeKey = 'wallet_import_mode';
  static const String _cryptoModeKey = 'wallet_crypto_mode';

  // Sensitive keys (flutter_secure_storage — Keychain/Keystore)
  static const String _seedKey = 'wallet_seed';
  static const String _publicKeyKey = 'wallet_public_key';
  static const String _secretKeyKey = 'wallet_secret_key';

  /// Encrypted storage backed by platform Keychain (iOS/macOS) or Keystore (Android)
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  /// One-time migration from SharedPreferences → SecureStorage
  /// Called on app startup. Silent if already migrated.
  Future<void> migrateFromSharedPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final existingSeed = prefs.getString(_seedKey);
    if (existingSeed != null) {
      // Migrate secrets to secure storage
      await _secureStorage.write(key: _seedKey, value: existingSeed);
      final pk = prefs.getString(_publicKeyKey);
      if (pk != null) await _secureStorage.write(key: _publicKeyKey, value: pk);
      final sk = prefs.getString(_secretKeyKey);
      if (sk != null) {
        await _secureStorage.write(key: _secretKeyKey, value: sk);
      }
      // Remove secrets from SharedPreferences
      await prefs.remove(_seedKey);
      await prefs.remove(_publicKeyKey);
      await prefs.remove(_secretKeyKey);
      print('🔒 Migrated wallet secrets to secure storage');
    }
  }

  /// Whether this wallet uses real Dilithium5 cryptography
  Future<bool> isDilithium5Wallet() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_cryptoModeKey) == 'dilithium5';
  }

  /// Generate new wallet with real Dilithium5 keypair (if available)
  Future<Map<String, String>> generateWallet() async {
    final mnemonic = bip39.generateMnemonic(strength: 256);
    String address;
    String cryptoMode;

    if (DilithiumService.isAvailable) {
      // Real Dilithium5 keypair — deterministic from seed
      final seed = bip39.mnemonicToSeed(mnemonic);
      final keypair = DilithiumService.generateKeypairFromSeed(seed);
      address = DilithiumService.publicKeyToAddress(keypair.publicKey);
      cryptoMode = 'dilithium5';

      // Secrets → Keychain/Keystore
      await _secureStorage.write(key: _seedKey, value: mnemonic);
      await _secureStorage.write(
          key: _publicKeyKey, value: keypair.publicKeyHex);
      await _secureStorage.write(
          key: _secretKeyKey, value: keypair.secretKeyHex);

      // Non-sensitive → SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_addressKey, address);
      await prefs.setString(_importModeKey, 'mnemonic');
      await prefs.setString(_cryptoModeKey, cryptoMode);

      print('🔐 Dilithium5 wallet created (deterministic from seed)');
      print('   Address: $address');
      print('   PK: ${keypair.publicKey.length} bytes');
    } else {
      // SHA256 fallback for testnet L1
      final seed = bip39.mnemonicToSeed(mnemonic);
      address = _deriveAddressSha256(seed);
      cryptoMode = 'sha256';

      await _secureStorage.write(key: _seedKey, value: mnemonic);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_addressKey, address);
      await prefs.setString(_importModeKey, 'mnemonic');
      await prefs.setString(_cryptoModeKey, cryptoMode);

      print('⚠️ SHA256 fallback wallet (Dilithium5 native lib not loaded)');
    }

    return {
      'mnemonic': mnemonic,
      'address': address,
      'crypto_mode': cryptoMode,
    };
  }

  /// Import wallet from mnemonic.
  ///
  /// Dilithium5: Deterministic from seed — same mnemonic = same address.
  /// SHA256 fallback: Also deterministic.
  Future<Map<String, String>> importWallet(String mnemonic) async {
    if (!bip39.validateMnemonic(mnemonic)) {
      throw Exception('Invalid mnemonic phrase');
    }

    String address;
    String cryptoMode;

    if (DilithiumService.isAvailable) {
      // Deterministic keypair from BIP39 seed
      final seed = bip39.mnemonicToSeed(mnemonic);
      final keypair = DilithiumService.generateKeypairFromSeed(seed);
      address = DilithiumService.publicKeyToAddress(keypair.publicKey);
      cryptoMode = 'dilithium5';

      // Secrets → Keychain/Keystore
      await _secureStorage.write(key: _seedKey, value: mnemonic);
      await _secureStorage.write(
          key: _publicKeyKey, value: keypair.publicKeyHex);
      await _secureStorage.write(
          key: _secretKeyKey, value: keypair.secretKeyHex);

      // Non-sensitive → SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_addressKey, address);
      await prefs.setString(_importModeKey, 'mnemonic');
      await prefs.setString(_cryptoModeKey, cryptoMode);

      print('🔐 Dilithium5 wallet restored from mnemonic (deterministic)');
      print('   Address: $address');
    } else {
      final seed = bip39.mnemonicToSeed(mnemonic);
      address = _deriveAddressSha256(seed);
      cryptoMode = 'sha256';

      await _secureStorage.write(key: _seedKey, value: mnemonic);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_addressKey, address);
      await prefs.setString(_importModeKey, 'mnemonic');
      await prefs.setString(_cryptoModeKey, cryptoMode);
    }

    return {
      'mnemonic': mnemonic,
      'address': address,
      'crypto_mode': cryptoMode,
    };
  }

  /// Import by address only (testnet genesis accounts)
  Future<Map<String, String>> importByAddress(String address) async {
    if (!address.startsWith('UAT') || address.length < 30) {
      throw Exception('Invalid UAT address format');
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_addressKey, address);
    await prefs.setString(_importModeKey, 'address');
    await prefs.setString(_cryptoModeKey, 'address_only');
    // Clear any secrets
    await _secureStorage.delete(key: _seedKey);
    await _secureStorage.delete(key: _publicKeyKey);
    await _secureStorage.delete(key: _secretKeyKey);

    return {'address': address};
  }

  /// Get current wallet info
  Future<Map<String, String>?> getCurrentWallet() async {
    final prefs = await SharedPreferences.getInstance();
    final address = prefs.getString(_addressKey);
    if (address == null) return null;

    final result = <String, String>{'address': address};
    final mnemonic = await _secureStorage.read(key: _seedKey);
    if (mnemonic != null) result['mnemonic'] = mnemonic;
    final pk = await _secureStorage.read(key: _publicKeyKey);
    if (pk != null) result['public_key'] = pk;
    final mode = prefs.getString(_cryptoModeKey);
    if (mode != null) result['crypto_mode'] = mode;

    return result;
  }

  /// Get hex-encoded public key (for sending with transactions)
  Future<String?> getPublicKeyHex() async {
    return await _secureStorage.read(key: _publicKeyKey);
  }

  /// Delete wallet — wipes all sensitive and non-sensitive data
  Future<void> deleteWallet() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_addressKey);
    await prefs.remove(_importModeKey);
    await prefs.remove(_cryptoModeKey);
    // Wipe secrets from secure storage
    await _secureStorage.delete(key: _seedKey);
    await _secureStorage.delete(key: _publicKeyKey);
    await _secureStorage.delete(key: _secretKeyKey);
  }

  /// Clear wallet — alias for deleteWallet
  Future<void> clearWallet() async {
    await deleteWallet();
  }

  /// Check if wallet was imported by address only
  Future<bool> isAddressOnlyImport() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_importModeKey) == 'address';
  }

  // ══════════════════════════════════════════════════════════════════════
  // SIGNING
  // ══════════════════════════════════════════════════════════════════════

  /// Sign transaction data with Dilithium5 or SHA256 fallback.
  Future<String> signTransaction(String txData) async {
    final wallet = await getCurrentWallet();
    if (wallet == null) throw Exception('No wallet found');

    final isAddressOnly = await isAddressOnlyImport();
    if (isAddressOnly) {
      return 'address-only-no-local-signing';
    }

    final cryptoMode = wallet['crypto_mode'] ?? 'sha256';

    if (cryptoMode == 'dilithium5' && DilithiumService.isAvailable) {
      final skHex = await _secureStorage.read(key: _secretKeyKey);
      if (skHex == null)
        throw Exception('Secret key not found in secure storage');

      final secretKey = DilithiumService.hexToBytes(skHex);
      final message = Uint8List.fromList(utf8.encode(txData));
      try {
        final signature = DilithiumService.sign(message, secretKey);
        return DilithiumService.bytesToHex(signature);
      } finally {
        // SECURITY FIX L-01: Zero secret key in Dart memory after signing.
        // FFI layer zeros its copy, but Dart Uint8List remains until GC.
        secretKey.fillRange(0, secretKey.length, 0);
      }
    } else {
      final mnemonic = await _secureStorage.read(key: _seedKey);
      if (mnemonic == null) throw Exception('No mnemonic for signing');
      final seed = bip39.mnemonicToSeed(mnemonic);
      final privateKey = seed.sublist(0, 32);
      try {
        final signature = sha256.convert(utf8.encode(txData) + privateKey);
        return signature.toString();
      } finally {
        // SECURITY FIX L-01: Zero private key material after signing
        privateKey.fillRange(0, privateKey.length, 0);
        seed.fillRange(0, seed.length, 0);
      }
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // ADDRESS DERIVATION — SHA256 fallback
  // ══════════════════════════════════════════════════════════════════════

  String _deriveAddressSha256(List<int> seed) {
    final privateKey = seed.sublist(0, 32);
    final publicKeyHash = sha256.convert(privateKey);
    final addressBytes = publicKeyHash.bytes.sublist(0, 20);
    final hexAddress =
        addressBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join('');
    return 'UAT$hexAddress';
  }
}
