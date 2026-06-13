// lib/models/task_routine.dart
import 'package:json_annotation/json_annotation.dart';

part 'task_routine.g.dart';

@JsonSerializable()
class TaskRoutine {
  final String id;
  final String title;
  final String? description;
  @JsonKey(name: 'assigned_to')
  final String assignedTo;
  final String status; // pending | completed
  @JsonKey(name: 'room_id')
  final int? roomId;
  @JsonKey(name: 'trigger_context')
  final String triggerContext;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @JsonKey(name: 'completed_at')
  final DateTime? completedAt;

  const TaskRoutine({
    required this.id,
    required this.title,
    this.description,
    this.assignedTo = 'Worker',
    this.status = 'pending',
    this.roomId,
    this.triggerContext = 'Manual',
    required this.createdAt,
    this.completedAt,
  });

  factory TaskRoutine.fromJson(Map<String, dynamic> json) => _$TaskRoutineFromJson(json);
  Map<String, dynamic> toJson() => _$TaskRoutineToJson(this);

  bool get isPending => status == 'pending';
  bool get isCompleted => status == 'completed';
  bool get isAutoTriggered => triggerContext == 'Tenant Checkout';

  TaskRoutine copyWith({
    String? id,
    String? title,
    String? description,
    String? assignedTo,
    String? status,
    int? roomId,
    String? triggerContext,
    DateTime? createdAt,
    DateTime? completedAt,
  }) {
    return TaskRoutine(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      assignedTo: assignedTo ?? this.assignedTo,
      status: status ?? this.status,
      roomId: roomId ?? this.roomId,
      triggerContext: triggerContext ?? this.triggerContext,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}
