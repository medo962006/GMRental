// lib/screens/tenants_screen.dart
// CRUD screen for managing hostel tenants.
// Responsive: desktop shows DataTable, mobile shows card list.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';
import '../models/tenant.dart';
import '../providers/app_providers.dart';

class TenantsScreen extends ConsumerStatefulWidget {
  const TenantsScreen({super.key});

  @override
  ConsumerState<TenantsScreen> createState() => _TenantsScreenState();
}

class _TenantsScreenState extends ConsumerState<TenantsScreen> {
  static const double _desktopBreakpoint = 900.0;

  // Filter: 0=All, 1=Active, 2=Unpaid, 3=Overdue, 4=Archived
  int _selectedFilter = 0;

  @override
  Widget build(BuildContext context) {
    final tenantsAsync = ref.watch(tenantsStreamProvider);
    final isDesktop = MediaQuery.of(context).size.width > _desktopBreakpoint;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tenants'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: Column(
        children: [
          // ── Filter Chips ──────────────────────────────
          _buildFilterChips(),
          const Divider(height: 1),
          // ── Tenant List ───────────────────────────────
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(tenantsStreamProvider);
              },
              child: tenantsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                      const SizedBox(height: 16),
                      Text('Error loading tenants',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text('$err', style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => ref.invalidate(tenantsStreamProvider),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
                data: (allTenants) {
                  final filtered = _applyFilter(allTenants);
                  if (filtered.isEmpty) {
                    return _buildEmptyState(context, allTenants.isEmpty);
                  }
                  if (isDesktop) {
                    return _buildDesktopTable(context, ref, filtered);
                  }
                  return _buildMobileList(context, ref, filtered);
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditDialog(context, ref),
        icon: const Icon(Icons.person_add),
        label: const Text('Add Tenant'),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // FILTER CHIPS
  // ══════════════════════════════════════════════════════

  Widget _buildFilterChips() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _filterChip('All', 0),
            const SizedBox(width: 8),
            _filterChip('Active', 1),
            const SizedBox(width: 8),
            _filterChip('Unpaid', 2),
            const SizedBox(width: 8),
            _filterChip('Overdue', 3),
            const SizedBox(width: 8),
            _filterChip('Archived', 4),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String label, int index) {
    final isSelected = _selectedFilter == index;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        setState(() => _selectedFilter = index);
      },
      selectedColor: Theme.of(context).colorScheme.primaryContainer,
      checkmarkColor: Theme.of(context).colorScheme.primary,
    );
  }

  List<Tenant> _applyFilter(List<Tenant> tenants) {
    switch (_selectedFilter) {
      case 1: // Active
        return tenants.where((t) => t.isActive).toList();
      case 2: // Unpaid
        return tenants.where((t) => t.isUnpaid).toList();
      case 3: // Overdue
        return tenants.where((t) => t.isOverdue).toList();
      case 4: // Archived
        return tenants.where((t) => t.status == 'archived').toList();
      default: // All
        return tenants;
    }
  }

  // ══════════════════════════════════════════════════════
  // EMPTY STATE
  // ══════════════════════════════════════════════════════

  Widget _buildEmptyState(BuildContext context, bool noTenantsAtAll) {
    return ListView(
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.25),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                noTenantsAtAll ? 'No tenants yet' : 'No tenants match this filter',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                noTenantsAtAll
                    ? 'Tap the + button to add your first tenant.'
                    : 'Try selecting a different filter.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[500],
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════
  // DESKTOP TABLE
  // ══════════════════════════════════════════════════════

  Widget _buildDesktopTable(
      BuildContext context, WidgetRef ref, List<Tenant> tenants) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Name')),
              DataColumn(label: Text('Phone')),
              DataColumn(label: Text('Room')),
              DataColumn(label: Text('Gender')),
              DataColumn(label: Text('Insurance')),
              DataColumn(label: Text('Payment')),
              DataColumn(label: Text('Due Date')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Actions')),
            ],
            rows: tenants.map((tenant) {
              final isArchived = tenant.status == 'archived';
              return DataRow(
                cells: [
                  DataCell(Text(
                    tenant.name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isArchived ? Colors.grey : null,
                    ),
                  )),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          tenant.phone,
                          style: TextStyle(
                            color: isArchived ? Colors.grey : null,
                          ),
                        ),
                        const SizedBox(width: 4),
                        InkWell(
                          onTap: () => _callTenant(tenant.phone),
                          child: const Icon(Icons.phone,
                              size: 16, color: Colors.green),
                        ),
                      ],
                    ),
                  ),
                  DataCell(Text(
                    tenant.roomId?.toString() ?? '-',
                    style: TextStyle(color: isArchived ? Colors.grey : null),
                  )),
                  DataCell(_buildGenderIcon(tenant.gender)),
                  DataCell(Text(
                    tenant.insuranceAmount > 0
                        ? '${_formatCurrency(tenant.insuranceAmount)} ${AppConfig.currency}'
                        : '-',
                    style: TextStyle(color: isArchived ? Colors.grey : null),
                  )),
                  DataCell(_buildPaymentBadge(tenant)),
                  DataCell(_buildDueDate(tenant)),
                  DataCell(_buildStatusBadge(tenant)),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (tenant.isUnpaid && !isArchived)
                          IconButton(
                            icon: const Icon(Icons.check_circle,
                                size: 20, color: Colors.green),
                            tooltip: 'Mark as Paid',
                            onPressed: () => _markPaid(context, ref, tenant),
                          ),
                        if (!isArchived)
                          IconButton(
                            icon: const Icon(Icons.archive,
                                size: 20, color: Colors.orange),
                            tooltip: 'Archive',
                            onPressed: () => _confirmArchive(context, ref, tenant),
                          ),
                        IconButton(
                          icon: const Icon(Icons.edit, size: 20),
                          tooltip: 'Edit',
                          onPressed: () =>
                              _showAddEditDialog(context, ref, tenant: tenant),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete,
                              size: 20, color: Colors.red),
                          tooltip: 'Delete',
                          onPressed: () =>
                              _confirmDelete(context, ref, tenant),
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
      BuildContext context, WidgetRef ref, List<Tenant> tenants) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: tenants.length,
      itemBuilder: (context, index) {
        final tenant = tenants[index];
        final isArchived = tenant.status == 'archived';
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: isArchived ? 0 : 2,
          color: isArchived ? Colors.grey[100] : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row: Name + Gender + Payment badge + Status badge
                Row(
                  children: [
                    _buildGenderIcon(tenant.gender),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        tenant.name,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: isArchived ? Colors.grey : null,
                                ),
                      ),
                    ),
                    if (isArchived)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'Archived',
                          style: TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      )
                    else
                      _buildPaymentBadge(tenant),
                  ],
                ),
                const SizedBox(height: 12),

                // Phone row
                Row(
                  children: [
                    Icon(Icons.phone, size: 18,
                        color: isArchived ? Colors.grey : Colors.grey[600]),
                    const SizedBox(width: 8),
                    Text(tenant.phone,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: isArchived ? Colors.grey : null)),
                    const Spacer(),
                    InkWell(
                      onTap: () => _callTenant(tenant.phone),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.call, size: 16, color: Colors.green),
                            SizedBox(width: 4),
                            Text('Call',
                                style: TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Room row
                Row(
                  children: [
                    Icon(Icons.meeting_room, size: 18,
                        color: isArchived ? Colors.grey : Colors.grey[600]),
                    const SizedBox(width: 8),
                    Text(
                      tenant.roomId != null
                          ? 'Room ${tenant.roomId}'
                          : 'No room assigned',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: isArchived ? Colors.grey : null),
                    ),
                  ],
                ),

                // Insurance row
                if (tenant.insuranceAmount > 0) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.security, size: 18,
                          color: isArchived ? Colors.grey : Colors.grey[600]),
                      const SizedBox(width: 8),
                      Text(
                        'Insurance: ${_formatCurrency(tenant.insuranceAmount)} ${AppConfig.currency}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: isArchived ? Colors.grey : null),
                      ),
                    ],
                  ),
                ],

                // Due date row
                if (tenant.dueDate != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.event,
                          size: 18,
                          color: tenant.isOverdue && !isArchived
                              ? Colors.red
                              : Colors.grey[600]),
                      const SizedBox(width: 8),
                      Text(
                        'Due: ${_formatDate(tenant.dueDate!)}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: tenant.isOverdue && !isArchived
                                  ? Colors.red
                                  : (isArchived ? Colors.grey : null),
                              fontWeight: tenant.isOverdue && !isArchived
                                  ? FontWeight.bold
                                  : null,
                            ),
                      ),
                      if (tenant.isOverdue && !isArchived) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.warning, size: 16, color: Colors.red),
                      ],
                    ],
                  ),
                ],

                const SizedBox(height: 12),

                // Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (tenant.isUnpaid && !isArchived)
                      TextButton.icon(
                        onPressed: () => _markPaid(context, ref, tenant),
                        icon: const Icon(Icons.check_circle, size: 18),
                        label: const Text('Mark Paid'),
                        style: TextButton.styleFrom(
                            foregroundColor: Colors.green),
                      ),
                    if (!isArchived)
                      TextButton.icon(
                        onPressed: () =>
                            _confirmArchive(context, ref, tenant),
                        icon: const Icon(Icons.archive, size: 18,
                            color: Colors.orange),
                        label: const Text('Archive',
                            style: TextStyle(color: Colors.orange)),
                      ),
                    TextButton.icon(
                      onPressed: () =>
                          _showAddEditDialog(context, ref, tenant: tenant),
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('Edit'),
                    ),
                    TextButton.icon(
                      onPressed: () => _confirmDelete(context, ref, tenant),
                      icon: const Icon(Icons.delete, size: 18, color: Colors.red),
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
  // BADGES & ICONS
  // ══════════════════════════════════════════════════════

  Widget _buildGenderIcon(String? gender) {
    if (gender == 'male') {
      return const Icon(Icons.male, color: Colors.blue, size: 22);
    } else if (gender == 'female') {
      return const Icon(Icons.female, color: Colors.pink, size: 22);
    }
    return const Icon(Icons.person, color: Colors.grey, size: 22);
  }

  Widget _buildPaymentBadge(Tenant tenant) {
    if (tenant.isPaid) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
        ),
        child: const Text(
          'Paid',
          style: TextStyle(
            color: Colors.green,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
      ),
      child: const Text(
        'Unpaid',
        style: TextStyle(
          color: Colors.red,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildStatusBadge(Tenant tenant) {
    if (tenant.status == 'archived') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.5)),
        ),
        child: const Text(
          'Archived',
          style: TextStyle(
            color: Colors.grey,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
      ),
      child: const Text(
        'Active',
        style: TextStyle(
          color: Colors.green,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildDueDate(Tenant tenant) {
    if (tenant.dueDate == null) {
      return const Text('-');
    }
    final isOverdue = tenant.isOverdue;
    return Text(
      _formatDate(tenant.dueDate!),
      style: TextStyle(
        color: isOverdue ? Colors.red : null,
        fontWeight: isOverdue ? FontWeight.bold : null,
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // CALL TENANT
  // ══════════════════════════════════════════════════════

  Future<void> _callTenant(String phone) async {
    final uri = Uri.parse('tel:$phone');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (_) {
      // Silently fail if url_launcher is not configured
    }
  }

  // ══════════════════════════════════════════════════════
  // MARK AS PAID
  // ══════════════════════════════════════════════════════

  Future<void> _markPaid(
      BuildContext context, WidgetRef ref, Tenant tenant) async {
    final repo = ref.read(supabaseRepositoryProvider);
    try {
      await repo.markTenantPaid(tenant.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${tenant.name} marked as paid'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ══════════════════════════════════════════════════════
  // ARCHIVE TENANT
  // ══════════════════════════════════════════════════════

  void _confirmArchive(BuildContext context, WidgetRef ref, Tenant tenant) {
    final roomLabel = tenant.roomId != null ? 'Room ${tenant.roomId}' : 'their room';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Archive Tenant'),
        content: Text(
          'Archiving this tenant will mark $roomLabel as available and create a deep clean task. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () async {
              Navigator.of(ctx).pop();
              final repo = ref.read(supabaseRepositoryProvider);
              try {
                await repo.updateTenant(tenant.copyWith(status: 'archived'));
                if (context.mounted) {
                  final roomText = tenant.roomId != null
                      ? 'Room ${tenant.roomId}'
                      : 'their room';
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          'Tenant archived. Deep clean task created for $roomText.'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error archiving tenant: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Archive'),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // ADD / EDIT DIALOG
  // ══════════════════════════════════════════════════════

  void _showAddEditDialog(BuildContext context, WidgetRef ref,
      {Tenant? tenant}) {
    showDialog(
      context: context,
      builder: (ctx) => _TenantFormDialog(
        tenant: tenant,
        onSave: (Tenant savedTenant) async {
          final repo = ref.read(supabaseRepositoryProvider);
          try {
            if (tenant == null) {
              await repo.addTenant(savedTenant);
            } else {
              await repo.updateTenant(savedTenant);
            }
            if (ctx.mounted) {
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(tenant == null
                      ? 'Tenant ${savedTenant.name} added'
                      : 'Tenant ${savedTenant.name} updated'),
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

  void _confirmDelete(BuildContext context, WidgetRef ref, Tenant tenant) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Tenant'),
        content: Text(
            'Are you sure you want to delete ${tenant.name}? This action cannot be undone.'),
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
                await repo.deleteTenant(tenant.id);
                if (ctx.mounted) Navigator.of(ctx).pop();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${tenant.name} deleted'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text('Error deleting tenant: $e'),
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

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

// ══════════════════════════════════════════════════════
// TENANT FORM DIALOG (StatefulWidget)
// ══════════════════════════════════════════════════════

class _TenantFormDialog extends StatefulWidget {
  final Tenant? tenant;
  final Function(Tenant) onSave;

  const _TenantFormDialog({this.tenant, required this.onSave});

  @override
  State<_TenantFormDialog> createState() => _TenantFormDialogState();
}

class _TenantFormDialogState extends State<_TenantFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _insuranceController;

  String? _selectedGender;
  int? _selectedRoomId;
  String _selectedPaymentStatus = 'unpaid';
  String _selectedStatus = 'active';
  DateTime? _selectedDueDate;

  static const List<String> _genders = ['male', 'female'];
  static const List<String> _paymentStatuses = ['paid', 'unpaid'];
  static const List<String> _statuses = ['active', 'archived'];

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.tenant?.name ?? '');
    _phoneController =
        TextEditingController(text: widget.tenant?.phone ?? '');
    _insuranceController = TextEditingController(
        text: widget.tenant != null && widget.tenant!.insuranceAmount > 0
            ? widget.tenant!.insuranceAmount.toString()
            : '');
    _selectedGender = widget.tenant?.gender;
    _selectedRoomId = widget.tenant?.roomId;
    _selectedPaymentStatus = widget.tenant?.paymentStatus ?? 'unpaid';
    _selectedStatus = widget.tenant?.status ?? 'active';
    _selectedDueDate = widget.tenant?.dueDate;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _insuranceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.tenant != null;

    return AlertDialog(
      title: Text(isEditing ? 'Edit Tenant' : 'Add New Tenant'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Name
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    hintText: 'e.g. Ahmed Ali',
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Phone
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    hintText: 'e.g. 01234567890',
                    prefixIcon: Icon(Icons.phone),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Phone number is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Gender Dropdown
                DropdownButtonFormField<String>(
                  value: _selectedGender,
                  decoration: const InputDecoration(
                    labelText: 'Gender',
                    prefixIcon: Icon(Icons.wc),
                    border: OutlineInputBorder(),
                  ),
                  items: _genders.map((g) {
                    return DropdownMenuItem(
                      value: g,
                      child: Row(
                        children: [
                          Icon(
                            g == 'male' ? Icons.male : Icons.female,
                            color: g == 'male' ? Colors.blue : Colors.pink,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(g[0].toUpperCase() + g.substring(1)),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() => _selectedGender = val);
                  },
                ),
                const SizedBox(height: 16),

                // Room Dropdown
                Consumer(
                  builder: (context, ref, _) {
                    final roomsAsync = ref.watch(roomsStreamProvider);
                    return roomsAsync.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (_, __) => const Text('Error loading rooms'),
                      data: (rooms) {
                        // Ensure selectedRoomId is valid
                        final validRoomIds = rooms.map((r) => r.id).toSet();
                        if (_selectedRoomId != null &&
                            !validRoomIds.contains(_selectedRoomId)) {
                          _selectedRoomId = null;
                        }
                        return DropdownButtonFormField<int>(
                          value: _selectedRoomId,
                          decoration: const InputDecoration(
                            labelText: 'Room',
                            prefixIcon: Icon(Icons.meeting_room),
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            const DropdownMenuItem<int>(
                              value: null,
                              child: Text('No room assigned'),
                            ),
                            ...rooms.map((r) {
                              return DropdownMenuItem<int>(
                                value: r.id,
                                child: Text(
                                    'Room ${r.roomNumber} (${r.status})'),
                              );
                            }),
                          ],
                          onChanged: (val) {
                            setState(() => _selectedRoomId = val);
                          },
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 16),

                // Insurance Amount
                TextFormField(
                  controller: _insuranceController,
                  decoration: InputDecoration(
                    labelText: 'Insurance Amount',
                    hintText: 'e.g. 500',
                    prefixIcon: const Icon(Icons.security),
                    suffixText: AppConfig.currency,
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  validator: (val) {
                    if (val != null && val.trim().isNotEmpty) {
                      final parsed = double.tryParse(val.trim());
                      if (parsed == null || parsed < 0) {
                        return 'Enter a valid amount';
                      }
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Payment Status Dropdown
                DropdownButtonFormField<String>(
                  value: _selectedPaymentStatus,
                  decoration: const InputDecoration(
                    labelText: 'Payment Status',
                    prefixIcon: Icon(Icons.payment),
                    border: OutlineInputBorder(),
                  ),
                  items: _paymentStatuses.map((s) {
                    return DropdownMenuItem(
                      value: s,
                      child: Row(
                        children: [
                          Icon(
                            s == 'paid'
                                ? Icons.check_circle
                                : Icons.cancel,
                            color:
                                s == 'paid' ? Colors.green : Colors.red,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(s[0].toUpperCase() + s.substring(1)),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedPaymentStatus = val);
                    }
                  },
                ),
                const SizedBox(height: 16),

                // Status Dropdown (active / archived)
                if (isEditing)
                  DropdownButtonFormField<String>(
                    value: _selectedStatus,
                    decoration: const InputDecoration(
                      labelText: 'Tenant Status',
                      prefixIcon: Icon(Icons.flag),
                      border: OutlineInputBorder(),
                    ),
                    items: _statuses.map((s) {
                      return DropdownMenuItem(
                        value: s,
                        child: Row(
                          children: [
                            Icon(
                              s == 'active'
                                  ? Icons.check_circle
                                  : Icons.archive,
                              color: s == 'active'
                                  ? Colors.green
                                  : Colors.grey,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(s[0].toUpperCase() + s.substring(1)),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedStatus = val);
                      }
                    },
                  ),
                if (isEditing) const SizedBox(height: 16),

                // Due Date Picker
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDueDate ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      setState(() => _selectedDueDate = picked);
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Due Date',
                      prefixIcon: Icon(Icons.event),
                      border: OutlineInputBorder(),
                    ),
                    child: Text(
                      _selectedDueDate != null
                          ? '${_selectedDueDate!.year}-${_selectedDueDate!.month.toString().padLeft(2, '0')}-${_selectedDueDate!.day.toString().padLeft(2, '0')}'
                          : 'Select due date (optional)',
                      style: TextStyle(
                        color: _selectedDueDate != null
                            ? Theme.of(context).textTheme.bodyLarge?.color
                            : Theme.of(context).hintColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final insurance = _insuranceController.text.trim().isNotEmpty
                  ? double.parse(_insuranceController.text.trim())
                  : 0.0;

              final tenant = Tenant(
                id: widget.tenant?.id ?? '',
                name: _nameController.text.trim(),
                phone: _phoneController.text.trim(),
                gender: _selectedGender,
                roomId: _selectedRoomId,
                status: _selectedStatus,
                insuranceAmount: insurance,
                insuranceReturned: widget.tenant?.insuranceReturned ?? false,
                paymentStatus: _selectedPaymentStatus,
                dueDate: _selectedDueDate,
                createdAt: widget.tenant?.createdAt ?? DateTime.now(),
              );
              widget.onSave(tenant);
            }
          },
          child: Text(isEditing ? 'Update' : 'Add'),
        ),
      ],
    );
  }
}
