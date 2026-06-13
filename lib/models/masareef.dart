// lib/models/masareef.dart
import 'package:json_annotation/json_annotation.dart';

part 'masareef.g.dart';

@JsonSerializable()
class Masareef {
  final String id;
  final String title;
  final double amount;
  final String category;
  @JsonKey(name: 'date_incurred')
  final DateTime dateIncurred;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  const Masareef({
    required this.id,
    required this.title,
    required this.amount,
    this.category = 'general',
    required this.dateIncurred,
    required this.createdAt,
  });

  factory Masareef.fromJson(Map<String, dynamic> json) => _$MasareefFromJson(json);
  Map<String, dynamic> toJson() => _$MasareefToJson(this);

  Masareef copyWith({
    String? id,
    String? title,
    double? amount,
    String? category,
    DateTime? dateIncurred,
    DateTime? createdAt,
  }) {
    return Masareef(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      dateIncurred: dateIncurred ?? this.dateIncurred,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
