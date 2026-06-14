// lib/models/insurance_ledger.g.dart
part of 'insurance_ledger.dart';

InsuranceLedger _$InsuranceLedgerFromJson(Map<String, dynamic> json) =>
    InsuranceLedger(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      totalAgreedAmount: (json['total_agreed_amount'] as num).toDouble(),
      amountPaidSoFar: (json['amount_paid_so_far'] as num).toDouble(),
      remainingBalance: (json['remaining_balance'] as num).toDouble(),
      dueDateForRemaining: json['due_date_for_remaining'] != null
          ? DateTime.parse(json['due_date_for_remaining'] as String)
          : null,
      status: json['status'] as String? ?? 'partial',
      createdAt: DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$InsuranceLedgerToJson(InsuranceLedger instance) =>
    <String, dynamic>{
      'id': instance.id,
      'tenant_id': instance.tenantId,
      'total_agreed_amount': instance.totalAgreedAmount,
      'amount_paid_so_far': instance.amountPaidSoFar,
      'remaining_balance': instance.remainingBalance,
      'due_date_for_remaining': instance.dueDateForRemaining?.toIso8601String().split('T').first,
      'status': instance.status,
      'created_at': instance.createdAt.toIso8601String(),
    };
