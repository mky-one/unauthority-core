import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/wallet_service.dart';
import '../services/api_service.dart';
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

    try {
      final walletService = context.read<WalletService>();
      final wallet = await walletService.getCurrentWallet();

      if (wallet == null) throw Exception('No wallet found');

      final apiService = context.read<ApiService>();

      // FIX C11-01: Backend expects UAT integer in `amount` field and does
      // × VOID_PER_UAT server-side. Sending VOID here would cause 10^11×
      // inflation. Parse user input as UAT double, round to integer UAT.
      final amountDouble = double.parse(_amountController.text.trim());
      final amountUat = amountDouble.round();
      if (amountUat <= 0) {
        throw Exception('Minimum send amount is 1 UAT');
      }

      // Balance validation: prevent sending more than available
      // Compare in UAT to avoid unit mismatch
      try {
        final account = await apiService.getBalance(wallet['address']!);
        if (amountDouble > account.balanceUAT) {
          throw Exception(
              'Insufficient balance: have ${BlockchainConstants.formatUat(account.balanceUAT)} UAT');
        }
      } catch (e) {
        if (e.toString().contains('Insufficient balance')) rethrow;
        // If balance check fails (network), let the backend reject
      }

      // FIX C11-02/C11-03: For L1 testnet, let the node sign the block.
      // Client-side signing (via BlockConstructionService) requires fee
      // negotiation protocol not yet available — sending a mismatched
      // signature causes guaranteed rejection. Omit signature so the
      // backend signs for node-owned addresses.
      // TODO: Route through BlockConstructionService once backend supports
      //       client timestamp/fee in SendRequest for L2+ signing.
      String? signature;
      String? publicKey;

      final result = await apiService.sendTransaction(
        from: wallet['address']!,
        to: _toController.text.trim(),
        amount: amountUat,
        signature: signature,
        publicKey: publicKey,
      );

      if (!mounted) return;

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Transaction sent! TXID: ${result['txid'] ?? 'N/A'}'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      if (!mounted) return;
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
                    hintText: '0.000000',
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
                      return 'Please enter valid amount';
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
