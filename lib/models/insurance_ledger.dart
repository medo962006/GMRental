// lib/models/insurance_ledger.dart
import 'package:json_annotation/json_annotation.dart';

part 'insurance_ledger.g.dart';

@JsonSerializable()
class InsuranceLedger {
  final String id;
  @JsonKey(name: 'tenant_id')
  final String tenantId;
  @JsonKey(name: 'total_agreed_amount')
  final double totalAgreedAmount;
  @JsonKey(name: 'amount_paid_so_far')
  final double amountPaidSoFar;
  @JsonKey(name: 'remaining_balance')
  final double remainingBalance;
  @JsonKey(name: 'due_date_for_remaining')
  final DateTime? dueDateForRemaining;
  final String status; // partial | fully_paid | refunded | forfeited
  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  const InsuranceLedger({
    required this.id,
    required this.tenantId,
    required this.totalAgreedAmount,
    required this.amountPaidSoFar,
    required this.remainingBalance,
    this.dueDateForRemaining,
    this.status = 'partial',
    required this.createdAt,
  });

  factory InsuranceLedger.fromJson(Map<String, dynamic> json) =>
      _$InsuranceLedgerFromJson(json);
  Map<String, dynamic> toJson() => _$InsuranceLedgerToJson(this);

  bool get hasRemaining => remainingBalance > 0;
  bool get isOverdue {
    if (dueDateForRemaining == null) return false;
    return DateTime.now().isAfter(dueDateForRemaining!);
  }

  InsuranceLedger copyWith({
    String? id,
    String? tenantId,
    double? totalAgreedAmount,
    double? amountPaidSoFar,
    double? remainingBalance,
    DateTime? dueDateForRemaining,
    String? status,
    DateTime? createdAt,
  }) {
    return InsuranceLedger(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      totalAgreedAmount: totalAgreedAmount ?? this.totalAgreedAmount,
      amountPaidSoFar: amountPaidSoFar ?? this.amountPaidSoFar,
      remainingBalance: remainingBalance ?? this.remainingBalance,
      dueDateForRemaining: dueDateForRemaining ?? this.dueDateForRemaining,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
