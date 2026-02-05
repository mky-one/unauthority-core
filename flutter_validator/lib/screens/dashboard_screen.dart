import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../models/account.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

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

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() => _isLoading = true);

    try {
      final apiService = context.read<ApiService>();

      final nodeInfo = await apiService.getNodeInfo();
      final health = await apiService.getHealth();
      final validators = await apiService.getValidators();
      final blocks = await apiService.getRecentBlocks();
      final peers = await apiService.getPeers();

      setState(() {
        _nodeInfo = nodeInfo;
        _health = health;
        _validators = validators;
        _recentBlocks = blocks;
        _peers = peers;
        _error = null;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('UAT Validator Dashboard'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDashboard,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
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
                            'Address',
                            _nodeInfo?['address'] ?? 'N/A',
                          ),
                          _buildInfoRow(
                            'Version',
                            _nodeInfo?['version'] ?? 'N/A',
                          ),
                          _buildInfoRow(
                            'Network',
                            _nodeInfo?['network'] ?? 'N/A',
                          ),
                          _buildInfoRow(
                            'Block Height',
                            '${_nodeInfo?['block_height'] ?? 0}',
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
                                color: _health?['status'] == 'ok'
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
                            _health?['status']?.toUpperCase() ?? 'UNKNOWN',
                          ),
                          _buildInfoRow(
                            'Uptime',
                            '${_health?['uptime'] ?? 0}s',
                          ),
                          _buildInfoRow('Peers', '${_peers.length}'),
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
                            (v) => ListTile(
                              leading: Icon(
                                Icons.check_circle,
                                color: v.isActive ? Colors.green : Colors.grey,
                              ),
                              title: Text(
                                v.address,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontFamily: 'monospace',
                                ),
                              ),
                              subtitle: Text(
                                'Stake: ${v.stakeUAT.toStringAsFixed(6)} UAT',
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
                            ),
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
                                '${block.hash.substring(0, 16)}...',
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                ),
                              ),
                              subtitle: Text(
                                DateFormat('MMM dd, yyyy HH:mm:ss').format(
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
                              leading: const Icon(Icons.router, size: 20),
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
                ],
              ),
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
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
