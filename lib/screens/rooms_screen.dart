// lib/screens/rooms_screen.dart
// Full CRUD Room + Tenant control — all data from Supabase via building_id filter.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_theme.dart';
import '../models/room.dart';
import '../models/tenant.dart';
import '../providers/app_providers.dart';
import '../repositories/supabase_repository.dart';
import '../services/auth_guard.dart';

enum RoomFilter { all, occupied, void_, unpaid }

class RoomsScreen extends ConsumerWidget {
  const RoomsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final buildingId = ref.watch(currentBuildingIdProvider);
    final isDesktop = MediaQuery.of(context).size.width > 800;

    return _RoomContent(
      isDesktop: isDesktop,
      buildingId: buildingId,
    );
  }
}

// ════════════════════════════════════════════════════════
// MAIN CONTENT — shared between buildings
// ════════════════════════════════════════════════════════

class _RoomContent extends ConsumerStatefulWidget {
  final bool isDesktop;
  final int buildingId;

  const _RoomContent({
    required this.isDesktop,
    required this.buildingId,
  });

  @override
  ConsumerState<_RoomContent> createState() => _RoomContentState();
}

class _RoomContentState extends ConsumerState<_RoomContent> {
  RoomFilter _filter = RoomFilter.all;
  String _search = '';

  /// Shows password dialog and returns true if authenticated.
  Future<bool> _requireAuth() async {
    return showPasswordDialog(context, ref);
  }

  @override
  Widget build(BuildContext context) {
    final roomsAsync = ref.watch(roomsStreamProvider(widget.buildingId));
    final tenantsAsync = ref.watch(tenantsStreamProvider(widget.buildingId));

    return roomsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (rooms) {
        return tenantsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => _buildRoomList(rooms, {}),
          data: (tenants) {
            final tenantMap = <int, Tenant>{};
            for (final t in tenants) {
              if (t.isActive && t.roomId != null) tenantMap[t.roomId!] = t;
            }
            return _buildRoomList(rooms, tenantMap);
          },
        );
      },
    );
  }

  Widget _buildRoomList(List<Room> allRooms, Map<int, Tenant> tenantMap) {
    var rooms = List<Room>.from(allRooms);

    // Search
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      rooms = rooms.where((r) {
        final t = tenantMap[r.id];
        return r.roomNumber.toLowerCase().contains(q) ||
            (t?.name.toLowerCase().contains(q) ?? false);
      }).toList();
    }

    // Filter
    rooms = rooms.where((r) {
      final t = tenantMap[r.id];
      switch (_filter) {
        case RoomFilter.occupied:
          return r.isOccupied;
        case RoomFilter.void_:
          return r.isVoid;
        case RoomFilter.unpaid:
          return t != null && t.isUnpaid;
        case RoomFilter.all:
          return true;
      }
    }).toList();

    // Sort by floor order, then room number
    rooms.sort((a, b) {
      if (a.floorOrder != b.floorOrder) return a.floorOrder.compareTo(b.floorOrder);
      final aNum = _extractNum(a.roomNumber);
      final bNum = _extractNum(b.roomNumber);
      return aNum.compareTo(bNum);
    });

    // Group by floor
    final grouped = <String, List<Room>>{};
    for (final r in rooms) {
      grouped.putIfAbsent(r.floorLabelAr, () => []).add(r);
    }

    if (widget.isDesktop) {
      return _buildDesktop(rooms, tenantMap);
    }

    return Column(
      children: [
        // Search + filters
        Container(
          color: AppColors.surface,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Column(children: [
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

        // Room list
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
                        ...entry.value.map((room) => _RoomCard(
                          room: room,
                          tenant: tenantMap[room.id],
                          buildingId: widget.buildingId,
                        )),
                      ],
                    );
                  },
                ),
        ),
      ],
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

  Widget _buildDesktop(List<Room> rooms, Map<int, Tenant> tenantMap) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Room Ledger', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.neutralDark)),
            const SizedBox(height: 4),
            Text('${rooms.length} rooms', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          ]),
          Consumer(builder: (context, ref, _) {
            final bId = ref.watch(currentBuildingIdProvider);
            return Text(bId == 1 ? 'Main Building' : 'Baraka',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary));
          }),
        ]),
        const SizedBox(height: 16),
        SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
          _filterChip('All', RoomFilter.all), const SizedBox(width: 6),
          _filterChip('Occupied', RoomFilter.occupied), const SizedBox(width: 6),
          _filterChip('Void', RoomFilter.void_), const SizedBox(width: 6),
          _filterChip('Unpaid', RoomFilter.unpaid),
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
                dataRowMaxHeight: 56,
                columns: const [
                  DataColumn(label: Text('Room')), DataColumn(label: Text('Floor')),
                  DataColumn(label: Text('Status')), DataColumn(label: Text('Rent')),
                  DataColumn(label: Text('Tenant')), DataColumn(label: Text('Payment')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: rooms.map((room) {
                  final t = tenantMap[room.id];
                  return DataRow(cells: [
                    DataCell(Text(room.displayRoomNumber.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary))),
                    DataCell(Text(room.floorLabel)),
                    DataCell(_statusBadge(room.status)),
                    DataCell(Text('${room.monthlyRent.toStringAsFixed(0)} LE', style: const TextStyle(fontWeight: FontWeight.w600))),
                    DataCell(Text(t?.name ?? '—')),
                    DataCell(t != null ? (t.isPaid ? AppBadge.paid() : AppBadge.unpaid()) : const Text('—')),
                    DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                      if (t != null && t.isUnpaid)
                        IconButton(
                          icon: const Icon(Icons.check_circle, size: 18, color: AppColors.success),
                          onPressed: () => _markPaid(t.id),
                        ),
                      IconButton(
                        icon: const Icon(Icons.edit, size: 18, color: AppColors.secondary),
                        onPressed: () => _showRoomActions(context, room, t),
                      ),
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

  Widget _statusBadge(String s) {
    if (s == 'occupied') return AppBadge.paid(label: 'Occupied');
    if (s == 'maintenance') return AppBadge.partial(label: 'Maint.');
    return AppBadge.status(label: 'Void', bg: AppColors.canvas, fg: AppColors.textSecondary);
  }

  void _markPaid(String tenantId) async {
    final authed = await _requireAuth();
    if (!authed) return;
    ref.read(supabaseRepositoryProvider).markTenantPaid(tenantId);
  }

  void _showRoomActions(BuildContext ctx, Room room, Tenant? tenant) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      builder: (bCtx) => _RoomActionsSheet(
        room: room,
        tenant: tenant,
        buildingId: widget.buildingId,
        onRefresh: () => setState(() {}),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════
// ROOM CARD — mobile
// ════════════════════════════════════════════════════════

class _RoomCard extends ConsumerWidget {
  final Room room;
  final Tenant? tenant;
  final int buildingId;

  const _RoomCard({required this.room, this.tenant, required this.buildingId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasTenant = tenant != null && room.isOccupied;

    return GestureDetector(
      onTap: () => _showActions(context, ref),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: AppDecorations.card(context),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Room number + floor + status
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: room.isOccupied ? AppColors.primary : AppColors.canvas,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('Room ${room.displayRoomNumber}',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: room.isOccupied ? Colors.white : AppColors.textSecondary)),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(room.floorLabelAr, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.accent)),
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
                Text(tenant!.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppColors.neutralDark)),
                const SizedBox(height: 6),
                Wrap(spacing: 12, runSpacing: 6, children: [
                  if (tenant!.phone.isNotEmpty) _detail(Icons.phone, tenant!.phone),
                  if (tenant!.dueDate != null) _detail(Icons.event, 'يوم الدفع: ${tenant!.dueDate!.day}'),
                  _detail(Icons.payments, '${tenant!.insuranceAmount.toStringAsFixed(0)} جنيه'),
                ]),
                const SizedBox(height: 8),
                tenant!.isPaid ? AppBadge.paid(label: 'مدفوع') : AppBadge.unpaid(label: 'متأخر'),
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
      builder: (bCtx) => _RoomActionsSheet(
        room: room,
        tenant: tenant,
        buildingId: buildingId,
        onRefresh: () {
          // Force rebuild by navigating to same screen
          if (ctx.mounted) {
            ref.invalidate(roomsStreamProvider(buildingId));
            ref.invalidate(tenantsStreamProvider(buildingId));
          }
        },
      ),
    );
  }
}

// ════════════════════════════════════════════════════════
// ACTIONS BOTTOM SHEET — full CRUD
// ════════════════════════════════════════════════════════

class _RoomActionsSheet extends ConsumerStatefulWidget {
  final Room room;
  final Tenant? tenant;
  final int buildingId;
  final VoidCallback onRefresh;

  const _RoomActionsSheet({
    required this.room,
    this.tenant,
    required this.buildingId,
    required this.onRefresh,
  });

  @override
  ConsumerState<_RoomActionsSheet> createState() => _RoomActionsSheetState();
}

class _RoomActionsSheetState extends ConsumerState<_RoomActionsSheet> {
  bool _loading = false;

  String _deviceCode = 'LOADING';

  @override
  void initState() {
    super.initState();
    _loadDeviceCode();
  }

  Future<void> _loadDeviceCode() async {
    final code = await getDeviceCode(ref);
    if (mounted) setState(() => _deviceCode = code);
  }

  /// Shows password dialog and returns true if authenticated.
  Future<bool> _requireAuth() async {
    return showPasswordDialog(context, ref);
  }

  /// Wraps an async action with password gate. Returns true if action ran.
  Future<bool> _guarded(Future<void> Function() action) async {
    if (!await _requireAuth()) return false;
    await action();
    return true;
  }

  Future<void> _log({
    required String action,
    required String entityType,
    String? entityId,
    String? entityName,
    Map<String, dynamic>? oldVal,
    Map<String, dynamic>? newVal,
    String? details,
  }) async {
    try {
      if (!mounted) return;
      final repo = ref.read(supabaseRepositoryProvider);
      await repo.logChange(
        deviceCode: _deviceCode,
        adminName: 'Admin',
        action: action,
        entityType: entityType,
        entityId: entityId,
        entityName: entityName,
        oldValue: oldVal,
        newValue: newVal,
        details: details,
        buildingId: widget.buildingId,
      );
    } catch (_) {
      // Silently fail — don't block the main operation
    }
  }

  Future<void> _run(Future<void> fn, {String? logAction, String? logEntity, String? logEntityId, String? logEntityName, Map<String, dynamic>? logOld, Map<String, dynamic>? logNew, String? logDetails, bool requiresAuth = false}) async {
    if (requiresAuth) {
      final authed = await _requireAuth();
      if (!authed) return;
    }
    setState(() => _loading = true);
    try {
      await fn;
      // Log the change
      if (logAction != null && mounted) {
        await _log(
          action: logAction,
          entityType: logEntity ?? 'tenant',
          entityId: logEntityId,
          entityName: logEntityName,
          oldVal: logOld,
          newVal: logNew,
          details: logDetails,
        );
      }
      if (mounted) {
        widget.onRefresh();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(supabaseRepositoryProvider);
    final room = widget.room;
    final tenant = widget.tenant;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(20),
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.borderMuted, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 16),
                Text('Room ${room.displayRoomNumber}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
                Text('Floor: ${room.floorLabelAr}', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                if (tenant != null) ...[
                  Text(tenant!.name, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                ],
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 12),

                if (tenant != null) ...[
                  // Call
                  if (tenant!.phone.isNotEmpty)
                    _action(Icons.call, 'اتصال', AppColors.success, () => _call(tenant!.phone)),
                  // WhatsApp
                  if (tenant!.phone.isNotEmpty)
                    _action(Icons.chat, 'واتساب', const Color(0xFF25D366), () => _whatsapp(tenant!.phone)),
                  // Mark paid
                  if (tenant!.isUnpaid)
                    _action(Icons.check_circle, 'تسجيل الدفع', AppColors.success, () => _run(
                      repo.markTenantPaid(tenant!.id),
                      logAction: 'mark_paid',
                      logEntity: 'tenant',
                      logEntityId: tenant!.id,
                      logEntityName: tenant!.name,
                      logOld: {'payment_status': 'unpaid'},
                      logNew: {'payment_status': 'paid'},
                      logDetails: 'Marked ${tenant!.name} as paid',
                      requiresAuth: true,
                    )),
                  // Edit tenant
                  _action(Icons.edit, 'تعديل الساكن', AppColors.secondary, () {
                    Navigator.pop(context);
                    _showTenantForm(context, ref, room, tenant);
                  }),
                  // Move tenant
                  _action(Icons.swap_horiz, 'نقل الساكن', AppColors.accent, () {
                    Navigator.pop(context);
                    _showMoveTenant(context, ref, room, tenant);
                  }),
                  // Archive tenant
                  _action(Icons.archive, 'أرشفة الساكن', AppColors.warning, () => _run(
                    repo.updateTenant(tenant!.copyWith(status: 'archived')),
                    logAction: 'archive',
                    logEntity: 'tenant',
                    logEntityId: tenant!.id,
                    logEntityName: tenant!.name,
                    logOld: {'status': 'active'},
                    logNew: {'status': 'archived'},
                    logDetails: 'Archived ${tenant!.name}',
                    requiresAuth: true,
                  )),
                  // Delete tenant
                  _action(Icons.delete_forever, 'مسح الساكن', AppColors.danger, () => _run(
                    repo.deleteTenant(tenant!.id),
                    logAction: 'delete',
                    logEntity: 'tenant',
                    logEntityId: tenant!.id,
                    logEntityName: tenant!.name,
                    logDetails: 'Deleted ${tenant!.name}',
                    requiresAuth: true,
                  )),
                ] else ...[
                  // Assign tenant
                  _action(Icons.person_add, 'إضافة ساكن', AppColors.success, () {
                    Navigator.pop(context);
                    _showTenantForm(context, ref, room, null);
                  }),
                ],

                // Room settings (always available)
                const Divider(height: 1),
                _action(Icons.settings, 'إعدادات الأوضة (السعر / الحالة / الطابق)', AppColors.accent, () {
                  Navigator.pop(context);
                  _showRoomSettings(context, ref, room);
                }),
                // Delete room
                _action(Icons.delete, 'مسح الأوضة', AppColors.danger, () => _run(
                  repo.deleteRoom(room.id),
                  logAction: 'delete',
                  logEntity: 'room',
                  logEntityId: room.id.toString(),
                  logEntityName: 'Room ${room.displayRoomNumber}',
                  logDetails: 'Deleted Room ${room.displayRoomNumber}',
                  requiresAuth: true,
                )),

                const SizedBox(height: 8),
              ],
            ),
          ),
    );
  }

  Widget _action(IconData icon, String label, Color color, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: color, size: 22),
      title: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.neutralDark)),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  void _call(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  void _whatsapp(String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^\d]'), '');
    final uri = Uri.parse('https://wa.me/$clean');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  // ── Tenant Form ───────────────────────────────────
  void _showTenantForm(BuildContext ctx, WidgetRef ref, Room room, Tenant? existing) {
    final repo = ref.read(supabaseRepositoryProvider);
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final phoneCtrl = TextEditingController(text: existing?.phone ?? '');
    final rentCtrl = TextEditingController(text: existing?.insuranceAmount.toString() ?? room.monthlyRent.toString());
    final dayCtrl = TextEditingController(text: existing?.dueDate?.day.toString() ?? '1');
    String gender = existing?.gender ?? 'male';

    showDialog(
      context: ctx,
      builder: (dCtx) => StatefulBuilder(
        builder: (dCtx, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'إضافة ساكن' : 'تعديل الساكن'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'الاسم', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'رقم الهاتف', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(controller: rentCtrl, decoration: const InputDecoration(labelText: 'الإيجار الشهري', border: OutlineInputBorder()), keyboardType: TextInputType.number),
              const SizedBox(height: 12),
              TextField(controller: dayCtrl, decoration: const InputDecoration(labelText: 'يوم الدفع (1-31)', border: OutlineInputBorder()), keyboardType: TextInputType.number),
              const SizedBox(height: 12),
              Row(children: [
                const Text('الجنس: '),
                Radio<String>(value: 'male', groupValue: gender, onChanged: (v) => setDialogState(() => gender = v!)),
                const Text('ذكر'),
                Radio<String>(value: 'female', groupValue: gender, onChanged: (v) => setDialogState(() => gender = v!)),
                const Text('أنثى'),
              ]),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('إلغاء')),
            FilledButton(
              onPressed: () async {
                // Password gate
                final authed = await showPasswordDialog(ctx, ref);
                if (!authed) return;

                final now = DateTime.now();
                final day = int.tryParse(dayCtrl.text) ?? 1;
                final rent = double.tryParse(rentCtrl.text) ?? 0;

                try {
                  if (existing == null) {
                    final newTenant = await repo.addTenant(Tenant(
                      id: '',
                      name: nameCtrl.text,
                      phone: phoneCtrl.text,
                      roomId: room.id,
                      buildingId: widget.buildingId,
                      gender: gender,
                      insuranceAmount: rent,
                      dueDate: DateTime(now.year, now.month, day),
                      createdAt: now,
                    ));
                    // Log create
                    await _log(
                      action: 'create',
                      entityType: 'tenant',
                      entityId: newTenant.id,
                      entityName: newTenant.name,
                      newVal: {'name': newTenant.name, 'phone': newTenant.phone, 'rent': rent, 'room': room.displayRoomNumber},
                      details: 'Added ${newTenant.name} to Room ${room.displayRoomNumber}',
                    );
                  } else {
                    final oldName = existing.name;
                    await repo.updateTenant(existing.copyWith(
                      name: nameCtrl.text,
                      phone: phoneCtrl.text,
                      insuranceAmount: rent,
                      dueDate: DateTime(now.year, now.month, day),
                      gender: gender,
                    ));
                    // Log update
                    await _log(
                      action: 'update',
                      entityType: 'tenant',
                      entityId: existing.id,
                      entityName: nameCtrl.text,
                      oldVal: {'name': oldName, 'phone': existing.phone},
                      newVal: {'name': nameCtrl.text, 'phone': phoneCtrl.text, 'rent': rent},
                      details: 'Updated ${nameCtrl.text} in Room ${room.displayRoomNumber}',
                    );
                  }
                  if (dCtx.mounted) Navigator.pop(dCtx);
                  widget.onRefresh();
                } catch (e) {
                  if (dCtx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                }
              },
              child: Text(existing == null ? 'إضافة' : 'حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Move Tenant ───────────────────────────────────
  void _showMoveTenant(BuildContext ctx, WidgetRef ref, Room currentRoom, Tenant tenant) {
    showDialog(
      context: ctx,
      builder: (dCtx) => AlertDialog(
        title: Text('نقل ${tenant.name}'),
        content: Text('من أوضة ${currentRoom.roomNumber} إلى...'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () async {
              // For now, just close — in a full implementation you'd show a room picker
              Navigator.pop(dCtx);
            },
            child: const Text('اختيار أوضة'),
          ),
        ],
      ),
    );
  }

  // ── Room Settings ─────────────────────────────────
  void _showRoomSettings(BuildContext ctx, WidgetRef ref, Room room) {
    final repo = ref.read(supabaseRepositoryProvider);
    final rentCtrl = TextEditingController(text: room.monthlyRent.toString());
    String status = room.status;
    String floor = room.floor;

    showDialog(
      context: ctx,
      builder: (dCtx) => StatefulBuilder(
        builder: (dCtx, setDialogState) => AlertDialog(
          title: Text('إعدادات أوضة ${room.roomNumber}'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: rentCtrl,
                decoration: const InputDecoration(labelText: 'الإيجار الشهري', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: status,
                decoration: const InputDecoration(labelText: 'الحالة', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'occupied', child: Text('مشغولة')),
                  DropdownMenuItem(value: 'void', child: Text('فارغة')),
                  DropdownMenuItem(value: 'maintenance', child: Text('صيانة')),
                ],
                onChanged: (v) => setDialogState(() => status = v!),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: floor,
                decoration: const InputDecoration(labelText: 'الطابق', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'G', child: Text('الأرضي')),
                  DropdownMenuItem(value: 'F', child: Text('الأول')),
                  DropdownMenuItem(value: 'S', child: Text('الثاني')),
                  DropdownMenuItem(value: 'T', child: Text('الثالث')),
                ],
                onChanged: (v) => setDialogState(() => floor = v!),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('إلغاء')),
            FilledButton(
              onPressed: () async {
                // Password gate
                final authed = await showPasswordDialog(ctx, ref);
                if (!authed) return;

                final rent = double.tryParse(rentCtrl.text) ?? room.monthlyRent;
                try {
                  await repo.updateRoom(room.copyWith(
                    monthlyRent: rent,
                    status: status,
                    floor: floor,
                  ));
                  // Log room settings change
                  await _log(
                    action: 'update',
                    entityType: 'room',
                    entityId: room.id.toString(),
                    entityName: 'Room ${room.displayRoomNumber}',
                    oldVal: {'rent': room.monthlyRent, 'status': room.status, 'floor': room.floor},
                    newVal: {'rent': rent, 'status': status, 'floor': floor},
                    details: 'Updated Room ${room.displayRoomNumber}: rent=$rent, status=$status, floor=$floor',
                  );
                  if (dCtx.mounted) Navigator.pop(dCtx);
                  widget.onRefresh();
                } catch (e) {
                  if (dCtx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                }
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }
}

int _extractNum(String rn) {
  // Handle room numbers like "B7G" → 7, "B13F" → 13, "1G" → 1
  final cleaned = rn.startsWith('B') && rn.length > 1 ? rn.substring(1) : rn;
  final m = RegExp(r'^(\d+)').firstMatch(cleaned);
  return m != null ? int.parse(m.group(1)!) : 0;
}
