// Validator Earnings Model - Tracks gas fee revenue

/// Type-safe int parser: handles int, double, String, null from JSON.
int _parseIntField(dynamic v, [int fallback = 0]) {
  if (v == null) return fallback;
  if (v is int) return v;
  if (v is double) return v.toInt();
  return int.tryParse(v.toString()) ?? fallback;
}

/// Type-safe double parser.
double _parseDoubleField(dynamic v, [double fallback = 0.0]) {
  if (v == null) return fallback;
  if (v is double) return v;
  if (v is int) return v.toDouble();
  return double.tryParse(v.toString()) ?? fallback;
}

class ValidatorEarnings {
  final String validatorAddress;
  final double totalEarningsLOS;
  final double last24HoursLOS;
  final double last7DaysLOS;
  final double last30DaysLOS;
  final double revenueSharePercentage;
  final int totalTransactionsProcessed;
  final List<DailyEarning> dailyHistory;

  ValidatorEarnings({
    required this.validatorAddress,
    required this.totalEarningsLOS,
    required this.last24HoursLOS,
    required this.last7DaysLOS,
    required this.last30DaysLOS,
    required this.revenueSharePercentage,
    required this.totalTransactionsProcessed,
    required this.dailyHistory,
  });

  factory ValidatorEarnings.fromJson(Map<String, dynamic> json) {
    return ValidatorEarnings(
      validatorAddress: (json['validator_address'] ?? '').toString(),
      // FIX C12-04: Type-safe numeric parsing for all fields
      totalEarningsLOS: _parseDoubleField(json['total_earnings_los']),
      last24HoursLOS: _parseDoubleField(json['last_24h_los']),
      last7DaysLOS: _parseDoubleField(json['last_7d_los']),
      last30DaysLOS: _parseDoubleField(json['last_30d_los']),
      revenueSharePercentage: _parseDoubleField(json['revenue_share_percent']),
      totalTransactionsProcessed: _parseIntField(
        json['total_transactions_processed'],
      ),
      dailyHistory: (json['daily_history'] as List<dynamic>?)
              ?.map((item) => DailyEarning.fromJson(item))
              .toList() ??
          [],
    );
  }
}

class DailyEarning {
  final DateTime date;
  final double earningsLOS;
  final int transactionsProcessed;

  DailyEarning({
    required this.date,
    required this.earningsLOS,
    required this.transactionsProcessed,
  });

  factory DailyEarning.fromJson(Map<String, dynamic> json) {
    return DailyEarning(
      date:
          DateTime.tryParse((json['date'] ?? '').toString()) ?? DateTime.now(),
      // FIX C12-04: Type-safe numeric parsing
      earningsLOS: _parseDoubleField(json['earnings_los']),
      transactionsProcessed: _parseIntField(json['transactions_processed']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'earnings_los': earningsLOS,
      'transactions_processed': transactionsProcessed,
    };
  }
}
