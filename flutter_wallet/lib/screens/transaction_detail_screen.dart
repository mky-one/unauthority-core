import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/account.dart';
import '../constants/blockchain.dart';

class TransactionDetailScreen extends StatelessWidget {
  final Transaction transaction;
  final String? currentAddress;

  const TransactionDetailScreen({
    super.key,
    required this.transaction,
    this.currentAddress,
  });

  void _copyToClipboard(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isOutgoing = transaction.from == currentAddress;
    final dateTime =
        DateTime.fromMillisecondsSinceEpoch(transaction.timestamp * 1000);
    final formattedDate = DateFormat('MMM dd, yyyy').format(dateTime);
    final formattedTime = DateFormat('HH:mm:ss').format(dateTime);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction Details'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Status Card
          Card(
            color: isOutgoing
                ? Colors.red.withOpacity(0.1)
                : Colors.green.withOpacity(0.1),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(
                    isOutgoing ? Icons.arrow_upward : Icons.arrow_downward,
                    size: 64,
                    color: isOutgoing ? Colors.red : Colors.green,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isOutgoing ? 'SENT' : 'RECEIVED',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isOutgoing ? Colors.red : Colors.green,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${BlockchainConstants.formatUat(transaction.amountUAT)} UAT',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Details Card
          Card(
            child: Column(
              children: [
                _DetailRow(
                  label: 'Type',
                  value: transaction.type.toUpperCase(),
                  icon: Icons.category,
                ),
                const Divider(height: 1),
                _DetailRow(
                  label: 'Date',
                  value: formattedDate,
                  icon: Icons.calendar_today,
                ),
                const Divider(height: 1),
                _DetailRow(
                  label: 'Time',
                  value: formattedTime,
                  icon: Icons.access_time,
                ),
                const Divider(height: 1),
                _DetailRow(
                  label: 'Amount',
                  value: '${transaction.amount} VOID',
                  subtitle:
                      '${BlockchainConstants.formatUat(transaction.amountUAT)} UAT',
                  icon: Icons.attach_money,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // From Address
          Card(
            child: ListTile(
              leading: const Icon(Icons.person),
              title: const Text(
                'From',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              subtitle: Text(
                transaction.from,
                style: const TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.copy, size: 20),
                onPressed: () =>
                    _copyToClipboard(context, transaction.from, 'From address'),
              ),
            ),
          ),

          // To Address
          Card(
            child: ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text(
                'To',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              subtitle: Text(
                transaction.to,
                style: const TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.copy, size: 20),
                onPressed: () =>
                    _copyToClipboard(context, transaction.to, 'To address'),
              ),
            ),
          ),

          // Memo (if present)
          if (transaction.memo != null && transaction.memo!.isNotEmpty) ...[
            Card(
              color: Colors.blue.withOpacity(0.1),
              child: ListTile(
                leading: const Icon(Icons.note, color: Colors.blue),
                title: const Text(
                  'Memo',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                subtitle: Text(
                  transaction.memo!,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.copy, size: 20),
                  onPressed: () => _copyToClipboard(
                    context,
                    transaction.memo!,
                    'Memo',
                  ),
                ),
              ),
            ),
          ],

          // Signature
          if (transaction.signature != null) ...[
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.verified),
                title: const Text(
                  'Signature',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                subtitle: Text(
                  transaction.signature!.length > 32
                      ? '${transaction.signature!.substring(0, 32)}...'
                      : transaction.signature!,
                  style: const TextStyle(
                    fontSize: 10,
                    fontFamily: 'monospace',
                  ),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.copy, size: 20),
                  onPressed: () => _copyToClipboard(
                    context,
                    transaction.signature!,
                    'Signature',
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final String? subtitle;
  final IconData icon;

  const _DetailRow({
    required this.label,
    required this.value,
    this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, size: 24),
      title: Text(
        label,
        style: const TextStyle(fontSize: 12, color: Colors.grey),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          if (subtitle != null)
            Text(
              subtitle!,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
        ],
      ),
    );
  }
}
