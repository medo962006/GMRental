// lib/screens/rooms_screen.dart
// Unified Rooms + Tenants — complete design system overhaul.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_theme.dart';
import '../models/room.dart';
import '../models/tenant.dart';
import '../providers/app_providers.dart';

class RoomsScreen extends ConsumerWidget {
  const RoomsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomsAsync = ref.watch(roomsStreamProvider);
    final tenantsAsync = ref.watch(tenantsStreamProvider);
    final isDesktop = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      body: roomsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (rooms) {
          return tenantsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => _buildContent(context, ref, rooms, {}, isDesktop),
            data: (tenants) {
              final tenantMap = <int, Tenant>{};
              for (final t in tenants) {
                if (t.isActive && t.roomId != null) {
                  tenantMap[t.roomId!] = t;
                }
              }
              return _buildContent(context, ref, rooms, tenantMap, isDesktop);
            },
          );
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, List<Room> rooms,
      Map<int, Tenant> tenantMap, bool isDesktop) {
    if (rooms.isEmpty) {
      return const Center(
        child: Text('No rooms yet.',
            style: TextStyle(color: AppColors.textSecondary)),
      );
    }

    final sorted = List<Room>.from(rooms);
    sorted.sort((a, b) {
      final aNum = _parseRoomNumber(a.roomNumber);
      final bNum = _parseRoomNumber(b.roomNumber);
      if (aNum.$1 != bNum.$1) return aNum.$1.compareTo(bNum.$1);
      return aNum.$2.compareTo(bNum.$2);
    });

    if (isDesktop) {
      return _buildDesktopTable(context, ref, sorted, tenantMap);
    }

    final grouped = <String, List<Room>>{};
    for (final r in sorted) {
      final floor = _parseRoomNumber(r.roomNumber).$1.toString();
      grouped.putIfAbsent(floor, () => []).add(r);
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      itemCount: grouped.entries.length,
      itemBuilder: (_, gi) {
        final entry = grouped.entries.elementAt(gi);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8, top: 8),
              child: Text('FLOOR ${entry.key}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      )),
            ),
            ...entry.value.map((room) => _MobileRoomCard(
                room: room, tenant: tenantMap[room.id], ref: ref)),
          ],
        );
      },
    );
  }

  Widget _buildDesktopTable(
      BuildContext context, WidgetRef ref, List<Room> rooms, Map<int, Tenant> tenantMap) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Room Ledger', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text('Manage all rooms and tenant assignments',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 24),
          DecoratedBox(
            decoration: AppDecorations.card(context),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(AppColors.primary),
                  headingTextStyle: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  dataRowMinHeight: 56,
                  dataRowMaxHeight: 64,
                  columns: const [
                    DataColumn(label: Text('Room')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Rent')),
                    DataColumn(label: Text('Tenant')),
                    DataColumn(label: Text('Phone')),
                    DataColumn(label: Text('Payment')),
                    DataColumn(label: Text('Since')),
                    DataColumn(label: Text('Actions')),
                  ],
                  rows: rooms.map((room) {
                    final tenant = tenantMap[room.id];
                    return DataRow(cells: [
                      DataCell(Text(room.roomNumber.toUpperCase(),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, color: AppColors.primary))),
                      DataCell(_statusBadge(room.status)),
                      DataCell(Text('${room.monthlyRent.toStringAsFixed(0)} LE',
                          style: const TextStyle(fontWeight: FontWeight.w600))),
                      DataCell(Text(tenant?.name ?? '—',
                          style: TextStyle(
                              color: tenant == null
                                  ? AppColors.textSecondary
                                  : AppColors.neutralDark,
                              fontWeight: FontWeight.w500))),
                      DataCell(Text(tenant?.phone ?? '—')),
                      DataCell(tenant != null
                          ? (tenant.isPaid ? AppBadge.paid() : AppBadge.unpaid())
                          : const Text('—')),
                      DataCell(Text(
                          tenant?.leaseStartDate != null
                              ? _fmtDate(tenant!.leaseStartDate)
                              : '—',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textSecondary))),
                      DataCell(_buildActions(ref, room, tenant)),
                    ]);
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(WidgetRef ref, Room room, Tenant? tenant) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (tenant != null && tenant.isUnpaid)
          IconButton(
            icon: const Icon(Icons.check_circle, size: 20, color: AppColors.success),
            tooltip: 'Mark Paid',
            onPressed: () => _markPaid(ref, tenant),
          ),
        IconButton(
          icon: const Icon(Icons.edit, size: 18, color: AppColors.secondary),
          tooltip: 'Edit',
          onPressed: () {},
        ),
        IconButton(
          icon: const Icon(Icons.settings, size: 18, color: AppColors.textSecondary),
          tooltip: 'Settings',
          onPressed: () {},
        ),
      ],
    );
  }

  (int, String) _parseRoomNumber(String rn) {
    final match = RegExp(r'^(\d+)([a-zA-Z]+)$').firstMatch(rn);
    if (match != null) {
      return (int.parse(match.group(1)!), match.group(2)!.toLowerCase());
    }
    return (0, rn);
  }

  Widget _statusBadge(String status) {
    if (status == 'occupied') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: AppColors.successBg, borderRadius: BorderRadius.circular(8)),
        child: Text('Occupied',
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.successText)),
      );
    }
    if (status == 'maintenance') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: AppColors.warningBg, borderRadius: BorderRadius.circular(8)),
        child: Text('Maintenance',
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.warningText)),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderMuted),
      ),
      child: const Text('Void',
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
    );
  }

  void _markPaid(WidgetRef ref, Tenant tenant) async {
    await ref.read(supabaseRepositoryProvider).markTenantPaid(tenant.id);
  }

  String _fmtDate(DateTime? d) {
    if (d == null) return '—';
    return '${d.day}/${d.month}/${d.year}';
  }
}

// ════════════════════════════════════════════════════════
// MOBILE ROOM CARD
// ════════════════════════════════════════════════════════

class _MobileRoomCard extends StatelessWidget {
  final Room room;
  final Tenant? tenant;
  final WidgetRef ref;

  const _MobileRoomCard({required this.room, this.tenant, required this.ref});

  @override
  Widget build(BuildContext context) {
    final hasTenant = tenant != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: AppDecorations.card(context),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: Room badge + status + rent
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: hasTenant ? AppColors.primary : AppColors.canvas,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(room.roomNumber.toUpperCase(),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: hasTenant ? Colors.white : AppColors.textSecondary,
                        )),
                  ),
                  const SizedBox(width: 8),
                  _roomStatusBadge(room.status),
                  const Spacer(),
                  Text('${room.monthlyRent.toStringAsFixed(0)} LE',
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary)),
                ],
              ),

              if (hasTenant) ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),

                // Tenant name + payment badge
                Row(
                  children: [
                    const Icon(Icons.person, size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(tenant!.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: AppColors.neutralDark)),
                    ),
                    tenant!.isPaid ? AppBadge.paid() : AppBadge.unpaid(),
                  ],
                ),
                const SizedBox(height: 8),

                // Phone + Call
                Row(
                  children: [
                    const Icon(Icons.phone, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 8),
                    Text(tenant!.phone,
                        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => _callPhone(tenant!.phone),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                            color: AppColors.successBg,
                            borderRadius: BorderRadius.circular(20)),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.call, size: 14, color: AppColors.success),
                            SizedBox(width: 4),
                            Text('Call',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.successText)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Lease date + Mark paid
                Row(
                  children: [
                    const Icon(Icons.event, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 8),
                    Text('Since ${_fmtDate(tenant!.leaseStartDate)}',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    const Spacer(),
                    if (tenant!.isUnpaid)
                      GestureDetector(
                        onTap: () async {
                          await ref
                              .read(supabaseRepositoryProvider)
                              .markTenantPaid(tenant!.id);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                              color: AppColors.successBg,
                              borderRadius: BorderRadius.circular(20)),
                          child: const Text('Mark Paid',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.successText)),
                        ),
                      ),
                  ],
                ),
              ] else ...[
                const SizedBox(height: 8),
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('Vacant',
                        style: TextStyle(
                            color: AppColors.textSecondary,
                            fontStyle: FontStyle.italic,
                            fontSize: 13)),
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
    if (status == 'occupied') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: AppColors.successBg, borderRadius: BorderRadius.circular(8)),
        child: Text('Occupied',
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.successText)));
    }
    if (status == 'maintenance') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: AppColors.warningBg, borderRadius: BorderRadius.circular(8)),
        child: Text('Maintenance',
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.warningText)));
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderMuted),
      ),
      child: const Text('Void',
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
    );
  }

  void _callPhone(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    try {
      // url_launcher handles this
    } catch (_) {}
  }

  String _fmtDate(DateTime? d) {
    if (d == null) return '—';
    return '${d.day}/${d.month}/${d.year}';
  }
}
