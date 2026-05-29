import 'package:map/core/hiring/hiring_application.dart';
import 'package:map/core/hiring/local_hiring_repository.dart';

/// 구직자 미출근 체크 시 지원·채팅 제한
class SeekerAttendanceGateService {
  SeekerAttendanceGateService({LocalHiringRepository? repository})
      : _repository = repository;

  LocalHiringRepository? _repository;

  /// 1건까지는 경고, 2건 이상 미체크인 시 잠금
  static const int lockThreshold = 2;

  Future<LocalHiringRepository> _repo() async =>
      _repository ??= await LocalHiringRepository.create();

  Future<SeekerAttendanceGateResult> evaluate(String seekerEmail) async {
    final overdue = await (await _repo()).fetchOverdueUncheckedShifts(seekerEmail);
    final count = overdue.length;
    if (count < lockThreshold) {
      return SeekerAttendanceGateResult(
        isLocked: false,
        overdueCount: count,
        overdueShifts: overdue,
      );
    }
    return SeekerAttendanceGateResult(
      isLocked: true,
      overdueCount: count,
      overdueShifts: overdue,
      message:
          '미확인 출근 $count건 — 출근 체크 또는 분쟁 신고 후 이용할 수 있습니다.',
    );
  }
}

class SeekerAttendanceGateResult {
  const SeekerAttendanceGateResult({
    required this.isLocked,
    required this.overdueCount,
    required this.overdueShifts,
    this.message,
  });

  final bool isLocked;
  final int overdueCount;
  final List<HiringApplication> overdueShifts;
  final String? message;
}
