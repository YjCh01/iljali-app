import 'dart:math' as math;

import 'package:map/features/job_seeker/domain/entities/job_map_pin.dart';
import 'package:map/features/job_seeker/domain/entities/job_map_pin_display_tier.dart';

/// mock 지도용 클러스터링 (줌 레벨에 따라 합치기/분리)
abstract final class JobMapClusterEngine {
  static List<JobMapCluster> cluster({
    required List<JobMapPin> pins,
    required double zoom,
  }) {
    if (pins.isEmpty) return const [];

    final ghosts = pins.where((pin) => pin.isClosedGhost).toList();
    final active = pins.where((pin) => !pin.isClosedGhost).toList();

    final activeClusters = active.isEmpty
        ? const <JobMapCluster>[]
        : _clusterActive(active, zoom);

    final ghostClusters = ghosts
        .map(
          (pin) => JobMapCluster(
            pins: [pin],
            latitude: pin.latitude,
            longitude: pin.longitude,
            displayTier: JobMapPinDisplayTier.closedGhost,
          ),
        )
        .toList();

    return [...activeClusters, ...ghostClusters];
  }

  static List<JobMapCluster> _clusterActive(
    List<JobMapPin> pins,
    double zoom,
  ) {
    if (pins.isEmpty) return const [];

    // 줌 10~18: 숫자가 클수록 더 촘촘히 분리
    final cellSize = 0.045 / math.pow(2, zoom - 12);
    final buckets = <String, List<JobMapPin>>{};

    for (final pin in pins) {
      final gx = (pin.longitude / cellSize).floor();
      final gy = (pin.latitude / cellSize).floor();
      final key = '$gx:$gy';
      buckets.putIfAbsent(key, () => []).add(pin);
    }

    return buckets.values.map((group) {
      var tier = JobMapPinDisplayTier.standard;
      for (final pin in group) {
        tier = JobMapPinDisplayTierX.maxOf(tier, pin.displayTier);
      }
      final lat =
          group.map((pin) => pin.latitude).reduce((a, b) => a + b) / group.length;
      final lng =
          group.map((pin) => pin.longitude).reduce((a, b) => a + b) / group.length;
      return JobMapCluster(
        pins: group,
        latitude: lat,
        longitude: lng,
        displayTier: tier,
      );
    }).toList();
  }
}
