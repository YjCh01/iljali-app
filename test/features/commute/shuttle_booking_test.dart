import 'package:flutter_test/flutter_test.dart';
import 'package:map/features/commute/domain/entities/shuttle_booking.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:map/features/commute/data/repositories/shuttle_booking_repository.dart';

void main() {
  group('ShuttleBooking', () {
    test('serializes and deserializes round-trip', () {
      final original = ShuttleBooking(
        id: 'book_1',
        seekerEmail: 'seeker@test.com',
        postId: 'post_1',
        routeId: 'route_1',
        stopId: 'stop_jamsil',
        stopLabel: '잠실역 2번 출구',
        pickupTime: '07:30',
        shiftDate: '2026-06-09',
        createdAt: DateTime(2026, 6, 9, 8, 0),
      );

      final restored = ShuttleBooking.fromJson(original.toJson());
      expect(restored.id, original.id);
      expect(restored.seekerEmail, original.seekerEmail);
      expect(restored.stopLabel, original.stopLabel);
      expect(restored.pickupTime, original.pickupTime);
      expect(restored.shiftDate, original.shiftDate);
    });
  });

  group('ShuttleBookingRepository', () {
    test('persists booking in SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = await ShuttleBookingRepository.create();
      final booking = ShuttleBooking(
        id: 'book_persist',
        seekerEmail: 'alpha@test.com',
        postId: 'post_alpha',
        routeId: 'demo_route',
        stopId: 'stop_1',
        stopLabel: '테스트 정류장',
        pickupTime: '08:00',
        shiftDate: '2026-06-10',
        createdAt: DateTime(2026, 6, 9),
      );

      await repo.save(booking);
      final loaded = await repo.findById('book_persist');
      expect(loaded, isNotNull);
      expect(loaded!.stopLabel, '테스트 정류장');
    });
  });
}
