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

  /// Parse a dynamic value (int, String, double, null) into int safely.
  static int _parseIntField(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      // Try direct int parse first, then UAT string → VOID conversion
      return int.tryParse(value) ?? BlockchainConstants.uatStringToVoid(value);
    }
    return 0;
  }

  factory Account.fromJson(Map<String, dynamic> json) {
    // FIX M-01: Use containsKey instead of != 0 so real zero balances
    // are not skipped. A zero balance from balance_voi is still valid data.
    final int parsedBalance = json.containsKey('balance_voi')
        ? _parseIntField(json['balance_voi'])
        : json.containsKey('balance_void')
            ? _parseIntField(json['balance_void'])
            : _parseIntField(json['balance']);

    return Account(
      address: json['address'] ?? '',
      balance: parsedBalance,
      voidBalance: _parseIntField(json['void_balance']),
      headBlock: json['head_block'],
      blockCount: json['block_count'] ?? 0,
      history: (json['transactions'] as List?)
              ?.map((tx) => Transaction.fromJson(tx))
              .toList() ??
          (json['history'] as List?)
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
  final int amount; // In VOID (smallest unit) for internal consistency
  final int timestamp;
  final String type;
  final String? memo;
  final String? signature;
  final int fee; // Fee in VOID

  Transaction({
    required this.txid,
    required this.from,
    required this.to,
    required this.amount,
    required this.timestamp,
    required this.type,
    this.memo,
    this.signature,
    this.fee = 0,
  });

  /// Parse amount from backend which may be:
  /// - int (from /account endpoint: UAT integer, needs ×VOID_PER_UAT)
  /// - double (rare but possible)
  /// - String like "10.00000000000" (from /history endpoint: formatted UAT)
  /// Returns value in VOID for internal consistency.
  static int _parseAmount(dynamic value) {
    if (value == null) return 0;
    if (value is int) {
      // /account endpoint returns amount as UAT integer (block.amount / VOID_PER_UAT)
      // Convert to VOID for consistent internal representation
      return value * BlockchainConstants.voidPerUat;
    }
    if (value is double) {
      return (value * BlockchainConstants.voidPerUat).toInt();
    }
    if (value is String) {
      // /history endpoint returns "10.00000000000" (formatted UAT string)
      return BlockchainConstants.uatStringToVoid(value);
    }
    return 0;
  }

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      // FIX C11-06: Backend returns "hash" not "txid" — map both
      txid: json['txid'] ?? json['hash'] ?? '',
      from: json['from'] ?? json['account'] ?? '',
      to: json['to'] ?? json['link'] ?? '',
      // FIX C11-05: Robust amount parsing for int/String/double
      amount: _parseAmount(json['amount']),
      timestamp: json['timestamp'] ?? 0,
      type: (json['type'] ?? 'transfer').toString().toLowerCase(),
      memo: json['memo'],
      signature: json['signature'],
      fee: (json['fee'] is int)
          ? json['fee']
          : (json['fee'] is String ? int.tryParse(json['fee']) ?? 0 : 0),
    );
  }

  /// Amount in UAT (1 UAT = 10^11 VOID)
  double get amountUAT => BlockchainConstants.voidToUat(amount);

  /// Fee in UAT (1 UAT = 10^11 VOID)
  double get feeUAT => BlockchainConstants.voidToUat(fee);
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
