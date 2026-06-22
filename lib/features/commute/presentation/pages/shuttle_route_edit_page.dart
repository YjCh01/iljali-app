import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/constants/app_routes.dart';
import 'package:map/core/geo/geo_coordinate.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/core/widgets/app_back_button.dart';
import 'package:map/core/widgets/map_form_split_layout.dart';
import 'package:map/core/widgets/web_right_navigation_rail.dart';
import 'package:map/features/commute/data/repositories/commute_route_repository.dart';
import 'package:map/features/commute/domain/entities/commute_route.dart';
import 'package:map/features/commute/domain/entities/commute_route_stop.dart';
import 'package:map/features/commute/domain/entities/shuttle_operation_guide_copy.dart';
import 'package:map/features/commute/domain/utils/shuttle_route_color_utils.dart';
import 'package:map/features/commute/domain/utils/shuttle_route_stop_policy.dart';
import 'package:map/features/commute/presentation/widgets/shuttle_route_color_picker.dart';
import 'package:map/features/commute/presentation/widgets/shuttle_route_stop_editor_sheet.dart';
import 'package:map/features/commute/presentation/widgets/shuttle_route_stop_row_list.dart';
import 'package:map/features/commute/domain/utils/shuttle_route_visibility.dart';
import 'package:map/features/corporate/presentation/widgets/push_radius_map_picker.dart';

/// 노선 수정 화면 진입 인자 — [lockedStopIds]가 있으면 해당 정류장은 보호하고 추가만 허용
class ShuttleRouteEditArgs {
  const ShuttleRouteEditArgs({
    this.route,
    this.lockedStopIds = const {},
    this.workplaceCoordinate,
  });

  final CommuteRoute? route;
  final Set<String> lockedStopIds;
  final GeoCoordinate? workplaceCoordinate;
}

/// 기업 — 셔틀 노선 등록·수정
class ShuttleRouteEditPage extends StatefulWidget {
  const ShuttleRouteEditPage({
    super.key,
    this.existing,
    this.lockedStopIds = const {},
    this.initialWorkplaceCoordinate,
  });

  final CommuteRoute? existing;
  final Set<String> lockedStopIds;
  final GeoCoordinate? initialWorkplaceCoordinate;

  @override
  State<ShuttleRouteEditPage> createState() => _ShuttleRouteEditPageState();
}

class _ShuttleRouteEditPageState extends State<ShuttleRouteEditPage> {
  final _nameController = TextEditingController();
  final _boardingNotesController = TextEditingController();
  final _arrivalNotesController = TextEditingController();
  final _vehicleGuideController = TextEditingController();
  final List<CommuteRouteStop> _intermediateStops = [];
  late CommuteRouteStop _workplaceStop;
  String _colorHex = '#E53935';
  bool _saving = false;
  bool _showOptionalNotes = false;
  int _activeStopIndex = -1;
  int _positionAdjustIndex = -1;
  String? _savedRouteId;
  late GeoCoordinate _mapCenter;
  final DraggableScrollableController _bottomSheetController =
      DraggableScrollableController();

  static const _bottomSheetSnaps = [0.22, 0.36, 0.58, 0.82];

  bool get _addOnlyMode => widget.lockedStopIds.isNotEmpty;

  List<CommuteRouteStop> get _stops =>
      ShuttleRouteStopPolicy.mergeStops(_intermediateStops, _workplaceStop);

  bool _isStopLocked(int index) =>
      index >= 0 &&
      index < _intermediateStops.length &&
      widget.lockedStopIds.contains(_intermediateStops[index].id);

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _nameController.text = existing.routeName;
      _boardingNotesController.text = existing.boardingNotes;
      _arrivalNotesController.text =
          ShuttleOperationGuideCopy.normalizeGuideText(
        existing.arrivalInstructions,
      );
      _vehicleGuideController.text = existing.vehicleGuide;
      final split = ShuttleRouteStopPolicy.splitRouteStops(existing.stops);
      _intermediateStops.addAll(split.intermediate);
      _workplaceStop = split.workplace;
      _colorHex = existing.overlayColorHex;
      _showOptionalNotes = existing.vehicleGuide.trim().isNotEmpty ||
          existing.boardingNotes.trim().isNotEmpty ||
          existing.arrivalInstructions.trim().isNotEmpty;
    } else {
      _workplaceStop = ShuttleRouteStopPolicy.defaultWorkplace(
        coordinate: widget.initialWorkplaceCoordinate,
      );
      _boardingNotesController.text =
          ShuttleOperationGuideCopy.boardingWaitRecommendation;
    }
    _syncMapFromStops();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _boardingNotesController.dispose();
    _arrivalNotesController.dispose();
    _vehicleGuideController.dispose();
    _bottomSheetController.dispose();
    super.dispose();
  }

  String? get _routeId => widget.existing?.id ?? _savedRouteId;

  void _syncMapFromStops() {
    if (_intermediateStops.isEmpty) {
      _activeStopIndex = -1;
      _mapCenter = _workplaceStop.coordinate;
      return;
    }
    if (_activeStopIndex < 0 ||
        _activeStopIndex >= _intermediateStops.length) {
      _activeStopIndex = 0;
    }
    _mapCenter = _intermediateStops[_activeStopIndex].coordinate;
  }

  void _finalizePositionAdjust() {
    if (_positionAdjustIndex >= 0 &&
        _positionAdjustIndex < _intermediateStops.length) {
      _intermediateStops[_positionAdjustIndex] =
          _intermediateStops[_positionAdjustIndex].copyWith(
        coordinate: _mapCenter,
      );
    }
  }

  void _selectStop(int index) {
    setState(() {
      _activeStopIndex = index;
      _positionAdjustIndex = -1;
      _mapCenter = _intermediateStops[index].coordinate;
    });
  }

  void _onMapPointTap(int pointIndex) {
    if (pointIndex >= 0 && pointIndex < _intermediateStops.length) {
      _selectStop(pointIndex);
    }
  }

  void _addStop() {
    if (_intermediateStops.length >= ShuttleRouteStopPolicy.maxIntermediateStops) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '경유 정류장은 최대 ${ShuttleRouteStopPolicy.maxIntermediateStops}곳까지 등록할 수 있습니다.',
          ),
        ),
      );
      return;
    }
    setState(() {
      _finalizePositionAdjust();
      final n = _intermediateStops.length;
      final newStop = CommuteRouteStop(
        id: 'stop_${DateTime.now().millisecondsSinceEpoch}',
        label: '정류장 ${n + 1}',
        coordinate: _mapCenter,
      );
      _intermediateStops.add(newStop);
      _activeStopIndex = n;
      _positionAdjustIndex = n;
    });
  }

  Future<void> _editStopDetails(int index) async {
    if (_isStopLocked(index)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('노출 중인 정류장은 수정할 수 없습니다.')),
      );
      return;
    }
    final saved = await ShuttleRouteStopEditorSheet.showDetails(
      context,
      initialStop: _intermediateStops[index],
      siblingStops: _stops,
      isLastStopHint: false,
    );
    if (saved == null || !mounted) return;
    setState(() {
      _intermediateStops[index] = saved;
    });
  }

  void _startPositionAdjust(int index) {
    if (_isStopLocked(index)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('노출 중인 정류장은 위치를 수정할 수 없습니다.')),
      );
      return;
    }
    setState(() {
      _activeStopIndex = index;
      _positionAdjustIndex = index;
      _mapCenter = _intermediateStops[index].coordinate;
    });
  }

  void _finishPositionAdjust() {
    if (_positionAdjustIndex < 0) return;
    setState(() => _positionAdjustIndex = -1);
  }

  void _onMapCenterChanged(GeoCoordinate coordinate) {
    setState(() {
      _mapCenter = coordinate;
      if (_positionAdjustIndex >= 0 &&
          _positionAdjustIndex < _intermediateStops.length) {
        _intermediateStops[_positionAdjustIndex] =
            _intermediateStops[_positionAdjustIndex]
                .copyWith(coordinate: coordinate);
      }
    });
  }

  void _removeStop(int index) {
    if (_isStopLocked(index)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('노출 중인 정류장은 삭제할 수 없습니다.')),
      );
      return;
    }
    setState(() {
      _intermediateStops.removeAt(index);
      if (_positionAdjustIndex == index) {
        _positionAdjustIndex = -1;
      } else if (_positionAdjustIndex > index) {
        _positionAdjustIndex--;
      }
      _syncMapFromStops();
    });
  }

  void _onReorder(int oldIndex, int newIndex) {
    if (_isStopLocked(oldIndex) || _isStopLocked(newIndex)) return;
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final activeId = _activeStopIndex >= 0 &&
              _activeStopIndex < _intermediateStops.length
          ? _intermediateStops[_activeStopIndex].id
          : null;
      final adjustId = _positionAdjustIndex >= 0 &&
              _positionAdjustIndex < _intermediateStops.length
          ? _intermediateStops[_positionAdjustIndex].id
          : null;
      final item = _intermediateStops.removeAt(oldIndex);
      _intermediateStops.insert(newIndex, item);
      if (activeId != null) {
        _activeStopIndex =
            _intermediateStops.indexWhere((s) => s.id == activeId);
      }
      if (adjustId != null) {
        _positionAdjustIndex =
            _intermediateStops.indexWhere((s) => s.id == adjustId);
      }
      _syncMapFromStops();
    });
  }

  List<GeoCoordinate> get _routePolylinePoints {
    final active = _stops.where((s) => s.exposureActivated).toList();
    if (active.length < ShuttleRouteVisibility.polylineMinActivatedStops) {
      return const [];
    }
    return active.map((s) => s.coordinate).toList(growable: false);
  }

  List<PushRadiusMapOverlayPoint> get _mapOverlays {
    final overlays = <PushRadiusMapOverlayPoint>[];
    for (var i = 0; i < _intermediateStops.length; i++) {
      if (_positionAdjustIndex == i) continue;
      overlays.add(
        PushRadiusMapOverlayPoint(
          coordinate: _intermediateStops[i].coordinate,
          radiusMeters: 0,
          label: '${i + 1}. ${_intermediateStops[i].label}',
          pointIndex: i,
        ),
      );
    }
    overlays.add(
      PushRadiusMapOverlayPoint(
        coordinate: _workplaceStop.coordinate,
        radiusMeters: 0,
        label: ShuttleRouteStopPolicy.workplaceLabel,
        pointIndex: ShuttleRouteStopPolicy.workplaceAdjustIndex,
      ),
    );
    return overlays;
  }

  String? get _activeMapLabel {
    if (_positionAdjustIndex >= 0 &&
        _positionAdjustIndex < _intermediateStops.length) {
      return '${_positionAdjustIndex + 1}. '
          '${_intermediateStops[_positionAdjustIndex].label}';
    }
    if (_intermediateStops.isEmpty) {
      return '지도에서 위치 선택';
    }
    return '새 정류장 위치';
  }

  Future<String?> _persistRoute({required bool showValidationErrors}) async {
    final profile = AuthSession.instance.currentUser?.corporateProfile;
    if (profile == null) return null;

    final name = _nameController.text.trim();
    if (name.isEmpty) {
      if (showValidationErrors) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('노선 이름을 입력해 주세요.')),
        );
      }
      return null;
    }
    if (_intermediateStops.isEmpty) {
      if (showValidationErrors) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('경유 정류장을 1곳 이상 추가해 주세요.')),
        );
      }
      return null;
    }
    if (_stops.length > CommuteRoute.maxStopsPerRoute) {
      if (showValidationErrors) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '노선당 최대 ${CommuteRoute.maxStopsPerRoute}곳까지 등록할 수 있습니다.',
            ),
          ),
        );
      }
      return null;
    }

    final route = CommuteRoute(
      id: _routeId ?? 'route_${DateTime.now().millisecondsSinceEpoch}',
      companyKey: profile.companyKey,
      routeName: name,
      stops: List.unmodifiable(_stops),
      polylinePoints: _routePolylinePoints,
      overlayColorHex: _colorHex,
      boardingNotes: _boardingNotesController.text.trim(),
      arrivalInstructions: ShuttleOperationGuideCopy.normalizeGuideText(
        _arrivalNotesController.text.trim(),
      ),
      vehicleGuide: _vehicleGuideController.text.trim(),
    );

    final repo = await CommuteRouteRepository.create();
    await repo.upsert(route);
    _savedRouteId = route.id;
    return route.id;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final routeId = await _persistRoute(showValidationErrors: true);
    if (!mounted) return;
    setState(() => _saving = false);
    if (routeId == null) return;

    final repo = await CommuteRouteRepository.create();
    final saved = await repo.findById(routeId);
    if (!mounted) return;
    Navigator.of(context).pop(saved);
  }

  Future<void> _openRouteList() async {
    await Navigator.of(context).pushNamed(AppRoutes.corporateShuttleRoutes);
    if (!mounted) return;
    final profile = AuthSession.instance.currentUser?.corporateProfile;
    if (profile == null) return;
    final repo = await CommuteRouteRepository.create();
    final routes = await repo.loadForCompany(profile.companyKey);
    if (!mounted || _routeId == null) return;
    CommuteRoute? refreshed;
    for (final route in routes) {
      if (route.id == _routeId) {
        refreshed = route;
        break;
      }
    }
    if (refreshed == null) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    final updated = refreshed;
    setState(() {
      _nameController.text = updated.routeName;
      _boardingNotesController.text = updated.boardingNotes;
      _arrivalNotesController.text =
          ShuttleOperationGuideCopy.normalizeGuideText(
        updated.arrivalInstructions,
      );
      _vehicleGuideController.text = updated.vehicleGuide;
      final split = ShuttleRouteStopPolicy.splitRouteStops(updated.stops);
      _intermediateStops
        ..clear()
        ..addAll(split.intermediate);
      _workplaceStop = split.workplace;
      _colorHex = updated.overlayColorHex;
      _syncMapFromStops();
    });
  }

  Widget _sheetDragHandle() {
    return MouseRegion(
      cursor: SystemMouseCursors.grab,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggleBottomSheet,
        onVerticalDragUpdate: (d) => _dragSheetByDelta(d.delta.dy),
        onVerticalDragEnd: (_) => _snapSheetToNearest(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
          child: Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textSecondary.withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _dragSheetByDelta(double deltaDy) {
    if (!_bottomSheetController.isAttached) return;
    final height = MediaQuery.sizeOf(context).height;
    if (height <= 0) return;
    final next = (_bottomSheetController.size - deltaDy / height).clamp(
      _bottomSheetSnaps.first,
      _bottomSheetSnaps.last,
    );
    _bottomSheetController.jumpTo(next);
  }

  void _snapSheetToNearest() {
    if (!_bottomSheetController.isAttached) return;
    final current = _bottomSheetController.size;
    var nearest = _bottomSheetSnaps.first;
    var bestDist = (current - nearest).abs();
    for (final snap in _bottomSheetSnaps) {
      final dist = (current - snap).abs();
      if (dist < bestDist) {
        bestDist = dist;
        nearest = snap;
      }
    }
    _bottomSheetController.animateTo(
      nearest,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  void _toggleBottomSheet() {
    if (!_bottomSheetController.isAttached) return;
    final current = _bottomSheetController.size;
    final next = current < 0.28 ? _bottomSheetSnaps[1] : _bottomSheetSnaps.first;
    _bottomSheetController.animateTo(
      next,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  Widget _buildMapLayer() {
    final wide = WebLayoutBreakpoints.isWideWeb(context);
    return PushRadiusMapPicker(
      key: ValueKey(
        'shuttle_map_${_activeStopIndex}_${_positionAdjustIndex}_'
        '${_stops.length}_'
        '${_stops.map((s) => s.id).join('-')}',
      ),
      center: _mapCenter,
      radiusMeters: 0,
      hideZeroRadiusLabel: true,
      centerEditable: true,
      existingPoints: _mapOverlays,
      activePointLabel: _activeMapLabel,
      polylinePoints: _routePolylinePoints,
      polylineColor: ShuttleRouteColorUtils.parseHex(_colorHex),
      onExistingPointTap:
          _intermediateStops.isNotEmpty ? _onMapPointTap : null,
      onCenterChanged: _onMapCenterChanged,
      maxZoom: 21,
      myLocationButtonBottom: wide ? 16 : 110,
    );
  }

  List<Widget> _buildRouteFormFieldList() {
    return [
                TextField(
                  controller: _nameController,
                  readOnly: _addOnlyMode,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: '노선 이름',
                    hintText: '예: 평택1노선, 평택2노선',
                    isDense: true,
                  ),
                ),
                if (_addOnlyMode) ...[
                  const SizedBox(height: 8),
                  Material(
                    color: AppColors.primaryLight.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Text(
                        '노출 중인 정류장은 수정·삭제할 수 없습니다. 새 정류장만 추가해 주세요.',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          fontWeight: FontWeight.w600,
                          color:
                              AppColors.textPrimary.withValues(alpha: 0.88),
                        ),
                      ),
                    ),
                  ),
                ],
                if (_positionAdjustIndex >= 0) ...[
                  const SizedBox(height: 8),
                  Material(
                    color: ShuttleRouteColorUtils.parseHex(_colorHex)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '지도를 움직여 정류장 위치를 조정하세요.',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color:
                                    ShuttleRouteColorUtils.parseHex(_colorHex),
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: _finishPositionAdjust,
                            child: const Text('완료'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                ShuttleRouteStopRowList(
                  intermediateStops:
                      List<CommuteRouteStop>.from(_intermediateStops),
                  workplaceStop: _workplaceStop,
                  activeIndex: _activeStopIndex,
                  positionAdjustIndex: _positionAdjustIndex,
                  routeColorHex: _colorHex,
                  showActivationControls: false,
                  lockedStopIds: widget.lockedStopIds,
                  onSelect: _selectStop,
                  onRemove: _removeStop,
                  onAdd: _addStop,
                  onEditDetails: _editStopDetails,
                  onAdjustPosition: _startPositionAdjust,
                  onReorder: _onReorder,
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 12),
                const Text(
                  '노선 색상',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                IgnorePointer(
                  ignoring: _addOnlyMode,
                  child: Opacity(
                    opacity: _addOnlyMode ? 0.55 : 1,
                    child: ShuttleRouteColorPicker(
                      colorHex: _colorHex,
                      onChanged: (hex) => setState(() => _colorHex = hex),
                    ),
                  ),
                ),
                if (!_addOnlyMode) ...[
                  const SizedBox(height: 12),
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    initiallyExpanded: _showOptionalNotes,
                    onExpansionChanged: (v) =>
                        setState(() => _showOptionalNotes = v),
                    title: const Text(
                      '운행 안내 (선택)',
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    subtitle: const Text(
                      '차량·탑승·현장 참고 메모',
                      style: TextStyle(fontSize: 12),
                    ),
                    children: [
                      TextField(
                        controller: _vehicleGuideController,
                        decoration: const InputDecoration(
                          labelText: '차량안내',
                          hintText:
                              '예: 12가3456 · 차량 앞유리에 (회사명)이 적혀 있습니다',
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _boardingNotesController,
                        decoration: const InputDecoration(
                          labelText: '탑승·정류장 안내',
                          hintText: '예: 탑승을 위해서 5분 전 대기를 권장합니다',
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _arrivalNotesController,
                        decoration: const InputDecoration(
                          labelText: '도착·현장 안내',
                          hintText: '예: 정문 경비실 옆 하차',
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(10),
                          border:
                              Border.all(color: AppColors.searchBarBorder),
                        ),
                        child: Text(
                          ShuttleOperationGuideCopy.driverDisclaimer,
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.45,
                            color:
                                AppColors.textSecondary.withValues(alpha: 0.95),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          '노선 저장',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _saving ? null : _openRouteList,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(
                      color: AppColors.primary.withValues(alpha: 0.45),
                    ),
                  ),
                  child: const Text(
                    '통근버스 노선도 리스트',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
    ];
  }

  Widget _buildBottomSheetContent(ScrollController scrollController) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sheetDragHandle(),
          Expanded(
            child: ListView(
              controller: scrollController,
              physics: const AlwaysScrollableScrollPhysics(
                parent: ClampingScrollPhysics(),
              ),
              padding: EdgeInsets.fromLTRB(16, 0, 16, 12 + bottomInset),
              children: _buildRouteFormFieldList(),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = WebLayoutBreakpoints.isWideWeb(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      extendBody: !wide,
      appBar: AppBar(
        backgroundColor: AppColors.surface.withValues(alpha: 0.94),
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: const AppBackButton(),
        automaticallyImplyLeading: false,
        title: Text(
          widget.existing == null
              ? '셔틀 노선 등록'
              : _addOnlyMode
                  ? '정류장 추가'
                  : '셔틀 노선 수정',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          TextButton(
            onPressed: _openRouteList,
            child: const Text('목록'),
          ),
        ],
      ),
      body: wide
          ? MapFormSplitLayout(
              map: _buildMapLayer(),
              panel: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: _buildRouteFormFieldList(),
              ),
            )
          : Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(child: _buildMapLayer()),
          DraggableScrollableSheet(
            controller: _bottomSheetController,
            initialChildSize: _bottomSheetSnaps[1],
            minChildSize: _bottomSheetSnaps.first,
            maxChildSize: _bottomSheetSnaps.last,
            snap: true,
            snapSizes: _bottomSheetSnaps,
            builder: (context, scrollController) {
              return ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(
                  dragDevices: {
                    PointerDeviceKind.touch,
                    PointerDeviceKind.mouse,
                    PointerDeviceKind.stylus,
                    PointerDeviceKind.trackpad,
                  },
                ),
                child: _buildBottomSheetContent(scrollController),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// 셔틀 노선 목록 화면 진입 옵션
class ShuttleRouteListArgs {
  const ShuttleRouteListArgs({
    this.pickForJobPost = false,
    this.forStopDisplayPin = false,
    this.jobPostTitle,
    this.selectedRouteId,
  });

  /// true면 노선 선택 후 [CommuteRoute]를 pop 결과로 반환
  final bool pickForJobPost;
  /// 유료 서비스 — 정류장 표시핀 연결 플로우
  final bool forStopDisplayPin;
  final String? jobPostTitle;
  final String? selectedRouteId;

  factory ShuttleRouteListArgs.pickForJobPost({
    required String jobPostTitle,
    String? selectedRouteId,
    bool forStopDisplayPin = false,
  }) =>
      ShuttleRouteListArgs(
        pickForJobPost: true,
        forStopDisplayPin: forStopDisplayPin,
        jobPostTitle: jobPostTitle,
        selectedRouteId: selectedRouteId,
      );
}

/// 기업 — 등록된 셔틀 노선 목록
class ShuttleRouteListPage extends StatefulWidget {
  const ShuttleRouteListPage({super.key, this.args});

  final ShuttleRouteListArgs? args;

  @override
  State<ShuttleRouteListPage> createState() => _ShuttleRouteListPageState();
}

class _ShuttleRouteListPageState extends State<ShuttleRouteListPage> {
  List<CommuteRoute> _routes = [];
  bool _loading = true;

  bool get _pickMode => widget.args?.pickForJobPost ?? false;

  String? get _selectedRouteId => widget.args?.selectedRouteId?.trim();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = AuthSession.instance.currentUser?.corporateProfile;
    if (profile == null) return;
    final repo = await CommuteRouteRepository.create();
    final routes = await repo.loadForCompany(profile.companyKey);
    if (!mounted) return;
    setState(() {
      _routes = routes;
      _loading = false;
    });
  }

  Future<void> _createRoute() async {
    final created = await Navigator.of(context).pushNamed<CommuteRoute>(
      AppRoutes.corporateShuttleRouteEdit,
    );
    if (created == null || !mounted) return;
    if (_pickMode && widget.args?.forStopDisplayPin == true) {
      await _load();
      return;
    }
    if (_pickMode) {
      Navigator.of(context).pop(created);
      return;
    }
    await _load();
  }

  void _selectRoute(CommuteRoute route) {
    if (!_pickMode) return;
    Navigator.of(context).pop(route);
  }

  Future<void> _editRoute(CommuteRoute route) async {
    final updated = await Navigator.of(context).pushNamed<CommuteRoute>(
      AppRoutes.corporateShuttleRouteEdit,
      arguments: route,
    );
    if (updated != null) await _load();
  }

  Future<void> _deleteRoute(CommuteRoute route) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('노선 삭제'),
        content: Text(
          '「${route.routeName}」 노선을 삭제할까요?\n'
          '연결된 공고·정류장 표시핀 설정도 함께 확인해 주세요.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFC62828),
            ),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _performDelete(route);
  }

  Future<void> _performDelete(CommuteRoute route) async {
    final profile = AuthSession.instance.currentUser?.corporateProfile;
    if (profile == null) return;
    final repo = await CommuteRouteRepository.create();
    await repo.remove(profile.companyKey, route.id);
    if (!mounted) return;
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('「${route.routeName}」 노선을 삭제했습니다.')),
    );
  }

  Future<bool> _confirmDeleteRoute(CommuteRoute route) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('노선 삭제'),
        content: Text('「${route.routeName}」 노선을 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFC62828),
            ),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _performDelete(route);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        leading: const AppBackButton(),
        automaticallyImplyLeading: false,
        title: Text(
          _pickMode ? '셔틀 노선 선택' : '통근버스 노선도 리스트',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          TextButton(
            onPressed: _createRoute,
            child: Text(_pickMode ? '새 노선' : '등록'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_pickMode) ...[
                  Container(
                    margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFE65100).withValues(alpha: 0.35),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.args?.forStopDisplayPin == true
                              ? '정류장 표시핀으로 연결할 노선을 선택하세요.'
                              : '공고에 연결할 셔틀 노선을 선택하세요.',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                        if (widget.args?.jobPostTitle?.trim().isNotEmpty ==
                            true) ...[
                          const SizedBox(height: 4),
                          Text(
                            '공고: ${widget.args!.jobPostTitle!.trim()}',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary
                                  .withValues(alpha: 0.95),
                            ),
                          ),
                        ],
                        const SizedBox(height: 4),
                        Text(
                          '목록에서 「연결」을 누르거나 행을 탭하세요.',
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            color: AppColors.textSecondary
                                .withValues(alpha: 0.95),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                Expanded(
                  child: _routes.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _pickMode
                                      ? '연결할 셔틀 노선이 없습니다.'
                                      : '등록된 셔틀 노선이 없습니다.',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '평택1노선처럼 이름을 정하고\n정류장을 순서대로 등록해 보세요.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: AppColors.textSecondary
                                        .withValues(alpha: 0.95),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                FilledButton(
                                  onPressed: _createRoute,
                                  child: Text(
                                    _pickMode ? '새 노선 등록 후 연결' : '첫 노선 등록',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(20),
                          itemCount: _routes.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final route = _routes[index];
                            final isLinked = _selectedRouteId == route.id;
                            return Dismissible(
                              key: ValueKey(route.id),
                              direction: _pickMode
                                  ? DismissDirection.none
                                  : DismissDirection.endToStart,
                              confirmDismiss: (_) => _confirmDeleteRoute(route),
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFC62828)
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.delete_outline_rounded,
                                  color: Color(0xFFC62828),
                                ),
                              ),
                              child: Material(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(12),
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
                                onTap: _pickMode
                                    ? () => _selectRoute(route)
                                    : () => _editRoute(route),
                                child: Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(12, 10, 8, 10),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: ShuttleRouteColorUtils.parseHex(
                                            route.overlayColorHex,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              route.routeName,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 15,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '정류장 ${route.stops.length}곳',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: AppColors.textSecondary
                                                    .withValues(alpha: 0.95),
                                              ),
                                            ),
                                            if (!_pickMode) ...[
                                              const SizedBox(height: 2),
                                              Text(
                                                '탭하여 수정 · 오른쪽으로 밀어 삭제',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: AppColors.textSecondary
                                                      .withValues(alpha: 0.75),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      if (_pickMode) ...[
                                        if (isLinked)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              right: 4,
                                            ),
                                            child: Icon(
                                              Icons.check_circle_rounded,
                                              size: 20,
                                              color: AppColors.primary
                                                  .withValues(alpha: 0.9),
                                            ),
                                          ),
                                        FilledButton.tonal(
                                          onPressed: () => _selectRoute(route),
                                          style: FilledButton.styleFrom(
                                            visualDensity:
                                                VisualDensity.compact,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                            ),
                                          ),
                                          child: const Text('연결'),
                                        ),
                                        const SizedBox(width: 4),
                                      ],
                                      if (!_pickMode) ...[
                                        IconButton(
                                          tooltip: '수정',
                                          onPressed: () => _editRoute(route),
                                          icon: Icon(
                                            Icons.edit_outlined,
                                            size: 20,
                                            color: AppColors.primary
                                                .withValues(alpha: 0.9),
                                          ),
                                        ),
                                        IconButton(
                                          tooltip: '삭제',
                                          onPressed: () => _deleteRoute(route),
                                          icon: const Icon(
                                            Icons.delete_outline_rounded,
                                            size: 20,
                                            color: Color(0xFFC62828),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
