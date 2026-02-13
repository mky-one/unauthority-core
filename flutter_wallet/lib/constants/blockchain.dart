/// LOS Blockchain Constants
/// Must be synchronized with backend: crates/los-core/src/lib.rs
///
/// Backend definition:
///   pub const CIL_PER_LOS: u128 = 100_000_000_000; // 10^11
///   1 LOS = 100,000,000,000 CIL (smallest unit)
library;

class BlockchainConstants {
  BlockchainConstants._();

  /// Wallet version — synced with pubspec.yaml
  static const String version = '1.0.9';

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

  /// Address version byte (0x4A = 74 = 'LOS' identifier)
  /// Used in address derivation: BLAKE2b → version+hash → checksum → Base58
  static const int addressVersionByte = 0x4A;

  /// Convert CIL (smallest unit) to LOS (display unit)
  static double cilToLos(int cilAmount) {
    return cilAmount / cilPerLos.toDouble();
  }

  /// Convert LOS string to CIL using integer-only math.
  /// Avoids IEEE 754 f64 precision loss that causes off-by-1 CIL errors.
  ///
  /// Examples:
  ///   "0.3"  → 30000000000 CIL (exact)
  ///   "1.5"  → 150000000000 CIL (exact)
  ///   "100"  → 10000000000000 CIL (exact)
  static int losStringToCil(String losStr) {
    final trimmed = losStr.trim();
    if (trimmed.isEmpty) return 0;

    final parts = trimmed.split('.');
    final wholePart = int.parse(parts[0].isEmpty ? '0' : parts[0]);

    if (parts.length == 1) {
      // Integer only: "100" → 100 * cilPerLos
      return wholePart * cilPerLos;
    }

    // Has decimal: pad/truncate to 11 decimal places (10^11 = cilPerLos)
    var fracStr = parts[1];
    if (fracStr.length > decimalPlaces) {
      fracStr = fracStr.substring(0, decimalPlaces);
    } else {
      fracStr = fracStr.padRight(decimalPlaces, '0');
    }

    final fracCil = int.parse(fracStr);
    return wholePart * cilPerLos + fracCil;
  }

  /// Format LOS amount for display with appropriate precision
  /// Shows up to 6 decimal places, trimming trailing zeros
  static String formatLos(double losAmount, {int maxDecimals = 6}) {
    if (losAmount == 0) return '0.000000';

    // Show up to maxDecimals places
    final formatted = losAmount.toStringAsFixed(maxDecimals);

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

  /// Format CIL amount directly for display as LOS
  static String formatCilAsLos(int cilAmount, {int maxDecimals = 6}) {
    return formatLos(cilToLos(cilAmount), maxDecimals: maxDecimals);
  }
}
