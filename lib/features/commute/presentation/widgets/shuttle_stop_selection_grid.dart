import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/features/commute/domain/entities/commute_route.dart';
import 'package:map/features/commute/domain/utils/shuttle_route_stop_policy.dart';
import 'package:map/features/commute/domain/entities/commute_route_stop.dart';
import 'package:map/features/commute/domain/entities/seeker_shuttle_commute_preference.dart';

/// 노선별 탑승 정류장 그리드 선택
class ShuttleStopSelectionGrid extends StatelessWidget {
  const ShuttleStopSelectionGrid({
    super.key,
    required this.route,
    required this.selectedStopId,
    required this.onStopSelected,
    this.savedPreference,
  });

  final CommuteRoute route;
  final String? selectedStopId;
  final ValueChanged<CommuteRouteStop> onStopSelected;
  final SeekerShuttleCommutePreference? savedPreference;

  List<CommuteRouteStop> get _pickupStops {
    final split = ShuttleRouteStopPolicy.splitRouteStops(route.stops);
    return split.intermediate;
  }

  @override
  Widget build(BuildContext context) {
    final stops = _pickupStops;
    if (stops.isEmpty) {
      return Text(
        '탑승 시간이 등록된 정류장이 없습니다.',
        style: TextStyle(
          fontSize: 13,
          color: AppColors.textSecondary.withValues(alpha: 0.9),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.45,
      ),
      itemCount: stops.length,
      itemBuilder: (context, index) {
        final stop = stops[index];
        final isSelected = selectedStopId == stop.id;
        final isSaved = savedPreference?.stopId == stop.id;
        return Material(
          color: isSelected
              ? AppColors.primaryLight.withValues(alpha: 0.35)
              : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => onStopSelected(stop),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : Colors.grey.shade300,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.directions_bus_outlined,
                        size: 18,
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
                      if (isSaved) ...[
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            '내 정류장',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const Spacer(),
                  Text(
                    stop.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                      color: isSelected
                          ? AppColors.textPrimary
                          : AppColors.textPrimary.withValues(alpha: 0.9),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    stop.departureTime == null
                        ? '탑승 시간 미등록'
                        : '${stop.departureTime} 탑승',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textSecondary.withValues(alpha: 0.95),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
