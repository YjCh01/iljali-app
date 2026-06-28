import 'dart:convert';

import 'package:map/features/commute/domain/entities/shuttle_booking.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 셔틀 탑승 예약 로컬 저장
class ShuttleBookingRepository {
  ShuttleBookingRepository(this._prefs);

  final SharedPreferences _prefs;

  static const _key = 'shuttle_bookings_v1';

  static Future<ShuttleBookingRepository> create() async {
    final prefs = await SharedPreferences.getInstance();
    return ShuttleBookingRepository(prefs);
  }

  Future<List<ShuttleBooking>> fetchAll() async {
    final raw = _prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    return decoded
        .whereType<Map>()
        .map((item) => ShuttleBooking.fromJson(item.cast<String, dynamic>()))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<List<ShuttleBooking>> fetchForSeeker(String email) async {
    final all = await fetchAll();
    return all.where((b) => b.seekerEmail == email).toList();
  }

  Future<ShuttleBooking?> findById(String id) async {
    final all = await fetchAll();
    for (final item in all) {
      if (item.id == id) return item;
    }
    return null;
  }

  Future<ShuttleBooking?> findForPostAndDate({
    required String seekerEmail,
    required String postId,
    required String shiftDate,
  }) async {
    final all = await fetchForSeeker(seekerEmail);
    for (final item in all) {
      if (item.postId == postId && item.shiftDate == shiftDate) return item;
    }
    return null;
  }

  Future<ShuttleBooking> save(ShuttleBooking booking) async {
    final all = await fetchAll();
    final index = all.indexWhere((b) => b.id == booking.id);
    if (index >= 0) {
      all[index] = booking;
    } else {
      all.insert(0, booking);
    }
    await _persist(all);
    return booking;
  }

  Future<void> ensureSeed(ShuttleBooking booking) async {
    final existing = await findById(booking.id);
    if (existing != null) return;
    await save(booking);
  }

  Future<void> removeById(String id) async {
    final all = await fetchAll();
    final next = all.where((b) => b.id != id).toList();
    if (next.length == all.length) return;
    await _persist(next);
  }

  Future<void> _persist(List<ShuttleBooking> items) async {
    await _prefs.setString(
      _key,
      jsonEncode(items.map((b) => b.toJson()).toList()),
    );
  }
}
