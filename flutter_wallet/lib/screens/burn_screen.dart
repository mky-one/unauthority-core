import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/wallet_service.dart';
import '../services/api_service.dart';

class BurnScreen extends StatefulWidget {
  const BurnScreen({super.key});

  @override
  State<BurnScreen> createState() => _BurnScreenState();
}

class _BurnScreenState extends State<BurnScreen> {
  final _formKey = GlobalKey<FormState>();
  final _btcTxidController = TextEditingController();
  final _ethTxidController = TextEditingController();
  final _amountController = TextEditingController();
  bool _isLoading = false;

  Future<void> _submitBurn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final walletService = context.read<WalletService>();
      final wallet = await walletService.getCurrentWallet();

      if (wallet == null) throw Exception('No wallet found');

      final apiService = context.read<ApiService>();
      final amount = (double.parse(_amountController.text) * 1000000).toInt();

      final result = await apiService.submitBurn(
        uatAddress: wallet['address']!,
        btcTxid: _btcTxidController.text.trim(),
        ethTxid: _ethTxidController.text.trim(),
        amount: amount,
      );

      if (!mounted) return;

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Burn submitted! ${result['msg'] ?? 'Pending verification'}'),
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
        title: const Text('Proof-of-Burn'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                const Icon(
                  Icons.local_fire_department,
                  size: 80,
                  color: Colors.orange,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Burn BTC or ETH to receive UAT',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Submit your Bitcoin or Ethereum burn transaction ID to receive UAT tokens',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _btcTxidController,
                  decoration: const InputDecoration(
                    labelText: 'Bitcoin TXID',
                    hintText: 'Enter BTC transaction ID',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.currency_bitcoin),
                  ),
                  validator: (value) {
                    if (value != null && value.trim().isNotEmpty) {
                      if (value.trim().length != 64) {
                        return 'Invalid BTC TXID length';
                      }
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _ethTxidController,
                  decoration: const InputDecoration(
                    labelText: 'Ethereum TXID',
                    hintText: 'Enter ETH transaction ID (0x...)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.currency_exchange),
                  ),
                  validator: (value) {
                    if (value != null && value.trim().isNotEmpty) {
                      if (!value.trim().startsWith('0x') ||
                          value.trim().length != 66) {
                        return 'Invalid ETH TXID format';
                      }
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _amountController,
                  decoration: const InputDecoration(
                    labelText: 'Burned Amount (UAT equivalent)',
                    hintText: '0.000000',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.local_fire_department),
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
                  onPressed: _isLoading ? null : _submitBurn,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepOrange,
                    padding: const EdgeInsets.all(16),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : const Text('SUBMIT BURN PROOF',
                          style: TextStyle(fontSize: 16)),
                ),
                const SizedBox(height: 16),
                const Card(
                  color: Color(0xFFB71C1C),
                  child: Padding(
                    padding: EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '⚠️ Important:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '• You must have already sent BTC/ETH to a burn address\n'
                          '• Oracle validators will verify your burn transaction\n'
                          '• UAT will be credited after verification (may take time)\n'
                          '• False submissions will be rejected',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
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
    _btcTxidController.dispose();
    _ethTxidController.dispose();
    _amountController.dispose();
    super.dispose();
  }
}
