// lib/models/tenant.g.dart
part of 'tenant.dart';

Tenant _$TenantFromJson(Map<String, dynamic> json) => Tenant(
      id: json['id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String,
      gender: json['gender'] as String?,
      roomId: json['room_id'] as int?,
      status: json['status'] as String? ?? 'active',
      insuranceAmount: (json['insurance_amount'] as num?)?.toDouble() ?? 0.0,
      insuranceReturned: json['insurance_returned'] as bool? ?? false,
      paymentStatus: json['payment_status'] as String? ?? 'unpaid',
      dueDate: json['due_date'] == null
          ? null
          : DateTime.parse(json['due_date'] as String),
      leaseStartDate: json['lease_start_date'] == null
          ? null
          : DateTime.parse(json['lease_start_date'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$TenantToJson(Tenant instance) => <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'phone': instance.phone,
      'gender': instance.gender,
      'room_id': instance.roomId,
      'status': instance.status,
      'insurance_amount': instance.insuranceAmount,
      'insurance_returned': instance.insuranceReturned,
      'payment_status': instance.paymentStatus,
      'due_date': instance.dueDate?.toIso8601String().split('T').first,
      'lease_start_date': instance.leaseStartDate?.toIso8601String().split('T').first,
      'created_at': instance.createdAt.toIso8601String(),
    };
