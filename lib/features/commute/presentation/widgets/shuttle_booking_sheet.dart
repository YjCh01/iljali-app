import 'package:flutter/material.dart';
import 'package:map/core/widgets/adaptive_sheet.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/features/commute/domain/entities/commute_route.dart';
import 'package:map/features/commute/domain/entities/commute_route_stop.dart';

/// 셔틀 탑승 정류장·시간 선택
class ShuttleBookingSelection {
  const ShuttleBookingSelection({
    required this.stop,
    required this.pickupTime,
  });

  final CommuteRouteStop stop;
  final String pickupTime;
}

Future<ShuttleBookingSelection?> showShuttleBookingSheet(
  BuildContext context, {
  required CommuteRoute route,
  CommuteRouteStop? initialStop,
}) {
  return showAdaptiveSheet<ShuttleBookingSelection>(
    context: context,
    builder: (ctx) => _ShuttleBookingSheetBody(
      route: route,
      initialStop: initialStop,
    ),
  );
}

class _ShuttleBookingSheetBody extends StatefulWidget {
  const _ShuttleBookingSheetBody({
    required this.route,
    this.initialStop,
  });

  final CommuteRoute route;
  final CommuteRouteStop? initialStop;

  @override
  State<_ShuttleBookingSheetBody> createState() =>
      _ShuttleBookingSheetBodyState();
}

class _ShuttleBookingSheetBodyState extends State<_ShuttleBookingSheetBody> {
  CommuteRouteStop? _selected;

  List<CommuteRouteStop> get _pickupStops => widget.route.stops
      .where((s) => s.departureTime != null)
      .toList();

  @override
  void initState() {
    super.initState();
    _selected = widget.initialStop ??
        (_pickupStops.isNotEmpty ? _pickupStops.first : null);
  }

  @override
  Widget build(BuildContext context) {
    final stops = _pickupStops;
    final selected = _selected;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '셔틀 탑승 정류장 선택',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              widget.route.routeName,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary.withValues(alpha: 0.95),
              ),
            ),
            const SizedBox(height: 16),
            if (stops.isEmpty)
              const Text('탑승 가능한 정류장이 없습니다.')
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.45,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: stops.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final stop = stops[index];
                    final isSelected = selected?.id == stop.id;
                    return Material(
                      color: isSelected
                          ? Colors.red.shade50
                          : AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => setState(() => _selected = stop),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isSelected
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_off,
                                color: isSelected
                                    ? Colors.red.shade700
                                    : AppColors.textSecondary,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      stop.label,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: isSelected
                                            ? Colors.red.shade900
                                            : AppColors.textPrimary,
                                      ),
                                    ),
                                    if (stop.departureTime != null)
                                      Text(
                                        '탑승 ${stop.departureTime}',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.red.shade800,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: selected == null || selected.departureTime == null
                  ? null
                  : () {
                      Navigator.of(context).pop(
                        ShuttleBookingSelection(
                          stop: selected,
                          pickupTime: selected.departureTime!,
                        ),
                      );
                    },
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                '셔틀 이용 확정',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
