import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/wallet_service.dart';
import '../services/api_service.dart';
import '../models/account.dart';
import '../constants/blockchain.dart';
import 'send_screen.dart';
import 'burn_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _address;
  Account? _account;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadWallet();
  }

  Future<void> _loadWallet() async {
    try {
      final walletService = context.read<WalletService>();
      final wallet = await walletService.getCurrentWallet();

      if (wallet == null) {
        setState(() => _error = 'No wallet found');
        return;
      }

      setState(() {
        _address = wallet['address'];
        _isLoading = false;
      });

      await _refreshBalance();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshBalance() async {
    if (_address == null) return;

    try {
      final apiService = context.read<ApiService>();
      final account = await apiService.getAccount(_address!);

      setState(() {
        _account = account;
        _error = null;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  Future<void> _requestFaucet() async {
    if (_address == null) return;

    setState(() => _isLoading = true);

    try {
      final apiService = context.read<ApiService>();
      final result = await apiService.requestFaucet(_address!);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['msg'] ?? 'Faucet claimed successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      await _refreshBalance();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _copyAddress() {
    if (_address != null) {
      Clipboard.setData(ClipboardData(text: _address!));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Address copied to clipboard')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('UAT Wallet'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshBalance,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Text('Error: $_error',
                      style: const TextStyle(color: Colors.red)))
              : RefreshIndicator(
                  onRefresh: _refreshBalance,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Balance Card
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            children: [
                              const Text('Total Balance',
                                  style: TextStyle(
                                      fontSize: 14, color: Colors.grey)),
                              const SizedBox(height: 8),
                              Text(
                                '${BlockchainConstants.formatUat(_account?.balanceUAT ?? 0)} UAT',
                                style: const TextStyle(
                                    fontSize: 36, fontWeight: FontWeight.bold),
                              ),
                              if (_account != null &&
                                  _account!.voidBalance > 0) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Void: ${BlockchainConstants.formatUat(_account!.voidBalanceUAT)} UAT',
                                  style: const TextStyle(
                                      fontSize: 14, color: Colors.orange),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Address Card
                      Card(
                        child: ListTile(
                          title: const Text('Your Address',
                              style:
                                  TextStyle(fontSize: 12, color: Colors.grey)),
                          subtitle: Text(
                            _address ?? 'N/A',
                            style: const TextStyle(
                                fontSize: 14, fontFamily: 'monospace'),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.copy, size: 20),
                            onPressed: _copyAddress,
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => const SendScreen()),
                                );
                                _refreshBalance();
                              },
                              icon: const Icon(Icons.send),
                              label: const Text('SEND'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.all(16),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => const BurnScreen()),
                                );
                                _refreshBalance();
                              },
                              icon: const Icon(Icons.local_fire_department),
                              label: const Text('BURN'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.all(16),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      ElevatedButton.icon(
                        onPressed: _requestFaucet,
                        icon: const Icon(Icons.water_drop),
                        label: const Text('REQUEST FAUCET (100 UAT)'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
                          padding: const EdgeInsets.all(16),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Transaction History
                      if (_account != null && _account!.history.isNotEmpty) ...[
                        const Text(
                          'Recent Transactions',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        ..._account!.history.map((tx) => Card(
                              child: ListTile(
                                leading: Icon(
                                  tx.from == _address
                                      ? Icons.arrow_upward
                                      : Icons.arrow_downward,
                                  color: tx.from == _address
                                      ? Colors.red
                                      : Colors.green,
                                ),
                                title: Text(
                                  '${BlockchainConstants.formatUat(tx.amountUAT)} UAT',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text(
                                  '${tx.from == _address ? 'To' : 'From'}: ${tx.from == _address ? tx.to : tx.from}\n'
                                  '${DateFormat('MMM dd, yyyy HH:mm').format(DateTime.fromMillisecondsSinceEpoch(tx.timestamp * 1000))}',
                                  style: const TextStyle(fontSize: 11),
                                ),
                                trailing: Text(
                                  tx.type.toUpperCase(),
                                  style: const TextStyle(
                                      fontSize: 10, color: Colors.grey),
                                ),
                              ),
                            )),
                      ],
                    ],
                  ),
                ),
    );
  }
}
