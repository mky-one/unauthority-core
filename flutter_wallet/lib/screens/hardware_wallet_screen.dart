import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/hardware_wallet.dart';
import '../services/hardware_wallet_service.dart';

class HardwareWalletScreen extends StatefulWidget {
  const HardwareWalletScreen({super.key});

  @override
  State<HardwareWalletScreen> createState() => _HardwareWalletScreenState();
}

class _HardwareWalletScreenState extends State<HardwareWalletScreen> {
  final _hwService = HardwareWalletService();
  List<HardwareWallet> _detectedWallets = [];
  HardwareWallet? _connectedWallet;
  bool _isScanning = false;
  bool _isConnecting = false;

  @override
  void initState() {
    super.initState();
    _hwService.connectionStream.listen((wallet) {
      setState(() {
        _connectedWallet = wallet;
        _isConnecting = wallet?.status == HardwareWalletStatus.connecting;
      });
    });
    _scanForWallets();
  }

  @override
  void dispose() {
    _hwService.dispose();
    super.dispose();
  }

  Future<void> _scanForWallets() async {
    setState(() => _isScanning = true);
    try {
      final wallets = await _hwService.detectWallets();
      setState(() {
        _detectedWallets = wallets;
        _isScanning = false;
      });
    } catch (e) {
      setState(() => _isScanning = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error scanning: $e')),
        );
      }
    }
  }

  Future<void> _connectWallet(HardwareWallet wallet) async {
    setState(() => _isConnecting = true);
    try {
      await _hwService.connect(wallet);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Connected to ${wallet.typeName}'),
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
    } catch (e) {
      setState(() => _isConnecting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Connection failed: $e')),
        );
      }
    }
  }

  Future<void> _disconnectWallet() async {
    await _hwService.disconnect();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hardware wallet disconnected')),
      );
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied to clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hardware Wallet'),
        actions: [
          if (_connectedWallet != null)
            IconButton(
              icon: const Icon(Icons.power_settings_new),
              onPressed: _disconnectWallet,
              tooltip: 'Disconnect',
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isScanning ? null : _scanForWallets,
            tooltip: 'Scan for wallets',
          ),
        ],
      ),
      body: _connectedWallet?.isConnected ?? false
          ? _buildConnectedView()
          : _buildDetectionView(),
    );
  }

  Widget _buildDetectionView() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Header Card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Icon(
                  Icons.security,
                  size: 64,
                  color: Colors.blue.shade400,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Hardware Wallet Support',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Connect your Ledger or Trezor hardware wallet for maximum security',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Supported Devices
        const Text(
          'Supported Devices',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),

        if (_isScanning)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Scanning for hardware wallets...'),
                ],
              ),
            ),
          )
        else if (_detectedWallets.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  Icon(
                    Icons.usb_off,
                    size: 48,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No hardware wallets detected',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Please connect your device and click refresh',
                    style: TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          )
        else
          ..._detectedWallets.map(
            (wallet) => Card(
              child: ListTile(
                leading: Icon(
                  _getWalletIcon(wallet.type),
                  size: 40,
                  color: Colors.blue.shade400,
                ),
                title: Text(
                  wallet.typeName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text('ID: ${wallet.id}'),
                trailing: _isConnecting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : ElevatedButton.icon(
                        onPressed: () => _connectWallet(wallet),
                        icon: const Icon(Icons.link),
                        label: const Text('Connect'),
                      ),
              ),
            ),
          ),

        const SizedBox(height: 24),

        // Security Notice
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.blue.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                color: Colors.blue.shade400,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Hardware wallets provide the highest level of security by keeping your private keys offline.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildConnectedView() {
    final wallet = _connectedWallet!;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Status Card
        Card(
          color: Colors.green.shade900,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle,
                  size: 48,
                  color: Colors.green.shade400,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        wallet.typeName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Connected',
                        style: TextStyle(
                          color: Colors.green.shade400,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Address Card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.account_balance_wallet, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'UAT Address',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 18),
                      onPressed: () => _copyToClipboard(
                        wallet.address!,
                        'Address',
                      ),
                      tooltip: 'Copy address',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  wallet.address!,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Public Key Card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.key, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Public Key (Dilithium5)',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 18),
                      onPressed: () => _copyToClipboard(
                        wallet.publicKey!,
                        'Public key',
                      ),
                      tooltip: 'Copy public key',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${wallet.publicKey!.substring(0, 64)}...',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Actions
        const Text(
          'Available Actions',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),

        ElevatedButton.icon(
          onPressed: () {
            // Navigate to send screen with hardware wallet
            Navigator.pop(context, wallet);
          },
          icon: const Icon(Icons.send),
          label: const Text('Send with Hardware Wallet'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.all(16),
          ),
        ),

        const SizedBox(height: 12),

        OutlinedButton.icon(
          onPressed: _disconnectWallet,
          icon: const Icon(Icons.power_settings_new),
          label: const Text('Disconnect Wallet'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.all(16),
          ),
        ),

        const SizedBox(height: 24),

        // Security Info
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.green.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(
                    Icons.shield,
                    color: Colors.green.shade400,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Your private keys never leave the hardware device',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'All transactions are signed securely on your hardware wallet. Confirm each transaction on your device screen.',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ),
      ],
    );
  }

  IconData _getWalletIcon(HardwareWalletType type) {
    switch (type) {
      case HardwareWalletType.ledgerNanoS:
      case HardwareWalletType.ledgerNanoX:
        return Icons.usb; // Ledger icon
      case HardwareWalletType.trezorOne:
      case HardwareWalletType.trezorT:
        return Icons.security; // Trezor icon
    }
  }
}
