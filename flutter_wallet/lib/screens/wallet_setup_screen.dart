import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/wallet_service.dart';
import 'home_screen.dart';

class WalletSetupScreen extends StatefulWidget {
  const WalletSetupScreen({super.key});

  @override
  State<WalletSetupScreen> createState() => _WalletSetupScreenState();
}

class _WalletSetupScreenState extends State<WalletSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _mnemonicController = TextEditingController();
  bool _isLoading = false;
  bool _isImportMode = false;

  Future<void> _generateWallet() async {
    setState(() => _isLoading = true);

    try {
      final walletService = context.read<WalletService>();
      final wallet = await walletService.generateWallet();

      if (!mounted) return;

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('⚠️ Backup Your Seed Phrase'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Write down these 24 words in order. This is the ONLY way to recover your wallet!',
                  style: TextStyle(color: Colors.redAccent),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    wallet['mnemonic']!,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Address: ${wallet['address']}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const HomeScreen()),
                );
              },
              child: const Text('I HAVE SAVED IT'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _importWallet() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final walletService = context.read<WalletService>();
      await walletService.importWallet(_mnemonicController.text.trim());

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('UAT Wallet Setup'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.account_balance_wallet,
                size: 80,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                _isImportMode ? 'Import Wallet' : 'Create New Wallet',
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              if (_isImportMode) ...[
                Form(
                  key: _formKey,
                  child: TextFormField(
                    controller: _mnemonicController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Seed Phrase (24 words)',
                      hintText: 'word1 word2 word3 ...',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your seed phrase';
                      }
                      final words = value.trim().split(RegExp(r'\s+'));
                      if (words.length != 24) {
                        return 'Seed phrase must be exactly 24 words';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isLoading ? null : _importWallet,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : const Text('IMPORT WALLET',
                          style: TextStyle(fontSize: 16)),
                ),
              ] else ...[
                ElevatedButton(
                  onPressed: _isLoading ? null : _generateWallet,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : const Text('CREATE NEW WALLET',
                          style: TextStyle(fontSize: 16)),
                ),
              ],
              const SizedBox(height: 16),
              TextButton(
                onPressed: _isLoading
                    ? null
                    : () {
                        setState(() => _isImportMode = !_isImportMode);
                      },
                child: Text(_isImportMode
                    ? 'Create New Wallet Instead'
                    : 'Import Existing Wallet'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _mnemonicController.dispose();
    super.dispose();
  }
}
