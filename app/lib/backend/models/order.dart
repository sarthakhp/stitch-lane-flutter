import 'package:hive/hive.dart';
import 'order_status.dart';

part 'order.g.dart';

@HiveType(typeId: 1)
class Order {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String customerId;

  @HiveField(2)
  final String? title;

  @HiveField(3)
  final DateTime dueDate;

  @HiveField(4)
  final String? description;

  @HiveField(5)
  final DateTime created;

  @HiveField(6)
  final OrderStatus status;

  @HiveField(7)
  final int value;

  @HiveField(8)
  final bool isPaid;

  @HiveField(9)
  final List<String> imagePaths;

  @HiveField(10)
  final DateTime? paymentDate;

  Order({
    required this.id,
    required this.customerId,
    this.title,
    required this.dueDate,
    this.description,
    required this.created,
    this.status = OrderStatus.pending,
    this.value = 0,
    this.isPaid = false,
    this.imagePaths = const [],
    this.paymentDate,
  });

  Order copyWith({
    String? id,
    String? customerId,
    String? title,
    DateTime? dueDate,
    String? description,
    DateTime? created,
    OrderStatus? status,
    int? value,
    bool? isPaid,
    List<String>? imagePaths,
    DateTime? paymentDate,
    bool clearPaymentDate = false,
  }) {
    return Order(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      title: title ?? this.title,
      dueDate: dueDate ?? this.dueDate,
      description: description ?? this.description,
      created: created ?? this.created,
      status: status ?? this.status,
      value: value ?? this.value,
      isPaid: isPaid ?? this.isPaid,
      imagePaths: imagePaths ?? this.imagePaths,
      paymentDate: clearPaymentDate ? null : (paymentDate ?? this.paymentDate),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'customerId': customerId,
      'title': title,
      'dueDate': dueDate.toIso8601String(),
      'description': description,
      'created': created.toIso8601String(),
      'status': status.name,
      'value': value,
      'isPaid': isPaid,
      'imagePaths': imagePaths,
      'paymentDate': paymentDate?.toIso8601String(),
    };
  }

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'] as String,
      customerId: json['customerId'] as String,
      title: json['title'] as String?,
      dueDate: DateTime.parse(json['dueDate'] as String),
      description: json['description'] as String?,
      created: DateTime.parse(json['created'] as String),
      status: json['status'] != null
          ? OrderStatus.values.firstWhere(
              (e) => e.name == json['status'],
              orElse: () => OrderStatus.pending,
            )
          : OrderStatus.pending,
      value: json['value'] as int? ?? 0,
      isPaid: json['isPaid'] as bool? ?? false,
      imagePaths: json['imagePaths'] != null
          ? List<String>.from(json['imagePaths'] as List)
          : [],
      paymentDate: json['paymentDate'] != null
          ? DateTime.parse(json['paymentDate'] as String)
          : null,
    );
  }

  @override
  String toString() {
    return 'Order(id: $id, customerId: $customerId, title: $title, dueDate: $dueDate, description: $description, created: $created, status: $status, value: $value, isPaid: $isPaid, imagePaths: $imagePaths, paymentDate: $paymentDate)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Order && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

