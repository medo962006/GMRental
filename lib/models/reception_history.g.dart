// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reception_history.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ReceptionHistory _$ReceptionHistoryFromJson(Map<String, dynamic> json) =>
    ReceptionHistory(
      id: json['id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String? ?? '',
      nationality: json['nationality'] as String? ?? '',
      buildingId: (json['building_id'] as num).toInt(),
      roomNumber: json['room_number'] as String? ?? '',
      moveInDate: json['move_in_date'] == null
          ? null
          : DateTime.parse(json['move_in_date'] as String),
      insuranceAmount: (json['insurance_amount'] as num?)?.toDouble() ?? 0,
      leaseDuration: json['lease_duration'] as String? ?? '',
      amountPaidUpfront: (json['amount_paid_upfront'] as num?)?.toDouble() ?? 0,
      remainingAmount: (json['remaining_amount'] as num?)?.toDouble() ?? 0,
      paymentMethod: json['payment_method'] as String? ?? '',
      leaseStatus: json['lease_status'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );

Map<String, dynamic> _$ReceptionHistoryToJson(ReceptionHistory instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'phone': instance.phone,
      'nationality': instance.nationality,
      'building_id': instance.buildingId,
      'room_number': instance.roomNumber,
      'move_in_date': instance.moveInDate?.toIso8601String(),
      'insurance_amount': instance.insuranceAmount,
      'lease_duration': instance.leaseDuration,
      'amount_paid_upfront': instance.amountPaidUpfront,
      'remaining_amount': instance.remainingAmount,
      'payment_method': instance.paymentMethod,
      'lease_status': instance.leaseStatus,
      'notes': instance.notes,
      'created_at': instance.createdAt.toIso8601String(),
      'updated_at': instance.updatedAt.toIso8601String(),
    };
