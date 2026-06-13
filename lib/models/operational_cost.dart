// lib/models/operational_cost.dart
import 'package:json_annotation/json_annotation.dart';

part 'operational_cost.g.dart';

@JsonSerializable()
class OperationalCost {
  final String id;
  final String title;
  final double amount;
  @JsonKey(name: 'cost_type')
  final String costType; // salary | ad_spend | subscription | other
  @JsonKey(name: 'billing_date')
  final DateTime billingDate;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  const OperationalCost({
    required this.id,
    required this.title,
    required this.amount,
    this.costType = 'other',
    required this.billingDate,
    required this.createdAt,
  });

  factory OperationalCost.fromJson(Map<String, dynamic> json) => _$OperationalCostFromJson(json);
  Map<String, dynamic> toJson() => _$OperationalCostToJson(this);

  bool get isSalary => costType == 'salary';
  bool get isAdSpend => costType == 'ad_spend';
  bool get isSubscription => costType == 'subscription';

  OperationalCost copyWith({
    String? id,
    String? title,
    double? amount,
    String? costType,
    DateTime? billingDate,
    DateTime? createdAt,
  }) {
    return OperationalCost(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      costType: costType ?? this.costType,
      billingDate: billingDate ?? this.billingDate,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
