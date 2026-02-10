import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/wallet_service.dart';
import '../services/api_service.dart';
import '../services/block_construction_service.dart';
import '../constants/blockchain.dart';
import '../utils/address_validator.dart';

class SendScreen extends StatefulWidget {
  const SendScreen({super.key});

  @override
  State<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends State<SendScreen> {
  final _formKey = GlobalKey<FormState>();
  final _toController = TextEditingController();
  final _amountController = TextEditingController();
  bool _isLoading = false;

  Future<void> _sendTransaction() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    debugPrint('💸 [Send] Starting send transaction...');

    try {
      final walletService = context.read<WalletService>();
      final apiService = context.read<ApiService>();
      final wallet = await walletService.getCurrentWallet();

      if (wallet == null) throw Exception('No wallet found');
      debugPrint('💸 [Send] From: ${wallet['address']}');

      // FIX C11-01: Backend expects UAT in `amount` field.
      // Support decimal amounts (e.g., 0.5 UAT) — BlockConstructionService
      // converts to VOID with full 10^11 precision.
      final amountUatDouble = double.tryParse(_amountController.text.trim());
      if (amountUatDouble == null || amountUatDouble <= 0) {
        throw Exception('Please enter a valid amount greater than 0');
      }
      if (amountUatDouble < 0.00000000001) {
        throw Exception('Minimum send amount is 0.00000000001 UAT (1 VOID)');
      }

      // FIX H-06: Prevent sending to own address
      final toAddress = _toController.text.trim();
      debugPrint('💸 [Send] To: $toAddress, Amount: $amountUatDouble UAT');
      if (toAddress == wallet['address']) {
        throw Exception('Cannot send to your own address');
      }

      // Balance validation: prevent sending more than available
      // Compare in UAT to avoid unit mismatch
      try {
        final account = await apiService.getBalance(wallet['address']!);
        if (amountUatDouble > account.balanceUAT) {
          throw Exception(
              'Insufficient balance: have ${BlockchainConstants.formatUat(account.balanceUAT)} UAT');
        }
      } catch (e) {
        if (e.toString().contains('Insufficient balance')) rethrow;
        // If balance check fails (network), let the backend reject
      }

      // Use BlockConstructionService for full client-side block construction
      // (PoW + Dilithium5 signing) — required for external addresses on L2+
      final blockService = BlockConstructionService(
        api: apiService,
        wallet: walletService,
      );

      // Check if wallet has signing keys (Dilithium5 keypair)
      final hasKeys = wallet['public_key'] != null;

      Map<String, dynamic> result;
      if (hasKeys) {
        // Full client-side signing via BlockConstructionService
        debugPrint('💸 [Send] Client-side signing with Dilithium5...');
        result = await blockService.sendTransaction(
          to: toAddress,
          amountUatDouble: amountUatDouble,
        );
      } else {
        // Address-only import — no keys, let node sign (functional testnet only)
        debugPrint(
            '💸 [Send] No signing keys — node-signed (functional testnet)...');
        result = await apiService.sendTransaction(
          from: wallet['address']!,
          to: toAddress,
          amount: amountUatDouble.floor(),
        );
      }

      if (!mounted) return;
      debugPrint(
          '💸 [Send] SUCCESS: ${result['tx_hash'] ?? result['txid'] ?? 'N/A'}');

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Transaction sent! TXID: ${result['tx_hash'] ?? result['txid'] ?? 'N/A'}'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      debugPrint('💸 [Send] ERROR: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Send UAT'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.send, size: 80, color: Colors.blue),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _toController,
                  decoration: const InputDecoration(
                    labelText: 'To Address',
                    hintText: 'UAT...',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter recipient address';
                    }
                    // FIX C11-09: Use AddressValidator for consistent
                    // hex/Base58 character validation across all screens
                    return AddressValidator.getValidationError(value.trim());
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _amountController,
                  decoration: const InputDecoration(
                    labelText: 'Amount (UAT)',
                    hintText: '0.5',
                    helperText: 'Supports decimals (e.g., 0.5 UAT)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.attach_money),
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter amount';
                    }
                    final amount = double.tryParse(value.trim());
                    if (amount == null || amount <= 0) {
                      return 'Please enter a number greater than 0';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _isLoading ? null : _sendTransaction,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : const Text('SEND TRANSACTION',
                          style: TextStyle(fontSize: 16)),
                ),
                const SizedBox(height: 16),
                const Text(
                  '⚠️ Make sure the address is correct. Transactions cannot be reversed!',
                  style: TextStyle(fontSize: 12, color: Colors.orange),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _toController.dispose();
    _amountController.dispose();
    super.dispose();
  }
}
