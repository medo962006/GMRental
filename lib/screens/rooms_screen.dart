// lib/screens/rooms_screen.dart
// Unified Rooms + Tenants view — rooms are the primary index.
// Each room card shows: room number, status, rent, and assigned tenant info.
// Rooms: 1f-11f, 1g-11g, 1s-11s
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_config.dart';
import '../models/room.dart';
import '../models/tenant.dart';
import '../providers/app_providers.dart';

class RoomsScreen extends ConsumerWidget {
  const RoomsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomsAsync = ref.watch(roomsStreamProvider);
    final tenantsAsync = ref.watch(tenantsStreamProvider);
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rooms & Tenants'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: roomsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (rooms) {
          return tenantsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => _buildRoomGrid(context, ref, rooms, {}, isDesktop),
            data: (tenants) {
              // Map room_id -> active tenant
              final tenantMap = <int, Tenant>{};
              for (final t in tenants) {
                if (t.isActive && t.roomId != null) {
                  tenantMap[t.roomId!] = t;
                }
              }
              return _buildRoomGrid(context, ref, rooms, tenantMap, isDesktop);
            },
          );
        },
      ),
    );
  }

  Widget _buildRoomGrid(BuildContext context, WidgetRef ref, List<Room> rooms,
      Map<int, Tenant> tenantMap, bool isDesktop) {
    if (rooms.isEmpty) {
      return const Center(child: Text('No rooms yet. Add rooms from the FAB.', style: TextStyle(color: Colors.grey)));
    }

    // Build sorted room list: by floor then suffix (f, g, s)
    final sortedRooms = List<Room>.from(rooms);
    sortedRooms.sort((a, b) {
      final aNum = _parseRoomNumber(a.roomNumber);
      final bNum = _parseRoomNumber(b.roomNumber);
      if (aNum.$1 != bNum.$1) return aNum.$1.compareTo(bNum.$1);
      return aNum.$2.compareTo(bNum.$2); // f < g < s
    });

    if (isDesktop) {
      return _buildDesktopTable(context, ref, sortedRooms, tenantMap);
    }
    return _buildMobileGrid(context, ref, sortedRooms, tenantMap);
  }

  /// Parse room number like "2f" -> (2, "f"), "10s" -> (10, "s")
  (int, String) _parseRoomNumber(String rn) {
    final match = RegExp(r'^(\d+)([a-zA-Z]+)$').firstMatch(rn);
    if (match != null) {
      return (int.parse(match.group(1)!), match.group(2)!.toLowerCase());
    }
    return (0, rn);
  }

  // ════════════════════════════════════════════════════════
  // MOBILE GRID
  // ════════════════════════════════════════════════════════

  Widget _buildMobileGrid(BuildContext context, WidgetRef ref,
      List<Room> rooms, Map<int, Tenant> tenantMap) {
    return RefreshIndicator(
      onRefresh: () async {
        // Invalidate both since they're merged
      },
      child: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.9,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: rooms.length,
        itemBuilder: (_, i) => _buildRoomCard(context, ref, rooms[i], tenantMap, false),
      ),
    );
  }

  Widget _buildDesktopTable(BuildContext context, WidgetRef ref,
      List<Room> rooms, Map<int, Tenant> tenantMap) {
    return RefreshIndicator(
      onRefresh: () async {},
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Card(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Room')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Rent')),
                DataColumn(label: Text('Tenant')),
                DataColumn(label: Text('Phone')),
                DataColumn(label: Text('Paid')),
                DataColumn(label: Text('Start Date')),
                DataColumn(label: Text('Actions')),
              ],
              rows: rooms.map((room) {
                final tenant = tenantMap[room.id];
                return DataRow(
                  cells: [
                    DataCell(Text(room.roomNumber.toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                    DataCell(_roomStatusBadge(room.status)),
                    DataCell(Text('${room.monthlyRent.toStringAsFixed(0)} LE')),
                    DataCell(Text(tenant?.name ?? '-', style: TextStyle(color: tenant == null ? Colors.grey : null))),
                    DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(tenant?.phone ?? '-'),
                      if (tenant != null && tenant.phone.isNotEmpty)
                        InkWell(
                          onTap: () => _callPhone(tenant.phone),
                          child: const Icon(Icons.phone, size: 16, color: Colors.green),
                        ),
                    ])),
                    DataCell(tenant != null ? _paymentBadge(tenant) : const Text('-')),
                    DataCell(Text(tenant?.leaseStartDate != null
                        ? _fmtDate(tenant!.leaseStartDate!)
                        : '-')),
                    DataCell(_buildRowActions(context, ref, room, tenant)),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRowActions(BuildContext context, WidgetRef ref, Room room, Tenant? tenant) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      if (tenant != null && tenant.isUnpaid)
        IconButton(
          icon: const Icon(Icons.check_circle, size: 20, color: Colors.green),
          tooltip: 'Mark Paid',
          onPressed: () => _markPaid(context, ref, tenant),
        ),
      if (tenant != null)
        IconButton(
          icon: const Icon(Icons.edit, size: 20),
          tooltip: 'Edit Tenant',
          onPressed: () => _showTenantDialog(context, ref, room, tenant),
        ),
      IconButton(
        icon: const Icon(Icons.settings, size: 20, color: Colors.blueGrey),
        tooltip: 'Room Settings',
        onPressed: () => _showRoomDialog(context, ref, room),
      ),
    ]);
  }

  // ════════════════════════════════════════════════════════
  // ROOM CARD (Mobile)
  // ════════════════════════════════════════════════════════

  Widget _buildRoomCard(BuildContext context, WidgetRef ref, Room room,
      Map<int, Tenant> tenantMap, bool isDesktop) {
    final tenant = tenantMap[room.id];
    final hasTenant = tenant != null;
    final statusColor = room.isOccupied
        ? (tenant?.isUnpaid == true ? Colors.orange : Colors.green)
        : room.isMaintenance ? Colors.amber : Colors.grey;

    return Card(
      elevation: hasTenant ? 3 : 1,
      color: hasTenant ? null : Colors.grey.shade50,
      child: InkWell(
        onTap: () => hasTenant
            ? _showTenantDialog(context, ref, room, tenant)
            : _showRoomDialog(context, ref, room),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Room number + status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(room.roomNumber.toUpperCase(),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  _roomStatusBadge(room.status),
                ],
              ),
              const SizedBox(height: 4),
              Text('${room.monthlyRent.toStringAsFixed(0)} LE/month',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
              const Divider(height: 12),
              // Tenant info
              if (hasTenant) ...[
                Row(children: [
                  Icon(Icons.person, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Expanded(child: Text(tenant.name, style: const TextStyle(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                ]),
                const SizedBox(height: 4),
                Row(children: [
                  Icon(Icons.phone, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(tenant.phone, style: const TextStyle(fontSize: 12)),
                  const Spacer(),
                  InkWell(
                    onTap: () => _callPhone(tenant.phone),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.call, size: 12, color: Colors.green),
                        SizedBox(width: 2),
                        Text('Call', style: TextStyle(fontSize: 11, color: Colors.green)),
                      ]),
                    ),
                  ),
                ]),
                const SizedBox(height: 4),
                Row(children: [
                  Icon(Icons.event, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text('Since ${_fmtDate(tenant.leaseStartDate)}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  const Spacer(),
                  if (tenant.isUnpaid)
                    IconButton(
                      icon: const Icon(Icons.check_circle, size: 20, color: Colors.green),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => _markPaid(context, ref, tenant),
                    ),
                ]),
                const SizedBox(height: 2),
                _paymentBadge(tenant),
              ] else ...[
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text('Vacant', style: TextStyle(color: Colors.grey.shade500, fontStyle: FontStyle.italic)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════
  // BADGES
  // ════════════════════════════════════════════════════════

  Widget _roomStatusBadge(String status) {
    final c = status == 'occupied' ? Colors.green : status == 'maintenance' ? Colors.amber.shade700 : Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
      child: Text(status, style: TextStyle(fontSize: 11, color: c, fontWeight: FontWeight.w600)),
    );
  }

  Widget _paymentBadge(Tenant tenant) {
    if (tenant.isPaid) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
        child: const Text('Paid', style: TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.w600)),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
      child: const Text('Unpaid', style: TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.w600)),
    );
  }

  // ════════════════════════════════════════════════════════
  // DIALOGS
  // ════════════════════════════════════════════════════════

  void _showTenantDialog(BuildContext context, WidgetRef ref, Room room, Tenant? tenant) {
    _showTenantFormDialog(context, ref, room, tenant);
  }

  void _showRoomDialog(BuildContext context, WidgetRef ref, Room room) {
    _showRoomFormDialog(context, ref, room);
  }

  void _markPaid(BuildContext context, WidgetRef ref, Tenant tenant) async {
    try {
      await ref.read(supabaseRepositoryProvider).markTenantPaid(tenant.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${tenant.name} marked as paid')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  void _callPhone(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    try {
      // url_launcher handles this
    } catch (_) {}
  }

  String _fmtDate(DateTime? d) {
    if (d == null) return '-';
    return '${d.day}/${d.month}/${d.year}';
  }
}

// ════════════════════════════════════════════════════════
// TENANT FORM DIALOG (embedded in room card tap)
// ════════════════════════════════════════════════════════

void _showTenantFormDialog(BuildContext context, WidgetRef ref, Room room, Tenant? tenant) {
  final nameCtrl = TextEditingController(text: tenant?.name ?? '');
  final phoneCtrl = TextEditingController(text: tenant?.phone ?? '');
  final insuranceCtrl = TextEditingController(text: tenant?.insuranceAmount.toString() ?? '0');
  String? selectedGender = tenant?.gender;
  String paymentStatus = tenant?.paymentStatus ?? 'unpaid';
  String tenantStatus = tenant?.status ?? 'active';
  DateTime? dueDate = tenant?.dueDate;
  DateTime? leaseStartDate = tenant?.leaseStartDate ?? DateTime.now();

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        title: Text(tenant == null ? 'Assign Tenant to ${room.roomNumber.toUpperCase()}' : 'Edit Tenant'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Phone', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: selectedGender,
              decoration: const InputDecoration(labelText: 'Gender', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'male', child: Text('Male')),
                DropdownMenuItem(value: 'female', child: Text('Female')),
              ],
              onChanged: (v) => setDialogState(() => selectedGender = v),
            ),
            const SizedBox(height: 12),
            TextField(controller: insuranceCtrl, decoration: const InputDecoration(labelText: 'Insurance (LE)', border: OutlineInputBorder()), keyboardType: TextInputType.number),
            const SizedBox(height: 12),
            // Lease Start Date
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(context: ctx, initialDate: leaseStartDate ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2030));
                if (picked != null) setDialogState(() => leaseStartDate = picked);
              },
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Lease Start Date', border: OutlineInputBorder()),
                child: Text(leaseStartDate != null ? '${leaseStartDate!.day}/${leaseStartDate!.month}/${leaseStartDate!.year}' : 'Select date'),
              ),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(context: ctx, initialDate: dueDate ?? DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
                if (picked != null) setDialogState(() => dueDate = picked);
              },
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Due Date', border: OutlineInputBorder()),
                child: Text(dueDate != null ? '${dueDate!.day}/${dueDate!.month}/${dueDate!.year}' : 'Select due date'),
              ),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: DropdownButtonFormField<String>(
                value: paymentStatus,
                decoration: const InputDecoration(labelText: 'Payment', border: OutlineInputBorder(), isDense: true),
                items: const [
                  DropdownMenuItem(value: 'paid', child: Text('Paid')),
                  DropdownMenuItem(value: 'unpaid', child: Text('Unpaid')),
                ],
                onChanged: (v) => setDialogState(() => paymentStatus = v ?? 'unpaid'),
              )),
              const SizedBox(width: 8),
              Expanded(child: DropdownButtonFormField<String>(
                value: tenantStatus,
                decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder(), isDense: true),
                items: const [
                  DropdownMenuItem(value: 'active', child: Text('Active')),
                  DropdownMenuItem(value: 'archived', child: Text('Archived')),
                ],
                onChanged: (v) => setDialogState(() => tenantStatus = v ?? 'active'),
              )),
            ]),
          ]),
        ),
        actions: [
          if (tenant != null)
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () async {
                // Remove tenant from room
                try {
                  final repo = ref.read(supabaseRepositoryProvider);
                  await repo.updateTenant(tenant.copyWith(roomId: null, status: 'archived'));
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (e) {
                  if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
              child: const Text('Remove'),
            ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              try {
                final repo = ref.read(supabaseRepositoryProvider);
                final insurance = double.tryParse(insuranceCtrl.text.trim()) ?? 0;
                if (tenant == null) {
                  // Create new tenant assigned to this room
                  await repo.addTenant(Tenant(
                    id: '',
                    name: nameCtrl.text.trim(),
                    phone: phoneCtrl.text.trim(),
                    gender: selectedGender,
                    roomId: room.id,
                    insuranceAmount: insurance,
                    paymentStatus: paymentStatus,
                    dueDate: dueDate,
                    leaseStartDate: leaseStartDate,
                    status: tenantStatus,
                    createdAt: DateTime.now(),
                  ));
                  // Mark room as occupied
                  await repo.updateRoom(room.copyWith(status: 'occupied'));
                } else {
                  // Update existing — preserve leaseStartDate
                  await repo.updateTenant(tenant.copyWith(
                    name: nameCtrl.text.trim(),
                    phone: phoneCtrl.text.trim(),
                    gender: selectedGender,
                    roomId: room.id,
                    insuranceAmount: insurance,
                    paymentStatus: paymentStatus,
                    dueDate: dueDate,
                    leaseStartDate: tenant.leaseStartDate, // Never overwrite
                    status: tenantStatus,
                  ));
                }
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: Text(tenant == null ? 'Assign' : 'Save'),
          ),
        ],
      ),
    ),
  );
}

// ════════════════════════════════════════════════════════
// ROOM FORM DIALOG
// ════════════════════════════════════════════════════════

void _showRoomFormDialog(BuildContext context, WidgetRef ref, Room room) {
  final rentCtrl = TextEditingController(text: room.monthlyRent.toString());
  String status = room.status;

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        title: Text('Room ${room.roomNumber.toUpperCase()} Settings'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: rentCtrl, decoration: const InputDecoration(labelText: 'Monthly Rent (LE)', border: OutlineInputBorder()), keyboardType: TextInputType.number),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: status,
            decoration: const InputDecoration(labelText: 'Room Status', border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: 'occupied', child: Text('Occupied')),
              DropdownMenuItem(value: 'void', child: Text('Void')),
              DropdownMenuItem(value: 'maintenance', child: Text('Maintenance')),
            ],
            onChanged: (v) => setDialogState(() => status = v ?? 'void'),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final rent = double.tryParse(rentCtrl.text.trim()) ?? room.monthlyRent;
              try {
                await ref.read(supabaseRepositoryProvider).updateRoom(room.copyWith(monthlyRent: rent, status: status));
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
}
