import 'package:hive/hive.dart';

part 'app_settings.g.dart';

@HiveType(typeId: 3)
class AppSettings {
  @HiveField(0)
  final int dueDateWarningThreshold;

  AppSettings({
    this.dueDateWarningThreshold = 3,
  });

  AppSettings copyWith({
    int? dueDateWarningThreshold,
  }) {
    return AppSettings(
      dueDateWarningThreshold: dueDateWarningThreshold ?? this.dueDateWarningThreshold,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'dueDateWarningThreshold': dueDateWarningThreshold,
    };
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      dueDateWarningThreshold: json['dueDateWarningThreshold'] as int? ?? 3,
    );
  }

  @override
  String toString() {
    return 'AppSettings(dueDateWarningThreshold: $dueDateWarningThreshold)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppSettings && 
           other.dueDateWarningThreshold == dueDateWarningThreshold;
  }

  @override
  int get hashCode => dueDateWarningThreshold.hashCode;
}

