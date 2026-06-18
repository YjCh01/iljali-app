import 'dart:math' as math;

import 'package:map/core/constants/map_constants.dart';
import 'package:map/features/job_seeker/domain/entities/job_bookmark.dart';
import 'package:map/features/job_seeker/domain/entities/viewed_job_entry.dart';

enum JobBookmarkSortMode {
  savedNewest,
  hourlyWageDesc,
  deadlineAsc,
  distanceAsc,
}

extension JobBookmarkSortModeX on JobBookmarkSortMode {
  String get label => switch (this) {
        JobBookmarkSortMode.savedNewest => '저장순',
        JobBookmarkSortMode.hourlyWageDesc => '시급순',
        JobBookmarkSortMode.deadlineAsc => '마감순',
        JobBookmarkSortMode.distanceAsc => '거리순',
      };
}

abstract final class JobBookmarkSort {
  static int parseHourlyWage(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(digits) ?? 0;
  }

  static double? distanceKm({
    required double? latitude,
    required double? longitude,
    double? refLat,
    double? refLng,
  }) {
    if (latitude == null || longitude == null) return null;
    final centerLat = refLat ?? MapConstants.warehouseAreaCenter.latitude;
    final centerLng = refLng ?? MapConstants.warehouseAreaCenter.longitude;
    const earthRadiusKm = 6371.0;
    final dLat = _degToRad(latitude - centerLat);
    final dLng = _degToRad(longitude - centerLng);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degToRad(centerLat)) *
            math.cos(_degToRad(latitude)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  static double _degToRad(double deg) => deg * math.pi / 180;

  static List<JobBookmark> sortBookmarks(
    List<JobBookmark> items,
    JobBookmarkSortMode mode,
  ) {
    final sorted = List<JobBookmark>.from(items);
    switch (mode) {
      case JobBookmarkSortMode.savedNewest:
        sorted.sort((a, b) => b.savedAt.compareTo(a.savedAt));
      case JobBookmarkSortMode.hourlyWageDesc:
        sorted.sort(
          (a, b) => parseHourlyWage(b.hourlyWage)
              .compareTo(parseHourlyWage(a.hourlyWage)),
        );
      case JobBookmarkSortMode.deadlineAsc:
        sorted.sort((a, b) {
          final aDeadline = a.expiresAt;
          final bDeadline = b.expiresAt;
          if (aDeadline == null && bDeadline == null) return 0;
          if (aDeadline == null) return 1;
          if (bDeadline == null) return -1;
          return aDeadline.compareTo(bDeadline);
        });
      case JobBookmarkSortMode.distanceAsc:
        sorted.sort((a, b) {
          final aDist = distanceKm(
                latitude: a.latitude,
                longitude: a.longitude,
              ) ??
              double.infinity;
          final bDist = distanceKm(
                latitude: b.latitude,
                longitude: b.longitude,
              ) ??
              double.infinity;
          return aDist.compareTo(bDist);
        });
    }
    return sorted;
  }

  static List<ViewedJobEntry> sortViewed(
    List<ViewedJobEntry> items,
    JobBookmarkSortMode mode,
  ) {
    final sorted = List<ViewedJobEntry>.from(items);
    switch (mode) {
      case JobBookmarkSortMode.savedNewest:
        sorted.sort((a, b) => b.viewedAt.compareTo(a.viewedAt));
      case JobBookmarkSortMode.hourlyWageDesc:
        sorted.sort(
          (a, b) => parseHourlyWage(b.hourlyWage)
              .compareTo(parseHourlyWage(a.hourlyWage)),
        );
      case JobBookmarkSortMode.deadlineAsc:
        sorted.sort((a, b) {
          final aDeadline = a.expiresAt;
          final bDeadline = b.expiresAt;
          if (aDeadline == null && bDeadline == null) return 0;
          if (aDeadline == null) return 1;
          if (bDeadline == null) return -1;
          return aDeadline.compareTo(bDeadline);
        });
      case JobBookmarkSortMode.distanceAsc:
        sorted.sort((a, b) {
          final aDist = distanceKm(
                latitude: a.latitude,
                longitude: a.longitude,
              ) ??
              double.infinity;
          final bDist = distanceKm(
                latitude: b.latitude,
                longitude: b.longitude,
              ) ??
              double.infinity;
          return aDist.compareTo(bDist);
        });
    }
    return sorted;
  }
}
