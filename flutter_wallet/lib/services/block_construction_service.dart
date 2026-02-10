import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:pointycastle/digests/keccak.dart';
import 'api_service.dart';
import 'wallet_service.dart';

/// Client-side block-lattice block construction for UAT.
///
/// Matches the backend's Block struct and signing_hash() exactly:
/// - Keccak-256 with CHAIN_ID domain separation (via pointycastle)
/// - PoW anti-spam: 16 leading zero bits
/// - Dilithium5 signature over signing_hash
///
/// This enables fully sovereign transactions — the node only verifies,
/// it never touches the user's secret key.
///
/// The backend's POST /send handler accepts client-provided `timestamp`
/// and `fee` fields when a signature is present, preserving the
/// signing_hash integrity for client-signed blocks.
class BlockConstructionService {
  final ApiService _api;
  final WalletService _wallet;

  /// Testnet CHAIN_ID = 2. Mainnet = 1.
  /// Must match uat_core::CHAIN_ID in the backend.
  static const int chainIdTestnet = 2;
  static const int chainIdMainnet = 1;

  /// Current chain ID — configurable at runtime.
  /// Defaults to testnet (2). Set to 1 for mainnet via constructor or setter.
  int chainId;

  /// PoW difficulty: 16 leading zero bits (matches backend MIN_POW_DIFFICULTY_BITS)
  static const int powDifficultyBits = 16;

  /// Minimum base fee in VOID (0.001 UAT = 100,000 VOID)
  /// Must match backend base_fee to pass fee validation.
  static const int baseFeeVoid = 100000;

  /// Maximum PoW iterations before giving up
  static const int maxPowIterations = 50000000;
  static const int blockTypeSend = 0;
  static const int blockTypeReceive = 1;
  static const int blockTypeChange = 2;
  static const int blockTypeMint = 3;
  static const int blockTypeSlash = 4;

  /// 1 UAT = 10^11 VOID (matches backend VOID_PER_UAT)
  static const int voidPerUat = 100000000000;

  BlockConstructionService({
    required ApiService api,
    required WalletService wallet,
    this.chainId = chainIdTestnet,
  })  : _api = api,
        _wallet = wallet;

  /// Update the chain ID at runtime (e.g., switching between testnet ↔ mainnet).
  void setChainId(int id) {
    assert(id == chainIdTestnet || id == chainIdMainnet,
        'Invalid chainId: must be $chainIdTestnet or $chainIdMainnet');
    chainId = id;
  }

  /// Send UAT with full client-side block construction.
  ///
  /// 1. Fetch sender's frontier (head block hash) from node
  /// 2. Construct Block with all fields
  /// 3. Mine PoW (16 zero bits anti-spam)
  /// 4. Sign with Dilithium5 (Keccak-256 signing_hash)
  /// 5. Submit pre-signed to POST /send
  ///
  /// Returns the transaction result from the node.
  Future<Map<String, dynamic>> sendTransaction({
    required String to,
    required double amountUatDouble,
  }) async {
    // 1. Get wallet info
    final walletInfo = await _wallet.getCurrentWallet();
    if (walletInfo == null) throw Exception('No wallet found');

    final address = walletInfo['address']!;
    final publicKeyHex = walletInfo['public_key'];
    if (publicKeyHex == null) {
      throw Exception(
          'No public key available — wallet must have Dilithium5 keypair');
    }

    // 2. Fetch account state (frontier)
    final account = await _api.getAccount(address);
    final previous = account.headBlock ?? '0';

    // 3. Convert amount to VOID (supports sub-UAT decimals)
    // e.g. 0.5 UAT = 0.5 × 10^11 = 50,000,000,000 VOID
    final amountVoid = BigInt.from((amountUatDouble * voidPerUat).round());
    final amountUat =
        amountUatDouble.floor(); // Integer UAT for API backward compat

    // 4. Current timestamp
    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    // 5. Mine PoW in a background isolate (FIX U1: prevents UI freeze)
    final powResult = await _minePoWInIsolate(
      chainId: chainId,
      account: address,
      previous: previous,
      blockType: blockTypeSend,
      amount: amountVoid,
      link: to,
      publicKey: publicKeyHex,
      timestamp: timestamp,
      fee: baseFeeVoid,
    );

    if (powResult == null) {
      throw Exception(
          'PoW failed after $maxPowIterations iterations. Try again.');
    }

    final work = powResult['work'] as int;
    final signingHash = powResult['hash'] as String;

    // 6. Sign the signing_hash with Dilithium5
    final signature = await _wallet.signTransaction(signingHash);

    // 7. Submit pre-signed block to node
    // Pass amount_void so backend uses exact VOID amount (supports sub-UAT precision)
    return await _api.sendTransaction(
      from: address,
      to: to,
      amount: amountUat,
      signature: signature,
      publicKey: publicKeyHex,
      previous: previous,
      work: work,
      timestamp: timestamp,
      fee: baseFeeVoid,
      amountVoid: amountVoid.toString(),
    );
  }

  /// Compute the signing_hash — delegates to static method for isolate compatibility.
  /// This is kept as a convenience entry point for non-PoW uses.
  ///
  /// Keccak-256 of:
  ///   chain_id (u64 LE) || account || previous || block_type (1 byte) ||
  ///   amount (u128 LE) || link || public_key || work (u64 LE) ||
  ///   timestamp (u64 LE) || fee (u128 LE)
  static String computeSigningHash({
    required int chainId,
    required String account,
    required String previous,
    required int blockType,
    required BigInt amount,
    required String link,
    required String publicKey,
    required int work,
    required int timestamp,
    required int fee,
  }) {
    return _computeSigningHashStatic(
      chainId: chainId,
      account: account,
      previous: previous,
      blockType: blockType,
      amount: amount,
      link: link,
      publicKey: publicKey,
      work: work,
      timestamp: timestamp,
      fee: fee,
    );
  }

  /// FIX U1: Mine PoW in a background isolate to prevent UI thread freezing.
  /// The heavy nonce loop runs off the main thread via Isolate.run().
  Future<Map<String, dynamic>?> _minePoWInIsolate({
    required int chainId,
    required String account,
    required String previous,
    required int blockType,
    required BigInt amount,
    required String link,
    required String publicKey,
    required int timestamp,
    required int fee,
  }) async {
    // Pass all params as a serializable map to the isolate
    final params = {
      'chainId': chainId,
      'account': account,
      'previous': previous,
      'blockType': blockType,
      'amount': amount.toString(), // BigInt → String for isolate transfer
      'link': link,
      'publicKey': publicKey,
      'timestamp': timestamp,
      'fee': fee,
      'maxIter': maxPowIterations,
      'diffBits': powDifficultyBits,
    };

    return await Isolate.run(() => _minePoWSync(params));
  }

  /// Static synchronous PoW mining — runs inside an isolate.
  /// Must be static/top-level for Isolate.run() compatibility.
  static Map<String, dynamic>? _minePoWSync(Map<String, dynamic> params) {
    final chainId = params['chainId'] as int;
    final account = params['account'] as String;
    final previous = params['previous'] as String;
    final blockType = params['blockType'] as int;
    final amount = BigInt.parse(params['amount'] as String);
    final link = params['link'] as String;
    final publicKey = params['publicKey'] as String;
    final timestamp = params['timestamp'] as int;
    final fee = params['fee'] as int;
    final maxIter = params['maxIter'] as int;
    final diffBits = params['diffBits'] as int;

    for (int nonce = 0; nonce < maxIter; nonce++) {
      final hash = _computeSigningHashStatic(
        chainId: chainId,
        account: account,
        previous: previous,
        blockType: blockType,
        amount: amount,
        link: link,
        publicKey: publicKey,
        work: nonce,
        timestamp: timestamp,
        fee: fee,
      );

      if (_hasLeadingZeroBitsStatic(hash, diffBits)) {
        return {'work': nonce, 'hash': hash};
      }
    }
    return null; // Failed to find valid nonce
  }

  /// Static version of _computeSigningHash for isolate use.
  static String _computeSigningHashStatic({
    required int chainId,
    required String account,
    required String previous,
    required int blockType,
    required BigInt amount,
    required String link,
    required String publicKey,
    required int work,
    required int timestamp,
    required int fee,
  }) {
    final data = <int>[];
    // chain_id (u64 LE)
    final cidData = ByteData(8);
    cidData.setUint64(0, chainId, Endian.little);
    data.addAll(cidData.buffer.asUint8List());
    // account bytes
    data.addAll(utf8.encode(account));
    // previous
    data.addAll(utf8.encode(previous));
    // block_type (1 byte)
    data.add(blockType);
    // amount (u128 LE)
    data.addAll(_u128ToLeBytesStatic(amount));
    // link
    data.addAll(utf8.encode(link));
    // public_key
    data.addAll(utf8.encode(publicKey));
    // work (u64 LE)
    final wData = ByteData(8);
    wData.setUint64(0, work, Endian.little);
    data.addAll(wData.buffer.asUint8List());
    // timestamp (u64 LE)
    final tData = ByteData(8);
    tData.setUint64(0, timestamp, Endian.little);
    data.addAll(tData.buffer.asUint8List());
    // fee (u128 LE)
    data.addAll(_u128ToLeBytesStatic(BigInt.from(fee)));

    return _keccak256Static(Uint8List.fromList(data));
  }

  /// Static leading zero bits check for isolate use.
  static bool _hasLeadingZeroBitsStatic(String hexHash, int requiredBits) {
    final bytes = _hexToBytesStatic(hexHash);
    int zeroBits = 0;
    for (final byte in bytes) {
      if (byte == 0) {
        zeroBits += 8;
      } else {
        int b = byte;
        for (int i = 7; i >= 0; i--) {
          if ((b >> i) & 1 == 0) {
            zeroBits++;
          } else {
            return zeroBits >= requiredBits;
          }
        }
        return zeroBits >= requiredBits;
      }
    }
    return zeroBits >= requiredBits;
  }

  /// Static u128 LE for isolate use.
  static Uint8List _u128ToLeBytesStatic(BigInt value) {
    final bytes = Uint8List(16);
    var v = value;
    for (int i = 0; i < 16; i++) {
      bytes[i] = (v & BigInt.from(0xFF)).toInt();
      v = v >> 8;
    }
    return bytes;
  }

  /// Static hex→bytes for isolate use.
  static Uint8List _hexToBytesStatic(String hex) {
    final result = Uint8List(hex.length ~/ 2);
    for (int i = 0; i < result.length; i++) {
      result[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return result;
  }

  // ════════════════════════════════════════════════════════════════════
  // Keccak-256 — via pointycastle (pre-NIST Keccak, matches sha3::Keccak256)
  // ════════════════════════════════════════════════════════════════════

  /// Keccak-256 using pointycastle's verified implementation.
  /// Works in isolates (pure Dart, no FFI).
  static String _keccak256Static(Uint8List input) {
    final digest = KeccakDigest(256);
    final output = digest.process(input);
    return output.map((b) => b.toRadixString(16).padLeft(2, '0')).join('');
  }
}
