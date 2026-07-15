import 'package:map/core/address/address_geocoder.dart';
import 'package:map/core/constants/map_constants.dart';
import 'package:map/core/geo/geo_coordinate.dart';
import 'package:map/features/corporate/data/datasources/corporate_job_post_local_data_source.dart';
import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';
import 'package:map/features/job_seeker/data/datasources/closed_ghost_pin_local_data_source.dart';
import 'package:map/features/job_seeker/data/datasources/event_map_pin_local_data_source.dart';
import 'package:map/features/job_seeker/domain/entities/job_map_pin.dart';
import 'package:map/features/job_seeker/domain/factories/closed_ghost_job_map_pin_factory.dart';
import 'package:map/features/job_seeker/domain/factories/event_job_map_pin_factory.dart';
import 'package:map/features/job_seeker/domain/utils/closed_ghost_pin_suppression_policy.dart';
import 'package:map/features/map_dashboard/data/datasources/warehouse_local_data_source.dart';
import 'package:map/features/map_dashboard/domain/entities/warehouse.dart';
import 'package:map/features/corporate/domain/utils/job_post_workplace_resolver.dart';
import 'package:map/features/corporate/presentation/widgets/push_radius_map_picker.dart';

abstract class JobMapPinsDataSource {
  Future<List<JobMapPin>> fetchActiveJobPins({bool includeClosedGhosts = false});
}

class JobMapPinsLocalDataSource implements JobMapPinsDataSource {
  const JobMapPinsLocalDataSource({
    this.jobPosts = const CorporateJobPostLocalDataSourceImpl(),
    this.warehouses = const WarehouseLocalDataSourceImpl(),
    this.ghostPins = const ClosedGhostPinLocalDataSourceImpl(),
    this.eventPins = const EventMapPinLocalDataSourceImpl(),
  });

  final CorporateJobPostLocalDataSource jobPosts;
  final WarehouseLocalDataSource warehouses;
  final ClosedGhostPinLocalDataSource ghostPins;
  final EventMapPinLocalDataSource eventPins;

  @override
  Future<List<JobMapPin>> fetchActiveJobPins({
    bool includeClosedGhosts = false,
  }) async {
    final posts = await jobPosts.fetchJobPosts();
    final warehouseList = await warehouses.fetchWarehouses();

    final activePosts = posts.where(
      (post) =>
          (post.status == CorporateJobPostStatus.recruiting ||
              post.status == CorporateJobPostStatus.closingSoon) &&
          post.isActiveForSeekers,
    );

    var fallbackIndex = 0;
    final activePins = <JobMapPin>[];
    for (final post in activePosts) {
      activePins.add(
        await _pinFromPost(
          post,
          warehouseList: warehouseList,
          fallbackIndex: fallbackIndex++,
        ),
      );
    }

    final events = await eventPins.fetchAll();
    final eventMapPins =
        events.map(EventJobMapPinFactory.fromEvent).toList(growable: false);

    if (!includeClosedGhosts) return [...activePins, ...eventMapPins];

    final ghostMapPins = await _fetchClosedGhostPins(
      posts: posts,
      warehouseList: warehouseList,
    );
    return [...activePins, ...eventMapPins, ...ghostMapPins];
  }

  Future<List<JobMapPin>> _fetchClosedGhostPins({
    required List<CorporateJobPost> posts,
    required List<Warehouse> warehouseList,
  }) async {
    final adminPins = await ghostPins.fetchAll();
    final postsById = {for (final post in posts) post.id: post};
    final coveredPostIds = <String>{};
    final result = <JobMapPin>[];

    for (final adminPin in adminPins) {
      final sourceId = adminPin.sourcePostId?.trim();
      final sourcePost =
          sourceId != null && sourceId.isNotEmpty ? postsById[sourceId] : null;
      result.add(
        ClosedGhostJobMapPinFactory.fromAdminPin(
          adminPin,
          sourcePost: sourcePost,
        ),
      );
      if (sourceId != null && sourceId.isNotEmpty) {
        coveredPostIds.add(sourceId);
      }
    }

    var fallbackIndex = 0;
    for (final post in posts) {
      if (coveredPostIds.contains(post.id)) continue;
      if (!ClosedGhostPinSuppressionPolicy.shouldRenderGhostForPost(
        post: post,
        allPosts: posts,
      )) {
        continue;
      }
      final coordinate = await _coordinateForPost(
        post,
        warehouseList: warehouseList,
        fallbackIndex: fallbackIndex++,
      );
      result.add(ClosedGhostJobMapPinFactory.fromPost(post, coordinate));
    }

    return result;
  }

  Future<JobMapPin> _pinFromPost(
    CorporateJobPost post, {
    required List<Warehouse> warehouseList,
    required int fallbackIndex,
  }) async {
    final coordinate = await _coordinateForPost(
      post,
      warehouseList: warehouseList,
      fallbackIndex: fallbackIndex,
    );
    return JobMapPin(
      post: post,
      latitude: coordinate.latitude,
      longitude: coordinate.longitude,
      companyName: post.registeredBy?.companyName ?? post.warehouseName,
      displayTier: post.effectiveMapPinTier,
    );
  }

  Future<GeoCoordinate> _coordinateForPost(
    CorporateJobPost post, {
    required List<Warehouse> warehouseList,
    required int fallbackIndex,
  }) async {
    final resolved = await JobPostWorkplaceResolver.resolveMapWorkplaceCoordinateAsync(post);
    if (!isLikelyDefaultPushMapCenter(resolved) ||
        isDefaultPushMapAddressLabel(post.warehouseName)) {
      if (!isLikelyDefaultPushMapCenter(resolved)) {
        if (post.workplaceLatitude == null) {
          await jobPosts.updateJobPost(
            post.copyWith(
              workplaceLatitude: resolved.latitude,
              workplaceLongitude: resolved.longitude,
            ),
          );
        }
        return resolved;
      }
    }

    final warehouse = _matchWarehouse(post, warehouseList);
    if (warehouse != null) {
      return GeoCoordinate(
        latitude: warehouse.latitude,
        longitude: warehouse.longitude,
      );
    }

    final road = post.warehouseName.trim();
    if (road.isNotEmpty) {
      final geocoded = await AddressGeocoder.geocode(road);
      if (geocoded != null) {
        if (post.workplaceLatitude == null) {
          await jobPosts.updateJobPost(
            post.copyWith(
              workplaceLatitude: geocoded.latitude,
              workplaceLongitude: geocoded.longitude,
            ),
          );
        }
        return geocoded;
      }
    }

    final offset = _fallbackOffset(fallbackIndex);
    return GeoCoordinate(
      latitude: MapConstants.warehouseAreaCenter.latitude + offset.$1,
      longitude: MapConstants.warehouseAreaCenter.longitude + offset.$2,
    );
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
