import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';
import 'package:map/features/job_seeker/domain/entities/job_map_pin_display_tier.dart';

/// 지도에 표시할 채용 공고 핀
class JobMapPin {
  const JobMapPin({
    required this.post,
    required this.latitude,
    required this.longitude,
    required this.companyName,
    required this.displayTier,
  });

  final CorporateJobPost post;
  final double latitude;
  final double longitude;
  final String companyName;
  final JobMapPinDisplayTier displayTier;
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
}
