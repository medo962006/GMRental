// lib/screens/rooms_screen.dart
// CRUD screen for managing hostel rooms.
// Responsive: desktop shows DataTable, mobile shows card list.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../models/room.dart';
import '../providers/app_providers.dart';

class RoomsScreen extends ConsumerWidget {
  const RoomsScreen({super.key});

  static const double _desktopBreakpoint = 900.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomsAsync = ref.watch(roomsStreamProvider);
    final isDesktop = MediaQuery.of(context).size.width > _desktopBreakpoint;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rooms'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(roomsStreamProvider);
        },
        child: roomsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                const SizedBox(height: 16),
                Text('Error loading rooms',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text('$err', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(roomsStreamProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
          data: (rooms) {
            if (rooms.isEmpty) {
              return _buildEmptyState(context);
            }
            if (isDesktop) {
              return _buildDesktopTable(context, ref, rooms);
            }
            return _buildMobileList(context, ref, rooms);
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add Room'),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // EMPTY STATE
  // ══════════════════════════════════════════════════════

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.meeting_room_outlined,
              size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No rooms yet',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the + button to add your first room.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[500],
                ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // DESKTOP TABLE
  // ══════════════════════════════════════════════════════

  Widget _buildDesktopTable(
      BuildContext context, WidgetRef ref, List<Room> rooms) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Room #')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Monthly Rent')),
              DataColumn(label: Text('Actions')),
            ],
            rows: rooms.map((room) {
              return DataRow(
                cells: [
                  DataCell(Text(
                    room.roomNumber,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  )),
                  DataCell(_buildStatusBadge(room.status)),
                  DataCell(Text(
                    '${_formatCurrency(room.monthlyRent)} ${AppConfig.currency}',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  )),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, size: 20),
                          tooltip: 'Edit',
                          onPressed: () =>
                              _showAddEditDialog(context, ref, room: room),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete,
                              size: 20, color: Colors.red),
                          tooltip: 'Delete',
                          onPressed: () =>
                              _confirmDelete(context, ref, room),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // MOBILE CARD LIST
  // ══════════════════════════════════════════════════════

  Widget _buildMobileList(
      BuildContext context, WidgetRef ref, List<Room> rooms) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: rooms.length,
      itemBuilder: (context, index) {
        final room = rooms[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.meeting_room,
                        color: _getStatusColor(room.status)),
                    const SizedBox(width: 8),
                    Text(
                      'Room ${room.roomNumber}',
                      style:
                          Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                    ),
                    const Spacer(),
                    _buildStatusBadge(room.status),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.attach_money,
                        size: 18, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      '${_formatCurrency(room.monthlyRent)} ${AppConfig.currency}/month',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () =>
                          _showAddEditDialog(context, ref, room: room),
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('Edit'),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () => _confirmDelete(context, ref, room),
                      icon: const Icon(Icons.delete,
                          size: 18, color: Colors.red),
                      label: const Text('Delete',
                          style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════
  // STATUS BADGE
  // ══════════════════════════════════════════════════════

  Widget _buildStatusBadge(String status) {
    final color = _getStatusColor(status);
    final label = status[0].toUpperCase() + status.substring(1);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'occupied':
        return Colors.green;
      case 'void':
        return Colors.grey;
      case 'maintenance':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }

  // ══════════════════════════════════════════════════════
  // ADD / EDIT DIALOG
  // ══════════════════════════════════════════════════════

  void _showAddEditDialog(BuildContext context, WidgetRef ref,
      {Room? room}) {
    showDialog(
      context: context,
      builder: (ctx) => _RoomFormDialog(
        room: room,
        onSave: (Room savedRoom) async {
          final repo = ref.read(supabaseRepositoryProvider);
          try {
            if (room == null) {
              await repo.addRoom(savedRoom);
            } else {
              await repo.updateRoom(savedRoom);
            }
            if (ctx.mounted) {
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(room == null
                      ? 'Room ${savedRoom.roomNumber} added'
                      : 'Room ${savedRoom.roomNumber} updated'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          } catch (e) {
            if (ctx.mounted) {
              ScaffoldMessenger.of(ctx).showSnackBar(
                SnackBar(
                  content: Text('Error: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        },
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // DELETE CONFIRMATION
  // ══════════════════════════════════════════════════════

  void _confirmDelete(BuildContext context, WidgetRef ref, Room room) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Room'),
        content: Text(
            'Are you sure you want to delete Room ${room.roomNumber}? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final repo = ref.read(supabaseRepositoryProvider);
              try {
                await repo.deleteRoom(room.id);
                if (ctx.mounted) Navigator.of(ctx).pop();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Room ${room.roomNumber} deleted'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text('Error deleting room: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // HELPERS
  // ══════════════════════════════════════════════════════

  String _formatCurrency(double amount) {
    if (amount == amount.roundToDouble()) {
      return amount.toInt().toString();
    }
    return amount.toStringAsFixed(2);
  }
}

// ══════════════════════════════════════════════════════
// ROOM FORM DIALOG (StatefulWidget)
// ══════════════════════════════════════════════════════

class _RoomFormDialog extends StatefulWidget {
  final Room? room;
  final Function(Room) onSave;

  const _RoomFormDialog({this.room, required this.onSave});

  @override
  State<_RoomFormDialog> createState() => _RoomFormDialogState();
}

class _RoomFormDialogState extends State<_RoomFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _roomNumberController;
  late final TextEditingController _rentController;
  String _selectedStatus = 'void';

  static const List<String> _statuses = ['void', 'occupied', 'maintenance'];

  @override
  void initState() {
    super.initState();
    _roomNumberController =
        TextEditingController(text: widget.room?.roomNumber ?? '');
    _rentController = TextEditingController(
        text: widget.room != null && widget.room!.monthlyRent > 0
            ? widget.room!.monthlyRent.toString()
            : '');
    _selectedStatus = widget.room?.status ?? 'void';
  }

  @override
  void dispose() {
    _roomNumberController.dispose();
    _rentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.room != null;
    return AlertDialog(
      title: Text(isEditing ? 'Edit Room' : 'Add New Room'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Room Number
              TextFormField(
                controller: _roomNumberController,
                decoration: const InputDecoration(
                  labelText: 'Room Number',
                  hintText: 'e.g. 101, A1, B2',
                  prefixIcon: Icon(Icons.meeting_room),
                  border: OutlineInputBorder(),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Room number is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Status Dropdown
              DropdownButtonFormField<String>(
                value: _selectedStatus,
                decoration: const InputDecoration(
                  labelText: 'Status',
                  prefixIcon: Icon(Icons.flag),
                  border: OutlineInputBorder(),
                ),
                items: _statuses.map((s) {
                  return DropdownMenuItem(
                    value: s,
                    child: Text(s[0].toUpperCase() + s.substring(1)),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedStatus = val);
                  }
                },
              ),
              const SizedBox(height: 16),

              // Monthly Rent
              TextFormField(
                controller: _rentController,
                decoration: InputDecoration(
                  labelText: 'Monthly Rent',
                  hintText: 'e.g. 1500',
                  prefixIcon: const Icon(Icons.attach_money),
                  suffixText: AppConfig.currency,
                  border: const OutlineInputBorder(),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Monthly rent is required';
                  }
                  final parsed = double.tryParse(val.trim());
                  if (parsed == null || parsed < 0) {
                    return 'Enter a valid amount';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _handleSave,
          child: Text(isEditing ? 'Update' : 'Add'),
        ),
      ],
    );
  }

  void _handleSave() {
    if (!_formKey.currentState!.validate()) return;

    final roomNumber = _roomNumberController.text.trim();
    final rent = double.parse(_rentController.text.trim());

    final room = Room(
      id: widget.room?.id ?? 0,
      roomNumber: roomNumber,
      status: _selectedStatus,
      monthlyRent: rent,
    );

    widget.onSave(room);
  }
}
