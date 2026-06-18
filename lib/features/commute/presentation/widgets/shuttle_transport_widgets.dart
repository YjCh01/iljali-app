import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/features/commute/domain/entities/commute_route.dart';
import 'package:map/features/commute/domain/entities/shuttle_operation_guide_copy.dart';

/// Wonolo·일본 앱 스타일 — 셔틀 배지 (리스트·상세 상단)
class ShuttleBenefitChips extends StatelessWidget {
  const ShuttleBenefitChips({
    super.key,
    this.compact = false,
  });

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: compact ? 6 : 8,
      runSpacing: 6,
      children: [
        _chip(
          icon: Icons.directions_bus_filled,
          label: '셔틀 운행',
          color: Colors.red.shade700,
          bg: Colors.red.shade50,
        ),
      ],
    );
  }

  Widget _chip({
    required IconData icon,
    required String label,
    required Color color,
    required Color bg,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 14 : 16, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// 정류장별 출발 시간표 (일본 앱 스타일)
class ShuttleTimetableTable extends StatelessWidget {
  const ShuttleTimetableTable({
    super.key,
    required this.route,
  });

  final CommuteRoute route;

  @override
  Widget build(BuildContext context) {
    final stops = route.stops;
    if (stops.isEmpty) return const SizedBox.shrink();

    return Table(
      columnWidths: const {
        0: FixedColumnWidth(52),
        1: FlexColumnWidth(),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        TableRow(
          decoration: BoxDecoration(
            color: Colors.red.shade50.withValues(alpha: 0.6),
          ),
          children: const [
            _TableHead('탑승'),
            _TableHead('정류장'),
          ],
        ),
        ...stops.asMap().entries.map((entry) {
          final stop = entry.value;
          final isLast = entry.key == stops.length - 1;
          final timeLabel = isLast && stop.departureTime == null
              ? '도착'
              : (stop.departureTime ?? '—');
          return TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                child: Text(
                  timeLabel,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: isLast
                        ? Colors.red.shade800
                        : AppColors.textPrimary,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Text(
                  stop.label,
                  style: const TextStyle(fontSize: 13, height: 1.3),
                ),
              ),
            ],
          );
        }),
      ],
    );
  }
}

class _TableHead extends StatelessWidget {
  const _TableHead(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: Colors.red.shade900,
        ),
      ),
    );
  }
}

/// 공고 상세 — 통근·교통 전용 섹션 (핀 탭 바텀시트)
class ShuttleTransportDetailCard extends StatelessWidget {
  const ShuttleTransportDetailCard({
    super.key,
    required this.route,
    this.onShowRouteOnMap,
    this.loading = false,
  });

  final CommuteRoute? route;
  final VoidCallback? onShowRouteOnMap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final resolved = route;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.red.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.directions_bus, size: 20, color: Colors.red.shade700),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '통근·교통 (送迎バス)',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.red.shade900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ShuttleBenefitChips(compact: true),
          const SizedBox(height: 10),
          if (loading || resolved == null)
            const Text(
              '노선 정보를 불러오는 중입니다.',
              style: TextStyle(fontSize: 12),
            )
          else ...[
            Text(
              resolved.routeName,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (resolved.vehicleGuide.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              _NoteBlock(
                title: '차량안내',
                body: resolved.vehicleGuide.trim(),
                icon: Icons.directions_bus_outlined,
              ),
            ],
            const SizedBox(height: 10),
            ShuttleTimetableTable(route: resolved),
            const SizedBox(height: 10),
            _NoteBlock(
              title: '탑승·도착 안내',
              body: ShuttleOperationGuideCopy.boardingNotesForDisplay(
                resolved.boardingNotes,
              ),
              icon: Icons.info_outline,
            ),
            if (resolved.arrivalInstructions.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              _NoteBlock(
                title: '도착·현장 안내',
                body: ShuttleOperationGuideCopy.arrivalInstructionsForDisplay(
                  resolved.arrivalInstructions,
                ),
                icon: Icons.login_outlined,
              ),
            ],
            if (onShowRouteOnMap != null) ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.tonalIcon(
                  onPressed: onShowRouteOnMap,
                  icon: const Icon(Icons.map_outlined, size: 18),
                  label: const Text('지도에서 노선 보기'),
                  style: FilledButton.styleFrom(
                    foregroundColor: Colors.red.shade800,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),
            Text(
              ShuttleOperationGuideCopy.driverDisclaimer,
              style: TextStyle(
                fontSize: 11,
                height: 1.45,
                color: AppColors.textSecondary.withValues(alpha: 0.92),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NoteBlock extends StatelessWidget {
  const _NoteBlock({
    required this.title,
    required this.body,
    required this.icon,
  });

  final String title;
  final String body;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.red.shade700),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.red.shade900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                body,
                style: const TextStyle(fontSize: 12, height: 1.45),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class ShuttleMapFilterChip extends StatelessWidget {
  const ShuttleMapFilterChip({
    super.key,
    required this.active,
    required this.onChanged,
  });

  /// true면 셔틀 운행 공고만 표시
  final bool active;
  final ValueChanged<bool> onChanged;

  static const _activeLabel = '셔틀 있음';
  static const _inactiveLabel = '전체';

  @override
  Widget build(BuildContext context) {
    final accent = Colors.red.shade700;
    final muted = AppColors.textSecondary;

    return Semantics(
      button: true,
      selected: active,
      label: active
          ? '$_activeLabel 필터 적용 중. 탭하면 $_inactiveLabel 공고를 표시합니다.'
          : '$_inactiveLabel 공고 표시 중. 탭하면 $_activeLabel 공고만 표시합니다.',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onChanged(!active),
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: active
                  ? accent
                  : Colors.white.withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: active ? accent : muted.withValues(alpha: 0.35),
                width: active ? 0 : 1,
              ),
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.28),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  active
                      ? Icons.directions_bus
                      : Icons.directions_bus_outlined,
                  size: 18,
                  color: active ? Colors.white : muted,
                ),
                const SizedBox(width: 6),
                Text(
                  active ? _activeLabel : _inactiveLabel,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: active ? Colors.white : muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 클러스터·카드용 미니 셔틀 태그
class ShuttleListTag extends StatelessWidget {
  const ShuttleListTag({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.directions_bus, size: 12, color: Colors.red.shade700),
          const SizedBox(width: 3),
          Text(
            '셔틀',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: Colors.red.shade800,
            ),
          ),
        ],
      ),
    );
  }
}
