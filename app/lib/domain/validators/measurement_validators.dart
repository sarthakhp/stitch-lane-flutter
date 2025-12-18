import '../../config/app_config.dart';

class MeasurementValidators {
  static String? validateDescription(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Measurement description is required';
    }

    if (value.length > AppConfig.maxDescriptionLength) {
      return 'Description must not exceed ${AppConfig.maxDescriptionLength} characters';
    }

    return null;
  }
}

