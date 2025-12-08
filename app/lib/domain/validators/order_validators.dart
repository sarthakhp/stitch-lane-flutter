import '../../config/app_config.dart';

class OrderValidators {
  static String? validateTitle(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Title is required';
    }

    if (value.trim().length < AppConfig.minTitleLength) {
      return 'Title must be at least ${AppConfig.minTitleLength} characters';
    }

    if (value.length > AppConfig.maxTitleLength) {
      return 'Title must not exceed ${AppConfig.maxTitleLength} characters';
    }

    return null;
  }

  static String? validateDueDate(DateTime? value, {bool isEdit = false}) {
    if (value == null) {
      return 'Due date is required';
    }

    if (!isEdit) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final selectedDate = DateTime(value.year, value.month, value.day);

      if (selectedDate.isBefore(today)) {
        return 'Due date cannot be in the past';
      }
    }

    return null;
  }

  static String? validateDescription(String? value) {
    if (value != null && value.length > AppConfig.maxDescriptionLength) {
      return 'Description must not exceed ${AppConfig.maxDescriptionLength} characters';
    }
    return null;
  }
}

