// lib/models/changelog_entry.dart
import 'package:json_annotation/json_annotation.dart';

part 'changelog_entry.g.dart';

@JsonSerializable()
class ChangelogEntry {
  final String id;
  @JsonKey(name: 'device_code')
  final String deviceCode;
  @JsonKey(name: 'admin_name')
  final String? adminName;
  final String action;
  @JsonKey(name: 'entity_type')
  final String entityType;
  @JsonKey(name: 'entity_id')
  final String? entityId;
  @JsonKey(name: 'entity_name')
  final String? entityName;
  @JsonKey(name: 'old_value')
  final Map<String, dynamic>? oldValue;
  @JsonKey(name: 'new_value')
  final Map<String, dynamic>? newValue;
  final String? details;
  @JsonKey(name: 'building_id')
  final int buildingId;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  const ChangelogEntry({
    required this.id,
    required this.deviceCode,
    this.adminName,
    required this.action,
    required this.entityType,
    this.entityId,
    this.entityName,
    this.oldValue,
    this.newValue,
    this.details,
    this.buildingId = 1,
    required this.createdAt,
  });

  factory ChangelogEntry.fromJson(Map<String, dynamic> json) =>
      _$ChangelogEntryFromJson(json);
  Map<String, dynamic> toJson() => _$ChangelogEntryToJson(this);

  String get buildingLabel => buildingId == 1 ? 'Gawy' : 'Baraka';

  String get actionLabel {
    switch (action) {
      case 'create': return 'Created';
      case 'update': return 'Updated';
      case 'delete': return 'Deleted';
      case 'archive': return 'Archived';
      case 'restore': return 'Restored';
      case 'mark_paid': return 'Marked Paid';
      case 'setup': return 'Setup';
      default: return action;
    }
  }

  String get entityTypeLabel {
    switch (entityType) {
      case 'tenant': return 'Tenant';
      case 'room': return 'Room';
      case 'system': return 'System';
      default: return entityType;
    }
  }

  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }
}
