// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'room.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Room _$RoomFromJson(Map<String, dynamic> json) => Room(
      id: json['id'] as int,
      roomNumber: json['room_number'] as String,
      status: json['status'] as String? ?? 'void',
      monthlyRent: (json['monthly_rent'] as num).toDouble(),
    );

Map<String, dynamic> _$RoomToJson(Room instance) => <String, dynamic>{
      'id': instance.id,
      'room_number': instance.roomNumber,
      'status': instance.status,
      'monthly_rent': instance.monthlyRent,
    };
