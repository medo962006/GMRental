// lib/models/booking.dart
// Booking model — represents a room booking/reservation.
class Booking {
  final String id;
  final String? roomId;
  final String? roomNumber;
  final int? buildingId;
  final String? tenantName;
  final String? tenantPhone;
  final String status; // pending, confirmed, cancelled, completed
  final DateTime? checkInDate;
  final DateTime? checkOutDate;
  final double? amount;
  final DateTime? createdAt;

  const Booking({
    required this.id,
    this.roomId,
    this.roomNumber,
    this.buildingId,
    this.tenantName,
    this.tenantPhone,
    this.status = 'pending',
    this.checkInDate,
    this.checkOutDate,
    this.amount,
    this.createdAt,
  });

  factory Booking.fromJson(Map<String, dynamic> json) {
    return Booking(
      id: json['id']?.toString() ?? '',
      roomId: json['room_id']?.toString(),
      roomNumber: json['room_number']?.toString(),
      buildingId: json['building_id'] as int?,
      tenantName: json['tenant_name']?.toString(),
      tenantPhone: json['tenant_phone']?.toString(),
      status: json['status']?.toString() ?? 'pending',
      checkInDate: json['check_in_date'] != null
          ? DateTime.tryParse(json['check_in_date'].toString())
          : null,
      checkOutDate: json['check_out_date'] != null
          ? DateTime.tryParse(json['check_out_date'].toString())
          : null,
      amount: (json['amount'] as num?)?.toDouble(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (roomId != null) 'room_id': roomId,
      if (roomNumber != null) 'room_number': roomNumber,
      if (buildingId != null) 'building_id': buildingId,
      if (tenantName != null) 'tenant_name': tenantName,
      if (tenantPhone != null) 'tenant_phone': tenantPhone,
      'status': status,
      if (checkInDate != null)
        'check_in_date': checkInDate!.toIso8601String().split('T').first,
      if (checkOutDate != null)
        'check_out_date': checkOutDate!.toIso8601String().split('T').first,
      if (amount != null) 'amount': amount,
    };
  }

  Booking copyWith({
    String? id,
    String? roomId,
    String? roomNumber,
    int? buildingId,
    String? tenantName,
    String? tenantPhone,
    String? status,
    DateTime? checkInDate,
    DateTime? checkOutDate,
    double? amount,
    DateTime? createdAt,
  }) {
    return Booking(
      id: id ?? this.id,
      roomId: roomId ?? this.roomId,
      roomNumber: roomNumber ?? this.roomNumber,
      buildingId: buildingId ?? this.buildingId,
      tenantName: tenantName ?? this.tenantName,
      tenantPhone: tenantPhone ?? this.tenantPhone,
      status: status ?? this.status,
      checkInDate: checkInDate ?? this.checkInDate,
      checkOutDate: checkOutDate ?? this.checkOutDate,
      amount: amount ?? this.amount,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  bool get isPending => status == 'pending';
  bool get isConfirmed => status == 'confirmed';
  bool get isCancelled => status == 'cancelled';
  bool get isCompleted => status == 'completed';
  bool get canCancel => isPending || isConfirmed;
}