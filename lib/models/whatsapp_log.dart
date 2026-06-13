// lib/models/whatsapp_log.dart
import 'package:json_annotation/json_annotation.dart';

part 'whatsapp_log.g.dart';

@JsonSerializable()
class WhatsAppLog {
  final String id;
  @JsonKey(name: 'tenant_id')
  final String? tenantId;
  @JsonKey(name: 'message_type')
  final String messageType; // debt_reminder | broadcast
  @JsonKey(name: 'message_body')
  final String messageBody;
  final String status; // sent | failed
  @JsonKey(name: 'sent_at')
  final DateTime sentAt;

  const WhatsAppLog({
    required this.id,
    this.tenantId,
    required this.messageType,
    required this.messageBody,
    this.status = 'sent',
    required this.sentAt,
  });

  factory WhatsAppLog.fromJson(Map<String, dynamic> json) => _$WhatsAppLogFromJson(json);
  Map<String, dynamic> toJson() => _$WhatsAppLogToJson(this);

  bool get isDebtReminder => messageType == 'debt_reminder';
  bool get isBroadcast => messageType == 'broadcast';
  bool get isSent => status == 'sent';
  bool get isFailed => status == 'failed';

  WhatsAppLog copyWith({
    String? id,
    String? tenantId,
    String? messageType,
    String? messageBody,
    String? status,
    DateTime? sentAt,
  }) {
    return WhatsAppLog(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      messageType: messageType ?? this.messageType,
      messageBody: messageBody ?? this.messageBody,
      status: status ?? this.status,
      sentAt: sentAt ?? this.sentAt,
    );
  }
}
