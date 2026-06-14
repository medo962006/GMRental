// lib/models/admin_notification.g.dart
part of 'admin_notification.dart';

AdminNotification _$AdminNotificationFromJson(Map<String, dynamic> json) {
  final readRaw = json['is_read_by_admin'];
  List<String> readList = [];
  if (readRaw is List) {
    readList = readRaw.map((e) => e.toString()).toList();
  }
  return AdminNotification(
    id: json['id'] as String,
    title: json['title'] as String,
    body: json['body'] as String,
    category: json['category'] as String,
    isReadByAdmin: readList,
    createdAt: DateTime.parse(json['created_at'] as String),
  );
}

Map<String, dynamic> _$AdminNotificationToJson(AdminNotification instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'body': instance.body,
      'category': instance.category,
      'is_read_by_admin': instance.isReadByAdmin,
      'created_at': instance.createdAt.toIso8601String(),
    };
