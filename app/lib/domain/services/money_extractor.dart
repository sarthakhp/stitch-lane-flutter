class MoneyExtractor {
  MoneyExtractor._();

  static final List<RegExp> _patterns = [
    // ₹500 or ₹ 500 or ₹1,500 or ₹1,500.50 (rupee symbol prefix)
    RegExp(r'₹\s*(\d{1,3}(?:,\d{3})*(?:\.\d+)?|\d+(?:\.\d+)?)'),

    // Rs. 500 or Rs 500 or Rs.500 (with optional comma/decimal)
    RegExp(r'Rs\.?\s*(\d{1,3}(?:,\d{3})*(?:\.\d+)?|\d+(?:\.\d+)?)', caseSensitive: false),

    // 500 ₹ or 500₹ (rupee symbol suffix)
    RegExp(r'(\d{1,3}(?:,\d{3})*(?:\.\d+)?|\d+(?:\.\d+)?)\s*₹'),

    // (950 rps) or (**950** rps) - number with rps in parentheses
    RegExp(r'\(\s*\*{0,2}(\d{1,3}(?:,\d{3})*(?:\.\d+)?|\d+(?:\.\d+)?)\*{0,2}\s*rps\s*\)', caseSensitive: false),

    // 500 rps or **500** rps (without parentheses)
    RegExp(r'\*{0,2}(\d{1,3}(?:,\d{3})*(?:\.\d+)?|\d+(?:\.\d+)?)\*{0,2}\s*rps(?!\w)', caseSensitive: false),

    // 500 ruppees or 500 rupees or 500rupees
    RegExp(r'(\d{1,3}(?:,\d{3})*(?:\.\d+)?|\d+(?:\.\d+)?)\s*rup+ees?', caseSensitive: false),
  ];

  static List<double> extractValues(String text) {
    if (text.isEmpty) return [];

    final Set<double> uniqueValues = {};
    final List<_MatchInfo> allMatches = [];

    for (final pattern in _patterns) {
      for (final match in pattern.allMatches(text)) {
        final valueStr = match.group(1);
        if (valueStr != null) {
          final cleanValue = valueStr.replaceAll(',', '');
          final value = double.tryParse(cleanValue);
          if (value != null && value > 0) {
            allMatches.add(_MatchInfo(
              value: value,
              start: match.start,
              end: match.end,
            ));
          }
        }
      }
    }

    allMatches.sort((a, b) => a.start.compareTo(b.start));

    int lastEnd = -1;
    for (final matchInfo in allMatches) {
      if (matchInfo.start >= lastEnd) {
        uniqueValues.add(matchInfo.value);
        lastEnd = matchInfo.end;
      }
    }

    return uniqueValues.toList();
  }

  static double calculateTotal(List<double> values) {
    if (values.isEmpty) return 0;
    return values.fold(0.0, (sum, value) => sum + value);
  }

  static String formatValue(double value) {
    if (value == value.truncateToDouble()) {
      return value.toInt().toString();
    }
    return value.toString();
  }

  static String formatTotal(List<double> values) {
    if (values.isEmpty) return '';
    final total = calculateTotal(values);
    final formattedValues = values.map(formatValue).join(' + ');
    return '$formattedValues = ${formatValue(total)}';
  }
}

class _MatchInfo {
  final double value;
  final int start;
  final int end;

  _MatchInfo({
    required this.value,
    required this.start,
    required this.end,
  });
}

