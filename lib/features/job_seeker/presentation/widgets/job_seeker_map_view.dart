import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:map/core/constants/map_constants.dart';
import 'package:map/core/utils/naver_map_platform.dart';
import 'package:map/features/job_seeker/data/datasources/job_map_pins_data_source.dart';
import 'package:map/features/job_seeker/domain/entities/job_map_pin.dart';
import 'package:map/features/job_seeker/domain/usecases/get_job_map_pins_usecase.dart';
import 'package:map/features/job_seeker/presentation/map/job_map_marker_factory.dart';
import 'package:map/features/job_seeker/presentation/widgets/job_seeker_mock_map.dart';
import 'package:map/features/map_dashboard/data/datasources/map_camera_holder.dart';
import 'package:map/features/map_dashboard/presentation/map/warehouse_cluster_options_factory.dart';

/// 구직자 지도 — Naver Map 클러스터링 또는 mock 지도
class JobSeekerMapView extends StatefulWidget {
  const JobSeekerMapView({
    super.key,
    required this.onPinTap,
    this.onMapBackgroundTap,
    this.searchFilter,
    GetJobMapPinsUseCase? getPins,
  }) : _getPins = getPins;

  final ValueChanged<JobMapPin> onPinTap;
  final VoidCallback? onMapBackgroundTap;
  final String? searchFilter;
  final GetJobMapPinsUseCase? _getPins;

  @override
  State<JobSeekerMapView> createState() => _JobSeekerMapViewState();
}

class _JobSeekerMapViewState extends State<JobSeekerMapView> {
  late final GetJobMapPinsUseCase _getPins = widget._getPins ??
      GetJobMapPinsUseCase(const JobMapPinsLocalDataSource());

  List<JobMapPin> _pins = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPins();
  }

  @override
  void didUpdateWidget(covariant JobSeekerMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchFilter != widget.searchFilter) {
      _loadPins();
    }
  }

  Future<void> _loadPins() async {
    setState(() => _loading = true);
    final pins = await _getPins();
    final filter = widget.searchFilter?.trim();
    final filtered = filter == null || filter.isEmpty
        ? pins
        : pins
            .where(
              (pin) =>
                  pin.post.title.contains(filter) ||
                  pin.companyName.contains(filter) ||
                  pin.post.warehouseName.contains(filter),
            )
            .toList();
    if (!mounted) return;
    setState(() {
      _pins = filtered;
      _loading = false;
    });
  }

  @override
  void dispose() {
    MapCameraHolder.instance.unbind();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!NaverMapPlatform.shouldShowMap) {
      return JobSeekerMockMap(
        pins: _pins,
        onPinTap: widget.onPinTap,
      );
    }

    final safeAreaPadding = MediaQuery.paddingOf(context);

    return NaverMap(
      options: NaverMapViewOptions(
        contentPadding: safeAreaPadding,
        initialCameraPosition: const NCameraPosition(
          target: MapConstants.warehouseAreaCenter,
          zoom: MapConstants.warehouseAreaZoom,
        ),
      ),
      clusterOptions: WarehouseClusterOptionsFactory.create(),
      onMapReady: _handleMapReady,
      onMapTapped: widget.onMapBackgroundTap == null
          ? null
          : (_, __) => widget.onMapBackgroundTap!(),
    );
  }

  Future<void> _handleMapReady(NaverMapController controller) async {
    MapCameraHolder.instance.bind(controller);

    final markers = JobMapMarkerFactory.createAll(
      _pins,
      onTap: widget.onPinTap,
    );
    controller.addOverlayAll(markers);
  }
}
