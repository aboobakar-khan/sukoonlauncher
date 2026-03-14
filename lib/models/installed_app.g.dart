// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'installed_app.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class InstalledAppAdapter extends TypeAdapter<InstalledApp> {
  @override
  final int typeId = 9;

  @override
  InstalledApp read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return InstalledApp(
      packageName: fields[0] as String,
      appName: fields[1] as String,
      lastUpdated: fields[2] as DateTime?,
      customName: fields[3] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, InstalledApp obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.packageName)
      ..writeByte(1)
      ..write(obj.appName)
      ..writeByte(2)
      ..write(obj.lastUpdated)
      ..writeByte(3)
      ..write(obj.customName);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InstalledAppAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
