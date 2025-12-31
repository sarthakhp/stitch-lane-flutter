// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'order.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class OrderAdapter extends TypeAdapter<Order> {
  @override
  final int typeId = 1;

  @override
  Order read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Order(
      id: fields[0] as String,
      customerId: fields[1] as String,
      title: fields[2] as String?,
      dueDate: fields[3] as DateTime,
      description: fields[4] as String?,
      created: fields[5] as DateTime,
      status: fields[6] as OrderStatus,
      value: fields[7] as int,
      isPaid: fields[8] as bool,
      imagePaths: (fields[9] as List?)?.cast<String>() ?? [],
      paymentDate: fields[10] as DateTime?,
      payments: (fields[11] as List?)?.cast<PaymentEntry>() ?? [],
      totalPaidAmount: fields[12] as int? ?? 0,
    );
  }

  @override
  void write(BinaryWriter writer, Order obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.customerId)
      ..writeByte(2)
      ..write(obj.title)
      ..writeByte(3)
      ..write(obj.dueDate)
      ..writeByte(4)
      ..write(obj.description)
      ..writeByte(5)
      ..write(obj.created)
      ..writeByte(6)
      ..write(obj.status)
      ..writeByte(7)
      ..write(obj.value)
      ..writeByte(8)
      ..write(obj.isPaid)
      ..writeByte(9)
      ..write(obj.imagePaths)
      ..writeByte(10)
      ..write(obj.paymentDate)
      ..writeByte(11)
      ..write(obj.payments)
      ..writeByte(12)
      ..write(obj.totalPaidAmount);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OrderAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
