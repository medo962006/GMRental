// lib/providers/booking_provider.dart
// Booking provider — manages booking state and cancellation.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/booking.dart';
import '../repositories/supabase_repository.dart';
import 'app_providers.dart';

/// Booking notifier — manages booking operations.
class BookingNotifier extends StateNotifier<AsyncValue<List<Booking>>> {
  final SupabaseRepository _repo;
  final int _buildingId;

  BookingNotifier(this._repo, this._buildingId) : super(const AsyncValue.loading()) {
    _init();
  }

  void _init() {
    _repo.watchBookings(buildingId: _buildingId).listen((bookings) {
      state = AsyncValue.data(bookings);
    });
  }

  /// Cancel a booking by ID.
  Future<void> cancelBooking(String bookingId) async {
    try {
      await _repo.cancelBooking(bookingId);
      // Stream will auto-update via watchBookings
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Create a new booking.
  Future<Booking> createBooking(Booking booking) async {
    return await _repo.createBooking(booking);
  }
}

/// Booking provider — building-aware stream of bookings.
final bookingProvider =
    StateNotifierProvider.family<BookingNotifier, AsyncValue<List<Booking>>, int>(
  (ref, buildingId) {
    final repo = ref.watch(supabaseRepositoryProvider);
    return BookingNotifier(repo, buildingId);
  },
);