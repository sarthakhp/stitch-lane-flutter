class SettingsValidators {
  static const int minDueDateWarningThreshold = 1;
  static const int maxDueDateWarningThreshold = 30;

  static String? validateDueDateWarningThreshold(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a number of days';
    }

    final threshold = int.tryParse(value);
    if (threshold == null) {
      return 'Please enter a valid number';
    }

    if (threshold < minDueDateWarningThreshold) {
      return 'Minimum value is $minDueDateWarningThreshold day';
    }

    if (threshold > maxDueDateWarningThreshold) {
      return 'Maximum value is $maxDueDateWarningThreshold days';
    }

    return null;
  }
}

