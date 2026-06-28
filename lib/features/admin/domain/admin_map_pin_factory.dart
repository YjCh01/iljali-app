import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';
import 'package:map/features/job_seeker/domain/entities/job_map_pin.dart';
import 'package:map/features/job_seeker/domain/entities/job_map_pin_display_tier.dart';

/// Admin API 공고 JSON → 지도 핀
abstract final class AdminMapPinFactory {
  static List<JobMapPin> fromServerJobs(List<Map<String, dynamic>> jobs) {
    return jobs.map(fromServerJob).toList();
  }

  static JobMapPin fromServerJob(Map<String, dynamic> json) {
    final tier = JobMapPinDisplayTierX.tryParseLegacy(
          json['map_pin_tier'] as String?,
        ) ??
        (json['recruitment_pin_active'] == true
            ? JobMapPinDisplayTier.packageActive
            : JobMapPinDisplayTier.standard);

    final post = CorporateJobPost(
      id: '${json['id']}',
      title: '${json['title'] ?? ''}',
      warehouseName: '${json['warehouse_name'] ?? ''}',
      hourlyWage: '${json['hourly_wage'] ?? ''}',
      workSchedule: '${json['work_schedule'] ?? ''}',
      summary: '${json['summary'] ?? ''}',
      status: _parseStatus('${json['status'] ?? 'recruiting'}'),
      applicantCount: (json['application_count'] as num?)?.toInt() ?? 0,
      postedAt: DateTime.tryParse('${json['created_at'] ?? ''}') ??
          DateTime.now(),
      mapPinDisplayTier: tier,
      hasShuttleRouteOverlay: json['shuttle_exposure_active'] == true,
    );

    return JobMapPin(
      post: post,
      latitude: (json['latitude'] as num?)?.toDouble() ?? 37.5128,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 127.0471,
      companyName: '${json['company_name'] ?? post.warehouseName}',
      displayTier: tier,
    );
  }

  static CorporateJobPostStatus _parseStatus(String raw) {
    switch (raw) {
      case 'closingSoon':
        return CorporateJobPostStatus.closingSoon;
      case 'closed':
      case 'expired':
        return CorporateJobPostStatus.closed;
      default:
        return CorporateJobPostStatus.recruiting;
    }
  }
}
