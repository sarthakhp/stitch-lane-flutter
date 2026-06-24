import '../util/audio_path_list.dart';
import 'order_status.dart';
import 'payment_entry.dart';

/// Derived payment state for an order. Computed from [Order.value] and
/// [Order.totalPaidAmount] — never stored, so it can't drift.
enum OrderPaymentStatus {
  /// No price set yet ("price not decided").
  priceNotSet,

  /// Price set, nothing paid.
  unpaid,

  /// Price set, some paid but less than the full value.
  partial,

  /// Fully paid (paid >= value, value > 0).
  paid,
}

class Order {
  final String id;

  final String customerId;

  final String? title;

  final DateTime dueDate;

  final String? description;

  final DateTime created;

  final OrderStatus status;

  /// Price in rupees. Null means "price not decided yet" (distinct from 0).
  final int? value;

  /// Denormalized cache of [isFullyPaid]. Repositories recompute it on every
  /// write, so reads stay fast and the flag never drifts from the derived rule.
  final bool isPaid;

  final List<String> imagePaths;

  final DateTime? paymentDate;

  final List<PaymentEntry> payments;

  final int totalPaidAmount;

  /// Voice dictations linked to this order, in capture order. Linked at
  /// creation (order creator) and from the order form's description mic.
  /// Empty for typed orders and all pre-feature orders.
  final List<String> audioFilePaths;

  Order({
    required this.id,
    required this.customerId,
    this.title,
    required this.dueDate,
    this.description,
    required this.created,
    this.status = OrderStatus.pending,
    this.value,
    this.isPaid = false,
    this.imagePaths = const [],
    this.paymentDate,
    this.payments = const [],
    this.totalPaidAmount = 0,
    this.audioFilePaths = const [],
  });

  /// First linked recording, for the few spots that only need one.
  String? get primaryAudioFilePath =>
      audioFilePaths.isEmpty ? null : audioFilePaths.first;

  /// True only when a real price is set and fully covered by payments.
  bool get isFullyPaid =>
      value != null && value! > 0 && totalPaidAmount >= value!;

  /// Remaining amount owed in rupees. 0 when fully paid or price not set.
  int get outstanding =>
      (value != null && value! > totalPaidAmount) ? value! - totalPaidAmount : 0;

  OrderPaymentStatus get paymentStatus {
    if (value == null) return OrderPaymentStatus.priceNotSet;
    if (isFullyPaid) return OrderPaymentStatus.paid;
    if (totalPaidAmount > 0) return OrderPaymentStatus.partial;
    return OrderPaymentStatus.unpaid;
  }

  Order copyWith({
    String? id,
    String? customerId,
    String? title,
    DateTime? dueDate,
    String? description,
    DateTime? created,
    OrderStatus? status,
    int? value,
    bool clearValue = false,
    bool? isPaid,
    List<String>? imagePaths,
    DateTime? paymentDate,
    bool clearPaymentDate = false,
    List<PaymentEntry>? payments,
    int? totalPaidAmount,
    List<String>? audioFilePaths,
  }) {
    return Order(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      title: title ?? this.title,
      dueDate: dueDate ?? this.dueDate,
      description: description ?? this.description,
      created: created ?? this.created,
      status: status ?? this.status,
      value: clearValue ? null : (value ?? this.value),
      isPaid: isPaid ?? this.isPaid,
      imagePaths: imagePaths ?? this.imagePaths,
      paymentDate: clearPaymentDate ? null : (paymentDate ?? this.paymentDate),
      payments: payments ?? this.payments,
      totalPaidAmount: totalPaidAmount ?? this.totalPaidAmount,
      audioFilePaths: audioFilePaths ?? this.audioFilePaths,
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
      'payments': payments.map((p) => p.toJson()).toList(),
      'totalPaidAmount': totalPaidAmount,
      'audioFilePaths': audioFilePaths,
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
      value: json['value'] as int?,
      isPaid: json['isPaid'] as bool? ?? false,
      imagePaths: json['imagePaths'] != null
          ? List<String>.from(json['imagePaths'] as List)
          : [],
      paymentDate: json['paymentDate'] != null
          ? DateTime.parse(json['paymentDate'] as String)
          : null,
      payments: json['payments'] != null
          ? (json['payments'] as List)
              .map((p) => PaymentEntry.fromJson(p as Map<String, dynamic>))
              .toList()
          : [],
      totalPaidAmount: json['totalPaidAmount'] as int? ?? 0,
      audioFilePaths: AudioPathList.read(
        json['audioFilePaths'],
        legacySingle: json['audioFilePath'],
      ),
    );
  }

  @override
  String toString() {
    return 'Order(id: $id, customerId: $customerId, title: $title, dueDate: $dueDate, description: $description, created: $created, status: $status, value: $value, isPaid: $isPaid, imagePaths: $imagePaths, paymentDate: $paymentDate, payments: $payments, totalPaidAmount: $totalPaidAmount)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Order && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
