/// Dual-UoM parsing and formatting engine for Indian wholesale and retail trade
/// (Pharma Box/Strip, FMCG Case/Pcs, Packaging/Base conversions).
///
/// Supports rapid counter entry formats:
/// - `10.5` or `10/5` or `10+5` -> 10 main packaging units + 5 loose sub-units.
/// - `.5` or `/5` or `0.5` -> 0 main units + 5 loose sub-units.
/// - Standard fallback for single-unit or continuous items (KG, LTR, PCS).
class DualUomQuantity {
  final double mainQty;
  final double subQty;
  final double totalBaseQty;
  final double totalMainQty;
  final double conversionFactor;
  final String mainUnit;
  final String? subUnit;
  final String displayText;
  final bool isDual;

  const DualUomQuantity({
    required this.mainQty,
    required this.subQty,
    required this.totalBaseQty,
    required this.totalMainQty,
    required this.conversionFactor,
    required this.mainUnit,
    this.subUnit,
    required this.displayText,
    required this.isDual,
  });

  /// Short summary for compact chips (e.g. "10 Box 5 Strip" or "10.5 Box")
  String get shortSummary {
    if (!isDual || subUnit == null) {
      return '${_fmt(totalMainQty)} $mainUnit';
    }
    if (mainQty > 0 && subQty > 0) {
      return '${_fmt(mainQty)} $mainUnit ${_fmt(subQty)} $subUnit';
    }
    if (mainQty > 0) {
      return '${_fmt(mainQty)} $mainUnit';
    }
    return '${_fmt(subQty)} $subUnit';
  }

  static String _fmt(double val) {
    if (val == val.roundToDouble()) {
      return val.toInt().toString();
    }
    return val.toStringAsFixed(2);
  }
}

class DualUomParser {
  /// Parses trade quantity input string into a structured [DualUomQuantity].
  ///
  /// If [conversionFactor] <= 1.0 or [subUnit] is null/empty, standard decimal
  /// parsing is used (e.g. `10.5` -> 10.5 units).
  static DualUomQuantity parse(
    String input, {
    double conversionFactor = 1.0,
    String mainUnit = 'PCS',
    String? subUnit,
  }) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      return DualUomQuantity(
        mainQty: 0,
        subQty: 0,
        totalBaseQty: 0,
        totalMainQty: 0,
        conversionFactor: conversionFactor,
        mainUnit: mainUnit,
        subUnit: subUnit,
        displayText: '0 $mainUnit',
        isDual: conversionFactor > 1.0 && subUnit != null && subUnit.isNotEmpty,
      );
    }

    final hasPackaging = conversionFactor > 1.0 &&
        subUnit != null &&
        subUnit.trim().isNotEmpty &&
        subUnit.trim().toUpperCase() != mainUnit.trim().toUpperCase();

    if (!hasPackaging) {
      final val = double.tryParse(trimmed) ?? 0.0;
      return DualUomQuantity(
        mainQty: val,
        subQty: 0,
        totalBaseQty: val,
        totalMainQty: val,
        conversionFactor: 1.0,
        mainUnit: mainUnit,
        subUnit: null,
        displayText: '${_formatNum(val)} $mainUnit',
        isDual: false,
      );
    }

    double main = 0;
    double sub = 0;

    if (trimmed.contains('/') || trimmed.contains('+')) {
      final delimiter = trimmed.contains('/') ? '/' : '+';
      final parts = trimmed.split(delimiter);
      if (parts.length == 2) {
        main = double.tryParse(parts[0].trim()) ?? 0.0;
        sub = double.tryParse(parts[1].trim()) ?? 0.0;
      } else if (trimmed.startsWith(delimiter)) {
        sub = double.tryParse(trimmed.substring(1).trim()) ?? 0.0;
      }
    } else if (trimmed.contains('.')) {
      final parts = trimmed.split('.');
      if (parts.length == 2) {
        main = double.tryParse(parts[0].trim()) ?? 0.0;
        final subStr = parts[1].trim();
        sub = double.tryParse(subStr) ?? 0.0;
      } else if (trimmed.startsWith('.')) {
        sub = double.tryParse(trimmed.substring(1).trim()) ?? 0.0;
      }
    } else {
      main = double.tryParse(trimmed) ?? 0.0;
      sub = 0;
    }

    // Auto-rollover if loose quantity exceeds packaging factor (e.g. 10/15 -> 11/5 when factor=10)
    if (sub >= conversionFactor && conversionFactor > 0) {
      final extraMain = (sub / conversionFactor).floorToDouble();
      main += extraMain;
      sub -= extraMain * conversionFactor;
    }

    final totalBase = (main * conversionFactor) + sub;
    final totalMain = conversionFactor > 0 ? (totalBase / conversionFactor) : main;

    String display;
    if (main > 0 && sub > 0) {
      display = '${_formatNum(main)} $mainUnit + ${_formatNum(sub)} $subUnit (${_formatNum(totalBase)} $subUnit)';
    } else if (main > 0) {
      display = '${_formatNum(main)} $mainUnit (${_formatNum(totalBase)} $subUnit)';
    } else if (sub > 0) {
      display = '${_formatNum(sub)} $subUnit';
    } else {
      display = '0 $mainUnit';
    }

    return DualUomQuantity(
      mainQty: main,
      subQty: sub,
      totalBaseQty: totalBase,
      totalMainQty: totalMain,
      conversionFactor: conversionFactor,
      mainUnit: mainUnit,
      subUnit: subUnit,
      displayText: display,
      isDual: true,
    );
  }

  /// Formats a base quantity into a trade dual representation (e.g. `105` base qty with factor `10` -> `"10.5"` or `"10/5"`).
  static String formatInput(
    double totalBaseQty,
    double conversionFactor, {
    bool useSlash = false,
  }) {
    if (conversionFactor <= 1.0) {
      return _formatNum(totalBaseQty);
    }
    final main = (totalBaseQty / conversionFactor).floorToDouble();
    final sub = totalBaseQty - (main * conversionFactor);
    if (sub == 0) {
      return _formatNum(main);
    }
    final delim = useSlash ? '/' : '.';
    return '${_formatNum(main)}$delim${_formatNum(sub)}';
  }

  static String _formatNum(double n) {
    if (n == n.roundToDouble()) {
      return n.toInt().toString();
    }
    return n.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');
  }
}
