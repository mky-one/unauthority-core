import '../constants/blockchain.dart';

class Account {
  final String address;
  final int balance; // In VOID (smallest unit)
  final int voidBalance; // Staked/locked VOID
  final List<Transaction> history;
  final String? headBlock; // Latest block hash (frontier) — from /account/:addr
  final int blockCount; // Number of blocks in this account's chain

  Account({
    required this.address,
    required this.balance,
    required this.voidBalance,
    required this.history,
    this.headBlock,
    this.blockCount = 0,
  });

  factory Account.fromJson(Map<String, dynamic> json) {
    return Account(
      address: json['address'] ?? '',
      // VOID integer: try balance_voi (from /account), balance_void (from /bal)
      balance: json['balance_voi'] ?? json['balance_void'] ?? json['balance'] ?? 0,
      voidBalance: json['void_balance'] ?? json['balance_voi'] ?? 0,
      headBlock: json['head_block'],
      blockCount: json['block_count'] ?? 0,
      history: (json['history'] as List?)
              ?.map((tx) => Transaction.fromJson(tx))
              .toList() ??
          (json['transactions'] as List?)
              ?.map((tx) => Transaction.fromJson(tx))
              .toList() ??
          [],
    );
  }

  /// Balance in UAT (1 UAT = 10^11 VOID)
  double get balanceUAT => BlockchainConstants.voidToUat(balance);

  /// Void balance in UAT
  double get voidBalanceUAT => BlockchainConstants.voidToUat(voidBalance);
}

class Transaction {
  final String txid;
  final String from;
  final String to;
  final int amount;
  final int timestamp;
  final String type;
  final String? memo;
  final String? signature;

  Transaction({
    required this.txid,
    required this.from,
    required this.to,
    required this.amount,
    required this.timestamp,
    required this.type,
    this.memo,
    this.signature,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      txid: json['txid'] ?? '',
      from: json['from'] ?? '',
      to: json['to'] ?? '',
      amount: json['amount'] ?? 0,
      timestamp: json['timestamp'] ?? 0,
      type: json['type'] ?? 'transfer',
      memo: json['memo'],
      signature: json['signature'],
    );
  }

  /// Amount in UAT (1 UAT = 10^11 VOID)
  double get amountUAT => BlockchainConstants.voidToUat(amount);
}

class BlockInfo {
  final int height;
  final String hash;
  final int timestamp;
  final int txCount;

  BlockInfo({
    required this.height,
    required this.hash,
    required this.timestamp,
    required this.txCount,
  });

  factory BlockInfo.fromJson(Map<String, dynamic> json) {
    return BlockInfo(
      height: json['height'] ?? 0,
      hash: json['hash'] ?? '',
      timestamp: json['timestamp'] ?? 0,
      txCount: json['tx_count'] ?? 0,
    );
  }
}

class ValidatorInfo {
  final String address;
  final int stake;
  final bool isActive;

  ValidatorInfo({
    required this.address,
    required this.stake,
    required this.isActive,
  });

  factory ValidatorInfo.fromJson(Map<String, dynamic> json) {
    return ValidatorInfo(
      address: json['address'] ?? '',
      stake: json['stake'] ?? 0,
      isActive: json['is_active'] ?? false,
    );
  }

  /// Stake in UAT — backend already sends stake as UAT integer
  double get stakeUAT => stake.toDouble();
}
