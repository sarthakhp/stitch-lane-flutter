import 'package:hive/hive.dart';

part 'customer.g.dart';

@HiveType(typeId: 0)
class Customer {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String? phoneNumber;

  @HiveField(3)
  final String? description;

  @HiveField(4)
  final DateTime created;

  Customer({
    required this.id,
    required this.name,
    this.phoneNumber,
    this.description,
    required this.created,
  });

  Customer copyWith({
    String? id,
    String? name,
    String? phoneNumber,
    String? description,
    DateTime? created,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      description: description ?? this.description,
      created: created ?? this.created,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phoneNumber': phoneNumber,
      'description': description,
      'created': created.toIso8601String(),
    };
  }

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'] as String,
      name: json['name'] as String,
      phoneNumber: json['phoneNumber'] as String?,
      description: json['description'] as String?,
      created: json['created'] != null
          ? DateTime.parse(json['created'] as String)
          : DateTime.now(),
    );
  }

  @override
  String toString() {
    return 'Customer(id: $id, name: $name, phoneNumber: $phoneNumber, description: $description, created: $created)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Customer && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

