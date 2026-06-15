// lib/screens/tasks_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/task_routine.dart';
import '../models/room.dart';
import '../providers/app_providers.dart';

class TasksScreen extends ConsumerWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(taskRoutinesStreamProvider);
    final roomsAsync = ref.watch(roomsStreamProvider(1));
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Routines'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: tasksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (tasks) {
          final pending = tasks.where((t) => t.isPending).toList();
          final completed = tasks.where((t) => t.isCompleted).toList();

          return roomsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => _buildContent(context, ref, tasks, pending, completed, {}, isDesktop),
            data: (rooms) {
              final roomMap = {for (var r in rooms) r.id: r.roomNumber};
              return _buildContent(context, ref, tasks, pending, completed, roomMap, isDesktop);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showQuickTaskDialog(context, ref),
        icon: const Icon(Icons.add_task),
        label: const Text('Quick Task'),
      ),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, List<TaskRoutine> allTasks,
      List<TaskRoutine> pending, List<TaskRoutine> completed, Map<int, String> roomMap, bool isDesktop) {
    if (isDesktop) {
      return Row(
        children: [
          Expanded(
            child: _buildTaskPanel(
              context, ref, pending, roomMap, 'Live Queue', Colors.orange, false,
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: _buildTaskPanel(
              context, ref, completed, roomMap, 'Completed', Colors.green, true,
            ),
          ),
        ],
      );
    }

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            tabs: [
              Tab(text: 'Pending (${pending.length})'),
              Tab(text: 'Completed (${completed.length})'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildTaskPanel(context, ref, pending, roomMap, null, Colors.orange, false),
                _buildTaskPanel(context, ref, completed, roomMap, null, Colors.green, true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskPanel(BuildContext context, WidgetRef ref, List<TaskRoutine> tasks,
      Map<int, String> roomMap, String? title, Color accentColor, bool isCompleted) {
    if (tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isCompleted ? Icons.check_circle_outline : Icons.inbox_outlined, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(isCompleted ? 'No completed tasks' : 'No pending tasks', style: const TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    // Group by trigger context
    final grouped = <String, List<TaskRoutine>>{};
    for (final t in tasks) {
      grouped.putIfAbsent(t.triggerContext, () => []).add(t);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: accentColor)),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(taskRoutinesStreamProvider);
            },
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: grouped.entries.map((entry) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
                      child: Row(
                        children: [
                          _triggerBadge(entry.key),
                          const SizedBox(width: 8),
                          Text('${entry.value.length} task${entry.value.length > 1 ? 's' : ''}',
                              style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ),
                    ...entry.value.map((task) => _buildTaskCard(context, ref, task, roomMap, isCompleted)),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTaskCard(BuildContext context, WidgetRef ref, TaskRoutine task,
      Map<int, String> roomMap, bool isCompleted) {
    final roomNum = task.roomId != null ? roomMap[task.roomId] ?? '?' : '-';
    final isAuto = task.isAutoTriggered;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isAuto ? Colors.purple.shade50 : null,
      child: ListTile(
        leading: Checkbox(
          value: isCompleted,
          onChanged: isCompleted ? null : (_) async {
            await ref.read(supabaseRepositoryProvider).completeTask(task.id);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('✓ "${task.title}" completed'), duration: const Duration(seconds: 2)),
              );
            }
          },
        ),
        title: Text(
          task.title,
          style: TextStyle(
            decoration: isCompleted ? TextDecoration.lineThrough : null,
            color: isCompleted ? Colors.grey : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (task.description != null && task.description!.isNotEmpty)
              Text(task.description!, maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Row(
              children: [
                _triggerBadge(task.triggerContext),
                const SizedBox(width: 8),
                Icon(Icons.meeting_room, size: 14, color: Colors.grey),
                Text(' $roomNum', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(width: 8),
                Icon(Icons.person, size: 14, color: Colors.grey),
                Text(' ${task.assignedTo}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ],
        ),
        trailing: isCompleted && task.completedAt != null
            ? Text(_formatTime(task.completedAt!), style: const TextStyle(fontSize: 11, color: Colors.grey))
            : null,
      ),
    );
  }

  Widget _triggerBadge(String context) {
    final color = context == 'Tenant Checkout'
        ? Colors.purple
        : context == 'Daily Routine'
            ? Colors.amber.shade700
            : Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
      child: Text(context, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    );
  }

  String _formatTime(DateTime dt) {
    return '${dt.day}/${dt.month} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }

  void _showQuickTaskDialog(BuildContext context, WidgetRef ref) {
    final titleCtrl = TextEditingController();
    int? selectedRoomId;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Quick Task'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'Task Title', border: OutlineInputBorder()),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              FutureBuilder<List<Room>>(
                future: ref.read(supabaseRepositoryProvider).getRooms(),
                builder: (ctx, snap) {
                  if (!snap.hasData) return const CircularProgressIndicator();
                  return DropdownButtonFormField<int>(
                    decoration: const InputDecoration(labelText: 'Room (optional)', border: OutlineInputBorder()),
                    value: selectedRoomId,
                    items: [
                      const DropdownMenuItem(value: null, child: Text('No room')),
                      ...snap.data!.map((r) => DropdownMenuItem(value: r.id, child: Text('Room ${r.roomNumber}'))),
                    ],
                    onChanged: (v) => setDialogState(() => selectedRoomId = v),
                  );
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                if (titleCtrl.text.trim().isEmpty) return;
                await ref.read(supabaseRepositoryProvider).quickAddTask(
                  title: titleCtrl.text.trim(),
                  roomId: selectedRoomId,
                );
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }
}
