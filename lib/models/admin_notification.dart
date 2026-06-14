// lib/models/admin_notification.dart
import 'package:json_annotation/json_annotation.dart';

part 'admin_notification.g.dart';

@JsonSerializable()
class AdminNotification {
  final String id;
  final String title;
  final String body;
  final String category; // rent_due | insurance_alert | task_pending
  @JsonKey(name: 'is_read_by_admin')
  final List<String> isReadByAdmin;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  const AdminNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    this.isReadByAdmin = const [],
    required this.createdAt,
  });

  factory AdminNotification.fromJson(Map<String, dynamic> json) =>
      _$AdminNotificationFromJson(json);
  Map<String, dynamic> toJson() => _$AdminNotificationToJson(this);

  bool get isRentDue => category == 'rent_due';
  bool get isInsuranceAlert => category == 'insurance_alert';
  bool get isTaskPending => category == 'task_pending';

  bool isReadBy(String adminId) => isReadByAdmin.contains(adminId);

  AdminNotification markReadBy(String adminId) {
    if (isReadBy(adminId)) return this;
    return AdminNotification(
      id: id,
      title: title,
      body: body,
      category: category,
      isReadByAdmin: [...isReadByAdmin, adminId],
      createdAt: createdAt,
    );
  }
}
