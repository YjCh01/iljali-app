import 'package:map/core/hiring/hiring_application_status.dart';
import 'package:map/core/hiring/local_hiring_repository.dart';
import 'package:map/core/trust/seeker_trust_badge.dart';

/// 구직자 이메일 기준 신뢰도·배지 계산
class SeekerTrustService {
  SeekerTrustService({LocalHiringRepository? repository})
      : _repository = repository;

  LocalHiringRepository? _repository;

  Future<LocalHiringRepository> _repo() async =>
      _repository ??= await LocalHiringRepository.create();

  Future<SeekerTrustSummary> summarize(String seekerEmail) async {
    final repo = await _repo();
    final apps = await repo.fetchForSeeker(seekerEmail);

    var checkIns = 0;
    var noShows = 0;
    var chatCount = 0;

    for (final app in apps) {
      if (app.status == HiringApplicationStatus.checkedIn ||
          app.status == HiringApplicationStatus.commissionPaid) {
        checkIns++;
      }
      if (app.status == HiringApplicationStatus.scheduled &&
          app.workDate != null &&
          DateTime.now().isAfter(app.workDate!.add(const Duration(days: 1))) &&
          app.checkedInAt == null) {
        noShows++;
      }
      if (app.status == HiringApplicationStatus.chatting) chatCount++;
    }

    final badges = <SeekerTrustBadge>[];
    if (apps.length <= 2) badges.add(SeekerTrustBadge.newcomer);
    if (checkIns >= 3) badges.add(SeekerTrustBadge.reliableAttendance);
    if (checkIns >= 10) badges.add(SeekerTrustBadge.veteran);
    if (noShows == 0 && checkIns >= 1) badges.add(SeekerTrustBadge.noShowFree);
    if (chatCount >= 2) badges.add(SeekerTrustBadge.fastResponder);

    var score = 50;
    score += checkIns * 8;
    score -= noShows * 25;
    score = score.clamp(0, 100);

    return SeekerTrustSummary(
      score: score,
      badges: badges,
      checkInCount: checkIns,
      noShowCount: noShows,
    );
  }
}
