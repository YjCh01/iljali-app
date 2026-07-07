import 'package:map/features/corporate/domain/entities/work_schedule_spec.dart';
import 'package:map/features/corporate/domain/utils/work_schedule_codec.dart';

/// 일용직 급여지급일 자동 산출
abstract final class DailyWorkerPolicy {
  static const paymentAutoSetupLine1 = '일용직은 근무일 다음날 급여일 자동설정';
  static const paymentAutoSetupLine2 =
      '실제 급여지급일은 구인·구직자 간 협의할 수 있으며, '
      '본 서비스는 해당 협의에 관여하지 않습니다.';

  /// 근무일마다 다음 날을 급여지급일로 반환 (날짜 오름차순)
  static List<DateTime> paymentDatesFromWorkSchedule(String scheduleRaw) {
    final spec = WorkScheduleCodec.tryParse(scheduleRaw);
    if (spec == null || spec.mode != WorkScheduleMode.dailyPick) {
      return const [];
    }
    if (spec.selectedWorkDates.isEmpty) return const [];

    final paymentDates = spec.selectedWorkDates
        .map(
          (workDate) => DateTime(workDate.year, workDate.month, workDate.day)
              .add(const Duration(days: 1)),
        )
        .toList()
      ..sort((a, b) => a.compareTo(b));
    return paymentDates;
  }
}
