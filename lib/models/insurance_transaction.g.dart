// lib/models/insurance_transaction.g.dart
part of 'insurance_transaction.dart';

InsuranceTransaction _$InsuranceTransactionFromJson(Map<String, dynamic> json) =>
    InsuranceTransaction(
      id: json['id'] as String,
      insuranceId: json['insurance_id'] as String,
      transactionType: json['transaction_type'] as String,
      amount: (json['amount'] as num).toDouble(),
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$InsuranceTransactionToJson(
        InsuranceTransaction instance) =>
    <String, dynamic>{
      'id': instance.id,
      'insurance_id': instance.insuranceId,
      'transaction_type': instance.transactionType,
      'amount': instance.amount,
      'notes': instance.notes,
      'created_at': instance.createdAt.toIso8601String(),
    };
