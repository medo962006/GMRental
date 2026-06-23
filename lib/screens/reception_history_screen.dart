// lib/screens/reception_history_screen.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_theme.dart';
import '../providers/app_providers.dart';
import '../models/reception_history.dart';
import '../repositories/supabase_repository.dart';

class ReceptionHistoryScreen extends ConsumerStatefulWidget {
  const ReceptionHistoryScreen({super.key});

  @override
  ConsumerState<ReceptionHistoryScreen> createState() =>
      _ReceptionHistoryScreenState();
}

class _ReceptionHistoryScreenState
    extends ConsumerState<ReceptionHistoryScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final buildingId = ref.watch(currentBuildingIdProvider);
    final historyAsync = ref.watch(receptionHistoryStreamProvider(buildingId));
    final isDesktop = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Column(
        children: [
          // ── Header ──
          _buildHeader(isDesktop, buildingId),
          // ── Search ──
          _buildSearchBar(),
          // ── List ──
          Expanded(
            child: historyAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline,
                        size: 48, color: AppColors.danger.withValues(alpha: 0.4)),
                    const SizedBox(height: 12),
                    Text('Error: $e',
                        style: const TextStyle(color: AppColors.danger)),
                  ],
                ),
              ),
              data: (allEntries) {
                // Filter by search
                final entries = _searchQuery.isEmpty
                    ? allEntries
                    : allEntries
                        .where((e) =>
                            e.name
                                .toLowerCase()
                                .contains(_searchQuery.toLowerCase()) ||
                            e.roomNumber
                                .toLowerCase()
                                .contains(_searchQuery.toLowerCase()))
                        .toList();

                if (entries.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history,
                            size: 48, color: AppColors.borderMuted),
                        const SizedBox(height: 12),
                        Text(
                          _searchQuery.isEmpty
                              ? 'No history entries yet'
                              : 'No results for "$_searchQuery"',
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 14),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: EdgeInsets.symmetric(
                    horizontal: isDesktop ? 24 : 12,
                    vertical: 8,
                  ),
                  itemCount: entries.length,
                  itemBuilder: (_, i) => _buildEntryCard(entries[i]),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEntryDialog(null),
        backgroundColor: AppColors.accent,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  // ════════════════════════════════════════════════════════
  // HEADER
  // ════════════════════════════════════════════════════════
  Widget _buildHeader(bool isDesktop, int buildingId) {
    final buildingName = buildingId == 1 ? 'Gawy' : 'Baraka';

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 24 : 16,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.history, size: 20, color: AppColors.accent),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Reception History',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.neutralDark)),
                Text('$buildingName Building',
                    style:
                        const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════
  // SEARCH BAR
  // ════════════════════════════════════════════════════════
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        onChanged: (v) => setState(() => _searchQuery = v),
        decoration: InputDecoration(
          hintText: 'Search by name or room...',
          hintStyle: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          prefixIcon:
              const Icon(Icons.search, size: 20, color: AppColors.textSecondary),
          filled: true,
          fillColor: AppColors.surface,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.borderMuted),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.borderMuted),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════
  // ENTRY CARD
  // ════════════════════════════════════════════════════════
  Widget _buildEntryCard(ReceptionHistory entry) {
    final isRemoved = entry.leaseStatus == 'removed';
    final statusColor = isRemoved ? AppColors.danger : AppColors.success;
    final statusText = isRemoved ? 'REMOVED' : entry.leaseStatus;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderMuted),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showEntryDialog(entry),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Status indicator
              Container(
                width: 4,
                height: 48,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.neutralDark,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (entry.roomNumber.isNotEmpty) ...[
                          Icon(Icons.bed, size: 12, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Text(entry.roomNumber,
                              style: const TextStyle(
                                  fontSize: 11, color: AppColors.textSecondary)),
                          const SizedBox(width: 12),
                        ],
                        if (entry.moveInDate != null) ...[
                          Icon(Icons.calendar_today,
                              size: 12, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Text(_formatDate(entry.moveInDate!),
                              style: const TextStyle(
                                  fontSize: 11, color: AppColors.textSecondary)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // Status badge + actions
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: isRemoved ? AppColors.dangerText : AppColors.successText,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _actionButton(Icons.edit, AppColors.accent, () {
                        _showEntryDialog(entry);
                      }),
                      const SizedBox(width: 4),
                      _actionButton(Icons.delete_outline, AppColors.danger, () {
                        _confirmDelete(entry);
                      }),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionButton(IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }

  // ════════════════════════════════════════════════════════
  // ADD/EDIT DIALOG
  // ════════════════════════════════════════════════════════
  void _showEntryDialog(ReceptionHistory? existing) {
    final isEdit = existing != null;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final phoneCtrl = TextEditingController(text: existing?.phone ?? '');
    final nationalityCtrl =
        TextEditingController(text: existing?.nationality ?? '');
    final roomCtrl = TextEditingController(text: existing?.roomNumber ?? '');
    final insuranceCtrl = TextEditingController(
        text: existing?.insuranceAmount != null && existing!.insuranceAmount > 0
            ? existing.insuranceAmount.toStringAsFixed(0)
            : '');
    final durationCtrl =
        TextEditingController(text: existing?.leaseDuration ?? '');
    final paidCtrl = TextEditingController(
        text: existing?.amountPaidUpfront != null && existing!.amountPaidUpfront > 0
            ? existing.amountPaidUpfront.toStringAsFixed(0)
            : '');
    final remainingCtrl = TextEditingController(
        text: existing?.remainingAmount != null && existing!.remainingAmount > 0
            ? existing.remainingAmount.toStringAsFixed(0)
            : '');
    final paymentMethodCtrl =
        TextEditingController(text: existing?.paymentMethod ?? '');
    final statusCtrl =
        TextEditingController(text: existing?.leaseStatus ?? 'ساري');
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isEdit ? Icons.edit : Icons.person_add,
                size: 20,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(width: 12),
            Text(isEdit ? 'Edit Entry' : 'Add to History',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dialogField('Name', nameCtrl, Icons.person),
                _dialogField('Phone', phoneCtrl, Icons.phone),
                _dialogField('Nationality', nationalityCtrl, Icons.flag),
                _dialogField('Room', roomCtrl, Icons.bed),
                _dialogField('Insurance', insuranceCtrl, Icons.shield,
                    isNumber: true),
                _dialogField('Lease Duration', durationCtrl, Icons.timer),
                _dialogField('Paid Upfront', paidCtrl, Icons.payments,
                    isNumber: true),
                _dialogField('Remaining', remainingCtrl, Icons.money_off,
                    isNumber: true),
                _dialogField('Payment Method', paymentMethodCtrl, Icons.account_balance_wallet),
                _dialogField('Lease Status', statusCtrl, Icons.assignment),
                _dialogField('Notes', notesCtrl, Icons.note, maxLines: 2),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;

              final buildingId = ref.read(currentBuildingIdProvider);
              final repo = ref.read(supabaseRepositoryProvider);

              final entry = ReceptionHistory(
                id: existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                name: nameCtrl.text.trim(),
                phone: phoneCtrl.text.trim(),
                nationality: nationalityCtrl.text.trim(),
                buildingId: buildingId,
                roomNumber: roomCtrl.text.trim(),
                moveInDate: existing?.moveInDate,
                insuranceAmount: double.tryParse(insuranceCtrl.text) ?? 0,
                leaseDuration: durationCtrl.text.trim(),
                amountPaidUpfront: double.tryParse(paidCtrl.text) ?? 0,
                remainingAmount: double.tryParse(remainingCtrl.text) ?? 0,
                paymentMethod: paymentMethodCtrl.text.trim(),
                leaseStatus: statusCtrl.text.trim(),
                notes: notesCtrl.text.trim(),
                createdAt: existing?.createdAt ?? DateTime.now(),
                updatedAt: DateTime.now(),
              );

              try {
                if (isEdit) {
                  await repo.updateReceptionHistory(entry);
                } else {
                  await repo.addReceptionHistory(entry);
                }
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
            ),
            child: Text(isEdit ? 'Save' : 'Add'),
          ),
        ],
      ),
    );
  }

  Widget _dialogField(
    String label,
    TextEditingController ctrl,
    IconData icon, {
    bool isNumber = false,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: ctrl,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontSize: 12),
          prefixIcon: Icon(icon, size: 18, color: AppColors.textSecondary),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: AppColors.borderMuted),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: AppColors.borderMuted),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
          ),
          filled: true,
          fillColor: AppColors.canvas,
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════
  // DELETE CONFIRMATION
  // ════════════════════════════════════════════════════════
  void _confirmDelete(ReceptionHistory entry) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Entry?',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: Text('Remove "${entry.name}" from reception history?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                await ref
                    .read(supabaseRepositoryProvider)
                    .deleteReceptionHistory(entry.id);
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
