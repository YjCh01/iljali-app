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
    required this.onSelect,
    required this.onRemove,
    required this.onAdd,
    required this.onEditDetails,
    required this.onAdjustPosition,
    required this.onReorder,
    this.showActivationControls = true,
    this.selectedForActivation = const {},
    this.onToggleActivationSelection,
    this.lockedStopIds = const {},
    this.maxIntermediateStops = 14,
  });

  static const listViewportRows = 4;
  static const rowHeight = 56.0;
  static const listRadius = 12.0;

  final List<CommuteRouteStop> intermediateStops;
  final CommuteRouteStop workplaceStop;
  final int activeIndex;
  final int positionAdjustIndex;
  final String routeColorHex;
  final ValueChanged<int> onSelect;
  final ValueChanged<int> onRemove;
  final VoidCallback onAdd;
  final ValueChanged<int> onEditDetails;
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
                            onTap: () => widget.onSelect(index),
                            onEditDetails: locked
                                ? null
                                : () => widget.onEditDetails(index),
                            onAdjustPosition: locked
                                ? null
                                : () => widget.onAdjustPosition(index),
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
              const _ShuttleWorkplaceStopRow(),
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
    this.onEditDetails,
    this.onAdjustPosition,
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
  final VoidCallback? onEditDetails;
  final VoidCallback? onAdjustPosition;
  final VoidCallback? onRemove;
  final Widget dragHandle;

  @override
  Widget build(BuildContext context) {
    final timeLabel = isLocked
        ? '노출 중 · 수정 불가'
        : adjusting
            ? '위치 조정 중'
            : isNewStop
                ? '새 정류장 · 지도에서 위치 조정'
                : !showActivationControls
                    ? (stop.departureTime == null
                        ? '경유·도착'
                        : '탑승 ${stop.departureTime}')
                    : stop.exposureActivated
                        ? '지도 노출 중'
                        : stop.departureTime == null
                            ? '경유·도착'
                            : '탑승 ${stop.departureTime}';

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
                      adjusting ? '위치 조정 중' : timeLabel,
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
              if (onEditDetails != null)
                _StopRowAction(
                  label: '편집',
                  onTap: onEditDetails!,
                  color: routeColor,
                ),
              if (onAdjustPosition != null)
                _StopRowAction(
                  label: '수정',
                  onTap: onAdjustPosition!,
                  color: adjusting ? routeColor : AppColors.textSecondary,
                  emphasized: adjusting,
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
  const _ShuttleWorkplaceStopRow();

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
            const Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
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
                    '도착지 · 수정 불가',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
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

class _StopRowAction extends StatelessWidget {
  const _StopRowAction({
    required this.label,
    required this.onTap,
    required this.color,
    this.emphasized = false,
  });

  final String label;
  final VoidCallback onTap;
  final Color color;
  final bool emphasized;

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
            fontWeight: emphasized ? FontWeight.w800 : FontWeight.w700,
            color: color.withValues(alpha: emphasized ? 1 : 0.88),
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
