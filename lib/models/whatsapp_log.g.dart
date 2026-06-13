// lib/models/whatsapp_log.g.dart
part of 'whatsapp_log.dart';

WhatsAppLog _$WhatsAppLogFromJson(Map<String, dynamic> json) => WhatsAppLog(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String?,
      messageType: json['message_type'] as String,
      messageBody: json['message_body'] as String,
      status: json['status'] as String? ?? 'sent',
      sentAt: DateTime.parse(json['sent_at'] as String),
    );

Map<String, dynamic> _$WhatsAppLogToJson(WhatsAppLog instance) => <String, dynamic>{
      'id': instance.id,
      'tenant_id': instance.tenantId,
      'message_type': instance.messageType,
      'message_body': instance.messageBody,
      'status': instance.status,
      'sent_at': instance.sentAt.toIso8601String(),
    };
