// lib/screens/rooms_screen.dart
// Unified Rooms + Tenants view — mobile-first design.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/room.dart';
import '../models/tenant.dart';
import '../providers/app_providers.dart';

class RoomsScreen extends ConsumerWidget {
  const RoomsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomsAsync = ref.watch(roomsStreamProvider);
    final tenantsAsync = ref.watch(tenantsStreamProvider);

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
            error: (_, __) => _buildRoomList(context, ref, rooms, {}),
            data: (tenants) {
              final tenantMap = <int, Tenant>{};
              for (final t in tenants) {
                if (t.isActive && t.roomId != null) {
                  tenantMap[t.roomId!] = t;
                }
              }
              return _buildRoomList(context, ref, rooms, tenantMap);
            },
          );
        },
      ),
    );
  }

  Widget _buildRoomList(BuildContext context, WidgetRef ref, List<Room> rooms,
      Map<int, Tenant> tenantMap) {
    if (rooms.isEmpty) {
      return const Center(
        child: Text('No rooms yet.', style: TextStyle(color: Colors.grey)),
      );
    }

    // Sort: by floor number, then suffix (f < g < s)
    final sorted = List<Room>.from(rooms);
    sorted.sort((a, b) {
      final aNum = _parseRoomNumber(a.roomNumber);
      final bNum = _parseRoomNumber(b.roomNumber);
      if (aNum.$1 != bNum.$1) return aNum.$1.compareTo(bNum.$1);
      return aNum.$2.compareTo(bNum.$2);
    });

    // Group by floor for section headers
    final grouped = <String, List<Room>>{};
    for (final r in sorted) {
      final floor = _parseRoomNumber(r.roomNumber).$1.toString();
      grouped.putIfAbsent(floor, () => []).add(r);
    }

    return RefreshIndicator(
      onRefresh: () async {},
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: grouped.entries.length,
        itemBuilder: (_, gi) {
          final entry = grouped.entries.elementAt(gi);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Floor header
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 12, 8, 4),
                child: Text('Floor ${entry.key}',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey)),
              ),
              // Rooms on this floor — single column, full-width cards
              ...entry.value.map((room) => _buildRoomCard(context, ref, room, tenantMap)),
            ],
          );
        },
      ),
    );
  }

  (int, String) _parseRoomNumber(String rn) {
    final match = RegExp(r'^(\d+)([a-zA-Z]+)$').firstMatch(rn);
    if (match != null) {
      return (int.parse(match.group(1)!), match.group(2)!.toLowerCase());
    }
    return (0, rn);
  }

  Widget _buildRoomCard(BuildContext context, WidgetRef ref, Room room,
      Map<int, Tenant> tenantMap) {
    final tenant = tenantMap[room.id];
    final hasTenant = tenant != null;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: hasTenant ? 2 : 0.5,
      child: InkWell(
        onTap: () => hasTenant
            ? _showTenantDialog(context, ref, room, tenant)
            : _showRoomDialog(context, ref, room),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: Room number + status + rent
              Row(
                children: [
                  // Room number badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: hasTenant ? Colors.indigo.shade50 : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      room.roomNumber.toUpperCase(),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: hasTenant ? Colors.indigo : Colors.grey,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _roomStatusBadge(room.status),
                  const Spacer(),
                  Text(
                    '${room.monthlyRent.toStringAsFixed(0)} LE',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),

              if (hasTenant) ...[
                const SizedBox(height: 10),
                const Divider(height: 1),
                const SizedBox(height: 10),

                // Tenant name
                Row(
                  children: [
                    const Icon(Icons.person, size: 18, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        tenant.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Phone + Call button
                Row(
                  children: [
                    const Icon(Icons.phone, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(tenant.phone, style: const TextStyle(fontSize: 13)),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => _callPhone(tenant.phone),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.call, size: 14, color: Colors.green),
                            SizedBox(width: 4),
                            Text('Call', style: TextStyle(fontSize: 12, color: Colors.green)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Lease start date + Payment status + Mark paid
                Row(
                  children: [
                    const Icon(Icons.event, size: 14, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      'Since ${_fmtDate(tenant.leaseStartDate)}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const Spacer(),
                    _paymentBadge(tenant),
                    if (tenant.isUnpaid) ...[
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () => _markPaid(context, ref, tenant),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check_circle, size: 20, color: Colors.green),
                        ),
                      ),
                    ],
                  ],
                ),
              ] else ...[
                const SizedBox(height: 6),
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Text('Vacant',
                        style: TextStyle(
                            color: Colors.grey, fontStyle: FontStyle.italic, fontSize: 13)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _roomStatusBadge(String status) {
    final c = status == 'occupied'
        ? Colors.green
        : status == 'maintenance'
            ? Colors.amber.shade700
            : Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(status,
          style: TextStyle(fontSize: 11, color: c, fontWeight: FontWeight.w600)),
    );
  }

  Widget _paymentBadge(Tenant tenant) {
    if (tenant.isPaid) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Text('Paid',
            style: TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.w600)),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Text('Unpaid',
          style: TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.w600)),
    );
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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
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

  void _showTenantDialog(BuildContext context, WidgetRef ref, Room room, Tenant? tenant) {
    _showTenantFormDialog(context, ref, room, tenant);
  }

  void _showRoomDialog(BuildContext context, WidgetRef ref, Room room) {
    _showRoomFormDialog(context, ref, room);
  }
}

// ════════════════════════════════════════════════════════
// TENANT FORM DIALOG
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
        title: Text(tenant == null
            ? 'Assign Tenant to ${room.roomNumber.toUpperCase()}'
            : 'Edit Tenant'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(
                controller: phoneCtrl,
                decoration: const InputDecoration(labelText: 'Phone', border: OutlineInputBorder())),
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
            TextField(
                controller: insuranceCtrl,
                decoration:
                    const InputDecoration(labelText: 'Insurance (LE)', border: OutlineInputBorder()),
                keyboardType: TextInputType.number),
            const SizedBox(height: 12),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                    context: ctx,
                    initialDate: leaseStartDate ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030));
                if (picked != null) setDialogState(() => leaseStartDate = picked);
              },
              child: InputDecorator(
                decoration:
                    const InputDecoration(labelText: 'Lease Start Date', border: OutlineInputBorder()),
                child: Text(leaseStartDate != null
                    ? '${leaseStartDate!.day}/${leaseStartDate!.month}/${leaseStartDate!.year}'
                    : 'Select date'),
              ),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                    context: ctx,
                    initialDate: dueDate ?? DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)));
                if (picked != null) setDialogState(() => dueDate = picked);
              },
              child: InputDecorator(
                decoration:
                    const InputDecoration(labelText: 'Due Date', border: OutlineInputBorder()),
                child: Text(dueDate != null
                    ? '${dueDate!.day}/${dueDate!.month}/${dueDate!.year}'
                    : 'Select due date'),
              ),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: paymentStatus,
                  decoration: const InputDecoration(
                      labelText: 'Payment', border: OutlineInputBorder(), isDense: true),
                  items: const [
                    DropdownMenuItem(value: 'paid', child: Text('Paid')),
                    DropdownMenuItem(value: 'unpaid', child: Text('Unpaid')),
                  ],
                  onChanged: (v) => setDialogState(() => paymentStatus = v ?? 'unpaid'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: tenantStatus,
                  decoration: const InputDecoration(
                      labelText: 'Status', border: OutlineInputBorder(), isDense: true),
                  items: const [
                    DropdownMenuItem(value: 'active', child: Text('Active')),
                    DropdownMenuItem(value: 'archived', child: Text('Archived')),
                  ],
                  onChanged: (v) => setDialogState(() => tenantStatus = v ?? 'active'),
                ),
              ),
            ]),
          ]),
        ),
        actions: [
          if (tenant != null)
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () async {
                try {
                  final repo = ref.read(supabaseRepositoryProvider);
                  await repo.updateTenant(tenant.copyWith(roomId: null, status: 'archived'));
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (e) {
                  if (ctx.mounted)
                    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e')));
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
                  await repo.updateRoom(room.copyWith(status: 'occupied'));
                } else {
                  await repo.updateTenant(tenant.copyWith(
                    name: nameCtrl.text.trim(),
                    phone: phoneCtrl.text.trim(),
                    gender: selectedGender,
                    roomId: room.id,
                    insuranceAmount: insurance,
                    paymentStatus: paymentStatus,
                    dueDate: dueDate,
                    leaseStartDate: tenant.leaseStartDate,
                    status: tenantStatus,
                  ));
                }
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                if (ctx.mounted)
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e')));
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
          TextField(
              controller: rentCtrl,
              decoration:
                  const InputDecoration(labelText: 'Monthly Rent (LE)', border: OutlineInputBorder()),
              keyboardType: TextInputType.number),
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
                await ref
                    .read(supabaseRepositoryProvider)
                    .updateRoom(room.copyWith(monthlyRent: rent, status: status));
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                if (ctx.mounted)
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
}
