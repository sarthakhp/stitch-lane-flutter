// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_settings.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AppSettingsAdapter extends TypeAdapter<AppSettings> {
  @override
  final int typeId = 3;

  @override
  AppSettings read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AppSettings(
      dueDateWarningThreshold: fields[0] as int,
      pendingOrdersReminderEnabledRaw: fields[1] as bool?,
      pendingOrdersReminderTimeRaw: fields[2] as String?,
      autoBackupEnabledRaw: fields[3] as bool?,
      autoBackupTimeRaw: fields[4] as String?,
      lastBackupTime: fields[5] as DateTime?,
      debugLogsEnabledRaw: fields[6] as bool?,
      aiChatModelRaw: fields[7] as String?,
      aiVoiceModelRaw: fields[8] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, AppSettings obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.dueDateWarningThreshold)
      ..writeByte(1)
      ..write(obj.pendingOrdersReminderEnabledRaw)
      ..writeByte(2)
      ..write(obj.pendingOrdersReminderTimeRaw)
      ..writeByte(3)
      ..write(obj.autoBackupEnabledRaw)
      ..writeByte(4)
      ..write(obj.autoBackupTimeRaw)
      ..writeByte(5)
      ..write(obj.lastBackupTime)
      ..writeByte(6)
      ..write(obj.debugLogsEnabledRaw)
      ..writeByte(7)
      ..write(obj.aiChatModelRaw)
      ..writeByte(8)
      ..write(obj.aiVoiceModelRaw);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppSettingsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
