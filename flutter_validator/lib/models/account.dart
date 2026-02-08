import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../constants/blockchain.dart';

class Account {
  final String address;
  final int balance; // In VOID (smallest unit)
  final int voidBalance; // Staked/locked VOID
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

  /// Convert balance from VOID to UAT for display
  /// 1 UAT = 100,000,000,000 VOID (10^11)
  double get balanceUAT => BlockchainConstants.voidToUat(balance);
  double get voidBalanceUAT => BlockchainConstants.voidToUat(voidBalance);
}

class Transaction {
  final String txid;
  final String from;
  final String to;
  final int amount; // In VOID
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

  /// Convert amount from VOID to UAT for display
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
  final int stake; // In VOID
  final bool isActive;
  final double uptimePercentage;
  final int totalSlashed; // In VOID
  final String status;

  ValidatorInfo({
    required this.address,
    required this.stake,
    required this.isActive,
    this.uptimePercentage = 99.5,
    this.totalSlashed = 0,
    this.status = 'active',
  });

  factory ValidatorInfo.fromJson(Map<String, dynamic> json) {
    return ValidatorInfo(
      address: json['address'] ?? '',
      stake: json['stake'] ?? 0,
      isActive: json['is_active'] ?? false,
      uptimePercentage: (json['uptime_percentage'] ?? 99.5).toDouble(),
      totalSlashed: json['total_slashed'] ?? 0,
      status: json['status'] ?? 'active',
    );
  }

  /// Convert stake from VOID to UAT for display
  /// 1 UAT = 100,000,000,000 VOID (10^11)
  double get stakeUAT => BlockchainConstants.voidToUat(stake);

  /// Quadratic voting power: sqrt(stake in UAT)
  /// Matches backend: calculate_voting_power() in anti_whale.rs
  double get votingPower {
    final stakeInUat = stakeUAT;
    if (stakeInUat <= 0) return 0;
    return math.sqrt(stakeInUat);
  }

  /// Get voting power percentage relative to all validators
  double getVotingPowerPercentage(List<ValidatorInfo> allValidators) {
    final totalPower = allValidators.fold(0.0, (sum, v) => sum + v.votingPower);
    if (totalPower == 0) return 0;
    return (votingPower / totalPower) * 100;
  }

  /// Slashed amount in UAT for display
  double get totalSlashedUat => BlockchainConstants.voidToUat(totalSlashed);

  /// Uptime status text
  String get uptimeStatus {
    if (uptimePercentage >= 99.0) return 'Excellent';
    if (uptimePercentage >= 95.0) return 'Good';
    if (uptimePercentage >= 90.0) return 'Warning';
    return 'Critical';
  }

  /// Uptime color
  Color get uptimeColor {
    if (uptimePercentage >= 99.0) return const Color(0xFF4CAF50);
    if (uptimePercentage >= 95.0) return const Color(0xFF8BC34A);
    if (uptimePercentage >= 90.0) return const Color(0xFFFF9800);
    return const Color(0xFFF44336);
  }
}
