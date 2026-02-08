/// UAT Blockchain Constants
/// Must be synchronized with backend: crates/uat-core/src/lib.rs
///
/// Backend definition:
///   pub const VOID_PER_UAT: u128 = 100_000_000_000; // 10^11
///   1 UAT = 100,000,000,000 VOID (smallest unit)
library;

class BlockchainConstants {
  BlockchainConstants._();

  /// Fixed total supply of UAT tokens
  static const int totalSupply = 21936236;

  /// VOID per UAT - the smallest unit conversion factor
  /// 1 UAT = 100,000,000,000 VOID (10^11 precision)
  /// CRITICAL: Must match backend VOID_PER_UAT exactly
  static const int voidPerUat = 100000000000; // 10^11

  /// Number of decimal places for display
  static const int decimalPlaces = 11;

  /// UAT address prefix
  static const String addressPrefix = 'UAT';

  /// Convert VOID (smallest unit) to UAT (display unit)
  static double voidToUat(int voidAmount) {
    return voidAmount / voidPerUat.toDouble();
  }

  /// Convert UAT (display unit) to VOID (smallest unit)
  static int uatToVoid(double uatAmount) {
    return (uatAmount * voidPerUat).toInt();
  }

  /// Format UAT amount for display with appropriate precision
  /// Shows up to 6 decimal places, trimming trailing zeros
  static String formatUat(double uatAmount, {int maxDecimals = 6}) {
    if (uatAmount == 0) return '0.000000';

    // Show up to maxDecimals places
    final formatted = uatAmount.toStringAsFixed(maxDecimals);

    // Trim trailing zeros but keep at least 2 decimal places
    final parts = formatted.split('.');
    if (parts.length == 2) {
      var decimals = parts[1];
      while (decimals.length > 2 && decimals.endsWith('0')) {
        decimals = decimals.substring(0, decimals.length - 1);
      }
      return '${parts[0]}.$decimals';
    }
    return formatted;
  }

  /// Format VOID amount directly for display as UAT
  static String formatVoidAsUat(int voidAmount, {int maxDecimals = 6}) {
    return formatUat(voidToUat(voidAmount), maxDecimals: maxDecimals);
  }
}
