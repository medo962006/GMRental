// lib/models/room.dart
import 'package:json_annotation/json_annotation.dart';

part 'room.g.dart';

@JsonSerializable()
class Room {
  final int id;
  @JsonKey(name: 'room_number')
  final String roomNumber;
  final String status; // occupied | void | maintenance | reserved
  @JsonKey(name: 'reserved_amount')
  final double reservedAmount;
  @JsonKey(name: 'building_id')
  final int buildingId;
  final String floor; // G | F | S | T

  const Room({
    required this.id,
    required this.roomNumber,
    required this.status,
    this.reservedAmount = 0,
    this.buildingId = 1,
    this.floor = 'G',
  });

  factory Room.fromJson(Map<String, dynamic> json) => _$RoomFromJson(json);
  Map<String, dynamic> toJson() => _$RoomToJson(this);

  Room copyWith({
    int? id,
    String? roomNumber,
    String? status,
    double? reservedAmount,
    int? buildingId,
    String? floor,
  }) {
    return Room(
      id: id ?? this.id,
      roomNumber: roomNumber ?? this.roomNumber,
      status: status ?? this.status,
      reservedAmount: reservedAmount ?? this.reservedAmount,
      buildingId: buildingId ?? this.buildingId,
      floor: floor ?? this.floor,
    );
  }

  bool get isOccupied => status == 'occupied';
  bool get isVoid => status == 'void';
  bool get isMaintenance => status == 'maintenance';
  bool get isReserved => status == 'reserved';

  String get floorLabel {
    switch (floor) {
      case 'G': return 'Ground';
      case 'F': return 'First';
      case 'S': return 'Second';
      case 'T': return 'Roof';
      default: return floor;
    }
  }

  String get floorLabelAr {
    switch (floor) {
      case 'G': return 'الأرضي';
      case 'F': return 'الأول';
      case 'S': return 'الثاني';
      case 'T': return 'السطح';
      default: return floor;
    }
  }

  /// Display room number without building prefix (B1G → 1G)
  String get displayRoomNumber {
    if (roomNumber.startsWith('B') && roomNumber.length > 1) {
      return roomNumber.substring(1);
    }
    return roomNumber;
  }

  int get floorOrder {
    switch (floor) {
      case 'G': return 0;
      case 'F': return 1;
      case 'S': return 2;
      case 'T': return 3;
      default: return 9;
    }
  }
}
