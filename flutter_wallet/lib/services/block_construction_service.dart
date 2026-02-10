import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';
import 'api_service.dart';
import 'wallet_service.dart';

/// Client-side block-lattice block construction for UAT.
///
/// Matches the backend's Block struct and signing_hash() exactly:
/// - Keccak-256 with CHAIN_ID domain separation
/// - PoW anti-spam: 16 leading zero bits
/// - Dilithium5 signature over signing_hash
///
/// This enables fully sovereign transactions — the node only verifies,
/// it never touches the user's secret key.
///
/// ⚠️  KNOWN PROTOCOL ISSUE (C11-07):
/// The backend's POST /send handler overwrites two signing_hash fields
/// after block construction:
///   1. `fee` — set by anti-whale engine (client signs with fee=0)
///   2. `timestamp` — always uses server's SystemTime::now()
/// As a result, the client's signing_hash will never match the backend's
/// until the backend's SendRequest accepts `timestamp` and either a
/// `fee` field or a fee-estimation endpoint is available.
/// Client-signed blocks currently fail verification on the backend.
/// Use L1 testnet mode (node signs) until this protocol gap is resolved.
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
    required int amountUat,
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

    // 3. Convert amount to VOID
    final amountVoid = BigInt.from(amountUat) * BigInt.from(voidPerUat);

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
  // Keccak-256 — Pure Dart implementation (pre-NIST, matches sha3::Keccak256)
  // ════════════════════════════════════════════════════════════════════
  //
  // Keccak-256 uses the Keccak sponge with:
  //   - Rate = 1088 bits (136 bytes)
  //   - Capacity = 512 bits
  //   - Padding = 0x01 (Keccak), NOT 0x06 (SHA-3)
  //   - Output = 256 bits (32 bytes)

  static const int _keccakRate = 136; // bytes
  static const int _keccakRounds = 24;

  /// Static Keccak-256 for isolate use (same algorithm as instance method).
  static String _keccak256Static(Uint8List input) {
    final padLen = _keccakRate - (input.length % _keccakRate);
    final padded = Uint8List(input.length + padLen);
    padded.setAll(0, input);
    if (padLen == 1) {
      padded[input.length] = 0x81;
    } else {
      padded[input.length] = 0x01;
      padded[padded.length - 1] |= 0x80;
    }
    final state = List<int>.filled(25, 0);
    for (int offset = 0; offset < padded.length; offset += _keccakRate) {
      for (int i = 0; i < _keccakRate ~/ 8; i++) {
        final idx = offset + i * 8;
        int word = 0;
        for (int b = 0; b < 8; b++) {
          word |= padded[idx + b] << (b * 8);
        }
        state[i] ^= word;
      }
      _keccakF1600Static(state);
    }
    final output = Uint8List(32);
    for (int i = 0; i < 4; i++) {
      final word = state[i];
      for (int b = 0; b < 8; b++) {
        output[i * 8 + b] = (word >> (b * 8)) & 0xFF;
      }
    }
    return output.map((b) => b.toRadixString(16).padLeft(2, '0')).join('');
  }

  /// Keccak-f[1600] permutation — 24 rounds (static for isolate use)
  static void _keccakF1600Static(List<int> state) {
    _keccakF1600Impl(state);
  }

  /// Shared implementation for static and instance methods
  static void _keccakF1600Impl(List<int> state) {
    // Round constants
    const rc = [
      0x0000000000000001,
      0x0000000000008082,
      0x800000000000808A,
      0x8000000080008000,
      0x000000000000808B,
      0x0000000080000001,
      0x8000000080008081,
      0x8000000000008009,
      0x000000000000008A,
      0x0000000000000088,
      0x0000000080008009,
      0x000000008000000A,
      0x000000008000808B,
      0x800000000000008B,
      0x8000000000008089,
      0x8000000000008003,
      0x8000000000008002,
      0x8000000000000080,
      0x000000000000800A,
      0x800000008000000A,
      0x8000000080008081,
      0x8000000000008080,
      0x0000000080000001,
      0x8000000080008008,
    ];

    // Rotation offsets
    const rotations = [
      0,
      1,
      62,
      28,
      27,
      36,
      44,
      6,
      55,
      20,
      3,
      10,
      43,
      25,
      39,
      41,
      45,
      15,
      21,
      8,
      18,
      2,
      61,
      56,
      14,
    ];

    // Pi permutation indices
    const piIndices = [
      0,
      10,
      7,
      11,
      17,
      18,
      3,
      5,
      16,
      8,
      21,
      24,
      4,
      15,
      23,
      9,
      13,
      2,
      12,
      20,
      14,
      22,
      1,
      6,
      19,
    ];

    for (int round = 0; round < _keccakRounds; round++) {
      // θ (theta) step
      final c = List<int>.filled(5, 0);
      for (int x = 0; x < 5; x++) {
        c[x] = state[x] ^
            state[x + 5] ^
            state[x + 10] ^
            state[x + 15] ^
            state[x + 20];
      }
      final d = List<int>.filled(5, 0);
      for (int x = 0; x < 5; x++) {
        d[x] = c[(x + 4) % 5] ^ _rotl64(c[(x + 1) % 5], 1);
      }
      for (int i = 0; i < 25; i++) {
        state[i] ^= d[i % 5];
      }

      // ρ (rho) and π (pi) steps — combined
      final temp = List<int>.filled(25, 0);
      for (int i = 0; i < 25; i++) {
        temp[piIndices[i]] = _rotl64(state[i], rotations[i]);
      }

      // χ (chi) step
      for (int y = 0; y < 25; y += 5) {
        for (int x = 0; x < 5; x++) {
          state[y + x] =
              temp[y + x] ^ (~temp[y + (x + 1) % 5] & temp[y + (x + 2) % 5]);
        }
      }

      // ι (iota) step
      state[0] ^= rc[round];
    }
  }

  /// 64-bit left rotation
  static int _rotl64(int value, int shift) {
    if (shift == 0) return value;
    return ((value << shift) | (value >>> (64 - shift)));
  }
}
