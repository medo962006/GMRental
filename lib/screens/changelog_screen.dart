// lib/screens/changelog_screen.dart
// Changelog — logs ALL changes/additions by any admin using a unique device code.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_theme.dart';
import '../models/changelog_entry.dart';
import '../providers/app_providers.dart';
import '../repositories/supabase_repository.dart';

class ChangelogScreen extends ConsumerStatefulWidget {
  const ChangelogScreen({super.key});

  @override
  ConsumerState<ChangelogScreen> createState() => _ChangelogScreenState();
}

class _ChangelogScreenState extends ConsumerState<ChangelogScreen> {
  String _search = '';
  String _filterAll = 'all'; // all, create, update, delete, archive, mark_paid

  @override
  Widget build(BuildContext context) {
    final buildingId = ref.watch(currentBuildingIdProvider);
    final changelogAsync = ref.watch(changelogStreamProvider(buildingId));
    final isDesktop = MediaQuery.of(context).size.width > 800;

    return Column(
        children: [
          // Header
          Container(
            color: AppColors.surface,
            padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(children: [
              Row(children: [
                const Icon(Icons.history, size: 20, color: AppColors.primary),
                const SizedBox(width: 8),
                const Text('Changelog',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
                const Spacer(),
                // Device code indicator
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.canvas,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.borderMuted),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.devices, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text('ADMIN001', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                  ]),
                ),
              ]),
              const SizedBox(height: 8),
              // Search
              TextField(
                decoration: InputDecoration(
                  hintText: 'Search changes...',
                  prefixIcon: const Icon(Icons.search, size: 18),
                  filled: true,
                  fillColor: AppColors.canvas,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.borderMuted)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.borderMuted)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.accent, width: 2)),
                ),
                style: const TextStyle(fontSize: 13),
                onChanged: (v) => setState(() => _search = v),
              ),
              const SizedBox(height: 8),
              // Filter chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  _filterChip('All', 'all'),
                  const SizedBox(width: 6),
                  _filterChip('Created', 'create'),
                  const SizedBox(width: 6),
                  _filterChip('Updated', 'update'),
                  const SizedBox(width: 6),
                  _filterChip('Deleted', 'delete'),
                  const SizedBox(width: 6),
                  _filterChip('Archived', 'archive'),
                  const SizedBox(width: 6),
                  _filterChip('Marked Paid', 'mark_paid'),
                ]),
              ),
            ]),
          ),
          const Divider(height: 1),

          // Content
          Expanded(
            child: changelogAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: AppColors.danger))),
              data: (List<ChangelogEntry> entries) {
                var filtered = entries;
                if (_filterAll != 'all') {
                  filtered = filtered.where((e) => e.action == _filterAll).toList();
                }
                if (_search.isNotEmpty) {
                  final q = _search.toLowerCase();
                  filtered = filtered.where((e) =>
                    (e.entityName?.toLowerCase().contains(q) ?? false) ||
                    (e.details?.toLowerCase().contains(q) ?? false) ||
                    e.action.toLowerCase().contains(q) ||
                    e.entityType.toLowerCase().contains(q) ||
                    e.deviceCode.toLowerCase().contains(q)
                  ).toList();
                }

                if (filtered.isEmpty) {
                  return const Center(
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.history_toggle_off, size: 48, color: AppColors.textSecondary),
                      SizedBox(height: 8),
                      Text('No changes recorded yet', style: TextStyle(color: AppColors.textSecondary)),
                    ]),
                  );
                }

                if (isDesktop) {
                  return _buildDesktopTable(filtered);
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) => _EntryCard(entry: filtered[i]),
                );
              },
            ),
          ),
        ],
      );
    }

  Widget _filterChip(String label, String value) {
    final isSelected = _filterAll == value;
    return GestureDetector(
      onTap: () => setState(() => _filterAll = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.canvas,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? AppColors.primary : AppColors.borderMuted),
        ),
        child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isSelected ? Colors.white : AppColors.textSecondary)),
      ),
    );
  }

  Widget _buildDesktopTable(List<ChangelogEntry> entries) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${entries.length} entries', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        const SizedBox(height: 12),
        DecoratedBox(
          decoration: AppDecorations.card(context),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(AppColors.primary),
                headingTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                dataRowMinHeight: 48,
                dataRowMaxHeight: 48,
                columns: const [
                  DataColumn(label: Text('Time')),
                  DataColumn(label: Text('Action')),
                  DataColumn(label: Text('Entity')),
                  DataColumn(label: Text('Name')),
                  DataColumn(label: Text('Building')),
                  DataColumn(label: Text('Device')),
                  DataColumn(label: Text('Details')),
                ],
                rows: entries.map((e) => DataRow(cells: [
                  DataCell(Text(e.timeAgo, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary))),
                  DataCell(_actionBadge(e.action)),
                  DataCell(Text(e.entityTypeLabel, style: const TextStyle(fontSize: 12))),
                  DataCell(Text(e.entityName ?? '—', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
                  DataCell(Text(e.buildingLabel, style: const TextStyle(fontSize: 11))),
                  DataCell(Text(e.deviceCode, style: const TextStyle(fontSize: 10, fontFamily: 'monospace'))),
                  DataCell(Text(e.details ?? '—', style: const TextStyle(fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis)),
                ])).toList(),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _actionBadge(String action) {
    Color bg, fg;
    switch (action) {
      case 'create': bg = AppColors.successBg; fg = AppColors.successText; break;
      case 'update': bg = AppColors.infoBg; fg = AppColors.infoText; break;
      case 'delete': bg = AppColors.dangerBg; fg = AppColors.dangerText; break;
      case 'archive': bg = AppColors.warningBg; fg = AppColors.warningText; break;
      case 'mark_paid': bg = AppColors.successBg; fg = AppColors.successText; break;
      default: bg = AppColors.canvas; fg = AppColors.textSecondary;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(action, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: fg)),
    );
  }
}

class _EntryCard extends StatelessWidget {
  final ChangelogEntry entry;
  const _EntryCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color iconColor;
    switch (entry.action) {
      case 'create': icon = Icons.add_circle; iconColor = AppColors.success; break;
      case 'update': icon = Icons.edit; iconColor = AppColors.accent; break;
      case 'delete': icon = Icons.delete; iconColor = AppColors.danger; break;
      case 'archive': icon = Icons.archive; iconColor = AppColors.warning; break;
      case 'mark_paid': icon = Icons.check_circle; iconColor = AppColors.success; break;
      default: icon = Icons.info; iconColor = AppColors.textSecondary;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: AppDecorations.card(context),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(entry.actionLabel, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(width: 6),
                  Text(entry.entityTypeLabel, style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  const Spacer(),
                  Text(entry.timeAgo, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                ]),
                if (entry.entityName != null) ...[
                  const SizedBox(height: 2),
                  Text(entry.entityName!, style: const TextStyle(fontSize: 12, color: AppColors.neutralDark)),
                ],
                if (entry.details != null && entry.details!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(entry.details!, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
                const SizedBox(height: 4),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: AppColors.canvas, borderRadius: BorderRadius.circular(6)),
                    child: Text(entry.buildingLabel, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: AppColors.canvas, borderRadius: BorderRadius.circular(6)),
                    child: Text(entry.deviceCode, style: const TextStyle(fontSize: 9, fontFamily: 'monospace')),
                  ),
                ]),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}
