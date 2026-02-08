import 'dart:convert';
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
class BlockConstructionService {
  final ApiService _api;
  final WalletService _wallet;

  /// Testnet CHAIN_ID = 2. Mainnet = 1.
  /// Must match uat_core::CHAIN_ID in the backend.
  static const int chainIdTestnet = 2;
  static const int chainIdMainnet = 1;

  /// Current chain ID (compile-time constant equivalent)
  /// TODO: Make configurable via environment/settings
  int chainId;

  /// PoW difficulty: 16 leading zero bits (matches backend MIN_POW_DIFFICULTY_BITS)
  static const int powDifficultyBits = 16;

  /// Maximum PoW iterations before giving up
  static const int maxPowIterations = 50000000;

  /// Block type byte encoding (matches backend BlockType)
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

    // 5. Construct the signing data and mine PoW
    // We need to find a nonce where signing_hash has >= 16 leading zero bits.
    // The signing_hash includes the nonce (work), so we iterate.
    int work = 0;
    String signingHash = '';
    bool found = false;

    for (int nonce = 0; nonce < maxPowIterations; nonce++) {
      final hash = _computeSigningHash(
        chainId: chainId,
        account: address,
        previous: previous,
        blockType: blockTypeSend,
        amount: amountVoid,
        link: to,
        publicKey: publicKeyHex,
        work: nonce,
        timestamp: timestamp,
        fee: 0, // Fee is set by the node's anti-whale engine
      );

      if (_hasLeadingZeroBits(hash, powDifficultyBits)) {
        work = nonce;
        signingHash = hash;
        found = true;
        break;
      }
    }

    if (!found) {
      throw Exception(
          'PoW failed after $maxPowIterations iterations. Try again.');
    }

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
    );
  }

  /// Compute the signing_hash — MUST match uat_core::Block::signing_hash() exactly.
  ///
  /// Keccak-256 of:
  ///   chain_id (u64 LE) || account || previous || block_type (1 byte) ||
  ///   amount (u128 LE) || link || public_key || work (u64 LE) ||
  ///   timestamp (u64 LE) || fee (u128 LE)
  String _computeSigningHash({
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
    // Build the pre-image exactly matching the Rust backend
    final buffer = BytesBuilder();

    // chain_id: u64 little-endian (8 bytes)
    buffer.add(_u64ToLeBytes(chainId));

    // account: raw bytes of the string
    buffer.add(utf8.encode(account));

    // previous: raw bytes of the string
    buffer.add(utf8.encode(previous));

    // block_type: single byte
    buffer.addByte(blockType);

    // amount: u128 little-endian (16 bytes)
    buffer.add(_u128ToLeBytes(amount));

    // link: raw bytes of the string
    buffer.add(utf8.encode(link));

    // public_key: raw bytes of the hex string (NOT decoded bytes!)
    // The backend does: hasher.update(self.public_key.as_bytes())
    // which hashes the HEX STRING, not the raw key bytes
    buffer.add(utf8.encode(publicKey));

    // work: u64 little-endian (8 bytes)
    buffer.add(_u64ToLeBytes(work));

    // timestamp: u64 little-endian (8 bytes)
    buffer.add(_u64ToLeBytes(timestamp));

    // fee: u128 little-endian (16 bytes)
    buffer.add(_u128ToLeBytes(BigInt.from(fee)));

    // Keccak-256 hash
    return _keccak256Hex(buffer.toBytes());
  }

  /// Keccak-256 hash → hex string
  /// Uses SHA3-256 (Keccak) matching sha3::Keccak256 in Rust
  String _keccak256Hex(List<int> data) {
    // The Rust backend uses sha3::Keccak256 (the original Keccak, NOT NIST SHA-3)
    // Dart's crypto package doesn't have Keccak-256 natively.
    // We implement it using the pointycastle package or a pure Dart implementation.
    //
    // For now, use the Dart `crypto` package's SHA-256 as a temporary bridge.
    // TODO: Replace with actual Keccak-256 implementation.
    //
    // IMPORTANT: This MUST use Keccak-256 (pre-NIST) to match the Rust backend.
    // Using SHA-256 here would produce wrong hashes and fail signature verification.
    return _keccak256(Uint8List.fromList(data));
  }

  /// Check if a hex hash string has >= n leading zero bits
  bool _hasLeadingZeroBits(String hexHash, int requiredBits) {
    final bytes = _hexToBytes(hexHash);
    int zeroBits = 0;
    for (final byte in bytes) {
      if (byte == 0) {
        zeroBits += 8;
      } else {
        // Count leading zeros in this byte
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

  /// u64 → 8 bytes little-endian
  Uint8List _u64ToLeBytes(int value) {
    final data = ByteData(8);
    data.setUint64(0, value, Endian.little);
    return data.buffer.asUint8List();
  }

  /// BigInt (u128) → 16 bytes little-endian
  Uint8List _u128ToLeBytes(BigInt value) {
    final bytes = Uint8List(16);
    var v = value;
    for (int i = 0; i < 16; i++) {
      bytes[i] = (v & BigInt.from(0xFF)).toInt();
      v >>= 8;
    }
    return bytes;
  }

  /// Hex string → bytes
  Uint8List _hexToBytes(String hex) {
    final result = Uint8List(hex.length ~/ 2);
    for (int i = 0; i < hex.length; i += 2) {
      result[i ~/ 2] = int.parse(hex.substring(i, i + 2), radix: 16);
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

  String _keccak256(Uint8List input) {
    // Pad the input (Keccak padding: append 0x01, then zeros, then 0x80)
    final padLen = _keccakRate - (input.length % _keccakRate);
    final padded = Uint8List(input.length + padLen);
    padded.setAll(0, input);

    if (padLen == 1) {
      padded[input.length] = 0x81; // Combined first and last padding byte
    } else {
      padded[input.length] =
          0x01; // First padding byte (Keccak, not SHA-3's 0x06)
      padded[padded.length - 1] |= 0x80; // Last padding byte
    }

    // State: 5x5 matrix of 64-bit words = 25 words = 200 bytes
    final state = List<int>.filled(25, 0);

    // Absorb phase
    for (int offset = 0; offset < padded.length; offset += _keccakRate) {
      // XOR block into state
      for (int i = 0; i < _keccakRate ~/ 8; i++) {
        final idx = offset + i * 8;
        int word = 0;
        for (int b = 0; b < 8; b++) {
          word |= padded[idx + b] << (b * 8);
        }
        state[i] ^= word;
      }
      _keccakF1600(state);
    }

    // Squeeze phase (only need 32 bytes = 4 words for Keccak-256)
    final output = Uint8List(32);
    for (int i = 0; i < 4; i++) {
      final word = state[i];
      for (int b = 0; b < 8; b++) {
        output[i * 8 + b] = (word >> (b * 8)) & 0xFF;
      }
    }

    return output.map((b) => b.toRadixString(16).padLeft(2, '0')).join('');
  }

  /// Keccak-f[1600] permutation — 24 rounds
  void _keccakF1600(List<int> state) {
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
  int _rotl64(int value, int shift) {
    if (shift == 0) return value;
    return ((value << shift) | (value >>> (64 - shift)));
  }
}
