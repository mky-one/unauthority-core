import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'package:bip39/bip39.dart' as bip39;
import 'package:pointycastle/digests/blake2b.dart';
import 'package:cryptography/cryptography.dart' as ed_crypto;
import 'dilithium_service.dart';

/// Wallet Service for UAT Validator Dashboard
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
  static const String _monitorModeKey = 'validator_monitor_mode';

  // Sensitive keys (flutter_secure_storage — Keychain/Keystore)
  static const String _seedKey = 'wallet_seed';
  static const String _publicKeyKey = 'wallet_public_key';
  static const String _secretKeyKey = 'wallet_secret_key';

  /// Encrypted storage backed by platform Keychain (iOS/macOS) or Keystore (Android)
  /// useDataProtectionKeyChain: false = legacy file-based keychain (works with ad-hoc signing)
  /// macOS will ask for login password ONCE → click "Always Allow" → never asks again.
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
    mOptions: MacOsOptions(useDataProtectionKeyChain: false),
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
      if (pk != null) {
        await _secureStorage.write(key: _publicKeyKey, value: pk);
      }
      final sk = prefs.getString(_secretKeyKey);
      if (sk != null) {
        await _secureStorage.write(key: _secretKeyKey, value: sk);
      }
      // Remove secrets from SharedPreferences
      await prefs.remove(_seedKey);
      await prefs.remove(_publicKeyKey);
      await prefs.remove(_secretKeyKey);
      debugPrint('🔒 Migrated wallet secrets to secure storage');
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
      try {
        final keypair = DilithiumService.generateKeypairFromSeed(seed);
        address = DilithiumService.publicKeyToAddress(keypair.publicKey);
        cryptoMode = 'dilithium5';

        // Secrets → Keychain/Keystore
        await _secureStorage.write(key: _seedKey, value: mnemonic);
        await _secureStorage.write(
          key: _publicKeyKey,
          value: keypair.publicKeyHex,
        );
        await _secureStorage.write(
          key: _secretKeyKey,
          value: keypair.secretKeyHex,
        );

        // Non-sensitive → SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_addressKey, address);
        await prefs.setString(_importModeKey, 'mnemonic');
        await prefs.setString(_cryptoModeKey, cryptoMode);

        // Zero Dart-side secret key copy
        keypair.secretKey.fillRange(0, keypair.secretKey.length, 0);

        debugPrint('🔐 Dilithium5 wallet created (deterministic from seed)');
        // NOTE: Do not log address or key sizes to console in production
      } finally {
        seed.fillRange(0, seed.length, 0);
      }
    } else {
      // Ed25519 + BLAKE2b fallback (matches uat-crypto address format)
      final seed = bip39.mnemonicToSeed(mnemonic);
      try {
        address = await _deriveAddressEd25519(seed);
        cryptoMode = 'ed25519';

        await _secureStorage.write(key: _seedKey, value: mnemonic);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_addressKey, address);
        await prefs.setString(_importModeKey, 'mnemonic');
        await prefs.setString(_cryptoModeKey, cryptoMode);

        debugPrint(
          '⚠️ Ed25519 fallback wallet (Dilithium5 native lib not loaded)',
        );
      } finally {
        seed.fillRange(0, seed.length, 0);
      }
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
      try {
        final keypair = DilithiumService.generateKeypairFromSeed(seed);
        address = DilithiumService.publicKeyToAddress(keypair.publicKey);
        cryptoMode = 'dilithium5';

        // Secrets → Keychain/Keystore
        await _secureStorage.write(key: _seedKey, value: mnemonic);
        await _secureStorage.write(
          key: _publicKeyKey,
          value: keypair.publicKeyHex,
        );
        await _secureStorage.write(
          key: _secretKeyKey,
          value: keypair.secretKeyHex,
        );

        // Non-sensitive → SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_addressKey, address);
        await prefs.setString(_importModeKey, 'mnemonic');
        await prefs.setString(_cryptoModeKey, cryptoMode);

        // Zero Dart-side secret key copy
        keypair.secretKey.fillRange(0, keypair.secretKey.length, 0);

        debugPrint(
          '🔐 Dilithium5 wallet restored from mnemonic (deterministic)',
        );
        // NOTE: Do not log address to console in production
      } finally {
        seed.fillRange(0, seed.length, 0);
      }
    } else {
      final seed = bip39.mnemonicToSeed(mnemonic);
      try {
        address = await _deriveAddressEd25519(seed);
        cryptoMode = 'ed25519';

        await _secureStorage.write(key: _seedKey, value: mnemonic);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_addressKey, address);
        await prefs.setString(_importModeKey, 'mnemonic');
        await prefs.setString(_cryptoModeKey, cryptoMode);
      } finally {
        seed.fillRange(0, seed.length, 0);
      }
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

  /// Import wallet by hex-encoded private key.
  ///
  /// Derives the public key and address from the secret key.
  /// Supports both Dilithium5 and Ed25519 fallback.
  Future<Map<String, String>> importByPrivateKey(String hexKey) async {
    final cleanHex = hexKey.trim();
    if (cleanHex.isEmpty || cleanHex.length < 64) {
      throw Exception('Invalid private key (too short)');
    }

    String address;
    String cryptoMode;

    if (DilithiumService.isAvailable) {
      // Dilithium5 secret key is 4864 bytes = 9728 hex chars
      // For shorter keys, treat as a seed and derive a keypair
      if (cleanHex.length >= 9728) {
        // Full Dilithium5 secret key
        final skBytes = _hexToBytes(cleanHex.substring(0, 9728));
        // Extract public key (last 2592 bytes of SK for Dilithium5)
        final pkBytes =
            Uint8List.fromList(skBytes.sublist(skBytes.length - 2592));
        address = DilithiumService.publicKeyToAddress(pkBytes);
        cryptoMode = 'dilithium5';

        await _secureStorage.write(
            key: _secretKeyKey, value: cleanHex.substring(0, 9728));
        await _secureStorage.write(
            key: _publicKeyKey,
            value: cleanHex.substring(cleanHex.length - 5184));
      } else {
        // Treat as seed bytes → derive keypair
        final seedBytes = _hexToBytes(cleanHex);
        final padded = List<int>.filled(64, 0);
        for (var i = 0; i < seedBytes.length && i < 64; i++) {
          padded[i] = seedBytes[i];
        }
        final keypair = DilithiumService.generateKeypairFromSeed(
            Uint8List.fromList(padded));
        address = DilithiumService.publicKeyToAddress(keypair.publicKey);
        cryptoMode = 'dilithium5';

        await _secureStorage.write(
            key: _publicKeyKey, value: keypair.publicKeyHex);
        await _secureStorage.write(
            key: _secretKeyKey, value: keypair.secretKeyHex);
        keypair.secretKey.fillRange(0, keypair.secretKey.length, 0);
      }
    } else {
      // Ed25519 fallback — treat hex as seed
      final seedBytes = _hexToBytes(cleanHex);
      address = await _deriveAddressEd25519(seedBytes);
      cryptoMode = 'ed25519';
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_addressKey, address);
    await prefs.setString(_importModeKey, 'private_key');
    await prefs.setString(_cryptoModeKey, cryptoMode);
    // No mnemonic for PK import
    await _secureStorage.delete(key: _seedKey);

    return {
      'address': address,
      'crypto_mode': cryptoMode,
    };
  }

  /// Convert hex string to bytes
  Uint8List _hexToBytes(String hex) {
    final clean = hex.replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
    final bytes = <int>[];
    for (var i = 0; i < clean.length - 1; i += 2) {
      bytes.add(int.parse(clean.substring(i, i + 2), radix: 16));
    }
    return Uint8List.fromList(bytes);
  }

  /// Get current wallet info.
  /// FIX C-02: Does NOT return mnemonic by default. Use [includeMnemonic]
  /// only when the user explicitly requests seed phrase (e.g. settings backup).
  Future<Map<String, String>?> getCurrentWallet({
    bool includeMnemonic = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final address = prefs.getString(_addressKey);
    if (address == null) return null;

    final result = <String, String>{'address': address};
    if (includeMnemonic) {
      final mnemonic = await _secureStorage.read(key: _seedKey);
      if (mnemonic != null) result['mnemonic'] = mnemonic;
    }
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
    await prefs.remove(_monitorModeKey);
    // Wipe secrets from secure storage (each wrapped individually —
    // macOS Keychain can throw PlatformException, must not block navigation)
    try {
      await _secureStorage.delete(key: _seedKey);
    } catch (e) {
      debugPrint('⚠️ Failed to delete seed from keychain: $e');
    }
    try {
      await _secureStorage.delete(key: _publicKeyKey);
    } catch (e) {
      debugPrint('⚠️ Failed to delete public key from keychain: $e');
    }
    try {
      await _secureStorage.delete(key: _secretKeyKey);
    } catch (e) {
      debugPrint('⚠️ Failed to delete secret key from keychain: $e');
    }
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

  /// Set monitor-only mode (genesis bootstrap validator — no local node spawn)
  Future<void> setMonitorMode(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_monitorModeKey, enabled);
  }

  /// Check if this wallet is in monitor-only mode
  /// (genesis bootstrap validator already running as CLI node)
  Future<bool> isMonitorMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_monitorModeKey) ?? false;
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
      if (skHex == null) {
        throw Exception('Secret key not found in secure storage');
      }

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
  // ADDRESS DERIVATION — Ed25519 + BLAKE2b-160 + Base58Check
  // Matches uat-crypto::public_key_to_address() EXACTLY
  // ══════════════════════════════════════════════════════════════════════

  /// Base58 alphabet (Bitcoin-style)
  static const _base58Chars =
      '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';

  /// Base58 encode bytes (matches bs58 crate in Rust)
  static String _base58Encode(Uint8List input) {
    if (input.isEmpty) return '';
    int zeros = 0;
    for (final b in input) {
      if (b != 0) break;
      zeros++;
    }
    final encoded = <int>[];
    var num = BigInt.zero;
    for (final b in input) {
      num = (num << 8) | BigInt.from(b);
    }
    while (num > BigInt.zero) {
      final rem = (num % BigInt.from(58)).toInt();
      num = num ~/ BigInt.from(58);
      encoded.insert(0, rem);
    }
    final result = StringBuffer();
    for (int i = 0; i < zeros; i++) {
      result.write('1');
    }
    for (final idx in encoded) {
      result.write(_base58Chars[idx]);
    }
    return result.toString();
  }

  /// Derive UAT address from Ed25519 public key (uat-crypto compatible).
  static String _deriveAddressFromPublicKey(Uint8List publicKey) {
    const versionByte = 0x4A;
    final blake2b = Blake2bDigest(digestSize: 64);
    final hash = Uint8List(64);
    blake2b.update(publicKey, 0, publicKey.length);
    blake2b.doFinal(hash, 0);
    final pubkeyHash = hash.sublist(0, 20);

    final payload = Uint8List(21);
    payload[0] = versionByte;
    payload.setRange(1, 21, pubkeyHash);

    final hash1 = sha256.convert(payload);
    final hash2 = sha256.convert(hash1.bytes);
    final checksum = hash2.bytes.sublist(0, 4);

    final addressBytes = Uint8List(25);
    addressBytes.setRange(0, 21, payload);
    addressBytes.setRange(21, 25, checksum);

    return 'UAT${_base58Encode(addressBytes)}';
  }

  /// Derive Ed25519 keypair from BIP39 seed and return UAT address.
  Future<String> _deriveAddressEd25519(List<int> seed) async {
    final privateSeed = Uint8List.fromList(seed.sublist(0, 32));
    try {
      final algorithm = ed_crypto.Ed25519();
      final keyPair = await algorithm.newKeyPairFromSeed(privateSeed.toList());
      final pubKey = await keyPair.extractPublicKey();
      return _deriveAddressFromPublicKey(Uint8List.fromList(pubKey.bytes));
    } finally {
      privateSeed.fillRange(0, privateSeed.length, 0);
    }
  }
}
