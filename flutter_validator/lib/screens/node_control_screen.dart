import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/wallet_service.dart';
import '../services/api_service.dart';
import '../services/network_status_service.dart';
import '../services/node_process_service.dart';
import '../services/tor_service.dart';
import '../constants/blockchain.dart';
import '../widgets/network_status_bar.dart';
import '../main.dart';
import 'dashboard_screen.dart';

/// Main screen after wallet registration.
/// Three tabs: Node (process controls), Dashboard (network monitoring), Settings.
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
  bool _showLogs = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
      if (mounted) setState(() => _balance = account.balanceUAT);
    } catch (e) {
      debugPrint('Balance refresh error: $e');
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
        title: const Row(children: [
          Icon(Icons.verified_user, size: 24),
          SizedBox(width: 8),
          Text('UAT Validator'),
        ]),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: Colors.orange.withValues(alpha: 0.5))),
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
            Tab(icon: Icon(Icons.dns), text: 'Node'),
            Tab(icon: Icon(Icons.dashboard), text: 'Dashboard'),
            Tab(icon: Icon(Icons.settings), text: 'Settings'),
          ],
        ),
      ),
      body: Column(children: [
        const NetworkStatusBar(),
        Expanded(
            child: TabBarView(
          controller: _tabController,
          children: [
            _buildNodeTab(),
            const DashboardScreen(),
            _buildSettingsTab(),
          ],
        )),
      ]),
    );
  }

  // ================================================================
  // TAB 1: NODE CONTROL
  // ================================================================

  Widget _buildNodeTab() {
    return Consumer<NodeProcessService>(
      builder: (context, node, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildNodeStatusCard(node),
              const SizedBox(height: 16),
              _buildNodeInfoCard(node),
              const SizedBox(height: 16),
              _buildControlButtons(node),
              const SizedBox(height: 16),
              _buildLogSection(node),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNodeStatusCard(NodeProcessService node) {
    final (statusColor, statusIcon, statusText) = switch (node.status) {
      NodeStatus.stopped => (Colors.grey, Icons.stop_circle, 'Stopped'),
      NodeStatus.starting => (Colors.amber, Icons.hourglass_top, 'Starting...'),
      NodeStatus.syncing => (Colors.blue, Icons.sync, 'Syncing'),
      NodeStatus.running => (Colors.green, Icons.check_circle, 'Running'),
      NodeStatus.stopping => (Colors.orange, Icons.pause_circle, 'Stopping...'),
      NodeStatus.error => (Colors.red, Icons.error, 'Error'),
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          Icon(statusIcon, size: 56, color: statusColor),
          const SizedBox(height: 12),
          Text(statusText,
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: statusColor)),
          const SizedBox(height: 4),
          if (node.status == NodeStatus.running)
            Text('Port ${node.apiPort} | PID active',
                style: TextStyle(color: Colors.grey[400], fontSize: 12)),
          if (node.status == NodeStatus.error && node.errorMessage != null)
            Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8)),
                    child: Text(node.errorMessage!,
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                        textAlign: TextAlign.center))),
        ]),
      ),
    );
  }

  Widget _buildNodeInfoCard(NodeProcessService node) {
    final torService = context.read<TorService>();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Icon(Icons.info_outline, color: Color(0xFF6B4CE6)),
              SizedBox(width: 8),
              Text('Node Details',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ]),
            const Divider(),
            _infoRow('Status', node.status.name.toUpperCase()),
            _infoRow('API Port', node.apiPort.toString()),
            _infoRow('Local API', node.localApiUrl),
            if (node.nodeAddress != null)
              _infoTapRow('Node Address', _shortAddr(node.nodeAddress!),
                  node.nodeAddress!),
            if (node.onionAddress != null || torService.onionAddress != null)
              _infoTapRow(
                '.onion Address',
                _shortOnion(node.onionAddress ?? torService.onionAddress!),
                node.onionAddress ?? torService.onionAddress!,
              ),
            if (node.dataDir != null) _infoRow('Data Dir', node.dataDir!),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButtons(NodeProcessService node) {
    final isRunning = node.isRunning;
    final isStopped = node.isStopped;

    return Row(children: [
      Expanded(
        flex: 2,
        child: ElevatedButton.icon(
          onPressed: isStopped
              ? () => _startNode(node)
              : (isRunning ? () => _stopNode(node) : null),
          icon: Icon(isStopped ? Icons.play_arrow : Icons.stop),
          label: Text(isStopped ? 'START NODE' : 'STOP NODE',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
              backgroundColor: isStopped ? Colors.green : Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12))),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: ElevatedButton.icon(
          onPressed: isRunning ? () => _restartNode(node) : null,
          icon: const Icon(Icons.refresh),
          label: const Text('RESTART'),
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6B4CE6),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12))),
        ),
      ),
    ]);
  }

  Widget _buildLogSection(NodeProcessService node) {
    return Card(
      child: Column(children: [
        ListTile(
          leading: const Icon(Icons.terminal, color: Colors.green),
          title: const Text('Node Logs',
              style: TextStyle(fontWeight: FontWeight.bold)),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            Text('${node.logs.length} lines',
                style: TextStyle(fontSize: 12, color: Colors.grey[400])),
            const SizedBox(width: 8),
            IconButton(
                icon: Icon(_showLogs ? Icons.expand_less : Icons.expand_more),
                onPressed: () => setState(() => _showLogs = !_showLogs)),
          ]),
        ),
        if (_showLogs)
          Container(
            height: 300,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            decoration: BoxDecoration(
                color: Colors.black, borderRadius: BorderRadius.circular(8)),
            child: node.logs.isEmpty
                ? const Center(
                    child: Text('No logs yet',
                        style: TextStyle(
                            color: Colors.grey, fontFamily: 'monospace')))
                : ListView.builder(
                    itemCount: node.logs.length,
                    reverse: true,
                    padding: const EdgeInsets.all(8),
                    itemBuilder: (_, i) {
                      final line = node.logs[node.logs.length - 1 - i];
                      Color color = Colors.grey[300]!;
                      if (line.contains('ERR')) {
                        color = Colors.red;
                      } else if (line.contains('ready') ||
                          line.contains('running')) {
                        color = Colors.green;
                      } else if (line.contains('restart') ||
                          line.contains('warning')) {
                        color = Colors.amber;
                      }
                      return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 1),
                          child: Text(line,
                              style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 11,
                                  color: color)));
                    }),
          ),
      ]),
    );
  }

  Future<void> _startNode(NodeProcessService node) async {
    final torService = context.read<TorService>();
    String? onion = torService.onionAddress;

    if (onion == null && !torService.isRunning) {
      onion = await torService.startWithHiddenService(
        localPort: node.apiPort,
        onionPort: 80,
      );
    }

    await node.start(port: node.apiPort, onionAddress: onion);
  }

  Future<void> _stopNode(NodeProcessService node) async {
    await node.stop();
  }

  Future<void> _restartNode(NodeProcessService node) async {
    await node.restart();
  }

  // ================================================================
  // TAB 3: SETTINGS
  // ================================================================

  Widget _buildSettingsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildWalletCard(),
          const SizedBox(height: 16),
          _buildNetworkInfoCard(),
          const SizedBox(height: 16),
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
                      'To send, receive, or burn UAT, use the UAT Wallet app. '
                      'This validator controls your node and monitors network health.',
                      style: TextStyle(fontSize: 12, color: Colors.blue))),
            ]),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
              onPressed: _confirmLogout,
              icon: const Icon(Icons.logout, color: Colors.red),
              label: const Text('Unregister Validator',
                  style: TextStyle(color: Colors.red)),
              style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  side: const BorderSide(color: Colors.red))),
        ],
      ),
    );
  }

  Widget _buildWalletCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Icon(Icons.account_balance_wallet, color: Color(0xFF6B4CE6)),
              SizedBox(width: 8),
              Text('Validator Wallet',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ]),
            const Divider(),
            const SizedBox(height: 8),
            const Text('Address',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 4),
            Row(children: [
              Expanded(
                  child: Text(_walletAddress ?? 'Loading...',
                      style: const TextStyle(
                          fontFamily: 'monospace', fontSize: 12))),
              if (_walletAddress != null)
                IconButton(
                    icon: const Icon(Icons.copy, size: 18),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _walletAddress!));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Address copied'),
                          duration: Duration(seconds: 2)));
                    }),
            ]),
            const SizedBox(height: 12),
            const Text('Balance',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 4),
            Row(children: [
              Text(
                  _balance != null
                      ? '${BlockchainConstants.formatUat(_balance!)} UAT'
                      : 'Loading...',
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  onPressed: _refreshBalance),
            ]),
            const SizedBox(height: 8),
            if (_balance != null)
              Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                      color: _balance! >= 1000
                          ? Colors.green.withValues(alpha: 0.1)
                          : Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(_balance! >= 1000 ? Icons.check_circle : Icons.warning,
                        size: 16,
                        color: _balance! >= 1000 ? Colors.green : Colors.red),
                    const SizedBox(width: 6),
                    Text(
                        _balance! >= 1000
                            ? 'Active Validator (Stake >= 1,000 UAT)'
                            : 'Insufficient Stake',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color:
                                _balance! >= 1000 ? Colors.green : Colors.red)),
                  ])),
          ],
        ),
      ),
    );
  }

  Widget _buildNetworkInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Icon(Icons.public, color: Colors.blue),
              SizedBox(width: 8),
              Text('Network',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ]),
            const Divider(),
            Consumer<NetworkStatusService>(
                builder: (context, net, _) => Column(children: [
                      _infoRow('Status',
                          net.isConnected ? 'Connected' : 'Disconnected'),
                      _infoRow('Block Height', '${net.blockHeight}'),
                      _infoRow('Peers', '${net.peerCount}'),
                      _infoRow('Version', net.nodeVersion),
                    ])),
          ],
        ),
      ),
    );
  }

  // ================================================================
  // HELPERS
  // ================================================================

  Widget _infoRow(String label, String value) {
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child:
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: TextStyle(color: Colors.grey[400])),
          Flexible(
              child: Text(value,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis)),
        ]));
  }

  Widget _infoTapRow(String label, String displayValue, String fullValue) {
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child:
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: TextStyle(color: Colors.grey[400])),
          Row(mainAxisSize: MainAxisSize.min, children: [
            Text(displayValue,
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontFamily: 'monospace',
                    fontSize: 12)),
            const SizedBox(width: 4),
            GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: fullValue));
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('$label copied'),
                      duration: const Duration(seconds: 2)));
                },
                child: const Icon(Icons.copy, size: 14, color: Colors.grey)),
          ]),
        ]));
  }

  String _shortAddr(String addr) {
    if (addr.length <= 20) return addr;
    return '${addr.substring(0, 10)}...${addr.substring(addr.length - 8)}';
  }

  String _shortOnion(String onion) {
    if (onion.length <= 20) return onion;
    return '${onion.substring(0, 12)}...onion';
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unregister Validator?'),
        content: const Text(
            'This will stop the node and remove your wallet from this app. '
            'Your funds are safe on the blockchain.\n\n'
            'You can re-register anytime with the same seed phrase.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
          TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                // Stop node & Tor
                try {
                  final node = context.read<NodeProcessService>();
                  if (node.isRunning) await node.stop();
                } catch (_) {}
                try {
                  final tor = context.read<TorService>();
                  await tor.stop();
                } catch (_) {}
                // Delete wallet
                final walletService = context.read<WalletService>();
                await walletService.deleteWallet();
                // Reset app back to setup wizard
                if (mounted) {
                  MyApp.resetToSetup(context);
                }
              },
              child: const Text('UNREGISTER',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }
}
