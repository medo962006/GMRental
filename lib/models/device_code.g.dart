// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_code.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DeviceCode _$DeviceCodeFromJson(Map<String, dynamic> json) => DeviceCode(
  id: json['id'] as String,
  code: json['code'] as String,
  deviceName: json['device_name'] as String?,
  isActive: json['is_active'] as bool,
  createdAt: DateTime.parse(json['created_at'] as String),
  lastSeenAt: DateTime.parse(json['last_seen_at'] as String),
);

Map<String, dynamic> _$DeviceCodeToJson(DeviceCode instance) =>
    <String, dynamic>{
      'id': instance.id,
      'code': instance.code,
      'device_name': instance.deviceName,
      'is_active': instance.isActive,
      'created_at': instance.createdAt.toIso8601String(),
      'last_seen_at': instance.lastSeenAt.toIso8601String(),
    };
