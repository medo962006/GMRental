// lib/widgets/booking_card_widget.dart
// Booking card widget — shows booking info with optional Cancel button.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_theme.dart';
import '../models/booking.dart';
import '../providers/booking_provider.dart';
import '../providers/app_providers.dart';

class BookingCardWidget extends ConsumerWidget {
  final Booking booking;

  const BookingCardWidget({
    super.key,
    required this.booking,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final buildingId = ref.watch(currentBuildingIdProvider);
    final bookingNotifier = ref.watch(bookingProvider(buildingId).notifier);
    final isBeforeMatch = booking.isPending; // treat "before match" as pending

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: status badge + room info
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: booking.isPending
                        ? AppColors.warningBg
                        : booking.isConfirmed
                            ? AppColors.successBg
                            : booking.isCancelled
                                ? AppColors.dangerBg
                                : AppColors.infoBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    booking.status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: booking.isPending
                          ? AppColors.warningText
                          : booking.isConfirmed
                              ? AppColors.successText
                              : booking.isCancelled
                                  ? AppColors.dangerText
                                  : AppColors.infoText,
                    ),
                  ),
                ),
                const Spacer(),
                Icon(
                  booking.isCancelled ? Icons.cancel : Icons.book_online,
                  size: 20,
                  color: booking.isCancelled ? AppColors.danger : AppColors.primary,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Room number
            Text(
              'Room ${booking.roomNumber ?? 'N/A'}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.neutralDark,
              ),
            ),
            const SizedBox(height: 4),

            // Guest name
            if (booking.tenantName != null)
              Text(
                booking.tenantName!,
                style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),

            const SizedBox(height: 8),

            // Dates
            if (booking.checkInDate != null || booking.checkOutDate != null)
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    _formatDates(),
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),

            // Amount
            if (booking.amount != null) ...[
              const SizedBox(height: 4),
              Text(
                '${booking.amount!.toStringAsFixed(0)} LE',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],

            // Cancel button (for beforeMatch / pending bookings)
            if (isBeforeMatch && booking.canCancel) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _confirmCancel(context, ref, bookingNotifier),
                  icon: const Icon(Icons.cancel_outlined, size: 16),
                  label: const Text('Cancel Booking'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: const BorderSide(color: AppColors.danger),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    textStyle: const TextStyle(fontSize: 13),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDates() {
    if (booking.checkInDate == null && booking.checkOutDate == null) return '';
    final inStr = booking.checkInDate != null
        ? '${booking.checkInDate!.month}/${booking.checkInDate!.day}'
        : '?';
    final outStr = booking.checkOutDate != null
        ? '${booking.checkOutDate!.month}/${booking.checkOutDate!.day}'
        : '?';
    return '$inStr - $outStr';
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