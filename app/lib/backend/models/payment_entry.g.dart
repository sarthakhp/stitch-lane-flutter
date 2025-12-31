// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'payment_entry.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PaymentEntryAdapter extends TypeAdapter<PaymentEntry> {
  @override
  final int typeId = 5;

  @override
  PaymentEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PaymentEntry(
      id: fields[0] as String,
      date: fields[1] as DateTime,
      amount: fields[2] as int,
    );
  }

  @override
  void write(BinaryWriter writer, PaymentEntry obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.date)
      ..writeByte(2)
      ..write(obj.amount);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaymentEntryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
