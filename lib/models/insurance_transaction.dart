// lib/models/insurance_transaction.dart
import 'package:json_annotation/json_annotation.dart';

part 'insurance_transaction.g.dart';

@JsonSerializable()
class InsuranceTransaction {
  final String id;
  @JsonKey(name: 'insurance_id')
  final String insuranceId;
  @JsonKey(name: 'transaction_type')
  final String transactionType; // payment_received | refund_paid | deduction_spend
  final double amount;
  final String? notes;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  const InsuranceTransaction({
    required this.id,
    required this.insuranceId,
    required this.transactionType,
    required this.amount,
    this.notes,
    required this.createdAt,
  });

  factory InsuranceTransaction.fromJson(Map<String, dynamic> json) =>
      _$InsuranceTransactionFromJson(json);
  Map<String, dynamic> toJson() => _$InsuranceTransactionToJson(this);

  bool get isPayment => transactionType == 'payment_received';
  bool get isRefund => transactionType == 'refund_paid';
  bool get isDeduction => transactionType == 'deduction_spend';
}
