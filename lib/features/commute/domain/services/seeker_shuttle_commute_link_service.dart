import 'package:intl/intl.dart';
import 'package:map/core/hiring/hiring_application.dart';
import 'package:map/core/hiring/local_hiring_repository.dart';
import 'package:map/core/hiring/selected_shift_dates.dart';
import 'package:map/features/commute/data/repositories/shuttle_booking_repository.dart';
import 'package:map/features/commute/domain/entities/commute_route.dart';
import 'package:map/features/commute/domain/entities/commute_route_stop.dart';
import 'package:map/features/commute/domain/entities/seeker_shuttle_commute_preference.dart';
import 'package:map/features/commute/domain/entities/shuttle_booking.dart';
import 'package:map/features/commute/domain/services/shuttle_reminder_service.dart';

/// 내 버스 정류장 선택 → 탑승 예약·지원 건 연동
abstract final class SeekerShuttleCommuteLinkService {
  static Future<SeekerShuttleCommutePreference> saveStopSelection({
    required String seekerEmail,
    required String companyKey,
    required String companyName,
    required CommuteRoute route,
    required CommuteRouteStop stop,
    required List<HiringApplication> applications,
  }) async {
    final pickupTime = stop.departureTime ?? '';
    final preference = SeekerShuttleCommutePreference(
      seekerEmail: seekerEmail.trim().toLowerCase(),
      companyKey: companyKey.trim(),
      companyName: companyName.trim(),
      routeId: route.id,
      routeName: route.routeName,
      stopId: stop.id,
      stopLabel: stop.label,
      pickupTime: pickupTime,
      updatedAt: DateTime.now(),
    );

    final hiringRepo = await LocalHiringRepository.create();
    final bookingRepo = await ShuttleBookingRepository.create();
    final reminderService = await ShuttleReminderService.create();
    final todayIso = DateFormat('yyyy-MM-dd').format(DateTime.now());

    for (final app in applications) {
      final shiftDate = _shiftDateForBooking(app, todayIso);
      if (shiftDate.isEmpty) continue;

      final existingId = app.shuttleBookingId;
      ShuttleBooking? existing =
          existingId == null ? null : await bookingRepo.findById(existingId);
      if (existing != null &&
          existing.routeId == route.id &&
          existing.stopId == stop.id &&
          existing.shiftDate == shiftDate) {
        await hiringRepo.attachShuttleBooking(
          applicationId: app.id,
          booking: existing,
        );
        continue;
      }

      final booking = ShuttleBooking(
        id: existing?.id ??
            'mybus_${app.id}_${route.id}_${DateTime.now().millisecondsSinceEpoch}',
        seekerEmail: seekerEmail.trim().toLowerCase(),
        postId: app.postId,
        routeId: route.id,
        stopId: stop.id,
        stopLabel: stop.label,
        pickupTime: pickupTime,
        shiftDate: shiftDate,
        createdAt: DateTime.now(),
      );
      await bookingRepo.save(booking);
      await reminderService.scheduleForBooking(booking);
      await hiringRepo.attachShuttleBooking(
        applicationId: app.id,
        booking: booking,
      );
    }

    return preference;
  }

  static String _shiftDateForBooking(
    HiringApplication app,
    String todayIso,
  ) {
    final raw = app.selectedShiftDate?.trim() ?? '';
    if (raw.isEmpty) return todayIso;
    final dates = SelectedShiftDates.decode(raw);
    if (dates.isEmpty) return todayIso;
    final today = DateTime.tryParse(todayIso);
    if (today == null) return SelectedShiftDates.encode([dates.first]);
    for (final date in dates) {
      if (date.year == today.year &&
          date.month == today.month &&
          date.day == today.day) {
        return todayIso;
      }
    }
    final upcoming = dates.where((d) => !d.isBefore(today)).toList()
      ..sort((a, b) => a.compareTo(b));
    if (upcoming.isNotEmpty) {
      return DateFormat('yyyy-MM-dd').format(upcoming.first);
    }
    return DateFormat('yyyy-MM-dd').format(dates.last);
  }
}
