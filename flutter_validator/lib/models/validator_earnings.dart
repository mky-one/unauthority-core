// Validator Earnings Model - Tracks gas fee revenue
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
      validatorAddress: json['validator_address'] ?? '',
      totalEarningsUAT: (json['total_earnings_uat'] ?? 0).toDouble(),
      last24HoursUAT: (json['last_24h_uat'] ?? 0).toDouble(),
      last7DaysUAT: (json['last_7d_uat'] ?? 0).toDouble(),
      last30DaysUAT: (json['last_30d_uat'] ?? 0).toDouble(),
      revenueSharePercentage: (json['revenue_share_percent'] ?? 0).toDouble(),
      totalTransactionsProcessed: json['total_transactions_processed'] ?? 0,
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
      date: DateTime.parse(json['date']),
      earningsUAT: (json['earnings_uat'] ?? 0).toDouble(),
      transactionsProcessed: json['transactions_processed'] ?? 0,
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
