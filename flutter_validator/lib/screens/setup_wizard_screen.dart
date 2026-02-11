import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/wallet_service.dart';
import '../services/api_service.dart';
import '../services/node_process_service.dart';
import '../services/tor_service.dart';
import '../constants/blockchain.dart';

/// Validator Setup Wizard - 3-step flow:
/// 1. Import Wallet (seed phrase / private key / address)
/// 2. Validate balance >= 1000 UAT -> Confirm
/// 3. Start Tor hidden service + uat-node binary -> Go to Dashboard
class SetupWizardScreen extends StatefulWidget {
  final VoidCallback onSetupComplete;

  const SetupWizardScreen({super.key, required this.onSetupComplete});

  @override
  State<SetupWizardScreen> createState() => _SetupWizardScreenState();
}

enum _ImportMethod { seedPhrase, privateKey, walletAddress }

class _SetupWizardScreenState extends State<SetupWizardScreen> {
  int _currentStep = 0; // 0=import, 1=confirm, 2=launching
  _ImportMethod _importMethod = _ImportMethod.seedPhrase;

  final _seedController = TextEditingController();
  final _privateKeyController = TextEditingController();
  final _addressController = TextEditingController();

  bool _isValidating = false;
  bool _isLaunching = false;
  bool _isGenesisMonitor =
      false; // Genesis bootstrap validator → monitor-only mode
  String? _error;
  String? _validatedAddress;
  double? _validatedBalance;

  // Launch progress
  String _launchStatus = '';
  double _launchProgress = 0.0;

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

      switch (_importMethod) {
        case _ImportMethod.seedPhrase:
          final seed = _seedController.text.trim();
          if (seed.isEmpty) throw Exception('Please enter your seed phrase');
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
          if (pk.isEmpty) throw Exception('Please enter your private key');
          final wallet = await walletService.importByPrivateKey(pk);
          walletAddress = wallet['address'];
          break;

        case _ImportMethod.walletAddress:
          final addr = _addressController.text.trim();
          if (addr.isEmpty) throw Exception('Please enter your wallet address');
          if (!addr.startsWith('UAT'))
            throw Exception('Invalid address format');
          await walletService.importByAddress(addr);
          walletAddress = addr;
          break;
      }

      if (walletAddress == null || walletAddress.isEmpty) {
        throw Exception('Failed to derive wallet address');
      }

      debugPrint('Checking balance for $walletAddress...');
      final account = await apiService.getBalance(walletAddress);

      if (account.balanceUAT < _minStakeUAT) {
        throw Exception(
          'Insufficient balance: ${BlockchainConstants.formatUat(account.balanceUAT)} UAT.\n'
          'Minimum validator stake is ${_minStakeUAT.toInt()} UAT.\n'
          'Fund your wallet first using the UAT Wallet app.',
        );
      }

      // Check if this address is an active genesis bootstrap validator.
      // If yes → monitor-only mode (no new node spawn, no new onion).
      final isGenesisActive =
          await apiService.isActiveGenesisValidator(walletAddress);

      setState(() {
        _validatedAddress = walletAddress;
        _validatedBalance = account.balanceUAT;
        _isGenesisMonitor = isGenesisActive;
        _currentStep = 1;
      });
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      setState(() => _isValidating = false);
    }
  }

  Future<void> _launchNode() async {
    setState(() {
      _isLaunching = true;
      _currentStep = 2;
      _launchProgress = 0.1;
      _error = null;
    });

    try {
      final walletService = context.read<WalletService>();

      // ── MONITOR-ONLY MODE ──
      // Genesis bootstrap validator is already running as a CLI node.
      // Don't spawn a new uat-node, don't create a new .onion address.
      // Just save the wallet and go straight to the dashboard.
      if (_isGenesisMonitor) {
        setState(() {
          _launchStatus = 'Genesis bootstrap validator detected.\n'
              'Entering monitor-only mode...';
          _launchProgress = 0.3;
        });

        await walletService.setMonitorMode(true);

        setState(() {
          _launchStatus = 'Connecting to bootstrap node dashboard...';
          _launchProgress = 0.7;
        });

        await Future.delayed(const Duration(seconds: 1));

        setState(() {
          _launchStatus = 'Monitor mode active!';
          _launchProgress = 1.0;
        });

        await Future.delayed(const Duration(seconds: 1));
        widget.onSetupComplete();
        return;
      }

      // ── NORMAL MODE ── Spawn new validator node with Tor hidden service
      await walletService.setMonitorMode(false);

      setState(() {
        _launchStatus = 'Initializing Tor hidden service...';
      });

      final nodeService = context.read<NodeProcessService>();
      final torService = context.read<TorService>();

      // Step A: Start Tor with hidden service
      setState(() {
        _launchStatus =
            'Starting Tor hidden service...\nThis may take up to 2 minutes on first run.';
        _launchProgress = 0.2;
      });

      // Find an available port (avoid conflict with bootstrap nodes on 3030-3033)
      final nodePort =
          await NodeProcessService.findAvailablePort(preferred: 3035);
      debugPrint('📡 Selected port $nodePort for validator node');

      final onionAddress = await torService.startWithHiddenService(
        localPort: nodePort,
        onionPort: 80,
      );

      if (onionAddress == null) {
        debugPrint('Tor hidden service failed, running localhost-only');
        setState(() {
          _launchStatus =
              'Tor unavailable - running in local mode.\nStarting validator node...';
          _launchProgress = 0.5;
        });
      } else {
        setState(() {
          _launchStatus = 'Tor ready!\nStarting validator node...';
          _launchProgress = 0.5;
        });
      }

      // Step B: Start uat-node
      setState(() {
        _launchProgress = 0.6;
      });

      final started = await nodeService.start(
        port: nodePort,
        onionAddress: onionAddress,
      );

      if (!started) {
        throw Exception(nodeService.errorMessage ?? 'Failed to start uat-node');
      }

      setState(() {
        _launchStatus = 'Validator node is running!';
        _launchProgress = 1.0;
      });

      await Future.delayed(const Duration(seconds: 2));
      widget.onSetupComplete();
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isLaunching = false;
        _launchStatus = '';
        _currentStep = 1;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: switch (_currentStep) {
            0 => _buildImportStep(),
            1 => _buildConfirmationStep(),
            2 => _buildLaunchingStep(),
            _ => _buildImportStep(),
          },
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
          const Icon(Icons.verified_user, size: 80, color: Color(0xFF6B4CE6)),
          const SizedBox(height: 16),
          const Text('Register Validator',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
              'Import your wallet to register as a validator node.\nMinimum stake: ${_minStakeUAT.toInt()} UAT',
              style: TextStyle(fontSize: 14, color: Colors.grey[400]),
              textAlign: TextAlign.center),
          const SizedBox(height: 32),
          const Text('Import Method',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          _buildMethodSelector(),
          const SizedBox(height: 24),
          _buildInputField(),
          const SizedBox(height: 24),
          if (_error != null) ...[
            _buildErrorBox(_error!),
            const SizedBox(height: 16),
          ],
          ElevatedButton(
              onPressed: _isValidating ? null : _importAndValidate,
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6B4CE6),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
              child: _isValidating
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('VALIDATE & CONTINUE',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold))),
          const SizedBox(height: 24),
          Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: const Row(children: [
                Icon(Icons.info_outlined, color: Colors.blue, size: 20),
                SizedBox(width: 8),
                Expanded(
                    child: Text(
                        'Your wallet needs at least 1,000 UAT to register as a validator. '
                        'Use the UAT Wallet app to send/receive funds.',
                        style: TextStyle(fontSize: 12, color: Colors.blue))),
              ])),
        ],
      ),
    );
  }

  Widget _buildConfirmationStep() {
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          const Icon(Icons.check_circle, size: 80, color: Colors.green),
          const SizedBox(height: 24),
          const Text('Wallet Verified!',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text('Your wallet is eligible to run a validator node.',
              style: TextStyle(fontSize: 14, color: Colors.grey[400]),
              textAlign: TextAlign.center),
          const SizedBox(height: 32),
          Card(
              child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(children: [
                    _infoRow('Address',
                        '${_validatedAddress!.substring(0, 12)}...${_validatedAddress!.substring(_validatedAddress!.length - 8)}'),
                    const Divider(),
                    _infoRow('Balance',
                        '${BlockchainConstants.formatUat(_validatedBalance!)} UAT'),
                    const Divider(),
                    _infoRow('Min Stake', '${_minStakeUAT.toInt()} UAT'),
                    const Divider(),
                    _infoRow('Status', 'Eligible'),
                  ]))),
          const SizedBox(height: 24),
          if (_error != null) ...[
            _buildErrorBox(_error!),
            const SizedBox(height: 16),
          ],
          if (_isGenesisMonitor) ...[
            // Genesis bootstrap validator — monitor-only flow
            Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: Colors.amber.withValues(alpha: 0.5))),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(children: [
                        Icon(Icons.shield, color: Colors.amber, size: 20),
                        SizedBox(width: 8),
                        Text('Genesis Bootstrap Validator',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.amber,
                                fontSize: 14)),
                      ]),
                      const SizedBox(height: 8),
                      Text(
                          'This address is an active genesis bootstrap validator.\n'
                          'The node is already running via CLI — no new node will be spawned.\n\n'
                          'You will enter monitor-only mode to view the dashboard.',
                          style:
                              TextStyle(fontSize: 13, color: Colors.grey[300])),
                    ])),
          ] else ...[
            // Normal validator — full node spawn flow
            Card(
                color: const Color(0xFF1A1F2E).withValues(alpha: 0.6),
                child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('What happens next:',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(height: 8),
                          _stepItem(
                              '1', 'Setup Tor hidden service (.onion address)'),
                          _stepItem('2', 'Start uat-node validator binary'),
                          _stepItem('3', 'Sync blockchain from network'),
                          _stepItem('4', 'Register as active validator'),
                        ]))),
          ],
          const SizedBox(height: 24),
          ElevatedButton.icon(
              onPressed: _isLaunching ? null : _launchNode,
              icon: Icon(_isGenesisMonitor
                  ? Icons.monitor_heart
                  : Icons.rocket_launch),
              label: Text(
                  _isGenesisMonitor
                      ? 'OPEN DASHBOARD (MONITOR MODE)'
                      : 'START VALIDATOR NODE',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                  backgroundColor: _isGenesisMonitor
                      ? const Color(0xFF6B4CE6)
                      : Colors.green,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)))),
          const SizedBox(height: 12),
          TextButton(
              onPressed: () => setState(() {
                    _currentStep = 0;
                    _error = null;
                  }),
              child: const Text('Back to wallet import')),
        ],
      ),
    );
  }

  Widget _stepItem(String num, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
                color: const Color(0xFF6B4CE6).withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12)),
            child: Center(
                child: Text(num,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.bold)))),
        const SizedBox(width: 12),
        Expanded(
            child: Text(text,
                style: TextStyle(fontSize: 13, color: Colors.grey[300]))),
      ]),
    );
  }

  Widget _buildLaunchingStep() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_launchProgress < 1.0)
            const SizedBox(
                width: 80,
                height: 80,
                child: CircularProgressIndicator(
                    strokeWidth: 4, color: Color(0xFF6B4CE6)))
          else
            Icon(_isGenesisMonitor ? Icons.monitor_heart : Icons.check_circle,
                size: 80, color: Colors.green),
          const SizedBox(height: 32),
          Text(
              _launchProgress < 1.0
                  ? (_isGenesisMonitor
                      ? 'Entering Monitor Mode...'
                      : 'Starting Validator Node...')
                  : (_isGenesisMonitor
                      ? 'Monitor Mode Active!'
                      : 'Validator Running!'),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Text(_launchStatus,
              style: TextStyle(fontSize: 14, color: Colors.grey[400]),
              textAlign: TextAlign.center),
          const SizedBox(height: 32),
          SizedBox(
              width: 300,
              child: LinearProgressIndicator(
                  value: _launchProgress,
                  backgroundColor: Colors.grey[800],
                  color: _launchProgress < 1.0
                      ? const Color(0xFF6B4CE6)
                      : Colors.green,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4))),
          const SizedBox(height: 8),
          Text('${(_launchProgress * 100).toInt()}%',
              style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        ],
      ),
    );
  }

  Widget _buildErrorBox(String message) {
    return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.red.withValues(alpha: 0.3))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 20),
          const SizedBox(width: 8),
          Expanded(
              child: Text(message,
                  style: const TextStyle(color: Colors.red, fontSize: 13))),
        ]));
  }

  Widget _buildMethodSelector() {
    return Column(children: [
      _methodTile(_ImportMethod.seedPhrase, Icons.key, 'Seed Phrase',
          '12 or 24 word mnemonic'),
      _methodTile(_ImportMethod.privateKey, Icons.vpn_key, 'Private Key',
          'Hex-encoded private key'),
      _methodTile(_ImportMethod.walletAddress, Icons.account_balance_wallet,
          'Wallet Address', 'UAT address (view-only)'),
    ]);
  }

  Widget _methodTile(
      _ImportMethod method, IconData icon, String title, String subtitle) {
    final selected = _importMethod == method;
    return Card(
      color: selected ? const Color(0xFF6B4CE6).withValues(alpha: 0.2) : null,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
              color: selected ? const Color(0xFF6B4CE6) : Colors.transparent,
              width: 1.5)),
      child: ListTile(
          leading: Icon(icon,
              color: selected ? const Color(0xFF6B4CE6) : Colors.grey),
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
              })),
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
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.key)));
      case _ImportMethod.privateKey:
        return TextField(
            controller: _privateKeyController,
            obscureText: true,
            decoration: InputDecoration(
                labelText: 'Private Key',
                hintText: 'Enter hex-encoded private key...',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.vpn_key)));
      case _ImportMethod.walletAddress:
        return TextField(
            controller: _addressController,
            decoration: InputDecoration(
                labelText: 'Wallet Address',
                hintText: 'UAT...',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.account_balance_wallet)));
    }
  }

  Widget _infoRow(String label, String value) {
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child:
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: TextStyle(color: Colors.grey[400])),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ]));
  }
}
