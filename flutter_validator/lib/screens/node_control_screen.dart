import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import '../services/node_process_service.dart';
import 'dashboard_screen.dart';

/// Main screen after setup — start/stop node, view logs, quick stats.
///
/// Bottom navigation:
///  - Control (start/stop, logs)
///  - Dashboard (network monitoring)
///  - Settings (config, reset)
class NodeControlScreen extends StatefulWidget {
  const NodeControlScreen({super.key});

  @override
  State<NodeControlScreen> createState() => _NodeControlScreenState();
}

class _NodeControlScreenState extends State<NodeControlScreen> {
  int _tabIndex = 0;
  Timer? _statsTimer;

  // Quick stats
  int _blockHeight = 0;
  int _peerCount = 0;
  int _validatorCount = 0;
  int _balance = 0;
  bool _isValidator = false;
  String _nodeVersion = '';

  @override
  void initState() {
    super.initState();
    _startStatsPolling();
  }

  @override
  void dispose() {
    _statsTimer?.cancel();
    super.dispose();
  }

  void _startStatsPolling() {
    _fetchStats();
    _statsTimer =
        Timer.periodic(const Duration(seconds: 10), (_) => _fetchStats());
  }

  Future<void> _fetchStats() async {
    final node = context.read<NodeProcessService>();
    if (node.status != NodeStatus.running) return;

    try {
      final api = context.read<ApiService>();
      // Temporarily override API baseUrl to local node
      final nodeInfo =
          await api.getNodeInfoFromUrl('http://127.0.0.1:${node.restPort}');
      if (nodeInfo != null && mounted) {
        setState(() {
          _blockHeight = nodeInfo['block_height'] ?? nodeInfo['height'] ?? 0;
          _peerCount = nodeInfo['peer_count'] ?? nodeInfo['peers'] ?? 0;
          _validatorCount =
              nodeInfo['validator_count'] ?? nodeInfo['validators'] ?? 0;
          _nodeVersion = nodeInfo['version'] ?? '';
        });
      }

      // Fetch balance
      _balance = await node.getNodeBalance();

      // Check if validator
      _isValidator = _balance >= 1000;

      if (mounted) setState(() {});
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      body: IndexedStack(
        index: _tabIndex,
        children: [
          _buildControlTab(),
          const DashboardScreen(embedded: true),
          _buildSettingsTab(),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // BOTTOM NAVIGATION
  // ══════════════════════════════════════════════════════════════════

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        border: Border(top: BorderSide(color: Colors.grey[800]!)),
      ),
      child: BottomNavigationBar(
        currentIndex: _tabIndex,
        onTap: (i) => setState(() => _tabIndex = i),
        backgroundColor: Colors.transparent,
        selectedItemColor: Colors.purpleAccent,
        unselectedItemColor: Colors.grey[600],
        elevation: 0,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.power_settings_new), label: 'Control'),
          BottomNavigationBarItem(
              icon: Icon(Icons.dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(
              icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // TAB 1: CONTROL
  // ══════════════════════════════════════════════════════════════════

  Widget _buildControlTab() {
    return Consumer<NodeProcessService>(
      builder: (context, node, _) {
        return SafeArea(
          child: Column(
            children: [
              // App bar
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  children: [
                    const Icon(Icons.shield,
                        color: Colors.purpleAccent, size: 28),
                    const SizedBox(width: 10),
                    const Text(
                      'UAT Validator',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    _statusBadge(node.status),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Start/Stop button
              _buildPowerButton(node),

              const SizedBox(height: 20),

              // Quick stats grid
              if (node.status == NodeStatus.running) _buildStatsGrid(node),

              const SizedBox(height: 16),

              // Logs section
              Expanded(
                child: _buildLogViewer(node),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _statusBadge(NodeStatus status) {
    Color color;
    switch (status) {
      case NodeStatus.running:
        color = Colors.greenAccent;
        break;
      case NodeStatus.starting:
      case NodeStatus.building:
        color = Colors.orangeAccent;
        break;
      default:
        color = Colors.redAccent;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, color: color, size: 8),
          const SizedBox(width: 6),
          Text(
            status.label.toUpperCase(),
            style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1),
          ),
        ],
      ),
    );
  }

  Widget _buildPowerButton(NodeProcessService node) {
    final isRunning = node.status == NodeStatus.running;
    final isStarting = node.status == NodeStatus.starting;
    final canToggle = !isStarting && node.status != NodeStatus.building;

    return GestureDetector(
      onTap: canToggle
          ? () async {
              if (isRunning) {
                await node.stopNode();
              } else {
                await node.startNode();
              }
            }
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isRunning
              ? Colors.green.withOpacity(0.15)
              : isStarting
                  ? Colors.orange.withOpacity(0.15)
                  : const Color(0xFF1A1A2E),
          border: Border.all(
            color: isRunning
                ? Colors.greenAccent
                : isStarting
                    ? Colors.orangeAccent
                    : Colors.purpleAccent.withOpacity(0.5),
            width: 2,
          ),
          boxShadow: [
            if (isRunning || isStarting)
              BoxShadow(
                color: (isRunning ? Colors.greenAccent : Colors.orangeAccent)
                    .withOpacity(0.2),
                blurRadius: 16,
              ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isStarting)
              const SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                    color: Colors.orangeAccent, strokeWidth: 2),
              )
            else
              Icon(
                isRunning
                    ? Icons.stop_circle_outlined
                    : Icons.power_settings_new,
                size: 36,
                color: isRunning ? Colors.greenAccent : Colors.purpleAccent,
              ),
            const SizedBox(height: 4),
            Text(
              isRunning
                  ? 'STOP'
                  : isStarting
                      ? '...'
                      : 'START',
              style: TextStyle(
                color: isRunning ? Colors.greenAccent : Colors.purpleAccent,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid(NodeProcessService node) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Row(
            children: [
              _statCard('Blocks', _formatNum(_blockHeight), Icons.view_in_ar,
                  Colors.blueAccent),
              const SizedBox(width: 10),
              _statCard('Peers', _peerCount.toString(), Icons.people,
                  Colors.cyanAccent),
              const SizedBox(width: 10),
              _statCard('Validators', _validatorCount.toString(), Icons.shield,
                  Colors.amberAccent),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _statCard('Balance', '${_formatNum(_balance)} UAT',
                  Icons.account_balance_wallet, Colors.purpleAccent),
              const SizedBox(width: 10),
              _statCard(
                'Status',
                _isValidator ? 'VALIDATOR' : 'OBSERVER',
                _isValidator ? Icons.verified : Icons.visibility,
                _isValidator ? Colors.greenAccent : Colors.grey,
              ),
              const SizedBox(width: 10),
              _statCard('Version', _nodeVersion.isEmpty ? '—' : _nodeVersion,
                  Icons.info_outline, Colors.tealAccent),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                  color: color, fontSize: 13, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(color: Colors.grey[600], fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogViewer(NodeProcessService node) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Log header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Row(
              children: [
                Icon(Icons.terminal, color: Colors.grey[500], size: 16),
                const SizedBox(width: 8),
                Text('Node Logs',
                    style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                const Spacer(),
                GestureDetector(
                  onTap: node.clearLogs,
                  child: Text('CLEAR',
                      style: TextStyle(color: Colors.grey[600], fontSize: 10)),
                ),
              ],
            ),
          ),

          // Log content
          Expanded(
            child: node.logs.isEmpty
                ? Center(
                    child: Text(
                      'No logs yet. Start your node!',
                      style: TextStyle(color: Colors.grey[700], fontSize: 13),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    reverse: true,
                    itemCount: node.logs.length,
                    itemBuilder: (context, index) {
                      final line = node.logs[node.logs.length - 1 - index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 1),
                        child: Text(
                          line,
                          style: TextStyle(
                            color: _logColor(line),
                            fontFamily: 'monospace',
                            fontSize: 11,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Color _logColor(String line) {
    if (line.contains('✅') ||
        line.contains('SUCCESS') ||
        line.contains('HEALTHY')) {
      return Colors.greenAccent;
    }
    if (line.contains('❌') ||
        line.contains('ERROR') ||
        line.contains('FAILED')) {
      return Colors.redAccent;
    }
    if (line.contains('⚠') ||
        line.contains('WARNING') ||
        line.contains('WARN')) {
      return Colors.orangeAccent;
    }
    if (line.contains('▶') || line.contains('📍') || line.contains('💰')) {
      return Colors.cyanAccent;
    }
    return Colors.grey[500]!;
  }

  // ══════════════════════════════════════════════════════════════════
  // TAB 3: SETTINGS
  // ══════════════════════════════════════════════════════════════════

  Widget _buildSettingsTab() {
    return Consumer<NodeProcessService>(
      builder: (context, node, _) {
        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'Settings',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),

              // Node Configuration
              _settingsSection('Node Configuration', [
                _settingsTile('Node ID', node.nodeId, Icons.badge),
                _settingsTile(
                    'Binary Path', node.binaryPath ?? 'Not set', Icons.folder),
                _settingsTile('REST Port', node.restPort.toString(), Icons.api),
                _settingsTile('P2P Port', node.p2pPort.toString(), Icons.hub),
                _settingsTile(
                    'Testnet Level', node.testnetLevel, Icons.science),
              ]),

              const SizedBox(height: 16),

              // Node Identity
              _settingsSection('Node Identity', [
                _settingsTile(
                    'Address', node.nodeAddress ?? 'Not started', Icons.person),
                _settingsTile(
                    'PID', node.nodePid?.toString() ?? 'Stopped', Icons.memory),
                _settingsTile('Balance', '${_formatNum(_balance)} UAT',
                    Icons.account_balance_wallet),
                _settingsTile('Status', _isValidator ? 'VALIDATOR' : 'Observer',
                    Icons.shield),
              ]),

              const SizedBox(height: 16),

              // Network
              _settingsSection('Network', [
                _settingsTile(
                  'Bootstrap Nodes',
                  '${node.bootstrapNodes.split(",").where((s) => s.isNotEmpty).length} peers configured',
                  Icons.hub,
                ),
                _settingsTile('Tor SOCKS5', '127.0.0.1:${node.torSocksPort}',
                    Icons.security),
              ]),

              const SizedBox(height: 32),

              // Actions
              Center(
                child: Column(
                  children: [
                    // Request faucet
                    if (node.status == NodeStatus.running && _balance < 1000)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final result = await node.requestFaucet();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    result['status'] == 'success'
                                        ? 'Received ${result['amount']} UAT!'
                                        : 'Error: ${result['error'] ?? result['msg']}',
                                  ),
                                ),
                              );
                              _fetchStats();
                            }
                          },
                          icon: const Icon(Icons.water_drop),
                          label: const Text('REQUEST FAUCET'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purpleAccent,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),

                    // Re-run setup
                    OutlinedButton.icon(
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Re-run Setup?'),
                            content: const Text(
                              'This will stop your node and open the setup wizard. '
                              'Your data will not be deleted.',
                            ),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('CANCEL')),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('RE-RUN SETUP',
                                    style:
                                        TextStyle(color: Colors.orangeAccent)),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true && mounted) {
                          await node.stopNode();
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setBool('node_setup_complete', false);
                          if (mounted) {
                            Navigator.pushNamedAndRemoveUntil(
                                context, '/', (_) => false);
                          }
                        }
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('RE-RUN SETUP WIZARD'),
                      style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.orangeAccent),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _settingsSection(String title, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Text(
              title,
              style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1),
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _settingsTile(String title, String subtitle, IconData icon) {
    return ListTile(
      leading: Icon(icon, color: Colors.purpleAccent, size: 20),
      title: Text(title,
          style: const TextStyle(color: Colors.white, fontSize: 14)),
      subtitle: Text(
        subtitle,
        style: TextStyle(
            color: Colors.grey[500], fontSize: 12, fontFamily: 'monospace'),
        overflow: TextOverflow.ellipsis,
      ),
      dense: true,
      visualDensity: VisualDensity.compact,
    );
  }

  String _formatNum(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }
}
