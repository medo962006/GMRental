// lib/models/task_routine.g.dart
part of 'task_routine.dart';

TaskRoutine _$TaskRoutineFromJson(Map<String, dynamic> json) => TaskRoutine(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      assignedTo: json['assigned_to'] as String? ?? 'Worker',
      status: json['status'] as String? ?? 'pending',
      roomId: json['room_id'] as int?,
      triggerContext: json['trigger_context'] as String? ?? 'Manual',
      createdAt: DateTime.parse(json['created_at'] as String),
      completedAt: json['completed_at'] == null
          ? null
          : DateTime.parse(json['completed_at'] as String),
    );

Map<String, dynamic> _$TaskRoutineToJson(TaskRoutine instance) => <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'description': instance.description,
      'assigned_to': instance.assignedTo,
      'status': instance.status,
      'room_id': instance.roomId,
      'trigger_context': instance.triggerContext,
      'created_at': instance.createdAt.toIso8601String(),
      'completed_at': instance.completedAt?.toIso8601String(),
    };
