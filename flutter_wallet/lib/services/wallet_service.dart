import 'dart:convert';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'package:bip39/bip39.dart' as bip39;
import 'dilithium_service.dart';

/// Wallet Service for UAT Blockchain
///
/// Dilithium5 mode (native library available):
/// - Real CRYSTALS-Dilithium5 keypair (PK: 2592 bytes, SK: 4864 bytes)
/// - Real UAT address: "UAT" + Base58Check(BLAKE2b-160(pubkey))
/// - Real post-quantum signatures for transactions
///
/// Fallback mode (native library not compiled):
/// - SHA256-based simplified derivation (testnet L1 compatible)
/// - Deterministic from BIP39 seed
///
/// Both modes use BIP39 24-word mnemonic for wallet creation/backup.
class WalletService {
  static const String _seedKey = 'wallet_seed';
  static const String _addressKey = 'wallet_address';
  static const String _importModeKey = 'wallet_import_mode';
  static const String _publicKeyKey = 'wallet_public_key';
  static const String _secretKeyKey = 'wallet_secret_key';
  static const String _cryptoModeKey = 'wallet_crypto_mode';

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
      // Real Dilithium5 keypair
      final keypair = DilithiumService.generateKeypair();
      address = DilithiumService.publicKeyToAddress(keypair.publicKey);
      cryptoMode = 'dilithium5';

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_seedKey, mnemonic);
      await prefs.setString(_addressKey, address);
      await prefs.setString(_publicKeyKey, keypair.publicKeyHex);
      await prefs.setString(_secretKeyKey, keypair.secretKeyHex);
      await prefs.setString(_importModeKey, 'mnemonic');
      await prefs.setString(_cryptoModeKey, cryptoMode);

      print('🔐 Dilithium5 wallet created');
      print('   Address: $address');
      print('   PK: ${keypair.publicKey.length} bytes');
    } else {
      // SHA256 fallback for testnet L1
      final seed = bip39.mnemonicToSeed(mnemonic);
      address = _deriveAddressSha256(seed);
      cryptoMode = 'sha256';

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_seedKey, mnemonic);
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
  /// Dilithium5: Generates a NEW keypair (address differs from original).
  /// SHA256 fallback: Deterministic — same address.
  Future<Map<String, String>> importWallet(String mnemonic) async {
    if (!bip39.validateMnemonic(mnemonic)) {
      throw Exception('Invalid mnemonic phrase');
    }

    String address;
    String cryptoMode;

    if (DilithiumService.isAvailable) {
      final prefs = await SharedPreferences.getInstance();
      final existingSeed = prefs.getString(_seedKey);
      final existingPk = prefs.getString(_publicKeyKey);

      if (existingSeed == mnemonic && existingPk != null) {
        // Same device — reuse existing keypair
        address = prefs.getString(_addressKey) ?? '';
        cryptoMode = 'dilithium5';
        await prefs.setString(_importModeKey, 'mnemonic');
        print('🔐 Restored Dilithium5 wallet from local storage');
      } else {
        // New import — generate new keypair
        final keypair = DilithiumService.generateKeypair();
        address = DilithiumService.publicKeyToAddress(keypair.publicKey);
        cryptoMode = 'dilithium5';

        await prefs.setString(_seedKey, mnemonic);
        await prefs.setString(_addressKey, address);
        await prefs.setString(_publicKeyKey, keypair.publicKeyHex);
        await prefs.setString(_secretKeyKey, keypair.secretKeyHex);
        await prefs.setString(_importModeKey, 'mnemonic');
        await prefs.setString(_cryptoModeKey, cryptoMode);

        print('🔐 New Dilithium5 keypair for imported mnemonic');
        print('   Address: $address');
      }
    } else {
      final seed = bip39.mnemonicToSeed(mnemonic);
      address = _deriveAddressSha256(seed);
      cryptoMode = 'sha256';

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_seedKey, mnemonic);
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
    await prefs.remove(_seedKey);
    await prefs.remove(_publicKeyKey);
    await prefs.remove(_secretKeyKey);

    return {'address': address};
  }

  /// Get current wallet info
  Future<Map<String, String>?> getCurrentWallet() async {
    final prefs = await SharedPreferences.getInstance();
    final address = prefs.getString(_addressKey);
    if (address == null) return null;

    final result = <String, String>{'address': address};
    final mnemonic = prefs.getString(_seedKey);
    if (mnemonic != null) result['mnemonic'] = mnemonic;
    final pk = prefs.getString(_publicKeyKey);
    if (pk != null) result['public_key'] = pk;
    final mode = prefs.getString(_cryptoModeKey);
    if (mode != null) result['crypto_mode'] = mode;

    return result;
  }

  /// Get hex-encoded public key (for sending with transactions)
  Future<String?> getPublicKeyHex() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_publicKeyKey);
  }

  /// Delete wallet
  Future<void> deleteWallet() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_seedKey);
    await prefs.remove(_addressKey);
    await prefs.remove(_importModeKey);
    await prefs.remove(_publicKeyKey);
    await prefs.remove(_secretKeyKey);
    await prefs.remove(_cryptoModeKey);
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
      final prefs = await SharedPreferences.getInstance();
      final skHex = prefs.getString(_secretKeyKey);
      if (skHex == null) throw Exception('Secret key not found');

      final secretKey = DilithiumService.hexToBytes(skHex);
      final message = Uint8List.fromList(utf8.encode(txData));
      final signature = DilithiumService.sign(message, secretKey);
      return DilithiumService.bytesToHex(signature);
    } else {
      final mnemonic = wallet['mnemonic'];
      if (mnemonic == null) throw Exception('No mnemonic for signing');
      final seed = bip39.mnemonicToSeed(mnemonic);
      final privateKey = seed.sublist(0, 32);
      final signature = sha256.convert(utf8.encode(txData) + privateKey);
      return signature.toString();
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
