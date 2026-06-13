// lib/models/app_version.dart
import 'package:json_annotation/json_annotation.dart';

part 'app_version.g.dart';

@JsonSerializable()
class AppVersion {
  final int id;
  @JsonKey(name: 'min_required_version')
  final String minRequiredVersion;
  @JsonKey(name: 'latest_patch_number')
  final int latestPatchNumber;
  @JsonKey(name: 'force_update_required')
  final bool forceUpdateRequired;
  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;

  const AppVersion({
    required this.id,
    required this.minRequiredVersion,
    required this.latestPatchNumber,
    this.forceUpdateRequired = false,
    required this.updatedAt,
  });

  factory AppVersion.fromJson(Map<String, dynamic> json) => _$AppVersionFromJson(json);
  Map<String, dynamic> toJson() => _$AppVersionToJson(this);
}
