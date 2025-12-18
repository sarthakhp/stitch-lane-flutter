import 'package:hive/hive.dart';

part 'measurement.g.dart';

@HiveType(typeId: 4)
class Measurement {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String customerId;

  @HiveField(2)
  final String description;

  @HiveField(3)
  final DateTime created;

  @HiveField(4)
  final DateTime modified;

  Measurement({
    required this.id,
    required this.customerId,
    required this.description,
    required this.created,
    required this.modified,
  });

  Measurement copyWith({
    String? id,
    String? customerId,
    String? description,
    DateTime? created,
    DateTime? modified,
  }) {
    return Measurement(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      description: description ?? this.description,
      created: created ?? this.created,
      modified: modified ?? this.modified,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'customerId': customerId,
      'description': description,
      'created': created.toIso8601String(),
      'modified': modified.toIso8601String(),
    };
  }

  factory Measurement.fromJson(Map<String, dynamic> json) {
    return Measurement(
      id: json['id'] as String,
      customerId: json['customerId'] as String,
      description: json['description'] as String,
      created: DateTime.parse(json['created'] as String),
      modified: DateTime.parse(json['modified'] as String),
    );
  }

  @override
  String toString() {
    return 'Measurement(id: $id, customerId: $customerId, description: $description, created: $created, modified: $modified)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Measurement && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

