class MoneyExtractor {
  MoneyExtractor._();

  // Regex Explanation:
  // 1. We allow optional styling characters: ( * _ [
  // 2. We capture the number: Allows digits, Indian commas (2 or 3 groups), and decimals.
  // 3. We allow optional closing styling: ) * _ ]
  static final List<RegExp> _patterns = [
    // ---------------------------------------------------------
    // PATTERN 1: Prefix Symbols (e.g., ₹500, Rs. 500, INR 500)
    // ---------------------------------------------------------
    RegExp(
      r'(?:₹|Rs\.?|INR)\s*[*_(\[]*\s*(\d{1,3}(?:,\d{2,3})*(?:\.\d+)?)\s*[*_)*\]]*',
      caseSensitive: false,
    ),

    // ---------------------------------------------------------
    // PATTERN 2: Suffix Words (e.g., 500 rps, **500** rupees, 500/-)
    // ---------------------------------------------------------
    // Looks for:
    // 1. Optional Prefix Noise: (, [, *, **
    // 2. The Number (Capturing Group 1)
    // 3. Optional Suffix Noise: ), ], *, **
    // 4. The Unit: rupees, rupee, rps, rp, /-, or just the symbol ₹ at the end
    RegExp(
      r'[*_(\[]*\s*(\d{1,3}(?:,\d{2,3})*(?:\.\d+)?)\s*[*_)*\]]*\s*(?:rupees?|rps?|rp|INR|₹|\/-)(?!\w)',
      caseSensitive: false,
    ),
  ];

  /// Extracts all rupee amounts found in the text and returns them as a List of Doubles.
  static List<double> extractValues(String text) {
    List<double> foundAmounts = [];

    for (var regex in _patterns) {
      Iterable<RegExpMatch> matches = regex.allMatches(text);

      for (var match in matches) {
        // Group 1 is always the number part in our regexes
        String? numberStr = match.group(1);

        if (numberStr != null) {
          // Clean the number (remove commas) and parse
          String cleanNumber = numberStr.replaceAll(',', '');
          double? amount = double.tryParse(cleanNumber);
          if (amount != null) {
            foundAmounts.add(amount);
          }
        }
      }
    }

    return foundAmounts;
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
