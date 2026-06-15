// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'admin_notification.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AdminNotification _$AdminNotificationFromJson(Map<String, dynamic> json) =>
    AdminNotification(
      id: json['id'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      category: json['category'] as String,
      isReadByAdmin:
          (json['is_read_by_admin'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      createdAt: DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$AdminNotificationToJson(AdminNotification instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'body': instance.body,
      'category': instance.category,
      'is_read_by_admin': instance.isReadByAdmin,
      'created_at': instance.createdAt.toIso8601String(),
    };
