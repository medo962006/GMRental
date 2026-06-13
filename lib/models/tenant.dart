// lib/models/tenant.dart
import 'package:json_annotation/json_annotation.dart';

part 'tenant.g.dart';

@JsonSerializable()
class Tenant {
  final String id;
  final String name;
  final String phone;
  final String? gender; // male | female
  @JsonKey(name: 'room_id')
  final int? roomId;
  final String status; // active | archived
  @JsonKey(name: 'insurance_amount')
  final double insuranceAmount;
  @JsonKey(name: 'insurance_returned')
  final bool insuranceReturned;
  @JsonKey(name: 'payment_status')
  final String paymentStatus; // paid | unpaid
  @JsonKey(name: 'due_date')
  final DateTime? dueDate;
  @JsonKey(name: 'lease_start_date')
  final DateTime? leaseStartDate;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  const Tenant({
    required this.id,
    required this.name,
    required this.phone,
    this.gender,
    this.roomId,
    this.status = 'active',
    this.insuranceAmount = 0.0,
    this.insuranceReturned = false,
    this.paymentStatus = 'unpaid',
    this.dueDate,
    this.leaseStartDate,
    required this.createdAt,
  });

  factory Tenant.fromJson(Map<String, dynamic> json) => _$TenantFromJson(json);
  Map<String, dynamic> toJson() => _$TenantToJson(this);

  Tenant copyWith({
    String? id,
    String? name,
    String? phone,
    String? gender,
    int? roomId,
    String? status,
    double? insuranceAmount,
    bool? insuranceReturned,
    String? paymentStatus,
    DateTime? dueDate,
    DateTime? leaseStartDate,
    DateTime? createdAt,
  }) {
    return Tenant(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      gender: gender ?? this.gender,
      roomId: roomId ?? this.roomId,
      status: status ?? this.status,
      insuranceAmount: insuranceAmount ?? this.insuranceAmount,
      insuranceReturned: insuranceReturned ?? this.insuranceReturned,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      dueDate: dueDate ?? this.dueDate,
      leaseStartDate: leaseStartDate ?? this.leaseStartDate,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  bool get isActive => status == 'active';
  bool get isPaid => paymentStatus == 'paid';
  bool get isUnpaid => paymentStatus == 'unpaid';

  bool get isOverdue {
    if (dueDate == null || isPaid) return false;
    return DateTime.now().isAfter(dueDate!);
  }
}
