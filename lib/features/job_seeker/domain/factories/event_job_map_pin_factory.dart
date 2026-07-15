import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';
import 'package:map/features/corporate/domain/entities/worker_category.dart';
import 'package:map/features/job_seeker/domain/entities/event_map_pin.dart';
import 'package:map/features/job_seeker/domain/entities/job_map_pin.dart';
import 'package:map/features/job_seeker/domain/entities/job_map_pin_display_tier.dart';

/// 이벤트핑 → 지도 JobMapPin
abstract final class EventJobMapPinFactory {
  static JobMapPin fromEvent(EventMapPin event) {
    return JobMapPin(
      post: _placeholderPost(event),
      latitude: event.latitude,
      longitude: event.longitude,
      companyName: event.title.isNotEmpty ? event.title : '이벤트',
      displayTier: JobMapPinDisplayTier.event,
      kind: JobMapPinKind.event,
      eventPin: event,
    );
  }

  static CorporateJobPost _placeholderPost(EventMapPin event) {
    final now = event.createdAt ?? DateTime.now();
    return CorporateJobPost(
      id: 'event_post_${event.id}',
      title: event.title.isNotEmpty ? event.title : '이벤트',
      warehouseName: event.title,
      hourlyWage: '',
      workSchedule: '',
      summary: event.body,
      jobDescription: event.body,
      status: CorporateJobPostStatus.recruiting,
      applicantCount: 0,
      postedAt: now,
      workplaceLatitude: event.latitude,
      workplaceLongitude: event.longitude,
      workerCategory: WorkerCategory.daily,
    );
  }
}
