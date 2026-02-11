import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../constants/blockchain.dart';

/// Type-safe int parser: handles int, double, String, null from JSON.
int _parseIntField(dynamic v, [int fallback = 0]) {
  if (v == null) return fallback;
  if (v is int) return v;
  if (v is double) return v.toInt();
  return int.tryParse(v.toString()) ?? fallback;
}

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
    // Backend returns balance_voi / balance_void as integer VOID,
    // and balance / balance_uat as formatted strings.
    int parsedBalance;
    if (json['balance_voi'] != null) {
      final v = json['balance_voi'];
      parsedBalance = v is int ? v : int.tryParse(v.toString()) ?? 0;
    } else if (json['balance_void'] != null) {
      final v = json['balance_void'];
      parsedBalance = v is int ? v : int.tryParse(v.toString()) ?? 0;
    } else if (json['balance'] != null) {
      final val = json['balance'];
      if (val is int) {
        parsedBalance = val;
      } else if (val is String) {
        parsedBalance = BlockchainConstants.uatStringToVoid(val);
      } else {
        parsedBalance = 0;
      }
    } else {
      parsedBalance = 0;
    }

    return Account(
      address: json['address'] ?? '',
      balance: parsedBalance,
      voidBalance: 0,
      // Backend sends "transactions", not "history"
      history:
          ((json['transactions'] ?? json['history']) as List?)
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
      txid: (json['txid'] ?? json['hash'] ?? '').toString(),
      from: (json['from'] ?? '').toString(),
      to: (json['to'] ?? json['target'] ?? '').toString(),
      // FIX C11-03: Type-safe int parsing for amount & timestamp
      amount: _parseIntField(json['amount']),
      timestamp: _parseIntField(json['timestamp']),
      type: (json['type'] ?? 'transfer').toString(),
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
      // FIX C11-05: Type-safe int parsing
      height: _parseIntField(json['height']),
      hash: (json['hash'] ?? '').toString(),
      timestamp: _parseIntField(json['timestamp']),
      // Backend sends "transactions_count"; also accept legacy "tx_count"
      txCount: _parseIntField(json['transactions_count'] ?? json['tx_count']),
    );
  }
}

class ValidatorInfo {
  final String address;
  final int stake; // In UAT (backend already divides by VOID_PER_UAT)
  final bool isActive;
  final bool isGenesis; // Genesis bootstrap validator
  final double uptimePercentage;
  final int totalSlashed; // In VOID
  final String status;

  ValidatorInfo({
    required this.address,
    required this.stake,
    required this.isActive,
    this.isGenesis = false,
    this.uptimePercentage = 99.5,
    this.totalSlashed = 0,
    this.status = 'active',
  });

  factory ValidatorInfo.fromJson(Map<String, dynamic> json) {
    // FIX C11-04: Type-safe int/double parsing for all numeric fields
    return ValidatorInfo(
      address: (json['address'] ?? '').toString(),
      stake: _parseIntField(json['stake']),
      isActive:
          json['is_active'] == true ||
          json['is_active'] == 1 ||
          (json['status'] ?? '').toString().toLowerCase() == 'active',
      isGenesis: json['is_genesis'] == true,
      uptimePercentage: _parseDouble(json['uptime_percentage'], 99.5),
      totalSlashed: _parseIntField(json['total_slashed']),
      status: (json['status'] ?? 'active').toString(),
    );
  }

  /// Type-safe double parser.
  static double _parseDouble(dynamic v, [double fallback = 0.0]) {
    if (v == null) return fallback;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString()) ?? fallback;
  }

  /// Backend already sends stake as integer UAT (balance / VOID_PER_UAT).
  /// FIX C-02: Do NOT divide again — value is already in UAT.
  double get stakeUAT => stake.toDouble();

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
