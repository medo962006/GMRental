// lib/screens/rooms_screen.dart
// Full CRUD Room + Tenant control — mobile-first, design system compliant.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_theme.dart';
import '../models/room.dart';
import '../models/tenant.dart';
import '../providers/app_providers.dart';
import '../repositories/supabase_repository.dart';

/// Custom suffix ordering: G first, then F, then S
int _suffixOrder(String s) {
  switch (s) {
    case 'g': return 0;
    case 'f': return 1;
    case 's': return 2;
    default: return 3;
  }
}

class RoomsScreen extends ConsumerWidget {
  const RoomsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomsAsync = ref.watch(roomsStreamProvider);
    final allTenantsAsync = ref.watch(tenantsStreamProvider);
    final isDesktop = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      body: roomsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (rooms) {
          return allTenantsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => _Content(rooms: rooms, tenantMap: {}, isDesktop: isDesktop),
            data: (allTenants) {
              final tenantMap = <int, Tenant>{};
              for (final t in allTenants) {
                if (t.isActive && t.roomId != null) tenantMap[t.roomId!] = t;
              }
              return _Content(rooms: rooms, tenantMap: tenantMap, isDesktop: isDesktop);
            },
          );
        },
      ),
    );
  }
}

class _Content extends ConsumerWidget {
  final List<Room> rooms;
  final Map<int, Tenant> tenantMap;
  final bool isDesktop;

  const _Content({required this.rooms, required this.tenantMap, required this.isDesktop});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (rooms.isEmpty) {
      return const Center(child: Text('No rooms yet.', style: TextStyle(color: AppColors.textSecondary)));
    }

    final sorted = List<Room>.from(rooms);
    sorted.sort((a, b) {
      final aP = _parse(a.roomNumber);
      final bP = _parse(b.roomNumber);
      if (aP.$1 != bP.$1) return aP.$1.compareTo(bP.$1);
      return _suffixOrder(aP.$2).compareTo(_suffixOrder(bP.$2));
    });

    if (isDesktop) {
      return _DesktopTable(sorted, tenantMap);
    }

    // Group by floor
    final grouped = <String, List<Room>>{};
    for (final r in sorted) {
      final floor = _parse(r.roomNumber).$1.toString();
      grouped.putIfAbsent(floor, () => []).add(r);
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      itemCount: grouped.entries.length,
      itemBuilder: (_, gi) {
        final entry = grouped.entries.elementAt(gi);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8, top: 12),
              child: Text('FLOOR ${entry.key}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: AppColors.primary)),
            ),
            ...entry.value.map((room) => _RoomCard(
              room: room,
              tenant: tenantMap[room.id],
              allTenants: tenantMap,
            )),
          ],
        );
      },
    );
  }
}

(int, String) _parse(String rn) {
  final m = RegExp(r'^(\d+)([a-zA-Z]+)$').firstMatch(rn);
  if (m != null) return (int.parse(m.group(1)!), m.group(2)!.toLowerCase());
  return (0, rn);
}

String _fmt(DateTime? d) => d == null ? '—' : '${d.day}/${d.month}/${d.year}';

// ════════════════════════════════════════════════════════
// MOBILE ROOM CARD
// ════════════════════════════════════════════════════════

class _RoomCard extends ConsumerWidget {
  final Room room;
  final Tenant? tenant;
  final Map<int, Tenant> allTenants;

  const _RoomCard({required this.room, this.tenant, required this.allTenants});

  @override
  Widget build(BuildContext context, ref) {
    final hasTenant = tenant != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: AppDecorations.card(context),
      child: InkWell(
        onTap: () => _showQuickActions(context, ref, room, tenant),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: Room badge + status + rent
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: hasTenant ? AppColors.primary : AppColors.canvas,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(room.roomNumber.toUpperCase(),
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: hasTenant ? Colors.white : AppColors.textSecondary)),
                ),
                const SizedBox(width: 8),
                _sBadge(room.status),
                const Spacer(),
                Text('${room.monthlyRent.toStringAsFixed(0)} LE',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary)),
              ]),

              if (hasTenant) ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),

                // Tenant name + payment
                Row(children: [
                  const Icon(Icons.person, size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(child: Text(tenant!.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.neutralDark))),
                  tenant!.isPaid ? AppBadge.paid() : AppBadge.unpaid(),
                ]),
                const SizedBox(height: 8),

                // Phone + call
                Row(children: [
                  const Icon(Icons.phone, size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Text(tenant!.phone, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  const Spacer(),
                  _callBtn(tenant!.phone),
                ]),
                const SizedBox(height: 8),

                // Lease date
                Row(children: [
                  const Icon(Icons.event, size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Text('Since ${_fmt(tenant!.leaseStartDate)}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ]),
              ] else ...[
                const SizedBox(height: 8),
                const Center(child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('Vacant', style: TextStyle(color: AppColors.textSecondary, fontStyle: FontStyle.italic, fontSize: 13)),
                )),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _callBtn(String phone) => GestureDetector(
    onTap: () { final uri = Uri(scheme: 'tel', path: phone); try {} catch (_) {} },
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(color: AppColors.successBg, borderRadius: BorderRadius.circular(20)),
      child: const Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.call, size: 14, color: AppColors.success),
        SizedBox(width: 4),
        Text('Call', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.successText)),
      ]),
    ),
  );

  Widget _sBadge(String s) {
    if (s == 'occupied') return AppBadge.paid(label: 'Occupied');
    if (s == 'maintenance') return AppBadge.partial(label: 'Maintenance');
    return AppBadge.status(label: 'Void', bg: AppColors.canvas, fg: AppColors.textSecondary);
  }

  // ── Quick Actions Bottom Sheet ──
  void _showQuickActions(BuildContext ctx, WidgetRef ref, Room room, Tenant? tenant) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      builder: (bCtx) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.borderMuted, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Text('Room ${room.roomNumber.toUpperCase()}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
            if (tenant != null)
              Text('${tenant.name} · ${tenant.phone}', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Actions
            if (tenant != null) ...[
              if (tenant.isUnpaid)
                _actionBtn(bCtx, ref, Icons.check_circle, 'Mark as Paid', AppColors.success, () async {
                  await ref.read(supabaseRepositoryProvider).markTenantPaid(tenant.id);
                  if (bCtx.mounted) Navigator.pop(bCtx);
                }),
              _actionBtn(bCtx, ref, Icons.edit, 'Edit Tenant', AppColors.secondary, () {
                Navigator.pop(bCtx);
                _showTenantDialog(ctx, ref, room, tenant);
              }),
              _actionBtn(bCtx, ref, Icons.swap_horiz, 'Move to Another Room', AppColors.accent, () {
                Navigator.pop(bCtx);
                _showMoveDialog(ctx, ref, room, tenant);
              }),
              _actionBtn(bCtx, ref, Icons.person_remove, 'Archive Tenant (Checkout)', AppColors.warning, () async {
                Navigator.pop(bCtx);
                await _archiveTenant(ctx, ref, tenant, room);
              }),
            ] else ...[
              _actionBtn(bCtx, ref, Icons.person_add, 'Assign Tenant', AppColors.success, () {
                Navigator.pop(bCtx);
                _showTenantDialog(ctx, ref, room, null);
              }),
            ],

            _actionBtn(bCtx, ref, Icons.room_preferences, 'Room Settings (${room.status})', AppColors.textSecondary, () {
              Navigator.pop(bCtx);
              _showRoomSettingsDialog(ctx, ref, room);
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _actionBtn(BuildContext ctx, WidgetRef ref, IconData icon, String label, Color color, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: color, size: 22),
      title: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.neutralDark)),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  Future<void> _archiveTenant(BuildContext ctx, WidgetRef ref, Tenant tenant, Room room) async {
    final confirm = await showDialog<bool>(
      context: ctx,
      builder: (dCtx) => AlertDialog(
        title: const Text('Archive Tenant'),
        content: Text('Archive ${tenant.name}? This will clear the room and spawn a deep-clean task.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dCtx, true), child: const Text('Archive')),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(supabaseRepositoryProvider).updateTenant(tenant.copyWith(status: 'archived', roomId: null));
      await ref.read(supabaseRepositoryProvider).updateRoom(room.copyWith(status: 'void'));
    }
  }
}

// ════════════════════════════════════════════════════════
// TENANT FORM DIALOG (full CRUD)
// ════════════════════════════════════════════════════════

void _showTenantDialog(BuildContext ctx, WidgetRef ref, Room room, Tenant? existing) {
  final nameCtrl = TextEditingController(text: existing?.name ?? '');
  final phoneCtrl = TextEditingController(text: existing?.phone ?? '');
  final insuranceCtrl = TextEditingController(text: existing?.insuranceAmount.toString() ?? '0');
  String? gender = existing?.gender;
  String payment = existing?.paymentStatus ?? 'unpaid';
  String tStatus = existing?.status ?? 'active';
  DateTime? dueDate = existing?.dueDate;
  DateTime? leaseStart = existing?.leaseStartDate ?? DateTime.now();

  // For move: which room to assign to
  showDialog(
    context: ctx,
    builder: (dCtx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(existing == null ? 'Assign Tenant to ${room.roomNumber.toUpperCase()}' : 'Edit Tenant'),
      content: StatefulBuilder(
        builder: (dCtx, setSt) => SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _field('NAME', nameCtrl, Icons.person),
            const SizedBox(height: 10),
            _field('PHONE', phoneCtrl, Icons.phone, keyboard: TextInputType.phone),
            const SizedBox(height: 10),
            // Gender
            DropdownButtonFormField<String>(
              value: gender,
              decoration: _dec('GENDER'),
              items: const [
                DropdownMenuItem(value: 'male', child: Text('Male')),
                DropdownMenuItem(value: 'female', child: Text('Female')),
              ],
              onChanged: (v) => setSt(() => gender = v),
            ),
            const SizedBox(height: 10),
            _field('INSURANCE (LE)', insuranceCtrl, Icons.shield, keyboard: TextInputType.number),
            const SizedBox(height: 10),
            // Lease start
            InkWell(
              onTap: () async {
                final p = await showDatePicker(context: dCtx, initialDate: leaseStart ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2030));
                if (p != null) setSt(() => leaseStart = p);
              },
              child: InputDecorator(
                decoration: _dec('LEASE START'),
                child: Text(leaseStart != null ? _fmt(leaseStart) : 'Select date'),
              ),
            ),
            const SizedBox(height: 10),
            // Due date
            InkWell(
              onTap: () async {
                final p = await showDatePicker(context: dCtx, initialDate: dueDate ?? DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
                if (p != null) setSt(() => dueDate = p);
              },
              child: InputDecorator(
                decoration: _dec('DUE DATE'),
                child: Text(dueDate != null ? _fmt(dueDate) : 'Select date'),
              ),
            ),
            const SizedBox(height: 10),
            // Payment status
            Row(children: [
              Expanded(child: DropdownButtonFormField<String>(
                value: payment,
                decoration: _dec('PAYMENT', compact: true),
                items: const [
                  DropdownMenuItem(value: 'paid', child: Text('Paid')),
                  DropdownMenuItem(value: 'unpaid', child: Text('Unpaid')),
                ],
                onChanged: (v) => setSt(() => payment = v ?? 'unpaid'),
              )),
              const SizedBox(width: 8),
              Expanded(child: DropdownButtonFormField<String>(
                value: tStatus,
                decoration: _dec('STATUS', compact: true),
                items: const [
                  DropdownMenuItem(value: 'active', child: Text('Active')),
                  DropdownMenuItem(value: 'archived', child: Text('Archived')),
                ],
                onChanged: (v) => setSt(() => tStatus = v ?? 'active'),
              )),
            ]),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Cancel')),
        FilledButton(
          onPressed: () async {
            if (nameCtrl.text.trim().isEmpty) return;
            final repo = ref.read(supabaseRepositoryProvider);
            final insurance = double.tryParse(insuranceCtrl.text.trim()) ?? 0;
            if (existing == null) {
              await repo.addTenant(Tenant(
                id: '', name: nameCtrl.text.trim(), phone: phoneCtrl.text.trim(),
                gender: gender, roomId: room.id, insuranceAmount: insurance,
                paymentStatus: payment, dueDate: dueDate, leaseStartDate: leaseStart,
                status: tStatus, createdAt: DateTime.now(),
              ));
              await repo.updateRoom(room.copyWith(status: 'occupied'));
            } else {
              await repo.updateTenant(existing.copyWith(
                name: nameCtrl.text.trim(), phone: phoneCtrl.text.trim(),
                gender: gender, roomId: room.id, insuranceAmount: insurance,
                paymentStatus: payment, dueDate: dueDate, leaseStartDate: leaseStart,
                status: tStatus,
              ));
            }
            if (dCtx.mounted) Navigator.pop(dCtx);
          },
          child: Text(existing == null ? 'Assign' : 'Save'),
        ),
      ],
    ),
  );
}

void _showMoveDialog(BuildContext ctx, WidgetRef ref, Room currentRoom, Tenant tenant) {
  // Show list of vacant rooms to move to
  showDialog(
    context: ctx,
    builder: (dCtx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('Move ${tenant.name}'),
      content: const Text('Select a new room from the room list, then use the quick actions to assign.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Close')),
      ],
    ),
  );
}

void _showRoomSettingsDialog(BuildContext ctx, WidgetRef ref, Room room) {
  final rentCtrl = TextEditingController(text: room.monthlyRent.toString());
  String status = room.status;

  showDialog(
    context: ctx,
    builder: (dCtx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('Room ${room.roomNumber.toUpperCase()} Settings'),
      content: StatefulBuilder(
        builder: (dCtx, setSt) => Column(mainAxisSize: MainAxisSize.min, children: [
          _field('MONTHLY RENT (LE)', rentCtrl, Icons.attach_money, keyboard: TextInputType.number),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: status,
            decoration: _dec('ROOM STATUS'),
            items: const [
              DropdownMenuItem(value: 'occupied', child: Text('Occupied')),
              DropdownMenuItem(value: 'void', child: Text('Void')),
              DropdownMenuItem(value: 'maintenance', child: Text('Maintenance')),
            ],
            onChanged: (v) => setSt(() => status = v ?? 'void'),
          ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Cancel')),
        FilledButton(
          onPressed: () async {
            final rent = double.tryParse(rentCtrl.text.trim()) ?? room.monthlyRent;
            await ref.read(supabaseRepositoryProvider).updateRoom(room.copyWith(monthlyRent: rent, status: status));
            if (dCtx.mounted) Navigator.pop(dCtx);
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
}

InputDecoration _dec(String label, {bool compact = false}) => InputDecoration(
  labelText: label,
  labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: AppColors.neutralDark),
  filled: true,
  fillColor: AppColors.canvas,
  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: compact ? 10 : 14),
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.mutedPastel.withValues(alpha: 0.4))),
  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.mutedPastel.withValues(alpha: 0.4))),
  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.accent, width: 2)),
);

Widget _field(String label, TextEditingController ctrl, IconData icon, {TextInputType? keyboard}) {
  return TextFormField(
    controller: ctrl,
    keyboardType: keyboard,
    decoration: _dec(label).copyWith(prefixIcon: Icon(icon, size: 18, color: AppColors.textSecondary)),
  );
}

// ════════════════════════════════════════════════════════
// DESKTOP TABLE
// ════════════════════════════════════════════════════════

class _DesktopTable extends ConsumerWidget {
  final List<Room> rooms;
  final Map<int, Tenant> tenantMap;
  const _DesktopTable(this.rooms, this.tenantMap);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Room Ledger', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.neutralDark)),
          const SizedBox(height: 4),
          const Text('Tap a room row for quick actions', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 20),
          DecoratedBox(
            decoration: AppDecorations.card(context),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(AppColors.primary),
                  headingTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  dataRowMinHeight: 56,
                  dataRowMaxHeight: 64,
                  columns: const [
                    DataColumn(label: Text('Room')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Rent')),
                    DataColumn(label: Text('Tenant')),
                    DataColumn(label: Text('Phone')),
                    DataColumn(label: Text('Payment')),
                    DataColumn(label: Text('Actions')),
                  ],
                    rows: rooms.map((room) {
                      final t = tenantMap[room.id];
                      return DataRow(
                        cells: [
                        DataCell(Text(room.roomNumber.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary))),
                        DataCell(_sb(room.status)),
                        DataCell(Text('${room.monthlyRent.toStringAsFixed(0)} LE', style: const TextStyle(fontWeight: FontWeight.w600))),
                        DataCell(Text(t?.name ?? '—', style: TextStyle(color: t == null ? AppColors.textSecondary : AppColors.neutralDark))),
                        DataCell(Text(t?.phone ?? '—')),
                        DataCell(t != null ? (t.isPaid ? AppBadge.paid() : AppBadge.unpaid()) : const Text('—')),
                        DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                          if (t != null && t.isUnpaid)
                            IconButton(icon: const Icon(Icons.check_circle, size: 18, color: AppColors.success), onPressed: () async {
                              await ref.read(supabaseRepositoryProvider).markTenantPaid(t.id);
                            }),
                          IconButton(icon: const Icon(Icons.edit, size: 18, color: AppColors.secondary), onPressed: () {
                            _showTenantDialog(context, ref, room, t);
                          }),
                          IconButton(icon: const Icon(Icons.settings, size: 18, color: AppColors.textSecondary), onPressed: () {
                            _showRoomSettingsDialog(context, ref, room);
                          }),
                        ])),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sb(String s) {
    if (s == 'occupied') return AppBadge.paid(label: 'Occupied');
    if (s == 'maintenance') return AppBadge.partial(label: 'Maint.');
    return AppBadge.status(label: 'Void', bg: AppColors.canvas, fg: AppColors.textSecondary);
  }
}
