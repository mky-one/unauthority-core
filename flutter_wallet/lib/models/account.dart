class Account {
  final String address;
  final int balance;
  final int voidBalance;
  final List<Transaction> history;

  Account({
    required this.address,
    required this.balance,
    required this.voidBalance,
    required this.history,
  });

  factory Account.fromJson(Map<String, dynamic> json) {
    return Account(
      address: json['address'] ?? '',
      balance: json['balance'] ?? 0,
      voidBalance: json['void_balance'] ?? 0,
      history: (json['history'] as List?)
              ?.map((tx) => Transaction.fromJson(tx))
              .toList() ??
          [],
    );
  }

  double get balanceUAT => balance / 1000000.0;
  double get voidBalanceUAT => voidBalance / 1000000.0;
}

class Transaction {
  final String txid;
  final String from;
  final String to;
  final int amount;
  final int timestamp;
  final String type;

  Transaction({
    required this.txid,
    required this.from,
    required this.to,
    required this.amount,
    required this.timestamp,
    required this.type,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      txid: json['txid'] ?? '',
      from: json['from'] ?? '',
      to: json['to'] ?? '',
      amount: json['amount'] ?? 0,
      timestamp: json['timestamp'] ?? 0,
      type: json['type'] ?? 'transfer',
    );
  }

  double get amountUAT => amount / 1000000.0;
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

  double get stakeUAT => stake / 1000000.0;
}
