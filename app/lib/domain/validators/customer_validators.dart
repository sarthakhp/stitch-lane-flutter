import '../../config/app_config.dart';

class CustomerValidators {
  static String? validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Name is required';
    }

    if (value.trim().length < AppConfig.minNameLength) {
      return 'Name must be at least ${AppConfig.minNameLength} characters';
    }

    if (value.length > AppConfig.maxNameLength) {
      return 'Name must not exceed ${AppConfig.maxNameLength} characters';
    }

    return null;
  }

  static String? validatePhoneNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    final digitsOnly = value.replaceAll(RegExp(r'[^\d]'), '');

    if (digitsOnly.length < AppConfig.minPhoneLength) {
      return 'Phone number must be at least ${AppConfig.minPhoneLength} digits';
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

