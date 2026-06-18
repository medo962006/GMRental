// lib/models/reception_history.dart
import 'package:json_annotation/json_annotation.dart';

part 'reception_history.g.dart';

@JsonSerializable()
class ReceptionHistory {
  final String id;
  final String name;
  final String phone;
  final String nationality;
  @JsonKey(name: 'building_id')
  final int buildingId;
  @JsonKey(name: 'room_number')
  final String roomNumber;
  @JsonKey(name: 'move_in_date')
  final DateTime? moveInDate;
  @JsonKey(name: 'monthly_rent')
  final double monthlyRent;
  @JsonKey(name: 'insurance_amount')
  final double insuranceAmount;
  @JsonKey(name: 'lease_duration')
  final String leaseDuration;
  @JsonKey(name: 'amount_paid_upfront')
  final double amountPaidUpfront;
  @JsonKey(name: 'remaining_amount')
  final double remainingAmount;
  @JsonKey(name: 'payment_method')
  final String paymentMethod;
  @JsonKey(name: 'lease_status')
  final String leaseStatus;
  final String notes;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;

  const ReceptionHistory({
    required this.id,
    required this.name,
    this.phone = '',
    this.nationality = '',
    required this.buildingId,
    this.roomNumber = '',
    this.moveInDate,
    this.monthlyRent = 0,
    this.insuranceAmount = 0,
    this.leaseDuration = '',
    this.amountPaidUpfront = 0,
    this.remainingAmount = 0,
    this.paymentMethod = '',
    this.leaseStatus = '',
    this.notes = '',
    required this.createdAt,
    required this.updatedAt,
  });

  factory ReceptionHistory.fromJson(Map<String, dynamic> json) =>
      _$ReceptionHistoryFromJson(json);
  Map<String, dynamic> toJson() => _$ReceptionHistoryToJson(this);

  ReceptionHistory copyWith({
    String? id,
    String? name,
    String? phone,
    String? nationality,
    int? buildingId,
    String? roomNumber,
    DateTime? moveInDate,
    double? monthlyRent,
    double? insuranceAmount,
    String? leaseDuration,
    double? amountPaidUpfront,
    double? remainingAmount,
    String? paymentMethod,
    String? leaseStatus,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ReceptionHistory(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      nationality: nationality ?? this.nationality,
      buildingId: buildingId ?? this.buildingId,
      roomNumber: roomNumber ?? this.roomNumber,
      moveInDate: moveInDate ?? this.moveInDate,
      monthlyRent: monthlyRent ?? this.monthlyRent,
      insuranceAmount: insuranceAmount ?? this.insuranceAmount,
      leaseDuration: leaseDuration ?? this.leaseDuration,
      amountPaidUpfront: amountPaidUpfront ?? this.amountPaidUpfront,
      remainingAmount: remainingAmount ?? this.remainingAmount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      leaseStatus: leaseStatus ?? this.leaseStatus,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
