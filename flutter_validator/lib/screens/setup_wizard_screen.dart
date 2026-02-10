import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/wallet_service.dart';
import '../services/api_service.dart';
import '../constants/blockchain.dart';

/// Validator Registration Wizard
///
/// Flow:
/// 1. Choose import method: Seed Phrase / Private Key / Wallet Address
/// 2. Input credentials
/// 3. Validate balance >= 1000 UAT
/// 4. Confirm registration → Navigate to dashboard
class SetupWizardScreen extends StatefulWidget {
  final VoidCallback onSetupComplete;

  const SetupWizardScreen({super.key, required this.onSetupComplete});

  @override
  State<SetupWizardScreen> createState() => _SetupWizardScreenState();
}

enum _ImportMethod { seedPhrase, privateKey, walletAddress }

class _SetupWizardScreenState extends State<SetupWizardScreen> {
  int _currentStep = 0;
  _ImportMethod _importMethod = _ImportMethod.seedPhrase;

  final _seedController = TextEditingController();
  final _privateKeyController = TextEditingController();
  final _addressController = TextEditingController();

  bool _isValidating = false;
  String? _error;
  String? _validatedAddress;
  double? _validatedBalance;

  static const double _minStakeUAT = 1000.0;

  @override
  void dispose() {
    _seedController.dispose();
    _privateKeyController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _importAndValidate() async {
    setState(() {
      _isValidating = true;
      _error = null;
    });

    try {
      final walletService = context.read<WalletService>();
      final apiService = context.read<ApiService>();
      String? walletAddress;

      // Step 1: Import wallet based on method
      switch (_importMethod) {
        case _ImportMethod.seedPhrase:
          final seed = _seedController.text.trim();
          if (seed.isEmpty) {
            throw Exception('Please enter your seed phrase');
          }
          final words = seed.split(RegExp(r'\s+'));
          if (words.length != 12 && words.length != 24) {
            throw Exception(
                'Seed phrase must be 12 or 24 words (got ${words.length})');
          }
          final wallet = await walletService.importWallet(seed);
          walletAddress = wallet['address'];
          break;

        case _ImportMethod.privateKey:
          final pk = _privateKeyController.text.trim();
          if (pk.isEmpty) {
            throw Exception('Please enter your private key');
          }
          // Import via private key — derive address from it
          final wallet = await walletService.importByPrivateKey(pk);
          walletAddress = wallet['address'];
          break;

        case _ImportMethod.walletAddress:
          final addr = _addressController.text.trim();
          if (addr.isEmpty) {
            throw Exception('Please enter your wallet address');
          }
          if (!addr.startsWith('UAT')) {
            throw Exception('Invalid address format (must start with UAT)');
          }
          // Import by address only (no signing capability, view-only validator)
          await walletService.importByAddress(addr);
          walletAddress = addr;
          break;
      }

      if (walletAddress == null || walletAddress.isEmpty) {
        throw Exception('Failed to derive wallet address');
      }

      // Step 2: Check balance >= 1000 UAT
      debugPrint('🔍 [Setup] Checking balance for $walletAddress...');
      final account = await apiService.getBalance(walletAddress);
      final balanceUAT = account.balanceUAT;

      debugPrint('🔍 [Setup] Balance: $balanceUAT UAT (need >= $_minStakeUAT)');

      if (balanceUAT < _minStakeUAT) {
        throw Exception(
          'Insufficient balance: ${BlockchainConstants.formatUat(balanceUAT)} UAT.\n'
          'Minimum validator stake is ${_minStakeUAT.toInt()} UAT.\n'
          'Please fund your wallet first using the UAT Wallet app.',
        );
      }

      setState(() {
        _validatedAddress = walletAddress;
        _validatedBalance = balanceUAT;
        _currentStep = 1; // Move to confirmation step
      });
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      setState(() => _isValidating = false);
    }
  }

  void _confirmRegistration() {
    widget.onSetupComplete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child:
              _currentStep == 0 ? _buildImportStep() : _buildConfirmationStep(),
        ),
      ),
    );
  }

  Widget _buildImportStep() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 32),
          // Header
          const Icon(Icons.verified_user, size: 80, color: Color(0xFF6B4CE6)),
          const SizedBox(height: 16),
          const Text(
            'Register Validator',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Import your wallet to register as a validator node.\n'
            'Minimum stake: ${_minStakeUAT.toInt()} UAT',
            style: TextStyle(fontSize: 14, color: Colors.grey[400]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          // Import method selector
          const Text('Import Method',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          _buildMethodSelector(),
          const SizedBox(height: 24),

          // Input field based on method
          _buildInputField(),
          const SizedBox(height: 24),

          // Error message
          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_error!,
                        style:
                            const TextStyle(color: Colors.red, fontSize: 13)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Submit button
          ElevatedButton(
            onPressed: _isValidating ? null : _importAndValidate,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6B4CE6),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: _isValidating
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('VALIDATE & REGISTER',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),

          const SizedBox(height: 24),
          // Info box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outlined, color: Colors.blue, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Your wallet needs at least 1,000 UAT to register as a validator. '
                    'Use the UAT Wallet app to send/receive funds.',
                    style: TextStyle(fontSize: 12, color: Colors.blue),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMethodSelector() {
    return Column(
      children: [
        _methodTile(
          _ImportMethod.seedPhrase,
          Icons.key,
          'Seed Phrase',
          '12 or 24 word mnemonic',
        ),
        _methodTile(
          _ImportMethod.privateKey,
          Icons.vpn_key,
          'Private Key',
          'Hex-encoded private key',
        ),
        _methodTile(
          _ImportMethod.walletAddress,
          Icons.account_balance_wallet,
          'Wallet Address',
          'UAT address (view-only)',
        ),
      ],
    );
  }

  Widget _methodTile(
      _ImportMethod method, IconData icon, String title, String subtitle) {
    final selected = _importMethod == method;
    return Card(
      color: selected ? const Color(0xFF6B4CE6).withOpacity(0.2) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: selected ? const Color(0xFF6B4CE6) : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: ListTile(
        leading:
            Icon(icon, color: selected ? const Color(0xFF6B4CE6) : Colors.grey),
        title: Text(title,
            style: TextStyle(
                fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
        subtitle: Text(subtitle,
            style: TextStyle(fontSize: 12, color: Colors.grey[400])),
        trailing: selected
            ? const Icon(Icons.check_circle, color: Color(0xFF6B4CE6))
            : null,
        onTap: () => setState(() {
          _importMethod = method;
          _error = null;
        }),
      ),
    );
  }

  Widget _buildInputField() {
    switch (_importMethod) {
      case _ImportMethod.seedPhrase:
        return TextField(
          controller: _seedController,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: 'Seed Phrase',
            hintText: 'Enter your 12 or 24 word seed phrase...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            prefixIcon: const Icon(Icons.key),
          ),
        );
      case _ImportMethod.privateKey:
        return TextField(
          controller: _privateKeyController,
          decoration: InputDecoration(
            labelText: 'Private Key',
            hintText: 'Enter hex-encoded private key...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            prefixIcon: const Icon(Icons.vpn_key),
          ),
          obscureText: true,
        );
      case _ImportMethod.walletAddress:
        return TextField(
          controller: _addressController,
          decoration: InputDecoration(
            labelText: 'Wallet Address',
            hintText: 'UAT...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            prefixIcon: const Icon(Icons.account_balance_wallet),
          ),
        );
    }
  }

  Widget _buildConfirmationStep() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.check_circle, size: 100, color: Colors.green),
        const SizedBox(height: 24),
        const Text(
          'Validator Registered!',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          'Your wallet has been verified',
          style: TextStyle(fontSize: 16, color: Colors.grey[400]),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),

        // Wallet info card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _infoRow('Address',
                    '${_validatedAddress!.substring(0, 12)}...${_validatedAddress!.substring(_validatedAddress!.length - 8)}'),
                const Divider(),
                _infoRow('Balance',
                    '${BlockchainConstants.formatUat(_validatedBalance!)} UAT'),
                const Divider(),
                _infoRow('Min Stake', '${_minStakeUAT.toInt()} UAT'),
                const Divider(),
                _infoRow('Status', '✅ Eligible'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 32),

        ElevatedButton(
          onPressed: _confirmRegistration,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('OPEN DASHBOARD',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[400])),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
