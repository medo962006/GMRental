// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'changelog_entry.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ChangelogEntry _$ChangelogEntryFromJson(Map<String, dynamic> json) =>
    ChangelogEntry(
      id: json['id'] as String,
      deviceCode: json['device_code'] as String,
      adminName: json['admin_name'] as String?,
      action: json['action'] as String,
      entityType: json['entity_type'] as String,
      entityId: json['entity_id'] as String?,
      entityName: json['entity_name'] as String?,
      oldValue: json['old_value'] as Map<String, dynamic>?,
      newValue: json['new_value'] as Map<String, dynamic>?,
      details: json['details'] as String?,
      buildingId: (json['building_id'] as num?)?.toInt() ?? 1,
      createdAt: DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$ChangelogEntryToJson(ChangelogEntry instance) =>
    <String, dynamic>{
      'id': instance.id,
      'device_code': instance.deviceCode,
      'admin_name': instance.adminName,
      'action': instance.action,
      'entity_type': instance.entityType,
      'entity_id': instance.entityId,
      'entity_name': instance.entityName,
      'old_value': instance.oldValue,
      'new_value': instance.newValue,
      'details': instance.details,
      'building_id': instance.buildingId,
      'created_at': instance.createdAt.toIso8601String(),
    };
