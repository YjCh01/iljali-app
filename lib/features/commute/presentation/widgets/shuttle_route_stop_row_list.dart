import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/features/commute/domain/entities/commute_route_stop.dart';
import 'package:map/features/commute/domain/utils/shuttle_route_color_utils.dart';
import 'package:map/features/commute/domain/utils/shuttle_route_stop_policy.dart';
import 'package:map/features/corporate/presentation/widgets/corporate_service_action_style.dart';

/// 셔틀 정류장 목록 — 상단 「+」 · 경유 정류장 스크롤 · 하단 근무지 고정
class ShuttleRouteStopRowList extends StatefulWidget {
  const ShuttleRouteStopRowList({
    super.key,
    required this.intermediateStops,
    required this.workplaceStop,
    required this.activeIndex,
    required this.positionAdjustIndex,
    required this.routeColorHex,
    required this.onRemove,
    required this.onAdd,
    required this.onPickPhoto,
    required this.onEditTime,
    this.onEditWorkplaceArrival,
    required this.onAdjustPosition,
    required this.onReorder,
    this.showActivationControls = true,
    this.selectedForActivation = const {},
    this.onToggleActivationSelection,
    this.lockedStopIds = const {},
    this.maxIntermediateStops = 14,
  });

  static const listViewportRows = 4;
  static const rowHeight = 60.0;
  static const listRadius = 12.0;

  final List<CommuteRouteStop> intermediateStops;
  final CommuteRouteStop workplaceStop;
  final int activeIndex;
  final int positionAdjustIndex;
  final String routeColorHex;
  final ValueChanged<int> onRemove;
  final VoidCallback onAdd;
  final ValueChanged<int> onPickPhoto;
  final ValueChanged<int> onEditTime;
  final VoidCallback? onEditWorkplaceArrival;
  final ValueChanged<int> onAdjustPosition;
  final void Function(int oldIndex, int newIndex) onReorder;
  final bool showActivationControls;
  final Set<String> selectedForActivation;
  final ValueChanged<int>? onToggleActivationSelection;
  final Set<String> lockedStopIds;
  final int maxIntermediateStops;

  @override
  State<ShuttleRouteStopRowList> createState() =>
      _ShuttleRouteStopRowListState();
}

class _ShuttleRouteStopRowListState extends State<ShuttleRouteStopRowList> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scheduleScrollToFocusedStop();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scheduleScrollToFocusedStop() {
    final target = _focusedIntermediateIndex;
    if (target < 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scrollToIndex(target);
    });
  }

  int get _focusedIntermediateIndex {
    if (widget.positionAdjustIndex >= 0) return widget.positionAdjustIndex;
    if (widget.activeIndex >= 0) return widget.activeIndex;
    return -1;
  }

  void _scrollToIndex(int index) {
    if (!_scrollController.hasClients || widget.intermediateStops.isEmpty) {
      return;
    }
    final cap = ShuttleRouteStopRowList.listViewportRows;
    final offset =
        ((index - cap + 1).clamp(0, index)) * ShuttleRouteStopRowList.rowHeight;
    final max = _scrollController.position.maxScrollExtent;
    _scrollController.jumpTo(offset.clamp(0.0, max));
  }

  @override
  void didUpdateWidget(covariant ShuttleRouteStopRowList oldWidget) {
    super.didUpdateWidget(oldWidget);
    final added =
        widget.intermediateStops.length > oldWidget.intermediateStops.length;
    final focusMoved =
        _focusedIntermediateIndex != _focusedIntermediateIndexFrom(oldWidget);
    if (added || focusMoved) {
      _scheduleScrollToFocusedStop();
    }
  }

  int _focusedIntermediateIndexFrom(ShuttleRouteStopRowList old) {
    if (old.positionAdjustIndex >= 0) return old.positionAdjustIndex;
    if (old.activeIndex >= 0) return old.activeIndex;
    return -1;
  }

  double get _listViewportHeight {
    if (widget.intermediateStops.isEmpty) return 0;
    final visibleRows = widget.intermediateStops.length
        .clamp(1, ShuttleRouteStopRowList.listViewportRows);
    return visibleRows * ShuttleRouteStopRowList.rowHeight;
  }

  bool get _canAddMore =>
      widget.intermediateStops.length < widget.maxIntermediateStops;

  int get _totalStopCount => widget.intermediateStops.length + 1;

  int get _maxTotalStops => widget.maxIntermediateStops + 1;

  int get _newStopCount => widget.intermediateStops
      .where((stop) => !widget.lockedStopIds.contains(stop.id))
      .length;

  @override
  Widget build(BuildContext context) {
    final routeColor = ShuttleRouteColorUtils.parseHex(widget.routeColorHex);
    final activatedCount = widget.showActivationControls
        ? widget.intermediateStops.where((s) => s.exposureActivated).length
        : 0;
    final scrollHeight = _listViewportHeight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '정류장',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary.withValues(alpha: 0.92),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          widget.lockedStopIds.isNotEmpty
              ? '총 $_totalStopCount/$_maxTotalStops곳(근무지 포함) · 새로 추가 $_newStopCount곳'
              : '총 $_totalStopCount/$_maxTotalStops곳 · 근무지 포함',
          style: TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary.withValues(alpha: 0.85),
          ),
        ),
        const SizedBox(height: 6),
        if (widget.showActivationControls) ...[
          Text(
            '저장은 무료 · 체크 후 결제하면 구직자 지도에 정류장이 보입니다.',
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: AppColors.textSecondary.withValues(alpha: 0.9),
            ),
          ),
          if (activatedCount > 0 && activatedCount < 3) ...[
            const SizedBox(height: 2),
            Text(
              '정류장 ${3 - activatedCount}곳 더 노출하면 경로가 연결됩니다.',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: routeColor.withValues(alpha: 0.9),
              ),
            ),
          ] else ...[
            const SizedBox(height: 2),
            Text(
              '정류장 3곳 이상 노출 시 노선 경로도 함께 표시됩니다.',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary.withValues(alpha: 0.82),
              ),
            ),
          ],
          const SizedBox(height: 8),
        ] else
          const SizedBox(height: 8),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius:
                BorderRadius.circular(ShuttleRouteStopRowList.listRadius),
            border: Border.all(color: AppColors.searchBarBorder),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_canAddMore)
                _ShuttleStopAddRow(onTap: widget.onAdd)
              else
                _ShuttleStopMaxRow(maxStops: _maxTotalStops),
              if (widget.intermediateStops.isNotEmpty) ...[
                Divider(
                  height: 1,
                  thickness: 1,
                  color: AppColors.searchBarBorder.withValues(alpha: 0.85),
                ),
                SizedBox(
                  height: scrollHeight,
                  child: ReorderableListView.builder(
                    scrollController: _scrollController,
                    padding: EdgeInsets.zero,
                    buildDefaultDragHandles: false,
                    itemCount: widget.intermediateStops.length,
                    onReorder: widget.onReorder,
                    itemBuilder: (context, index) {
                      final stop = widget.intermediateStops[index];
                      final locked = widget.lockedStopIds.contains(stop.id);
                      return Column(
                        key: ValueKey(stop.id),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _ShuttleRouteStopRow(
                            index: index,
                            stop: stop,
                            selected: index == widget.activeIndex,
                            adjusting: index == widget.positionAdjustIndex,
                            routeColor: routeColor,
                            isFirst: index == 0,
                            isNewStop: widget.lockedStopIds.isNotEmpty &&
                                !widget.lockedStopIds.contains(stop.id),
                            showActivationControls:
                                widget.showActivationControls,
                            isLocked: locked,
                            checked: stop.exposureActivated ||
                                widget.selectedForActivation.contains(stop.id),
                            checkEnabled: !stop.exposureActivated,
                            onToggleCheck: stop.exposureActivated ||
                                    !widget.showActivationControls
                                ? null
                                : () => widget
                                    .onToggleActivationSelection?.call(index),
                            onTap: () => widget.onAdjustPosition(index),
                            onPickPhoto: locked
                                ? null
                                : () => widget.onPickPhoto(index),
                            onEditTime: locked
                                ? null
                                : () => widget.onEditTime(index),
                            onRemove: locked
                                ? null
                                : () => widget.onRemove(index),
                            dragHandle: locked
                                ? Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                    ),
                                    child: Icon(
                                      Icons.lock_clock_outlined,
                                      size: 18,
                                      color: AppColors.textSecondary
                                          .withValues(alpha: 0.45),
                                    ),
                                  )
                                : ReorderableDragStartListener(
                                    index: index,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 2,
                                      ),
                                      child: Icon(
                                        Icons.drag_handle,
                                        size: 20,
                                        color: AppColors.textSecondary
                                            .withValues(alpha: 0.65),
                                      ),
                                    ),
                                  ),
                          ),
                          if (index < widget.intermediateStops.length - 1)
                            Divider(
                              height: 1,
                              thickness: 1,
                              color: AppColors.searchBarBorder
                                  .withValues(alpha: 0.85),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ],
              Divider(
                height: 1,
                thickness: 1,
                color: AppColors.searchBarBorder.withValues(alpha: 0.85),
              ),
              _ShuttleWorkplaceStopRow(
                workplaceStop: widget.workplaceStop,
                onEditArrival: widget.onEditWorkplaceArrival,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ShuttleRouteStopRow extends StatelessWidget {
  const _ShuttleRouteStopRow({
    required this.index,
    required this.stop,
    required this.selected,
    required this.adjusting,
    required this.routeColor,
    required this.isFirst,
    this.isNewStop = false,
    this.showActivationControls = true,
    required this.checked,
    required this.checkEnabled,
    this.isLocked = false,
    this.onToggleCheck,
    required this.onTap,
    this.onPickPhoto,
    this.onEditTime,
    this.onRemove,
    required this.dragHandle,
  });

  final int index;
  final CommuteRouteStop stop;
  final bool selected;
  final bool adjusting;
  final Color routeColor;
  final bool isFirst;
  final bool isNewStop;
  final bool showActivationControls;
  final bool checked;
  final bool checkEnabled;
  final bool isLocked;
  final VoidCallback? onToggleCheck;
  final VoidCallback onTap;
  final VoidCallback? onPickPhoto;
  final VoidCallback? onEditTime;
  final VoidCallback? onRemove;
  final Widget dragHandle;

  bool get _hasPhoto => stop.photoPath?.trim().isNotEmpty == true;

  String get _timeDisplay {
    final time = stop.departureTime?.trim();
    if (time != null && time.isNotEmpty) return time;
    return '00:00';
  }

  bool get _timeMissing =>
      stop.departureTime == null || stop.departureTime!.trim().isEmpty;

  @override
  Widget build(BuildContext context) {
    final statusLabel = isLocked
        ? '노출 중 · 수정 불가'
        : adjusting
            ? '위치 조정 중'
            : isNewStop
                ? '새 정류장 · 탭하여 위치 조정'
                : !showActivationControls
                    ? '탭하여 위치 조정'
                    : stop.exposureActivated
                        ? '지도 노출 중'
                        : '탭하여 위치 조정';

    return Material(
      color: isLocked
          ? AppColors.textSecondary.withValues(alpha: 0.08)
          : adjusting
              ? routeColor.withValues(alpha: 0.18)
              : isNewStop
                  ? routeColor.withValues(alpha: 0.1)
                  : selected
                      ? routeColor.withValues(alpha: 0.12)
                      : AppColors.surface,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: ShuttleRouteStopRowList.rowHeight,
          child: Row(
            children: [
              if (showActivationControls)
                SizedBox(
                  width: 36,
                  child: stop.exposureActivated
                      ? Icon(Icons.check_circle, size: 20, color: routeColor)
                      : Checkbox(
                          value: checked,
                          onChanged: checkEnabled
                              ? (_) => onToggleCheck?.call()
                              : null,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                          activeColor: routeColor,
                        ),
                ),
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color:
                      selected || adjusting ? routeColor : Colors.transparent,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: routeColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: routeColor,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.place_outlined, size: 17, color: routeColor),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stop.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isLocked
                            ? AppColors.textSecondary.withValues(alpha: 0.7)
                            : AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      adjusting ? '위치 조정 중' : statusLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: isLocked
                            ? AppColors.textSecondary.withValues(alpha: 0.65)
                            : adjusting
                                ? routeColor
                                : AppColors.textSecondary
                                    .withValues(alpha: 0.85),
                        fontWeight:
                            adjusting ? FontWeight.w700 : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              if (onPickPhoto != null)
                _StopRowIconButton(
                  tooltip: _hasPhoto ? '사진 변경' : '사진 등록',
                  icon: _hasPhoto
                      ? Icons.photo_camera_rounded
                      : Icons.add_a_photo_outlined,
                  onTap: onPickPhoto!,
                  color: _hasPhoto ? routeColor : AppColors.textSecondary,
                  filled: _hasPhoto,
                ),
              if (onEditTime != null)
                _StopTimeChip(
                  time: _timeDisplay,
                  isPlaceholder: _timeMissing,
                  emphasize: isFirst && _timeMissing,
                  routeColor: routeColor,
                  onTap: onEditTime!,
                ),
              dragHandle,
              if (onRemove != null)
                _StopRowAction(
                  label: '삭제',
                  onTap: onRemove!,
                  color: const Color(0xFFC62828),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShuttleWorkplaceStopRow extends StatelessWidget {
  const _ShuttleWorkplaceStopRow({
    required this.workplaceStop,
    this.onEditArrival,
  });

  final CommuteRouteStop workplaceStop;
  final VoidCallback? onEditArrival;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.textSecondary.withValues(alpha: 0.08),
      borderRadius: const BorderRadius.vertical(
        bottom: Radius.circular(ShuttleRouteStopRowList.listRadius),
      ),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: ShuttleRouteStopRowList.rowHeight,
        child: Row(
          children: [
            const SizedBox(width: 12),
            Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFF5E35B1).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.business_outlined,
                size: 13,
                color: Color(0xFF5E35B1),
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.flag_outlined,
              size: 17,
              color: Color(0xFF5E35B1),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    ShuttleRouteStopPolicy.workplaceLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    workplaceStop.arrivalTime?.trim().isNotEmpty == true
                        ? '도착 ${workplaceStop.arrivalTime} · 알림 기준'
                        : '도착 시각 입력 · 시계 아이콘 탭',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            if (onEditArrival != null)
              _StopTimeChip(
                time: workplaceStop.arrivalTime?.trim().isNotEmpty == true
                    ? workplaceStop.arrivalTime!.trim()
                    : '00:00',
                isPlaceholder:
                    workplaceStop.arrivalTime?.trim().isNotEmpty != true,
                emphasize:
                    workplaceStop.arrivalTime?.trim().isNotEmpty != true,
                routeColor: const Color(0xFF5E35B1),
                onTap: onEditArrival!,
              )
            else
              Icon(
                Icons.lock_clock_outlined,
                size: 18,
                color: AppColors.textSecondary.withValues(alpha: 0.55),
              ),
            const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }
}

class _StopRowIconButton extends StatelessWidget {
  const _StopRowIconButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
    required this.color,
    this.filled = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;
  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.all(4),
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      icon: Icon(
        icon,
        size: 18,
        color: filled ? color : color.withValues(alpha: 0.82),
      ),
      style: filled
          ? IconButton.styleFrom(
              backgroundColor: color.withValues(alpha: 0.12),
            )
          : null,
    );
  }
}

class _StopTimeChip extends StatelessWidget {
  const _StopTimeChip({
    required this.time,
    required this.isPlaceholder,
    required this.emphasize,
    required this.routeColor,
    required this.onTap,
  });

  final String time;
  final bool isPlaceholder;
  final bool emphasize;
  final Color routeColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = emphasize
        ? const Color(0xFFE65100)
        : isPlaceholder
            ? AppColors.textSecondary.withValues(alpha: 0.35)
            : routeColor.withValues(alpha: 0.45);
    final textColor = isPlaceholder
        ? AppColors.textSecondary.withValues(alpha: 0.55)
        : routeColor;

    return Padding(
      padding: const EdgeInsets.only(right: 2),
      child: Material(
        color: emphasize
            ? const Color(0xFFFFF3E0)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.schedule_outlined,
                  size: 14,
                  color: textColor.withValues(alpha: isPlaceholder ? 0.7 : 1),
                ),
                const SizedBox(width: 3),
                Text(
                  time,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: textColor,
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

class _StopRowAction extends StatelessWidget {
  const _StopRowAction({
    required this.label,
    required this.onTap,
    required this.color,
  });

  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: color.withValues(alpha: 0.88),
          ),
        ),
      ),
    );
  }
}

class _ShuttleStopMaxRow extends StatelessWidget {
  const _ShuttleStopMaxRow({required this.maxStops});

  final int maxStops;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      child: SizedBox(
        height: ShuttleRouteStopRowList.rowHeight,
        child: Center(
          child: Text(
            '노선당 최대 $maxStops곳까지 등록할 수 있습니다',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary.withValues(alpha: 0.85),
            ),
          ),
        ),
      ),
    );
  }
}

class _ShuttleStopAddRow extends StatelessWidget {
  const _ShuttleStopAddRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: CorporateServiceActionStyle.setupBackground,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: ShuttleRouteStopRowList.rowHeight,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add_rounded,
                size: 20,
                color: CorporateServiceActionStyle.setupForeground
                    .withValues(alpha: 0.95),
              ),
              const SizedBox(width: 6),
              Text(
                '정류장 추가',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: CorporateServiceActionStyle.setupForeground
                      .withValues(alpha: 0.95),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
