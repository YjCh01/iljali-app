import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';
import 'package:map/features/job_seeker/domain/entities/event_map_pin.dart';
import 'package:map/features/job_seeker/domain/entities/job_map_pin_display_tier.dart';
import 'package:map/features/job_seeker/domain/entities/job_map_pin_ranking_context.dart';
import 'package:map/features/job_seeker/domain/factories/closed_ghost_job_map_pin_factory.dart';
import 'package:map/features/job_seeker/domain/utils/job_map_pin_ranking_service.dart';

/// 지도 핀 종류
enum JobMapPinKind {
  /// 채용 중 공고
  active,

  /// 마감된 무료 공고 · 어드민 배치 마감유령핀
  closedGhost,

  /// 어드민 이벤트핑 (퀴즈·투표·안내)
  event,
}

/// 지도에 표시할 채용 공고 핀
class JobMapPin {
  const JobMapPin({
    required this.post,
    required this.latitude,
    required this.longitude,
    required this.companyName,
    required this.displayTier,
    this.kind = JobMapPinKind.active,
    this.ghostPinId,
    this.eventPin,
  });

  final CorporateJobPost post;
  final double latitude;
  final double longitude;
  final String companyName;
  final JobMapPinDisplayTier displayTier;
  final JobMapPinKind kind;
  final String? ghostPinId;
  final EventMapPin? eventPin;

  bool get isClosedGhost => kind == JobMapPinKind.closedGhost;
  bool get isEvent => kind == JobMapPinKind.event;

  String get closedGhostMessage => ClosedGhostJobMapPinFactory.message;

  /// 네이버·웹 마커 ID
  String get mapMarkerId {
    if (isEvent) return 'event_${eventPin?.id ?? post.id}';
    if (isClosedGhost) return 'ghost_${ghostPinId ?? post.id}';
    return post.id;
  }
}

/// 화면 좌표 기반 mock 클러스터
class JobMapCluster {
  const JobMapCluster({
    required this.pins,
    required this.latitude,
    required this.longitude,
    required this.displayTier,
  });

  final List<JobMapPin> pins;
  final double latitude;
  final double longitude;
  final JobMapPinDisplayTier displayTier;

  int get count => pins.length;
  bool get isSingle => pins.length == 1;
  JobMapPin get singlePin => pins.first;

  /// 클러스터 목록 — [JobMapPinRankingService] 기준 상위 노출 순
  List<JobMapPin> rankedPins({
    JobMapPinRankingContext context = const JobMapPinRankingContext(),
    DateTime? now,
  }) =>
      JobMapPinRankingService.rankClusterPins(
        pins,
        context: context,
        now: now,
      );
}
