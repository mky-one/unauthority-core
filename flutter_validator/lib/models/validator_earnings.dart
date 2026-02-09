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
  final double totalEarningsUAT;
  final double last24HoursUAT;
  final double last7DaysUAT;
  final double last30DaysUAT;
  final double revenueSharePercentage;
  final int totalTransactionsProcessed;
  final List<DailyEarning> dailyHistory;

  ValidatorEarnings({
    required this.validatorAddress,
    required this.totalEarningsUAT,
    required this.last24HoursUAT,
    required this.last7DaysUAT,
    required this.last30DaysUAT,
    required this.revenueSharePercentage,
    required this.totalTransactionsProcessed,
    required this.dailyHistory,
  });

  factory ValidatorEarnings.fromJson(Map<String, dynamic> json) {
    return ValidatorEarnings(
      validatorAddress: (json['validator_address'] ?? '').toString(),
      // FIX C12-04: Type-safe numeric parsing for all fields
      totalEarningsUAT: _parseDoubleField(json['total_earnings_uat']),
      last24HoursUAT: _parseDoubleField(json['last_24h_uat']),
      last7DaysUAT: _parseDoubleField(json['last_7d_uat']),
      last30DaysUAT: _parseDoubleField(json['last_30d_uat']),
      revenueSharePercentage: _parseDoubleField(json['revenue_share_percent']),
      totalTransactionsProcessed: _parseIntField(
        json['total_transactions_processed'],
      ),
      dailyHistory:
          (json['daily_history'] as List<dynamic>?)
              ?.map((item) => DailyEarning.fromJson(item))
              .toList() ??
          [],
    );
  }

  // Mock data for testing (until backend endpoint is ready)
  factory ValidatorEarnings.mock(String address) {
    final now = DateTime.now();
    final dailyHistory = List.generate(30, (index) {
      final date = now.subtract(Duration(days: 29 - index));
      final earnings = 0.5 + (index % 7) * 0.1; // Simulate varying earnings
      return DailyEarning(
        date: date,
        earningsUAT: earnings,
        transactionsProcessed: 10 + (index % 20),
      );
    });

    return ValidatorEarnings(
      validatorAddress: address,
      totalEarningsUAT: 45.8,
      last24HoursUAT: 1.2,
      last7DaysUAT: 8.4,
      last30DaysUAT: 35.6,
      revenueSharePercentage: 2.5,
      totalTransactionsProcessed: 420,
      dailyHistory: dailyHistory,
    );
  }
}

class DailyEarning {
  final DateTime date;
  final double earningsUAT;
  final int transactionsProcessed;

  DailyEarning({
    required this.date,
    required this.earningsUAT,
    required this.transactionsProcessed,
  });

  factory DailyEarning.fromJson(Map<String, dynamic> json) {
    return DailyEarning(
      date:
          DateTime.tryParse((json['date'] ?? '').toString()) ?? DateTime.now(),
      // FIX C12-04: Type-safe numeric parsing
      earningsUAT: _parseDoubleField(json['earnings_uat']),
      transactionsProcessed: _parseIntField(json['transactions_processed']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'earnings_uat': earningsUAT,
      'transactions_processed': transactionsProcessed,
    };
  }
}
