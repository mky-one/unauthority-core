import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/wallet_service.dart';
import '../services/api_service.dart';
import '../services/network_status_service.dart';
import '../constants/blockchain.dart';
import '../widgets/network_status_bar.dart';
import 'dashboard_screen.dart';

/// Main screen after wallet registration.
/// Two tabs: Dashboard (network monitoring) and Settings (wallet info + logout).
class NodeControlScreen extends StatefulWidget {
  const NodeControlScreen({super.key});

  @override
  State<NodeControlScreen> createState() => _NodeControlScreenState();
}

class _NodeControlScreenState extends State<NodeControlScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _walletAddress;
  double? _balance;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadWalletInfo();
  }

  Future<void> _loadWalletInfo() async {
    final walletService = context.read<WalletService>();
    final wallet = await walletService.getCurrentWallet();
    if (wallet != null && mounted) {
      setState(() => _walletAddress = wallet['address']);
      _refreshBalance();
    }
  }

  Future<void> _refreshBalance() async {
    if (_walletAddress == null) return;
    try {
      final apiService = context.read<ApiService>();
      final account = await apiService.getBalance(_walletAddress!);
      if (mounted) {
        setState(() => _balance = account.balanceUAT);
      }
    } catch (e) {
      debugPrint('⚠️ Balance refresh error: $e');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.verified_user, size: 24),
            SizedBox(width: 8),
            Text('UAT Validator'),
          ],
        ),
        actions: [
          // Testnet badge
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.withOpacity(0.5)),
            ),
            child: const Text('TESTNET',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange)),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'Dashboard'),
            Tab(icon: Icon(Icons.settings), text: 'Settings'),
          ],
        ),
      ),
      body: Column(
        children: [
          const NetworkStatusBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Dashboard
                const DashboardScreen(),

                // Tab 2: Settings
                _buildSettingsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Wallet Info Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.account_balance_wallet,
                          color: Color(0xFF6B4CE6)),
                      SizedBox(width: 8),
                      Text('Validator Wallet',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 8),
                  // Address
                  const Text('Address',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _walletAddress ?? 'Loading...',
                          style: const TextStyle(
                              fontFamily: 'monospace', fontSize: 12),
                        ),
                      ),
                      if (_walletAddress != null)
                        IconButton(
                          icon: const Icon(Icons.copy, size: 18),
                          onPressed: () {
                            Clipboard.setData(
                                ClipboardData(text: _walletAddress!));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Address copied'),
                                  duration: Duration(seconds: 2)),
                            );
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Balance
                  const Text('Balance',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        _balance != null
                            ? '${BlockchainConstants.formatUat(_balance!)} UAT'
                            : 'Loading...',
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.refresh, size: 20),
                        onPressed: _refreshBalance,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Stake status
                  if (_balance != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _balance! >= 1000
                            ? Colors.green.withOpacity(0.1)
                            : Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _balance! >= 1000
                                ? Icons.check_circle
                                : Icons.warning,
                            size: 16,
                            color:
                                _balance! >= 1000 ? Colors.green : Colors.red,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _balance! >= 1000
                                ? 'Active Validator (Stake ≥ 1,000 UAT)'
                                : 'Insufficient Stake (need 1,000 UAT)',
                            style: TextStyle(
                              fontSize: 12,
                              color:
                                  _balance! >= 1000 ? Colors.green : Colors.red,
                              fontWeight: FontWeight.w600,
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

          // Network Info Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.public, color: Colors.blue),
                      SizedBox(width: 8),
                      Text('Network',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const Divider(),
                  Consumer<NetworkStatusService>(
                    builder: (context, net, _) => Column(
                      children: [
                        _settingsRow(
                            'Status',
                            net.isConnected
                                ? '🟢 Connected'
                                : '🔴 Disconnected'),
                        _settingsRow('Block Height', '${net.blockHeight}'),
                        _settingsRow('Peers', '${net.peerCount}'),
                        _settingsRow('Version', net.nodeVersion),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Info note
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
                    'To send, receive, or burn UAT, use the UAT Wallet app. '
                    'This validator app monitors your node status and network health.',
                    style: TextStyle(fontSize: 12, color: Colors.blue),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Logout button
          OutlinedButton.icon(
            onPressed: _confirmLogout,
            icon: const Icon(Icons.logout, color: Colors.red),
            label: const Text('Unregister Validator',
                style: TextStyle(color: Colors.red)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.all(16),
              side: const BorderSide(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Widget _settingsRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[400])),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unregister Validator?'),
        content: const Text(
          'This will remove your wallet from this validator app. '
          'Your funds are safe — you can re-register anytime.\n\n'
          'Your wallet and UAT tokens remain on the blockchain.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final walletService = context.read<WalletService>();
              await walletService.deleteWallet();
              if (mounted) {
                Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
              }
            },
            child:
                const Text('UNREGISTER', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
