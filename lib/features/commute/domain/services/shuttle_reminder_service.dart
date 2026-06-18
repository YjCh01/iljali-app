import 'dart:convert';

import 'package:map/features/commute/domain/entities/shuttle_booking.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 로컬 셔틀 알림 (MVP — 배너·인박스용)
class ShuttleReminder {
  const ShuttleReminder({
    required this.id,
    required this.seekerEmail,
    required this.title,
    required this.body,
    required this.dueAt,
    required this.createdAt,
    this.read = false,
    this.postId,
    this.bookingId,
  });

  final String id;
  final String seekerEmail;
  final String title;
  final String body;
  final DateTime dueAt;
  final DateTime createdAt;
  final bool read;
  final String? postId;
  final String? bookingId;

  bool get isDue => !DateTime.now().isBefore(dueAt);

  Map<String, dynamic> toJson() => {
        'id': id,
        'seekerEmail': seekerEmail,
        'title': title,
        'body': body,
        'dueAt': dueAt.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'read': read,
        'postId': postId,
        'bookingId': bookingId,
      };

  factory ShuttleReminder.fromJson(Map<String, dynamic> json) {
    return ShuttleReminder(
      id: json['id'] as String? ?? '',
      seekerEmail: json['seekerEmail'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      dueAt: DateTime.tryParse(json['dueAt'] as String? ?? '') ?? DateTime.now(),
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      read: json['read'] as bool? ?? false,
      postId: json['postId'] as String?,
      bookingId: json['bookingId'] as String?,
    );
  }

  ShuttleReminder copyWith({bool? read}) {
    return ShuttleReminder(
      id: id,
      seekerEmail: seekerEmail,
      title: title,
      body: body,
      dueAt: dueAt,
      createdAt: createdAt,
      read: read ?? this.read,
      postId: postId,
      bookingId: bookingId,
    );
  }
}

class ShuttleReminderService {
  ShuttleReminderService(this._prefs);

  final SharedPreferences _prefs;

  static const _key = 'shuttle_reminders_v1';

  static Future<ShuttleReminderService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return ShuttleReminderService(prefs);
  }

  Future<List<ShuttleReminder>> fetchForSeeker(String email) async {
    final all = await _fetchAll();
    return all.where((r) => r.seekerEmail == email).toList()
      ..sort((a, b) => a.dueAt.compareTo(b.dueAt));
  }

  Future<List<ShuttleReminder>> fetchActiveForSeeker(String email) async {
    final items = await fetchForSeeker(email);
    return items.where((r) => r.isDue && !r.read).toList();
  }

  Future<void> scheduleForBooking(ShuttleBooking booking) async {
    final now = DateTime.now();
    final shiftDate = DateTime.tryParse(booking.shiftDate) ?? now;
    final pickupParts = booking.pickupTime.split(':');
    final pickupHour = int.tryParse(pickupParts.first) ?? 7;
    final pickupMinute =
        pickupParts.length > 1 ? int.tryParse(pickupParts[1]) ?? 0 : 0;
    final pickupAt = DateTime(
      shiftDate.year,
      shiftDate.month,
      shiftDate.day,
      pickupHour,
      pickupMinute,
    );

    final reminders = <ShuttleReminder>[
      ShuttleReminder(
        id: 'rem_${booking.id}_30min',
        seekerEmail: booking.seekerEmail,
        title: '셔틀 30분 후 탑승',
        body:
            '${booking.stopLabel} · ${booking.pickupTime} 탑승 — 미리 탑승장으로 이동해 주세요.',
        dueAt: pickupAt.subtract(const Duration(minutes: 30)),
        createdAt: now,
        postId: booking.postId,
        bookingId: booking.id,
      ),
      ShuttleReminder(
        id: 'rem_${booking.id}_today',
        seekerEmail: booking.seekerEmail,
        title: '오늘 셔틀 확인하기',
        body:
            '${booking.stopLabel} ${booking.pickupTime} 탑승 · 내 지원에서 노선을 확인하세요.',
        dueAt: DateTime(shiftDate.year, shiftDate.month, shiftDate.day, 6, 0),
        createdAt: now,
        postId: booking.postId,
        bookingId: booking.id,
      ),
    ];

    final all = await _fetchAll();
    for (final r in reminders) {
      final idx = all.indexWhere((x) => x.id == r.id);
      if (idx >= 0) {
        all[idx] = r;
      } else {
        all.add(r);
      }
    }
    await _persist(all);
  }

  Future<void> markRead(String id) async {
    final all = await _fetchAll();
    final idx = all.indexWhere((r) => r.id == id);
    if (idx < 0) return;
    all[idx] = all[idx].copyWith(read: true);
    await _persist(all);
  }

  Future<List<ShuttleReminder>> _fetchAll() async {
    final raw = _prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    return decoded
        .whereType<Map>()
        .map((m) => ShuttleReminder.fromJson(m.cast<String, dynamic>()))
        .toList();
  }

  Future<void> _persist(List<ShuttleReminder> items) async {
    await _prefs.setString(
      _key,
      jsonEncode(items.map((r) => r.toJson()).toList()),
    );
  }
}
