/// LOS Blockchain Constants for Validator Dashboard
/// Must be synchronized with backend: crates/los-core/src/lib.rs
///
/// Backend definition:
///   pub const CIL_PER_LOS: u128 = 100_000_000_000; // 10^11
///   1 LOS = 100,000,000,000 CIL (smallest unit)
library;

class BlockchainConstants {
  BlockchainConstants._();

  /// Fixed total supply of LOS tokens
  static const int totalSupply = 21936236;

  /// CIL per LOS - the smallest unit conversion factor
  /// 1 LOS = 100,000,000,000 CIL (10^11 precision)
  /// CRITICAL: Must match backend CIL_PER_LOS exactly
  static const int cilPerLos = 100000000000; // 10^11

  /// Number of decimal places for display
  static const int decimalPlaces = 11;

  /// LOS address prefix
  static const String addressPrefix = 'LOS';

  /// Convert CIL (smallest unit) to LOS (display unit)
  static double cilToLos(int cilAmount) {
    return cilAmount / cilPerLos.toDouble();
  }

  /// Convert LOS string to CIL using integer-only math.
  /// Avoids IEEE 754 f64 precision loss that causes off-by-1 CIL errors.
  static int losStringToCil(String losStr) {
    final trimmed = losStr.trim();
    if (trimmed.isEmpty) return 0;

    final parts = trimmed.split('.');
    final wholePart = int.parse(parts[0].isEmpty ? '0' : parts[0]);

    if (parts.length == 1) {
      return wholePart * cilPerLos;
    }

    var fracStr = parts[1];
    if (fracStr.length > decimalPlaces) {
      fracStr = fracStr.substring(0, decimalPlaces);
    } else {
      fracStr = fracStr.padRight(decimalPlaces, '0');
    }

    final fracVoid = int.parse(fracStr);
    return wholePart * cilPerLos + fracVoid;
  }

  /// Format LOS amount for display with appropriate precision
  static String formatLos(double losAmount, {int maxDecimals = 6}) {
    if (losAmount == 0) return '0.000000';

    final formatted = losAmount.toStringAsFixed(maxDecimals);
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

  /// Format CIL amount directly for display as LOS
  static String formatCilAsLos(int voidAmount, {int maxDecimals = 6}) {
    return formatLos(cilToLos(voidAmount), maxDecimals: maxDecimals);
  }
}
