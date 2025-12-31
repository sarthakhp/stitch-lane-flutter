import 'package:hive/hive.dart';

part 'payment_entry.g.dart';

@HiveType(typeId: 5)
class PaymentEntry {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final DateTime date;

  @HiveField(2)
  final int amount;

  PaymentEntry({
    required this.id,
    required this.date,
    required this.amount,
  });

  PaymentEntry copyWith({
    String? id,
    DateTime? date,
    int? amount,
  }) {
    return PaymentEntry(
      id: id ?? this.id,
      date: date ?? this.date,
      amount: amount ?? this.amount,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'amount': amount,
    };
  }

  factory PaymentEntry.fromJson(Map<String, dynamic> json) {
    return PaymentEntry(
      id: json['id'] as String,
      date: DateTime.parse(json['date'] as String),
      amount: json['amount'] as int,
    );
  }

  @override
  String toString() {
    return 'PaymentEntry(id: $id, date: $date, amount: $amount)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PaymentEntry && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

