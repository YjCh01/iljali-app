import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';
import 'package:map/features/corporate/domain/utils/job_post_workplace_resolver.dart';
import 'package:map/features/job_seeker/domain/entities/job_map_pin.dart';

JobMapPin jobMapPinFromPost(CorporateJobPost post) {
  final coordinate = JobPostWorkplaceResolver.resolveMapWorkplaceCoordinate(post);
  return JobMapPin(
    post: post,
    latitude: coordinate.latitude,
    longitude: coordinate.longitude,
    companyName: post.registeredBy?.companyName ?? post.warehouseName,
    displayTier: post.effectiveMapPinTier,
  );
}
