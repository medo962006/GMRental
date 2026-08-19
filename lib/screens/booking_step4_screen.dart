// lib/screens/booking_step4_screen.dart
// Booking Step 4 — confirmation screen with Cancel button.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_theme.dart';
import '../models/booking.dart';
import '../providers/booking_provider.dart';
import '../providers/app_providers.dart';

class BookingStep4Screen extends ConsumerWidget {
  final Booking booking;
  final VoidCallback? onConfirmed;

  const BookingStep4Screen({
    super.key,
    required this.booking,
    this.onConfirmed,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final buildingId = ref.watch(currentBuildingIdProvider);
    final bookingNotifier = ref.watch(bookingProvider(buildingId).notifier);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: const Text('Review Booking'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Booking summary card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.calendar_today, color: AppColors.primary, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Booking Summary',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.neutralDark,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    _summaryRow('Room', booking.roomNumber ?? 'N/A'),
                    _summaryRow('Guest', booking.tenantName ?? 'N/A'),
                    _summaryRow('Phone', booking.tenantPhone ?? 'N/A'),
                    if (booking.checkInDate != null)
                      _summaryRow(
                        'Check In',
                        '${booking.checkInDate!.year}-${booking.checkInDate!.month.toString().padLeft(2, '0')}-${booking.checkInDate!.day.toString().padLeft(2, '0')}',
                      ),
                    if (booking.checkOutDate != null)
                      _summaryRow(
                        'Check Out',
                        '${booking.checkOutDate!.year}-${booking.checkOutDate!.month.toString().padLeft(2, '0')}-${booking.checkOutDate!.day.toString().padLeft(2, '0')}',
                      ),
                    if (booking.amount != null)
                      _summaryRow('Amount', '${booking.amount!.toStringAsFixed(0)} LE'),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: booking.isPending
                            ? AppColors.warningBg
                            : booking.isConfirmed
                                ? AppColors.successBg
                                : AppColors.dangerBg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        booking.status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: booking.isPending
                              ? AppColors.warningText
                              : booking.isConfirmed
                                  ? AppColors.successText
                                  : AppColors.dangerText,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Cancel button
            if (booking.canCancel)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _confirmCancel(context, ref, bookingNotifier),
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('Cancel Booking'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: const BorderSide(color: AppColors.danger),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        ],
      ),
    );
  }

  Future<void> _confirmCancel(
    BuildContext context,
    WidgetRef ref,
    BookingNotifier notifier,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Booking'),
        content: const Text('Are you sure you want to cancel this booking?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      await notifier.cancelBooking(booking.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Booking cancelled successfully')),
        );
      }
    }
  }
}