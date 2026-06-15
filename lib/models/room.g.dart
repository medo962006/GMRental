// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'room.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Room _$RoomFromJson(Map<String, dynamic> json) => Room(
  id: (json['id'] as num).toInt(),
  roomNumber: json['room_number'] as String,
  status: json['status'] as String,
  monthlyRent: (json['monthly_rent'] as num).toDouble(),
  buildingId: (json['building_id'] as num?)?.toInt() ?? 1,
  floor: json['floor'] as String? ?? 'G',
);

Map<String, dynamic> _$RoomToJson(Room instance) => <String, dynamic>{
  'id': instance.id,
  'room_number': instance.roomNumber,
  'status': instance.status,
  'monthly_rent': instance.monthlyRent,
  'building_id': instance.buildingId,
  'floor': instance.floor,
};
