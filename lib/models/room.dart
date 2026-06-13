// lib/models/room.dart
import 'package:json_annotation/json_annotation.dart';

part 'room.g.dart';

@JsonSerializable()
class Room {
  final int id;
  @JsonKey(name: 'room_number')
  final String roomNumber;
  final String status; // occupied | void | maintenance
  @JsonKey(name: 'monthly_rent')
  final double monthlyRent;

  const Room({
    required this.id,
    required this.roomNumber,
    required this.status,
    required this.monthlyRent,
  });

  factory Room.fromJson(Map<String, dynamic> json) => _$RoomFromJson(json);
  Map<String, dynamic> toJson() => _$RoomToJson(this);

  Room copyWith({
    int? id,
    String? roomNumber,
    String? status,
    double? monthlyRent,
  }) {
    return Room(
      id: id ?? this.id,
      roomNumber: roomNumber ?? this.roomNumber,
      status: status ?? this.status,
      monthlyRent: monthlyRent ?? this.monthlyRent,
    );
  }

  bool get isOccupied => status == 'occupied';
  bool get isVoid => status == 'void';
  bool get isMaintenance => status == 'maintenance';
}
