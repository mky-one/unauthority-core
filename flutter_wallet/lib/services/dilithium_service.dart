import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';

/// Dilithium5 Post-Quantum cryptography service via native Rust FFI.
///
/// Provides real CRYSTALS-Dilithium5 operations matching the uat-crypto backend:
/// - Keypair generation (NIST Level 5, 2592-byte PK, 4864-byte SK)
/// - Message signing (detached signatures)
/// - Signature verification
/// - UAT address derivation (Base58Check, identical to backend)
/// - Address validation
///
/// Falls back to a "not available" state if the native library isn't compiled.
/// Use [DilithiumService.isAvailable] to check before calling crypto functions.
class DilithiumService {
  static DilithiumService? _instance;
  static bool _initialized = false;
  static bool _available = false;
  static DynamicLibrary? _lib;

  // FFI function typedefs
  static late int Function() _uatPublicKeyBytes;
  static late int Function() _uatSecretKeyBytes;
  static late int Function() _uatSignatureBytes;
  static late int Function() _uatMaxAddressBytes;
  static late int Function(Pointer<Uint8>, int, Pointer<Uint8>, int)
      _uatGenerateKeypair;
  static late int Function(
          Pointer<Uint8>, int, Pointer<Uint8>, int, Pointer<Uint8>, int)
      _uatGenerateKeypairFromSeed;
  static late int Function(
      Pointer<Uint8>, int, Pointer<Uint8>, int, Pointer<Uint8>, int) _uatSign;
  static late int Function(
      Pointer<Uint8>, int, Pointer<Uint8>, int, Pointer<Uint8>, int) _uatVerify;
  static late int Function(Pointer<Uint8>, int, Pointer<Uint8>, int)
      _uatPublicKeyToAddress;
  static late int Function(Pointer<Uint8>, int) _uatValidateAddress;
  static late int Function(Pointer<Uint8>, int, Pointer<Uint8>, int)
      _uatBytesToHex;
  static late int Function(Pointer<Uint8>, int, Pointer<Uint8>, int)
      _uatHexToBytes;

  // Cached sizes
  static int _pkBytes = 0;
  static int _skBytes = 0;
  static int _sigBytes = 0;
  static int _maxAddrBytes = 0;

  DilithiumService._();

  static DilithiumService get instance {
    _instance ??= DilithiumService._();
    return _instance!;
  }

  /// Whether the native Dilithium5 library is loaded and available.
  static bool get isAvailable => _available;

  /// Public key size in bytes (2592 for Dilithium5)
  static int get publicKeyBytes => _pkBytes;

  /// Secret key size in bytes (4864 for Dilithium5)
  static int get secretKeyBytes => _skBytes;

  /// Signature size in bytes
  static int get signatureBytes => _sigBytes;

  /// Initialize the Dilithium5 native library.
  /// Call once at app startup. If the library is not found, [isAvailable] will be false.
  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      _lib = _loadNativeLibrary();
      if (_lib == null) {
        print(
            '⚠️  Dilithium5 native library not found — using SHA256 fallback');
        _available = false;
        return;
      }

      // Bind FFI functions
      _uatPublicKeyBytes = _lib!
          .lookupFunction<Int32 Function(), int Function()>(
              'uat_public_key_bytes');
      _uatSecretKeyBytes = _lib!
          .lookupFunction<Int32 Function(), int Function()>(
              'uat_secret_key_bytes');
      _uatSignatureBytes = _lib!
          .lookupFunction<Int32 Function(), int Function()>(
              'uat_signature_bytes');
      _uatMaxAddressBytes = _lib!
          .lookupFunction<Int32 Function(), int Function()>(
              'uat_max_address_bytes');

      _uatGenerateKeypair = _lib!.lookupFunction<
          Int32 Function(Pointer<Uint8>, Int32, Pointer<Uint8>, Int32),
          int Function(Pointer<Uint8>, int, Pointer<Uint8>,
              int)>('uat_generate_keypair');

      _uatGenerateKeypairFromSeed = _lib!.lookupFunction<
          Int32 Function(Pointer<Uint8>, Int32, Pointer<Uint8>, Int32,
              Pointer<Uint8>, Int32),
          int Function(Pointer<Uint8>, int, Pointer<Uint8>, int, Pointer<Uint8>,
              int)>('uat_generate_keypair_from_seed');

      _uatSign = _lib!.lookupFunction<
          Int32 Function(Pointer<Uint8>, Int32, Pointer<Uint8>, Int32,
              Pointer<Uint8>, Int32),
          int Function(Pointer<Uint8>, int, Pointer<Uint8>, int, Pointer<Uint8>,
              int)>('uat_sign');

      _uatVerify = _lib!.lookupFunction<
          Int32 Function(Pointer<Uint8>, Int32, Pointer<Uint8>, Int32,
              Pointer<Uint8>, Int32),
          int Function(Pointer<Uint8>, int, Pointer<Uint8>, int, Pointer<Uint8>,
              int)>('uat_verify');

      _uatPublicKeyToAddress = _lib!.lookupFunction<
          Int32 Function(Pointer<Uint8>, Int32, Pointer<Uint8>, Int32),
          int Function(Pointer<Uint8>, int, Pointer<Uint8>,
              int)>('uat_public_key_to_address');

      _uatValidateAddress = _lib!.lookupFunction<
          Int32 Function(Pointer<Uint8>, Int32),
          int Function(Pointer<Uint8>, int)>('uat_validate_address');

      _uatBytesToHex = _lib!.lookupFunction<
          Int32 Function(Pointer<Uint8>, Int32, Pointer<Uint8>, Int32),
          int Function(
              Pointer<Uint8>, int, Pointer<Uint8>, int)>('uat_bytes_to_hex');

      _uatHexToBytes = _lib!.lookupFunction<
          Int32 Function(Pointer<Uint8>, Int32, Pointer<Uint8>, Int32),
          int Function(
              Pointer<Uint8>, int, Pointer<Uint8>, int)>('uat_hex_to_bytes');

      // Query sizes
      _pkBytes = _uatPublicKeyBytes();
      _skBytes = _uatSecretKeyBytes();
      _sigBytes = _uatSignatureBytes();
      _maxAddrBytes = _uatMaxAddressBytes();

      _available = true;
      print('✅ Dilithium5 native library loaded');
      print(
          '   PK: $_pkBytes bytes, SK: $_skBytes bytes, Sig: $_sigBytes bytes');
    } catch (e) {
      print('⚠️  Failed to load Dilithium5 native library: $e');
      _available = false;
    }
  }

  /// Load the native library from platform-specific locations.
  static DynamicLibrary? _loadNativeLibrary() {
    final String libName;
    if (Platform.isMacOS) {
      libName = 'libuat_crypto_ffi.dylib';
    } else if (Platform.isLinux) {
      libName = 'libuat_crypto_ffi.so';
    } else if (Platform.isWindows) {
      libName = 'uat_crypto_ffi.dll';
    } else {
      return null;
    }

    // Try multiple locations in order of priority
    final sep = Platform.pathSeparator;
    final execDir =
        Platform.resolvedExecutable.replaceAll(RegExp(r'[/\\][^/\\]+$'), '');
    final searchPaths = <String>[
      // 1. macOS app bundle (release): .app/Contents/Frameworks/
      '$execDir$sep..${sep}Frameworks$sep$libName',
      // 2. Linux bundle: bundle/lib/
      '$execDir${sep}lib$sep$libName',
      // 3. Windows/Linux: next to executable
      '$execDir$sep$libName',
      // 4. Development: relative to flutter_wallet/
      'native${sep}uat_crypto_ffi${sep}target${sep}release$sep$libName',
      // 5. Development: from workspace root
      '${Directory.current.path}${sep}native${sep}uat_crypto_ffi${sep}target${sep}release$sep$libName',
      // 6. macOS Runner copy
      '${Directory.current.path}${sep}macos${sep}Runner$sep$libName',
      // 7. System library path (fallback)
      libName,
    ];

    for (final path in searchPaths) {
      try {
        final lib = DynamicLibrary.open(path);
        print('✅ Loaded native library from: $path');
        return lib;
      } catch (_) {
        // Try next path
      }
    }
    return null;
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // PUBLIC API — Dart-friendly wrappers around FFI calls
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  /// Generate a new Dilithium5 keypair.
  /// Returns {publicKey: Uint8List, secretKey: Uint8List}
  static DilithiumKeypair generateKeypair() {
    if (!_available) {
      throw StateError('Dilithium5 native library not available');
    }

    final pkPtr = calloc<Uint8>(_pkBytes);
    final skPtr = calloc<Uint8>(_skBytes);

    try {
      final result = _uatGenerateKeypair(pkPtr, _pkBytes, skPtr, _skBytes);
      if (result != 0) {
        throw StateError('Keypair generation failed: error $result');
      }

      return DilithiumKeypair(
        publicKey: Uint8List.fromList(pkPtr.asTypedList(_pkBytes)),
        secretKey: Uint8List.fromList(skPtr.asTypedList(_skBytes)),
      );
    } finally {
      // FIX C12-06: Zero secret key memory before freeing
      skPtr.asTypedList(_skBytes).fillRange(0, _skBytes, 0);
      calloc.free(pkPtr);
      calloc.free(skPtr);
    }
  }

  /// Generate a deterministic Dilithium5 keypair from BIP39 seed.
  ///
  /// Same seed always produces the same keypair, enabling wallet recovery
  /// from mnemonic alone. Uses domain-separated SHA-256 → ChaCha20 DRBG.
  static DilithiumKeypair generateKeypairFromSeed(List<int> seed) {
    if (!_available) {
      throw StateError('Dilithium5 native library not available');
    }
    if (seed.length < 32) {
      throw ArgumentError('Seed must be at least 32 bytes');
    }

    final seedPtr = calloc<Uint8>(seed.length);
    final pkPtr = calloc<Uint8>(_pkBytes);
    final skPtr = calloc<Uint8>(_skBytes);

    try {
      seedPtr.asTypedList(seed.length).setAll(0, seed);

      final result = _uatGenerateKeypairFromSeed(
        seedPtr,
        seed.length,
        pkPtr,
        _pkBytes,
        skPtr,
        _skBytes,
      );
      if (result != 0) {
        throw StateError('Seeded keypair generation failed: error $result');
      }

      return DilithiumKeypair(
        publicKey: Uint8List.fromList(pkPtr.asTypedList(_pkBytes)),
        secretKey: Uint8List.fromList(skPtr.asTypedList(_skBytes)),
      );
    } finally {
      // Zero the seed memory before freeing
      seedPtr.asTypedList(seed.length).fillRange(0, seed.length, 0);
      // FIX C12-06: Zero secret key memory before freeing
      skPtr.asTypedList(_skBytes).fillRange(0, _skBytes, 0);
      calloc.free(seedPtr);
      calloc.free(pkPtr);
      calloc.free(skPtr);
    }
  }

  /// Sign a message with a Dilithium5 secret key.
  /// Returns the signature as Uint8List.
  static Uint8List sign(Uint8List message, Uint8List secretKey) {
    if (!_available) {
      throw StateError('Dilithium5 native library not available');
    }

    final msgPtr = calloc<Uint8>(message.length);
    final skPtr = calloc<Uint8>(secretKey.length);
    final sigPtr = calloc<Uint8>(_sigBytes);

    try {
      msgPtr.asTypedList(message.length).setAll(0, message);
      skPtr.asTypedList(secretKey.length).setAll(0, secretKey);

      final sigLen = _uatSign(
        msgPtr,
        message.length,
        skPtr,
        secretKey.length,
        sigPtr,
        _sigBytes,
      );
      if (sigLen < 0) {
        throw StateError('Signing failed: error $sigLen');
      }

      return Uint8List.fromList(sigPtr.asTypedList(sigLen));
    } finally {
      // SECURITY FIX S3: Zero secret key memory before freeing to prevent leak
      skPtr.asTypedList(secretKey.length).fillRange(0, secretKey.length, 0);
      calloc.free(msgPtr);
      calloc.free(skPtr);
      calloc.free(sigPtr);
    }
  }

  /// Verify a Dilithium5 signature.
  static bool verify(
      Uint8List message, Uint8List signature, Uint8List publicKey) {
    if (!_available) return false;

    final msgPtr = calloc<Uint8>(message.length);
    final sigPtr = calloc<Uint8>(signature.length);
    final pkPtr = calloc<Uint8>(publicKey.length);

    try {
      msgPtr.asTypedList(message.length).setAll(0, message);
      sigPtr.asTypedList(signature.length).setAll(0, signature);
      pkPtr.asTypedList(publicKey.length).setAll(0, publicKey);

      final result = _uatVerify(
        msgPtr,
        message.length,
        sigPtr,
        signature.length,
        pkPtr,
        publicKey.length,
      );
      return result == 1;
    } finally {
      calloc.free(msgPtr);
      calloc.free(sigPtr);
      calloc.free(pkPtr);
    }
  }

  /// Derive UAT address from Dilithium5 public key.
  /// Returns a string like "UATHjvLcaLZp..." (Base58Check format).
  static String publicKeyToAddress(Uint8List publicKey) {
    if (!_available) {
      throw StateError('Dilithium5 native library not available');
    }

    final pkPtr = calloc<Uint8>(publicKey.length);
    final addrPtr = calloc<Uint8>(_maxAddrBytes);

    try {
      pkPtr.asTypedList(publicKey.length).setAll(0, publicKey);

      final addrLen = _uatPublicKeyToAddress(
        pkPtr,
        publicKey.length,
        addrPtr,
        _maxAddrBytes,
      );
      if (addrLen < 0) {
        throw StateError('Address derivation failed: error $addrLen');
      }

      final bytes = addrPtr.asTypedList(addrLen);
      return String.fromCharCodes(bytes);
    } finally {
      calloc.free(pkPtr);
      calloc.free(addrPtr);
    }
  }

  /// Validate a UAT address (checksum + format).
  static bool validateAddress(String address) {
    if (!_available) return false;

    final addrBytes = address.codeUnits;
    final addrPtr = calloc<Uint8>(addrBytes.length);

    try {
      addrPtr.asTypedList(addrBytes.length).setAll(0, addrBytes);
      return _uatValidateAddress(addrPtr, addrBytes.length) == 1;
    } finally {
      calloc.free(addrPtr);
    }
  }

  /// Convert raw bytes to hex string (via native lib).
  static String bytesToHex(Uint8List bytes) {
    if (!_available) {
      return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join('');
    }

    final inPtr = calloc<Uint8>(bytes.length);
    final outPtr = calloc<Uint8>(bytes.length * 2 + 1);

    try {
      inPtr.asTypedList(bytes.length).setAll(0, bytes);
      final hexLen =
          _uatBytesToHex(inPtr, bytes.length, outPtr, bytes.length * 2 + 1);
      if (hexLen < 0) {
        return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join('');
      }
      return String.fromCharCodes(outPtr.asTypedList(hexLen));
    } finally {
      calloc.free(inPtr);
      calloc.free(outPtr);
    }
  }

  /// Decode hex string to raw bytes.
  static Uint8List hexToBytes(String hex) {
    if (!_available) {
      final result = Uint8List(hex.length ~/ 2);
      for (var i = 0; i < hex.length; i += 2) {
        result[i ~/ 2] = int.parse(hex.substring(i, i + 2), radix: 16);
      }
      return result;
    }

    final hexBytes = hex.codeUnits;
    final inPtr = calloc<Uint8>(hexBytes.length);
    final outPtr = calloc<Uint8>(hexBytes.length); // hex/2, but over-allocate

    try {
      inPtr.asTypedList(hexBytes.length).setAll(0, hexBytes);
      final bytesLen =
          _uatHexToBytes(inPtr, hexBytes.length, outPtr, hexBytes.length);
      if (bytesLen < 0) {
        throw StateError('Hex decode failed: $bytesLen');
      }
      return Uint8List.fromList(outPtr.asTypedList(bytesLen));
    } finally {
      calloc.free(inPtr);
      calloc.free(outPtr);
    }
  }
}

/// Dilithium5 keypair container
class DilithiumKeypair {
  final Uint8List publicKey;
  final Uint8List secretKey;

  const DilithiumKeypair({required this.publicKey, required this.secretKey});

  /// Public key as hex string
  String get publicKeyHex => DilithiumService.bytesToHex(publicKey);

  /// Secret key as hex string
  String get secretKeyHex => DilithiumService.bytesToHex(secretKey);
}
