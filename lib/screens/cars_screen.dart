// lib/screens/cars_screen.dart
// Car search screen - list all tenants with cars, searchable by license plate or car model.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/tenant.dart';
import '../providers/app_providers.dart';

class CarsScreen extends ConsumerStatefulWidget {
  const CarsScreen({super.key});

  @override
  ConsumerState<CarsScreen> createState() => _CarsScreenState();
}

class _CarsScreenState extends ConsumerState<CarsScreen> {
  static const double _desktopBreakpoint = 900.0;
  String _carSearchQuery = '';

  @override
  Widget build(BuildContext context) {
    final buildingId = ref.watch(currentBuildingIdProvider);
    final tenantsAsync = ref.watch(tenantsStreamProvider(buildingId));
    final isDesktop = MediaQuery.of(context).size.width > _desktopBreakpoint;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cars'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                labelText: 'Search by License Plate or Car Model',
                hintText: 'e.g. ABC-1234 or Toyota Camry',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _carSearchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() => _carSearchQuery = '');
                        },
                      )
                    : null,
                border: const OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() => _carSearchQuery = value.trim().toLowerCase());
              },
            ),
          ),
          const Divider(height: 1),
          // Cars List
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(tenantsStreamProvider(buildingId));
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
                        onPressed: () => ref.invalidate(tenantsStreamProvider(buildingId)),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
                data: (allTenants) {
                  // Filter tenants who have cars
                  var cars = allTenants.where((t) => t.hasCar && t.status == 'active').toList();

                  // Apply search filter
                  if (_carSearchQuery.isNotEmpty) {
                    cars = cars.where((t) {
                      final model = t.carModel?.toLowerCase() ?? '';
                      final plate = t.licensePlate?.toLowerCase() ?? '';
                      return model.contains(_carSearchQuery) || plate.contains(_carSearchQuery);
                    }).toList();
                  }

                  if (cars.isEmpty) {
                    return _buildEmptyCarsState(context, _carSearchQuery.isNotEmpty);
                  }

                  if (isDesktop) {
                    return _buildDesktopCarsTable(context, ref, cars);
                  }
                  return _buildMobileCarsList(context, ref, cars);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCarsState(BuildContext context, bool hasSearch) {
    return ListView(
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.25),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.directions_car_outlined, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                hasSearch ? 'No cars match your search' : 'No tenants with cars yet',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                hasSearch
                    ? 'Try a different search term'
                    : 'Add a tenant with car info to see it here',
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

  // ═══════════════════════════════════════════════════════
  // DESKTOP CARS TABLE
  // ═══════════════════════════════════════════════════════

  Widget _buildDesktopCarsTable(BuildContext context, WidgetRef ref, List<Tenant> cars) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Tenant Name')),
              DataColumn(label: Text('Phone')),
              DataColumn(label: Text('Room')),
              DataColumn(label: Text('Car Model')),
              DataColumn(label: Text('License Plate')),
              DataColumn(label: Text('Actions')),
            ],
            rows: cars.map((tenant) {
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
                  DataCell(Text(
                    tenant.phone,
                    style: TextStyle(color: isArchived ? Colors.grey : null),
                  )),
                  DataCell(Text(
                    tenant.roomId?.toString() ?? '-',
                    style: TextStyle(color: isArchived ? Colors.grey : null),
                  )),
                  DataCell(Text(
                    tenant.carModel ?? '-',
                    style: TextStyle(color: isArchived ? Colors.grey : null),
                  )),
                  DataCell(Text(
                    tenant.licensePlate ?? '-',
                    style: TextStyle(
                      color: isArchived ? Colors.grey : null,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'monospace',
                    ),
                  )),
                  DataCell(Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: () => _callTenant(tenant.phone),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.call, size: 16, color: Colors.green),
                              SizedBox(width: 4),
                              Text('Call', style: TextStyle(color: Colors.green, fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () => _openWhatsApp(tenant.phone),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.green[700]!.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.chat, size: 16, color: Colors.green[700]),
                              const SizedBox(width: 4),
                              Text('WhatsApp', style: TextStyle(color: Colors.green[700], fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // MOBILE CARS LIST
  // ═══════════════════════════════════════════════════════

  Widget _buildMobileCarsList(BuildContext context, WidgetRef ref, List<Tenant> cars) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: cars.length,
      itemBuilder: (context, index) {
        final tenant = cars[index];
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
                // Header: Tenant Name + Car Icon
                Row(
                  children: [
                    _buildGenderIcon(tenant.gender),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        tenant.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isArchived ? Colors.grey : null,
                            ),
                      ),
                    ),
                    Icon(Icons.directions_car, color: Colors.blue[700], size: 24),
                  ],
                ),
                const SizedBox(height: 12),

                // Phone row
                Row(
                  children: [
                    Icon(Icons.phone, size: 18, color: isArchived ? Colors.grey : Colors.grey[600]),
                    const SizedBox(width: 8),
                    Text(tenant.phone,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: isArchived ? Colors.grey : null)),
                    const Spacer(),
                    InkWell(
                      onTap: () => _callTenant(tenant.phone),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.call, size: 16, color: Colors.green),
                            SizedBox(width: 4),
                            Text('Call', style: TextStyle(color: Colors.green, fontWeight: FontWeight.w500)),
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
                    Icon(Icons.meeting_room, size: 18, color: isArchived ? Colors.grey : Colors.grey[600]),
                    const SizedBox(width: 8),
                    Text(
                      tenant.roomId != null ? 'Room ${tenant.roomId}' : 'No room assigned',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: isArchived ? Colors.grey : null),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Car Model row
                if (tenant.carModel != null) ...[
                  Row(
                    children: [
                      Icon(Icons.model_training, size: 18, color: isArchived ? Colors.grey : Colors.grey[600]),
                      const SizedBox(width: 8),
                      Text(
                        'Car: ${tenant.carModel}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: isArchived ? Colors.grey : null,
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],

                // License Plate row
                if (tenant.licensePlate != null) ...[
                  Row(
                    children: [
                      Icon(Icons.badge, size: 18, color: isArchived ? Colors.grey : Colors.grey[600]),
                      const SizedBox(width: 8),
                      Text(
                        'Plate: ${tenant.licensePlate}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: isArchived ? Colors.grey : null,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace'),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 12),

                // Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () => _callTenant(tenant.phone),
                      icon: const Icon(Icons.call, size: 18, color: Colors.green),
                      label: const Text('Call', style: TextStyle(color: Colors.green)),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () => _openWhatsApp(tenant.phone),
                      icon: Icon(Icons.chat, size: 18, color: Colors.green[700]),
                      label: Text('WhatsApp', style: TextStyle(color: Colors.green[700])),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () => _showAddEditDialog(context, ref, tenant: tenant),
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('Edit'),
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

  // ═══════════════════════════════════════════════════════
  // WHATSAPP HELPER
  // ═══════════════════════════════════════════════════════

  Future<void> _openWhatsApp(String phone) async {
    // Remove any non-digit characters
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    // Egypt country code is 20
    final whatsappPhone = cleanPhone.startsWith('20') ? cleanPhone : '20$cleanPhone';
    final uri = Uri.parse('https://wa.me/$whatsappPhone');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      // Silently fail
    }
  }

  Future<void> _callTenant(String phone) async {
    final uri = Uri.parse('tel:$phone');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (_) {
      // Silently fail
    }
  }

  Widget _buildGenderIcon(String? gender) {
    if (gender == 'male') {
      return const Icon(Icons.male, color: Colors.blue, size: 22);
    } else if (gender == 'female') {
      return const Icon(Icons.female, color: Colors.pink, size: 22);
    }
    return const Icon(Icons.person, color: Colors.grey, size: 22);
  }

  void _showAddEditDialog(BuildContext context, WidgetRef ref, {Tenant? tenant}) {
    // Navigate to Tenants screen to edit - could also implement direct edit here
    // For now, just show a snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Use the Tenants screen to edit tenant details')),
    );
  }
}