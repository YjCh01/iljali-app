import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';
import 'package:map/features/job_seeker/domain/entities/job_map_pin.dart';
import 'package:map/features/job_seeker/domain/entities/job_map_pin_display_tier.dart';

JobMapPin jobMapPinFromPost(CorporateJobPost post) {
  return JobMapPin(
    post: post,
    latitude: 0,
    longitude: 0,
    companyName: post.registeredBy?.companyName ?? post.warehouseName,
    displayTier: post.effectiveMapPinTier,
  );
}
