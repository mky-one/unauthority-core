import 'dart:async';
import 'dart:math';
import '../models/hardware_wallet.dart';

/// Mock Hardware Wallet Service
/// Production version would use platform channels to communicate with actual hardware wallets
class HardwareWalletService {
  HardwareWallet? _connectedWallet;
  final _connectionController = StreamController<HardwareWallet?>.broadcast();

  Stream<HardwareWallet?> get connectionStream => _connectionController.stream;
  HardwareWallet? get connectedWallet => _connectedWallet;
  bool get isConnected => _connectedWallet?.isConnected ?? false;

  /// Mock: Detect connected hardware wallets
  /// Production: Use HID/USB libraries to detect actual devices
  Future<List<HardwareWallet>> detectWallets() async {
    // Simulate device detection delay
    await Future.delayed(const Duration(milliseconds: 800));

    // Mock: Return sample wallets for testing
    return [
      HardwareWallet(
        id: 'ledger-nano-x-001',
        type: HardwareWalletType.ledgerNanoX,
        status: HardwareWalletStatus.disconnected,
      ),
      HardwareWallet(
        id: 'trezor-t-002',
        type: HardwareWalletType.trezorT,
        status: HardwareWalletStatus.disconnected,
      ),
    ];
  }

  /// Mock: Connect to hardware wallet
  /// Production: Establish USB/Bluetooth connection and verify device
  Future<HardwareWallet> connect(HardwareWallet wallet) async {
    // Update status to connecting
    final connectingWallet = wallet.copyWith(
      status: HardwareWalletStatus.connecting,
    );
    _connectionController.add(connectingWallet);

    // Simulate connection delay and device verification
    await Future.delayed(const Duration(seconds: 2));

    // Mock: Generate sample address and public key
    // Production: Get actual address from hardware wallet
    final mockAddress = _generateMockUATAddress();
    final mockPublicKey = _generateMockPublicKey();

    final connectedWallet = wallet.copyWith(
      status: HardwareWalletStatus.connected,
      address: mockAddress,
      publicKey: mockPublicKey,
      connectedAt: DateTime.now(),
    );

    _connectedWallet = connectedWallet;
    _connectionController.add(connectedWallet);

    return connectedWallet;
  }

  /// Mock: Disconnect hardware wallet
  Future<void> disconnect() async {
    if (_connectedWallet != null) {
      final disconnectedWallet = _connectedWallet!.copyWith(
        status: HardwareWalletStatus.disconnected,
        address: null,
        publicKey: null,
        connectedAt: null,
      );

      _connectedWallet = null;
      _connectionController.add(null);

      await Future.delayed(const Duration(milliseconds: 500));
    }
  }

  /// Mock: Sign transaction with hardware wallet
  /// Production: Send transaction to device for user confirmation and signing
  Future<HardwareWalletSignature> signTransaction({
    required String from,
    required String to,
    required int amount,
  }) async {
    if (_connectedWallet == null || !_connectedWallet!.isConnected) {
      throw Exception('Hardware wallet not connected');
    }

    // Simulate user confirmation delay on device
    await Future.delayed(const Duration(seconds: 3));

    // Mock: Generate signature
    // Production: Get actual Dilithium5 signature from hardware wallet
    final mockSignature = _generateMockSignature();

    return HardwareWalletSignature(
      signature: mockSignature,
      publicKey: _connectedWallet!.publicKey!,
      signedAt: DateTime.now(),
    );
  }

  /// Mock: Verify hardware wallet firmware
  /// Production: Check device firmware version and security
  Future<bool> verifyFirmware(HardwareWallet wallet) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return true; // Mock: Always valid
  }

  /// Mock: Get balance from hardware wallet address
  /// This would query the blockchain with the wallet's address
  Future<int> getBalance() async {
    if (_connectedWallet?.address == null) {
      throw Exception('Hardware wallet not connected');
    }
    // In production, query actual balance from backend
    return 50000000; // Mock: 50 UAT
  }

  // ========== Mock Data Generators ==========

  String _generateMockUATAddress() {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random();
    final address = List.generate(
      40,
      (index) => chars[random.nextInt(chars.length)],
    ).join();
    return 'UAT$address';
  }

  String _generateMockPublicKey() {
    const chars = '0123456789abcdef';
    final random = Random();
    return List.generate(
      128,
      (index) => chars[random.nextInt(chars.length)],
    ).join();
  }

  String _generateMockSignature() {
    const chars = '0123456789abcdef';
    final random = Random();
    return List.generate(
      256,
      (index) => chars[random.nextInt(chars.length)],
    ).join();
  }

  void dispose() {
    _connectionController.close();
  }
}
