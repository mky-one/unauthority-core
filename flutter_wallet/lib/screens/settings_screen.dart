import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/wallet_service.dart';
import '../services/api_service.dart';
import '../widgets/network_badge.dart';
import 'wallet_setup_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _showSeedPhrase = false;
  String? _seedPhrase;
  NetworkEnvironment _currentNetwork = NetworkEnvironment.testnet;

  @override
  void initState() {
    super.initState();
    _loadNetworkState();
  }

  /// SECURITY FIX M-02: Clear seed phrase reference on widget disposal.
  /// Removes the Dart String reference so GC can collect sooner.
  /// (Dart Strings are immutable — content persists until GC, but
  /// removing the reference is the best Dart can do.)
  @override
  void dispose() {
    _seedPhrase = null;
    _showSeedPhrase = false;
    super.dispose();
  }

  /// FIX H-02: Only load network state on init; seed phrase is loaded
  /// lazily when user explicitly taps the reveal button.
  Future<void> _loadNetworkState() async {
    final apiService = context.read<ApiService>();
    if (mounted) {
      setState(() {
        _currentNetwork = apiService.environment;
      });
      debugPrint(
          '⚙️ [SettingsScreen._loadNetworkState] Current network: ${apiService.environment.name}');
    }
  }

  /// FIX H-02: Lazy-load seed phrase only when user taps reveal.
  /// Prevents keeping mnemonic in widget state longer than necessary.
  Future<void> _revealSeedPhrase() async {
    debugPrint(
        '⚙️ [SettingsScreen._revealSeedPhrase] Toggling seed phrase visibility...');
    if (_seedPhrase != null) {
      // Already loaded — just toggle visibility
      setState(() => _showSeedPhrase = !_showSeedPhrase);
      return;
    }
    final walletService = context.read<WalletService>();
    final wallet = await walletService.getCurrentWallet(includeMnemonic: true);
    if (wallet != null && mounted) {
      setState(() {
        _seedPhrase = wallet['mnemonic'];
        _showSeedPhrase = true;
      });
      debugPrint('⚙️ [SettingsScreen._revealSeedPhrase] Seed phrase revealed');
    }
  }

  void _copySeedPhrase() {
    if (_seedPhrase != null) {
      Clipboard.setData(ClipboardData(text: _seedPhrase!));
      // FIX M-01: Auto-clear clipboard after 30 seconds for security
      Future.delayed(const Duration(seconds: 30), () {
        Clipboard.setData(const ClipboardData(text: ''));
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Seed phrase copied to clipboard (auto-clears in 30s)'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _confirmLogout() async {
    debugPrint(
        '⚙️ [SettingsScreen._confirmLogout] Showing logout confirmation...');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text(
          'Are you sure you want to logout? Make sure you have backed up your seed phrase!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('LOGOUT'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      debugPrint('⚙️ [SettingsScreen._confirmLogout] Logout confirmed');
      final walletService = context.read<WalletService>();
      await walletService.clearWallet();

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const WalletSetupScreen()),
          (route) => false,
        );
      }
    }
  }

  void _switchNetwork(NetworkEnvironment network) {
    debugPrint(
        '⚙️ [SettingsScreen._switchNetwork] Switching from ${_currentNetwork.name} to ${network.name}');
    setState(() => _currentNetwork = network);
    final apiService = context.read<ApiService>();
    apiService.switchEnvironment(network);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Switched to ${network.name.toUpperCase()}',
        ),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
      ),
      body: ListView(
        children: [
          // Network Switcher
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Network',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<NetworkEnvironment>(
                    segments: const [
                      ButtonSegment(
                        value: NetworkEnvironment.testnet,
                        label: Text('TESTNET'),
                        icon: Icon(Icons.science),
                      ),
                      ButtonSegment(
                        value: NetworkEnvironment.mainnet,
                        label: Text('MAINNET'),
                        icon: Icon(Icons.rocket_launch),
                      ),
                    ],
                    selected: {_currentNetwork},
                    onSelectionChanged: (Set<NetworkEnvironment> selected) {
                      _switchNetwork(selected.first);
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _currentNetwork == NetworkEnvironment.testnet
                        ? 'Connected to Testnet (.onion via Tor)'
                        : 'Mainnet coming Q2 2026',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const NetworkSettingsScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.tune, size: 16),
                    label: const Text('Advanced Network Settings'),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Backup Seed Phrase
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.vpn_key, color: Colors.orange),
                  title: const Text('Backup Seed Phrase'),
                  subtitle: const Text('Save your recovery phrase'),
                  trailing: IconButton(
                    icon: Icon(_showSeedPhrase
                        ? Icons.visibility_off
                        : Icons.visibility),
                    onPressed: _revealSeedPhrase,
                  ),
                ),
                if (_showSeedPhrase && _seedPhrase != null) ...[
                  const Divider(),
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0x1AFF9800), // orange at 10% opacity
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.warning, color: Colors.orange, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'KEEP THIS SECRET!',
                              style: TextStyle(
                                color: Colors.orange,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SelectableText(
                          _seedPhrase!,
                          style: const TextStyle(
                            fontSize: 14,
                            fontFamily: 'monospace',
                          ),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: _copySeedPhrase,
                          icon: const Icon(Icons.copy, size: 18),
                          label: const Text('COPY'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // About Section
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info),
                  title: const Text('About LOS'),
                  subtitle: const Text('Blockchain information'),
                  onTap: () => _showAboutDialog(),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.help),
                  title: const Text('Help & Support'),
                  subtitle: const Text('Documentation and FAQ'),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Documentation coming soon')),
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Danger Zone
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color(0x1AF44336), // red at 10% opacity
            child: ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text(
                'Logout',
                style:
                    TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
              subtitle: const Text('Clear wallet data from this device'),
              onTap: _confirmLogout,
            ),
          ),

          const SizedBox(height: 16),
          const Center(
            child: Text(
              'LOS Wallet v1.0.5-testnet\nBuilt with Flutter',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About Unauthority (LOS)'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Unauthority is a privacy-focused blockchain with:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 12),
              Text('• Oracle-driven aBFT consensus'),
              Text('• Proof-of-Burn economics (ETH/BTC → LOS)'),
              Text('• Fixed supply: 21.9 million LOS'),
              Text('• Tor-only mainnet for privacy'),
              Text('• WASM smart contracts (UVM)'),
              Text('• Quadratic validator staking'),
              SizedBox(height: 12),
              Text(
                'Network Status:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('• Testnet: Online (.onion)'),
              Text('• Mainnet: Coming Q2 2026'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CLOSE'),
          ),
        ],
      ),
    );
  }
}
