import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../services/network_status_service.dart';
import '../services/wallet_service.dart';
import '../models/account.dart';
import '../widgets/network_status_bar.dart';
import '../widgets/voting_power_card.dart';
import '../widgets/uptime_card.dart';

class DashboardScreen extends StatefulWidget {
  /// When embedded in NodeControlScreen's IndexedStack, hide appbar.
  final bool embedded;

  const DashboardScreen({super.key, this.embedded = false});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? _nodeInfo;
  Map<String, dynamic>? _health;
  List<ValidatorInfo> _validators = [];
  List<BlockInfo> _recentBlocks = [];
  List<String> _peers = [];
  bool _isLoading = true;
  String? _error;
  String? _myAddress;

  @override
  void initState() {
    super.initState();
    _loadMyAddress();
    _loadDashboard();
  }

  Future<void> _loadMyAddress() async {
    final walletService = context.read<WalletService>();
    final wallet = await walletService.getCurrentWallet();
    if (wallet != null && mounted) {
      setState(() => _myAddress = wallet['address']);
    }
  }

  Future<void> _loadDashboard() async {
    setState(() => _isLoading = true);

    try {
      final apiService = context.read<ApiService>();

      // FIX C12-05: Parallelize independent API calls (critical over Tor)
      final results = await Future.wait([
        apiService.getNodeInfo(),
        apiService.getHealth(),
        apiService.getValidators(),
        apiService.getRecentBlocks(),
        apiService.getPeers(),
      ]);

      if (!mounted) return;
      setState(() {
        _nodeInfo = results[0] as Map<String, dynamic>;
        _health = results[1] as Map<String, dynamic>;
        _validators = results[2] as List<ValidatorInfo>;
        _recentBlocks = results[3] as List<BlockInfo>;
        _peers = results[4] as List<String>;
        _error = null;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('UAT Validator'),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.15),
                      border: Border.all(color: Colors.orange, width: 1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'TESTNET',
                      style: TextStyle(
                        color: Colors.orange,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              centerTitle: true,
              actions: [
                // Online/Offline dot indicator
                Consumer<NetworkStatusService>(
                  builder: (context, status, _) => Tooltip(
                    message: status.statusText,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(
                        Icons.circle,
                        size: 12,
                        color: status.isConnected
                            ? Colors.green
                            : status.isConnecting
                                ? Colors.orange
                                : Colors.red,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadDashboard,
                ),
              ],
            ),
      body: Column(
        children: [
          const NetworkStatusBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline,
                                size: 64, color: Colors.red),
                            const SizedBox(height: 16),
                            Text(
                              'Error: $_error',
                              style: const TextStyle(color: Colors.red),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadDashboard,
                              child: const Text('RETRY'),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadDashboard,
                        child: ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            // Testnet Warning Banner
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.1),
                                border:
                                    Border.all(color: Colors.orange, width: 1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.science,
                                      color: Colors.orange, size: 20),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      '⚠️ TESTNET — This is a testing network. '
                                      'Tokens have no real value.',
                                      style: TextStyle(
                                        color: Colors.orange,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Node Info Card
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Row(
                                      children: [
                                        Icon(Icons.dns, size: 24),
                                        SizedBox(width: 8),
                                        Text(
                                          'Node Information',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Divider(),
                                    _buildInfoRow(
                                      'Network',
                                      _nodeInfo?['network'] ??
                                          _nodeInfo?['chain_id'] ??
                                          'N/A',
                                    ),
                                    _buildInfoRow(
                                      'Version',
                                      _nodeInfo?['version'] ?? 'N/A',
                                    ),
                                    _buildInfoRow(
                                      'Block Height',
                                      '${_nodeInfo?['block_height'] ?? 0}',
                                    ),
                                    _buildInfoRow(
                                      'Validators',
                                      '${_nodeInfo?['validator_count'] ?? 0}',
                                    ),
                                    _buildInfoRow(
                                      'Peers',
                                      '${_nodeInfo?['peer_count'] ?? 0}',
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Health Status Card
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.favorite,
                                          size: 24,
                                          color:
                                              _health?['status']?.toString() ==
                                                      'healthy'
                                                  ? Colors.green
                                                  : Colors.red,
                                        ),
                                        const SizedBox(width: 8),
                                        const Text(
                                          'Health Status',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Divider(),
                                    _buildInfoRow(
                                      'Status',
                                      _health?['status']
                                              ?.toString()
                                              .toUpperCase() ??
                                          'UNKNOWN',
                                    ),
                                    _buildInfoRow(
                                      'Uptime',
                                      _formatUptime(_health?['uptime_seconds']),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Validators Card
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Row(
                                      children: [
                                        Icon(Icons.verified_user, size: 24),
                                        SizedBox(width: 8),
                                        Text(
                                          'Active Validators',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Divider(),
                                    ..._validators.map(
                                      (v) {
                                        final isYou = _myAddress != null &&
                                            v.address == _myAddress;
                                        return ListTile(
                                          leading: Icon(
                                            isYou
                                                ? Icons.star
                                                : Icons.check_circle,
                                            color: isYou
                                                ? Colors.amberAccent
                                                : v.isActive
                                                    ? Colors.green
                                                    : Colors.grey,
                                          ),
                                          title: Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  v.address,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontFamily: 'monospace',
                                                    color: isYou
                                                        ? Colors.amberAccent
                                                        : null,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              if (isYou)
                                                Container(
                                                  margin: const EdgeInsets.only(
                                                      left: 6),
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 6,
                                                      vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: Colors.amberAccent
                                                        .withOpacity(0.2),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                    border: Border.all(
                                                        color:
                                                            Colors.amberAccent,
                                                        width: 1),
                                                  ),
                                                  child: const Text(
                                                    'YOU',
                                                    style: TextStyle(
                                                        color:
                                                            Colors.amberAccent,
                                                        fontSize: 9,
                                                        fontWeight:
                                                            FontWeight.bold),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          subtitle: Text(
                                            'Stake: ${v.stakeUAT.toStringAsFixed(0)} UAT',
                                          ),
                                          trailing: Text(
                                            v.isActive ? 'ACTIVE' : 'INACTIVE',
                                            style: TextStyle(
                                              color: v.isActive
                                                  ? Colors.green
                                                  : Colors.grey,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Recent Blocks Card
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Row(
                                      children: [
                                        Icon(Icons.view_module, size: 24),
                                        SizedBox(width: 8),
                                        Text(
                                          'Recent Blocks',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Divider(),
                                    ..._recentBlocks.map(
                                      (block) => ListTile(
                                        leading: CircleAvatar(
                                          child: Text('${block.height}'),
                                        ),
                                        title: Text(
                                          block.hash.length >= 16
                                              ? '${block.hash.substring(0, 16)}...'
                                              : block.hash,
                                          style: const TextStyle(
                                            fontFamily: 'monospace',
                                            fontSize: 12,
                                          ),
                                        ),
                                        subtitle: Text(
                                          DateFormat('MMM dd, yyyy HH:mm:ss')
                                              .format(
                                            DateTime.fromMillisecondsSinceEpoch(
                                              block.timestamp * 1000,
                                            ),
                                          ),
                                        ),
                                        trailing: Text('${block.txCount} TXs'),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Peers Card
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.connect_without_contact,
                                          size: 24,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Connected Peers (${_peers.length})',
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Divider(),
                                    ..._peers.map(
                                      (peer) => ListTile(
                                        leading:
                                            const Icon(Icons.router, size: 20),
                                        title: Text(
                                          peer,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontFamily: 'monospace',
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Voting Power Card (if validators available)
                            if (_validators.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              Builder(builder: (ctx) {
                                final myValidator = _myAddress != null
                                    ? _validators
                                        .cast<ValidatorInfo?>()
                                        .firstWhere(
                                          (v) => v!.address == _myAddress,
                                          orElse: () => null,
                                        )
                                    : null;
                                return VotingPowerCard(
                                  validatorInfo:
                                      myValidator ?? _validators.first,
                                  allValidators: _validators,
                                );
                              }),
                            ],

                            // Uptime Card (if validators available)
                            if (_validators.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              Builder(builder: (ctx) {
                                final myValidator = _myAddress != null
                                    ? _validators
                                        .cast<ValidatorInfo?>()
                                        .firstWhere(
                                          (v) => v!.address == _myAddress,
                                          orElse: () => null,
                                        )
                                    : null;
                                return UptimeCard(
                                    validatorInfo:
                                        myValidator ?? _validators.first);
                              }),
                            ],
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  /// Format uptime from Unix epoch timestamp to human-readable duration
  String _formatUptime(dynamic uptimeSeconds) {
    if (uptimeSeconds == null) return 'N/A';
    // Backend sends epoch timestamp, not actual uptime — calculate difference
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final up = uptimeSeconds is int
        ? uptimeSeconds
        : int.tryParse(uptimeSeconds.toString()) ?? 0;
    // If the value looks like an epoch timestamp (> year 2020), calculate real uptime
    final seconds = up > 1577836800 ? (now - up).abs() : up;
    if (seconds < 60) return '${seconds}s';
    if (seconds < 3600) return '${seconds ~/ 60}m ${seconds % 60}s';
    if (seconds < 86400)
      return '${seconds ~/ 3600}h ${(seconds % 3600) ~/ 60}m';
    return '${seconds ~/ 86400}d ${(seconds % 86400) ~/ 3600}h';
  }
}
