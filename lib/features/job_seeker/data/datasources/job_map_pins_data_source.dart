import 'package:map/core/constants/map_constants.dart';
import 'package:map/features/corporate/data/datasources/corporate_job_post_local_data_source.dart';
import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';
import 'package:map/features/job_seeker/domain/entities/job_map_pin.dart';
import 'package:map/features/map_dashboard/data/datasources/warehouse_local_data_source.dart';
import 'package:map/features/map_dashboard/domain/entities/warehouse.dart';

abstract class JobMapPinsDataSource {
  Future<List<JobMapPin>> fetchActiveJobPins();
}

class JobMapPinsLocalDataSource implements JobMapPinsDataSource {
  const JobMapPinsLocalDataSource({
    this.jobPosts = const CorporateJobPostLocalDataSourceImpl(),
    this.warehouses = const WarehouseLocalDataSourceImpl(),
  });

  final CorporateJobPostLocalDataSource jobPosts;
  final WarehouseLocalDataSource warehouses;

  @override
  Future<List<JobMapPin>> fetchActiveJobPins() async {
    final posts = await jobPosts.fetchJobPosts();
    final warehouseList = await warehouses.fetchWarehouses();

    final activePosts = posts.where(
      (post) =>
          (post.status == CorporateJobPostStatus.recruiting ||
              post.status == CorporateJobPostStatus.closingSoon) &&
          post.isActiveForSeekers,
    );

    var fallbackIndex = 0;
    return activePosts.map((post) {
      final warehouse = _matchWarehouse(post, warehouseList);
      if (warehouse != null) {
        return JobMapPin(
          post: post,
          latitude: warehouse.latitude,
          longitude: warehouse.longitude,
          companyName: post.registeredBy?.companyName ?? warehouse.name,
          displayTier: post.effectiveMapPinTier,
        );
      }

      final offset = _fallbackOffset(fallbackIndex++);
      return JobMapPin(
        post: post,
        latitude: MapConstants.warehouseAreaCenter.latitude + offset.$1,
        longitude: MapConstants.warehouseAreaCenter.longitude + offset.$2,
        companyName: post.registeredBy?.companyName ?? post.warehouseName,
        displayTier: post.effectiveMapPinTier,
      );
    }).toList();
  }

  Warehouse? _matchWarehouse(
    CorporateJobPost post,
    List<Warehouse> warehouseList,
  ) {
    final label = post.warehouseName.trim();
    for (final warehouse in warehouseList) {
      if (label.contains(warehouse.name) || warehouse.name.contains(label)) {
        return warehouse;
      }
    }
    return null;
  }

  (double, double) _fallbackOffset(int index) {
    const offsets = [
      (0.004, 0.003),
      (-0.003, 0.005),
      (0.006, -0.004),
      (-0.005, -0.003),
    ];
    return offsets[index % offsets.length];
  }
}
