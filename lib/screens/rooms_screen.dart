// lib/screens/rooms_screen.dart
// Full CRUD Room + Tenant control with filters and multi-building support.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_theme.dart';
import '../models/room.dart';
import '../models/tenant.dart';
import '../providers/app_providers.dart';
import '../data/building2_data.dart';

enum RoomFilter { all, occupied, void_, unpaid }

class RoomsScreen extends ConsumerWidget {
  const RoomsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final buildingId = ref.watch(currentBuildingIdProvider);
    final isB2 = buildingId == 2;
    final isDesktop = MediaQuery.of(context).size.width > 800;

    // Building 2 uses static data; Building 1 uses Supabase
    if (isB2) {
      return _Building2View(isDesktop: isDesktop);
    }

    // Building 1 — Supabase data
    final roomsAsync = ref.watch(roomsStreamProvider);
    final tenantsAsync = ref.watch(tenantsStreamProvider);

    return Scaffold(
      body: roomsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (rooms) {
          return tenantsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => _B1Content(rooms: rooms, tenantMap: {}, isDesktop: isDesktop),
            data: (tenants) {
              final tenantMap = <int, Tenant>{};
              for (final t in tenants) {
                if (t.isActive && t.roomId != null) tenantMap[t.roomId!] = t;
              }
              return _B1Content(rooms: rooms, tenantMap: tenantMap, isDesktop: isDesktop);
            },
          );
        },
      ),
    );
  }
}

// ════════════════════════════════════════════════════════
// BUILDING 2 — STATIC DATA VIEW
// ════════════════════════════════════════════════════════

class _Building2View extends StatefulWidget {
  final bool isDesktop;
  const _Building2View({required this.isDesktop});

  @override
  State<_Building2View> createState() => _Building2ViewState();
}

class _Building2ViewState extends State<_Building2View> {
  RoomFilter _filter = RoomFilter.all;
  String _search = '';

  @override
  Widget build(BuildContext context) {
    var rooms = Building2Data.rooms;
    final tenants = Building2Data.tenants;
    final tenantMap = <int, Tenant>{for (final t in tenants) if (t.roomId != null) t.roomId!: t};

    // Apply search
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      rooms = rooms.where((r) {
        final t = tenantMap[r.id];
        return r.roomNumber.toLowerCase().contains(q) ||
            (t?.name.toLowerCase().contains(q) ?? false);
      }).toList();
    }

    // Apply filter
    rooms = rooms.where((r) {
      final t = tenantMap[r.id];
      switch (_filter) {
        case RoomFilter.occupied: return r.isOccupied;
        case RoomFilter.void_: return r.isVoid;
        case RoomFilter.unpaid: return t != null && t.isUnpaid;
        case RoomFilter.all: return true;
      }
    }).toList();

    // Sort: Ground (no suffix) → First (--) → Second (---), then by number
    rooms.sort((a, b) {
      final aFloor = _b2Floor(a.roomNumber);
      final bFloor = _b2Floor(b.roomNumber);
      if (aFloor != bFloor) return aFloor.compareTo(bFloor);
      final aNum = _b2Num(a.roomNumber);
      final bNum = _b2Num(b.roomNumber);
      return aNum.compareTo(bNum);
    });

    // Group by floor
    final grouped = <String, List<Room>>{};
    for (final r in rooms) {
      final floor = _b2FloorName(r.roomNumber);
      grouped.putIfAbsent(floor, () => []).add(r);
    }

    return Scaffold(
      body: Column(
        children: [
          // ── Search + Filters ──
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Column(children: [
              // Search bar
              TextField(
                decoration: InputDecoration(
                  hintText: 'ابحث بالاسم أو رقم الأوضة',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  filled: true,
                  fillColor: AppColors.canvas,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.borderMuted)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.borderMuted)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.accent, width: 2)),
                ),
                onChanged: (v) => setState(() => _search = v),
              ),
              const SizedBox(height: 8),
              // Filter chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  _filterChip('الكل', RoomFilter.all),
                  const SizedBox(width: 6),
                  _filterChip('مشغول', RoomFilter.occupied),
                  const SizedBox(width: 6),
                  _filterChip('فارغ', RoomFilter.void_),
                  const SizedBox(width: 6),
                  _filterChip('متأخر', RoomFilter.unpaid),
                ]),
              ),
            ]),
          ),
          const Divider(height: 1),

          // ── Room list ──
          Expanded(
            child: rooms.isEmpty
                ? const Center(child: Text('لا توجد نتائج', style: TextStyle(color: AppColors.textSecondary)))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    itemCount: grouped.entries.length,
                    itemBuilder: (_, gi) {
                      final entry = grouped.entries.elementAt(gi);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8, top: 12),
                            child: Text(entry.key,
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: AppColors.primary)),
                          ),
                          ...entry.value.map((room) => _B2RoomCard(
                            room: room,
                            tenant: tenantMap[room.id],
                          )),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, RoomFilter f) {
    final isSelected = _filter == f;
    return GestureDetector(
      onTap: () => setState(() => _filter = f),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.canvas,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? AppColors.primary : AppColors.borderMuted),
        ),
        child: Text(label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isSelected ? Colors.white : AppColors.textSecondary)),
      ),
    );
  }

  int _b2Floor(String rn) {
    if (rn.contains('---')) return 2;
    if (rn.contains('--')) return 1;
    return 0;
  }

  int _b2Num(String rn) {
    final m = RegExp(r'^(\d+)').firstMatch(rn);
    return m != null ? int.parse(m.group(1)!) : 0;
  }

  String _b2FloorName(String rn) {
    if (rn.contains('---')) return 'الطابق الثاني';
    if (rn.contains('--')) return 'الطابق الأول';
    return 'الأرضي';
  }
}

class _B2RoomCard extends ConsumerWidget {
  final Room room;
  final Tenant? tenant;
  const _B2RoomCard({required this.room, this.tenant});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasTenant = tenant != null && room.isOccupied;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: AppDecorations.card(context),
      child: InkWell(
        onTap: () => _showActions(context, ref),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Room number + status
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: room.isOccupied ? AppColors.primary : AppColors.canvas,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('Room ${room.roomNumber}',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: room.isOccupied ? Colors.white : AppColors.textSecondary)),
                ),
                const SizedBox(width: 8),
                if (room.isOccupied) AppBadge.paid(label: 'مشغول'),
                if (room.isVoid) AppBadge.status(label: 'فارغ', bg: AppColors.canvas, fg: AppColors.textSecondary),
                if (room.isMaintenance) AppBadge.partial(label: 'صيانة'),
              ]),

              if (hasTenant) ...[
                const SizedBox(height: 10),
                const Divider(height: 1),
                const SizedBox(height: 10),

                // Tenant name
                Text(tenant!.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppColors.neutralDark)),
                const SizedBox(height: 6),

                // Details grid
                Wrap(spacing: 12, runSpacing: 6, children: [
                  if (tenant!.phone.isNotEmpty) _detail(Icons.phone, tenant!.phone),
                  if (tenant!.dueDate != null) _detail(Icons.event, 'يوم الدفع: ${tenant!.dueDate!.day}'),
                  _detail(Icons.payments, '${tenant!.insuranceAmount.toStringAsFixed(0)} جنيه'),
                ]),

                const SizedBox(height: 8),
                // Payment status
                tenant!.isPaid
                    ? AppBadge.paid(label: 'مدفوع')
                    : AppBadge.unpaid(label: 'متأخر'),
              ] else ...[
                const SizedBox(height: 8),
                Center(child: Text('فارغة — اضغط لإضافة ساكن', style: TextStyle(color: AppColors.textSecondary, fontStyle: FontStyle.italic, fontSize: 13))),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _detail(IconData icon, String text) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 14, color: AppColors.textSecondary),
      const SizedBox(width: 4),
      Text(text, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
    ]);
  }

  void _showActions(BuildContext ctx, WidgetRef ref) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      builder: (bCtx) => Container(
        decoration: const BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.borderMuted, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          Text('Room ${room.roomNumber}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
          if (tenant != null) ...[
            Text('${tenant!.name}', style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),
            if (tenant!.phone.isNotEmpty)
              _action(bCtx, Icons.call, 'اتصال', AppColors.success, () {}),
            if (tenant!.phone.isNotEmpty)
              _action(bCtx, Icons.chat, 'واتساب', AppColors.accent, () {}),
            if (tenant!.isUnpaid)
              _action(bCtx, Icons.check_circle, 'تسجيل الدفع', AppColors.success, () {}),
            _action(bCtx, Icons.edit, 'تعديل', AppColors.secondary, () {}),
            _action(bCtx, Icons.delete, 'مسح', AppColors.danger, () {}),
          ] else ...[
            const SizedBox(height: 16),
            _action(bCtx, Icons.person_add, 'إضافة ساكن', AppColors.success, () {}),
          ],
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  Widget _action(BuildContext ctx, IconData icon, String label, Color color, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: color, size: 22),
      title: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.neutralDark)),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}

// ════════════════════════════════════════════════════════
// BUILDING 1 — SUPABASE DATA VIEW
// ════════════════════════════════════════════════════════

class _B1Content extends ConsumerStatefulWidget {
  final List<Room> rooms;
  final Map<int, Tenant> tenantMap;
  final bool isDesktop;
  const _B1Content({required this.rooms, required this.tenantMap, required this.isDesktop});

  @override
  ConsumerState<_B1Content> createState() => _B1ContentState();
}

class _B1ContentState extends ConsumerState<_B1Content> {
  RoomFilter _filter = RoomFilter.all;

  @override
  Widget build(BuildContext context) {
    var rooms = widget.rooms;

    // Apply filter
    rooms = rooms.where((r) {
      final t = widget.tenantMap[r.id];
      switch (_filter) {
        case RoomFilter.occupied: return r.isOccupied;
        case RoomFilter.void_: return r.isVoid;
        case RoomFilter.unpaid: return t != null && t.isUnpaid;
        case RoomFilter.all: return true;
      }
    }).toList();

    // Sort by floor then suffix (G < F < S)
    rooms.sort((a, b) {
      final aP = _parse(a.roomNumber);
      final bP = _parse(b.roomNumber);
      if (aP.$1 != bP.$1) return aP.$1.compareTo(bP.$1);
      return _suffixOrder(aP.$2).compareTo(_suffixOrder(bP.$2));
    });

    if (widget.isDesktop) {
      return _b1Desktop(rooms);
    }

    // Group by floor
    final grouped = <String, List<Room>>{};
    for (final r in rooms) {
      final floor = _parse(r.roomNumber).$1.toString();
      grouped.putIfAbsent(floor, () => []).add(r);
    }

    return Column(children: [
      // Filters
      Container(
        color: AppColors.surface,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            _fChip('All', RoomFilter.all),
            const SizedBox(width: 6),
            _fChip('Occupied', RoomFilter.occupied),
            const SizedBox(width: 6),
            _fChip('Void', RoomFilter.void_),
            const SizedBox(width: 6),
            _fChip('Unpaid', RoomFilter.unpaid),
          ]),
        ),
      ),
      const Divider(height: 1),
      Expanded(
        child: rooms.isEmpty
            ? const Center(child: Text('No rooms match filter', style: TextStyle(color: AppColors.textSecondary)))
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                itemCount: grouped.entries.length,
                itemBuilder: (_, gi) {
                  final entry = grouped.entries.elementAt(gi);
                  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8, top: 12),
                      child: Text('FLOOR ${entry.key}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: AppColors.primary)),
                    ),
                    ...entry.value.map((room) => _B1Card(room: room, tenant: widget.tenantMap[room.id])),
                  ]);
                },
              ),
      ),
    ]);
  }

  Widget _fChip(String label, RoomFilter f) {
    final isSel = _filter == f;
    return GestureDetector(
      onTap: () => setState(() => _filter = f),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSel ? AppColors.primary : AppColors.canvas,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSel ? AppColors.primary : AppColors.borderMuted),
        ),
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isSel ? Colors.white : AppColors.textSecondary)),
      ),
    );
  }

  Widget _b1Desktop(List<Room> rooms) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Room Ledger', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.neutralDark)),
        const SizedBox(height: 4),
        const Text('Tap a room for quick actions', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        const SizedBox(height: 16),
        // Filters
        SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
          _fChip('All', RoomFilter.all), const SizedBox(width: 6),
          _fChip('Occupied', RoomFilter.occupied), const SizedBox(width: 6),
          _fChip('Void', RoomFilter.void_), const SizedBox(width: 6),
          _fChip('Unpaid', RoomFilter.unpaid),
        ])),
        const SizedBox(height: 16),
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
                columns: const [
                  DataColumn(label: Text('Room')), DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Rent')), DataColumn(label: Text('Tenant')),
                  DataColumn(label: Text('Payment')), DataColumn(label: Text('Actions')),
                ],
                rows: rooms.map((room) {
                  final t = widget.tenantMap[room.id];
                  return DataRow(cells: [
                    DataCell(Text(room.roomNumber.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary))),
                    DataCell(_sb(room.status)),
                    DataCell(Text('${room.monthlyRent.toStringAsFixed(0)} LE', style: const TextStyle(fontWeight: FontWeight.w600))),
                    DataCell(Text(t?.name ?? '—')),
                    DataCell(t != null ? (t.isPaid ? AppBadge.paid() : AppBadge.unpaid()) : const Text('—')),
                    DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                      if (t != null && t.isUnpaid)
                        IconButton(icon: const Icon(Icons.check_circle, size: 18, color: AppColors.success),
                          onPressed: () => ref.read(supabaseRepositoryProvider).markTenantPaid(t.id)),
                      IconButton(icon: const Icon(Icons.edit, size: 18, color: AppColors.secondary), onPressed: () {}),
                    ])),
                  ]);
                }).toList(),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _sb(String s) {
    if (s == 'occupied') return AppBadge.paid(label: 'Occupied');
    if (s == 'maintenance') return AppBadge.partial(label: 'Maint.');
    return AppBadge.status(label: 'Void', bg: AppColors.canvas, fg: AppColors.textSecondary);
  }
}

class _B1Card extends StatelessWidget {
  final Room room;
  final Tenant? tenant;
  const _B1Card({required this.room, this.tenant});

  @override
  Widget build(BuildContext context) {
    final hasTenant = tenant != null;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: AppDecorations.card(context),
      child: InkWell(borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: hasTenant ? AppColors.primary : AppColors.canvas, borderRadius: BorderRadius.circular(10)),
                child: Text(room.roomNumber.toUpperCase(), style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: hasTenant ? Colors.white : AppColors.textSecondary)),
              ),
              const SizedBox(width: 8),
              if (room.isOccupied) AppBadge.paid(label: 'Occupied'),
              if (room.isVoid) AppBadge.status(label: 'Void', bg: AppColors.canvas, fg: AppColors.textSecondary),
              if (room.isMaintenance) AppBadge.partial(label: 'Maintenance'),
              const Spacer(),
              Text('${room.monthlyRent.toStringAsFixed(0)} LE', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary)),
            ]),
            if (hasTenant) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(children: [
                const Icon(Icons.person, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Expanded(child: Text(tenant!.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
                tenant!.isPaid ? AppBadge.paid() : AppBadge.unpaid(),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.phone, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Text(tenant!.phone, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                const Spacer(),
                GestureDetector(
                  onTap: () { final uri = Uri(scheme: 'tel', path: tenant!.phone); try {} catch (_) {} },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(color: AppColors.successBg, borderRadius: BorderRadius.circular(20)),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.call, size: 14, color: AppColors.success),
                      SizedBox(width: 4),
                      Text('Call', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.successText)),
                    ]),
                  ),
                ),
              ]),
            ] else ...[
              const SizedBox(height: 8),
              const Center(child: Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Vacant', style: TextStyle(color: AppColors.textSecondary, fontStyle: FontStyle.italic, fontSize: 13)),
              )),
            ],
          ]),
        ),
      ),
    );
  }
}

(int, String) _parse(String rn) {
  final m = RegExp(r'^(\d+)([a-zA-Z]+)$').firstMatch(rn);
  if (m != null) return (int.parse(m.group(1)!), m.group(2)!.toLowerCase());
  return (0, rn);
}

int _suffixOrder(String s) {
  switch (s) {
    case 'g': return 0;
    case 'f': return 1;
    case 's': return 2;
    default: return 3;
  }
}
