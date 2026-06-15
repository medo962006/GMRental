// lib/models/device_code.dart
import 'package:json_annotation/json_annotation.dart';

part 'device_code.g.dart';

@JsonSerializable()
class DeviceCode {
  final String id;
  final String code;
  @JsonKey(name: 'device_name')
  final String? deviceName;
  @JsonKey(name: 'is_active')
  final bool isActive;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @JsonKey(name: 'last_seen_at')
  final DateTime lastSeenAt;

  const DeviceCode({
    required this.id,
    required this.code,
    this.deviceName,
    required this.isActive,
    required this.createdAt,
    required this.lastSeenAt,
  });

  factory DeviceCode.fromJson(Map<String, dynamic> json) =>
      _$DeviceCodeFromJson(json);
  Map<String, dynamic> toJson() => _$DeviceCodeToJson(this);
}
