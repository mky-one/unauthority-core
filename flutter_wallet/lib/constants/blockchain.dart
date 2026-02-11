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

  /// Base transaction fee in VOID (0.001 UAT = 100,000 VOID)
  /// Must match backend base_fee
  static const int baseFeeVoid = 100000;

  /// UAT address prefix
  static const String addressPrefix = 'UAT';

  /// Convert VOID (smallest unit) to UAT (display unit)
  static double voidToUat(int voidAmount) {
    return voidAmount / voidPerUat.toDouble();
  }

  /// Convert UAT (display unit) to VOID (smallest unit)
  /// ⚠️ DEPRECATED: Uses f64 multiplication which causes off-by-1 VOID errors
  /// on common decimals (0.3, 0.6, 0.7). Use uatStringToVoid() instead.
  @Deprecated(
      'Use uatStringToVoid() for precision. f64 causes off-by-1 VOID errors.')
  static int uatToVoid(double uatAmount) {
    return (uatAmount * voidPerUat).toInt();
  }

  /// Convert UAT string to VOID using integer-only math.
  /// Avoids IEEE 754 f64 precision loss that causes off-by-1 VOID errors.
  ///
  /// Examples:
  ///   "0.3"  → 30000000000 VOID (exact)
  ///   "1.5"  → 150000000000 VOID (exact)
  ///   "100"  → 10000000000000 VOID (exact)
  static int uatStringToVoid(String uatStr) {
    final trimmed = uatStr.trim();
    if (trimmed.isEmpty) return 0;

    final parts = trimmed.split('.');
    final wholePart = int.parse(parts[0].isEmpty ? '0' : parts[0]);

    if (parts.length == 1) {
      // Integer only: "100" → 100 * voidPerUat
      return wholePart * voidPerUat;
    }

    // Has decimal: pad/truncate to 11 decimal places (10^11 = voidPerUat)
    var fracStr = parts[1];
    if (fracStr.length > decimalPlaces) {
      fracStr = fracStr.substring(0, decimalPlaces);
    } else {
      fracStr = fracStr.padRight(decimalPlaces, '0');
    }

    final fracVoid = int.parse(fracStr);
    return wholePart * voidPerUat + fracVoid;
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
