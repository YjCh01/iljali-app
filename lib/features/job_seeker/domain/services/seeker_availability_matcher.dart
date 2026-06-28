import 'package:map/features/job_seeker/domain/entities/seeker_work_availability.dart';

/// 구직자 희망 근무시간 ↔ 공고/푸시 시간대 매칭 (페이즈 2 푸시 타겟팅 베이스)
abstract final class SeekerAvailabilityMatcher {
  /// [startMinutes]~[endMinutes] on [weekday], [endDayOffset] when job spans midnight.
  static bool slotCoversJob({
    required SeekerAvailabilitySlot slot,
    required int jobWeekday,
    required int jobStartMinutes,
    required int jobEndMinutes,
    int jobEndDayOffset = 0,
  }) {
    if (slot.anyTime && slot.weekday == jobWeekday) return true;

    final slotStart = _absoluteMinute(slot.weekday, slot.startMinutes ?? 0);
    var slotEnd = _absoluteMinute(
      slot.weekday + slot.endDayOffset,
      slot.endMinutes ?? 0,
    );
    if (slotEnd <= slotStart && !slot.anyTime) {
      slotEnd += 7 * 24 * 60;
    }

    final jobStart = _absoluteMinute(jobWeekday, jobStartMinutes);
    var jobEnd = _absoluteMinute(
      jobWeekday + jobEndDayOffset,
      jobEndMinutes,
    );
    if (jobEnd <= jobStart) {
      jobEnd += 7 * 24 * 60;
    }

    // 같은 주 기준 ±7일 윈도우에서 겹침 검사
    for (final shift in [-7 * 24 * 60, 0, 7 * 24 * 60]) {
      final js = jobStart + shift;
      final je = jobEnd + shift;
      if (slotStart < je && slotEnd > js) return true;
    }
    return false;
  }

  static bool anySlotCoversJob({
    required SeekerWorkAvailability availability,
    required int jobWeekday,
    required int jobStartMinutes,
    required int jobEndMinutes,
    int jobEndDayOffset = 0,
  }) {
    for (final slot in availability.slots) {
      if (slotCoversJob(
        slot: slot,
        jobWeekday: jobWeekday,
        jobStartMinutes: jobStartMinutes,
        jobEndMinutes: jobEndMinutes,
        jobEndDayOffset: jobEndDayOffset,
      )) {
        return true;
      }
    }
    return false;
  }

  static int _absoluteMinute(int weekday, int minutes) {
    final day = weekday.clamp(0, 6);
    return day * 24 * 60 + minutes.clamp(0, 24 * 60 - 1);
  }
}
