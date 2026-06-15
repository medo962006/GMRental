// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'masareef.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Masareef _$MasareefFromJson(Map<String, dynamic> json) => Masareef(
  id: json['id'] as String,
  title: json['title'] as String,
  amount: (json['amount'] as num).toDouble(),
  category: json['category'] as String? ?? 'general',
  dateIncurred: DateTime.parse(json['date_incurred'] as String),
  createdAt: DateTime.parse(json['created_at'] as String),
);

Map<String, dynamic> _$MasareefToJson(Masareef instance) => <String, dynamic>{
  'id': instance.id,
  'title': instance.title,
  'amount': instance.amount,
  'category': instance.category,
  'date_incurred': instance.dateIncurred.toIso8601String(),
  'created_at': instance.createdAt.toIso8601String(),
};
