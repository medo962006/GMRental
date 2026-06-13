// lib/models/app_version.g.dart
part of 'app_version.dart';

AppVersion _$AppVersionFromJson(Map<String, dynamic> json) => AppVersion(
      id: json['id'] as int,
      minRequiredVersion: json['min_required_version'] as String,
      latestPatchNumber: json['latest_patch_number'] as int,
      forceUpdateRequired: json['force_update_required'] as bool? ?? false,
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );

Map<String, dynamic> _$AppVersionToJson(AppVersion instance) => <String, dynamic>{
      'id': instance.id,
      'min_required_version': instance.minRequiredVersion,
      'latest_patch_number': instance.latestPatchNumber,
      'force_update_required': instance.forceUpdateRequired,
      'updated_at': instance.updatedAt.toIso8601String(),
    };
