/// 근무 일정을 달력 없이 협의로 표시
abstract final class WorkScheduleNegotiable {
  static const label = '근무일정 협의';

  static bool isLabel(String raw) => raw.trim() == label;
}
