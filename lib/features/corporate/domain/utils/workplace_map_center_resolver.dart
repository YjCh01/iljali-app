import 'package:map/core/map/map_initial_center_policy.dart';
import 'package:map/core/geo/geo_coordinate.dart';
import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';
import 'package:map/features/corporate/domain/entities/workplace_address.dart';
import 'package:map/features/corporate/presentation/widgets/push_radius_map_picker.dart';

/// @Deprecated [MapInitialCenterPolicy] 사용
abstract final class WorkplaceMapCenterResolver {
  static GeoCoordinate fallback() => MapInitialCenterPolicy.fallback();

  static bool isFallback(GeoCoordinate coordinate) =>
      MapInitialCenterPolicy.isFallback(coordinate);

  static Future<GeoCoordinate> resolveAsync({
    GeoCoordinate? coordinate,
    String? address,
    WorkplaceAddress? workplace,
    CorporateJobPost? post,
  }) {
    final mergedWorkplace = workplace ??
        (address != null && address.trim().isNotEmpty
            ? WorkplaceAddress(roadAddress: address.trim())
            : null);
    return MapInitialCenterPolicy.corporateJobPostAction(
      post: post,
      workplace: mergedWorkplace?.copyWith(
        coordinate: mergedWorkplace.coordinate ?? coordinate,
      ),
    );
  }

  static Future<GeoCoordinate> fromWorkplace(WorkplaceAddress? workplace) =>
      MapInitialCenterPolicy.corporateJobPostAction(workplace: workplace);
}
