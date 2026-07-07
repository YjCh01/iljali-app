import 'dart:io';

import 'package:flutter/material.dart';
import 'package:map/features/commute/presentation/widgets/shuttle_stop_photo_actions.dart';
import 'package:map/core/widgets/adaptive_sheet.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/constants/app_routes.dart';
import 'package:map/core/geo/geo_coordinate.dart';
import 'package:map/features/commute/domain/entities/commute_route_stop.dart';
import 'package:map/features/commute/domain/utils/shuttle_route_stop_policy.dart';
import 'package:map/features/commute/domain/utils/shuttle_stop_photo_storage.dart';
import 'package:map/features/commute/presentation/pages/shuttle_stop_map_picker_page.dart';
import 'package:map/features/corporate/domain/entities/workplace_address.dart';
import 'package:map/features/corporate/presentation/widgets/push_radius_map_picker.dart';

/// 정류장 추가·수정 — 이름, 지도 핀, 사진, 탑승/도착 시간
enum ShuttleRouteStopEditorMode { full, detailsOnly, workplace }

class ShuttleRouteStopEditorSheet extends StatefulWidget {
  const ShuttleRouteStopEditorSheet({
    super.key,
    this.initialStop,
    this.initialCoordinate,
    required this.siblingStops,
    required this.isLastStopHint,
    this.mode = ShuttleRouteStopEditorMode.full,
  });

  final CommuteRouteStop? initialStop;
  final GeoCoordinate? initialCoordinate;
  final List<CommuteRouteStop> siblingStops;
  final bool isLastStopHint;
  final ShuttleRouteStopEditorMode mode;

  static Future<CommuteRouteStop?> show(
    BuildContext context, {
    CommuteRouteStop? initialStop,
    GeoCoordinate? initialCoordinate,
    List<CommuteRouteStop> siblingStops = const [],
    bool isLastStopHint = false,
  }) {
    return showAdaptiveSheet<CommuteRouteStop>(
      context: context,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: ShuttleRouteStopEditorSheet(
          initialStop: initialStop,
          initialCoordinate: initialCoordinate,
          siblingStops: siblingStops,
          isLastStopHint: isLastStopHint,
        ),
      ),
    );
  }

  /// 이름·탑승 시간·사진만 편집 (좌표는 지도 「수정」에서)
  static Future<CommuteRouteStop?> showDetails(
    BuildContext context, {
    required CommuteRouteStop initialStop,
    List<CommuteRouteStop> siblingStops = const [],
    bool isLastStopHint = false,
  }) {
    return showAdaptiveSheet<CommuteRouteStop>(
      context: context,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: ShuttleRouteStopEditorSheet(
          initialStop: initialStop,
          siblingStops: siblingStops,
          isLastStopHint: isLastStopHint,
          mode: ShuttleRouteStopEditorMode.detailsOnly,
        ),
      ),
    );
  }

  /// 근무지 도착 시각 편집
  static Future<CommuteRouteStop?> showWorkplaceArrival(
    BuildContext context, {
    required CommuteRouteStop initialStop,
  }) {
    return showAdaptiveSheet<CommuteRouteStop>(
      context: context,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: ShuttleRouteStopEditorSheet(
          initialStop: initialStop,
          siblingStops: const [],
          isLastStopHint: true,
          mode: ShuttleRouteStopEditorMode.workplace,
        ),
      ),
    );
  }

  @override
  State<ShuttleRouteStopEditorSheet> createState() =>
      _ShuttleRouteStopEditorSheetState();
}

class _ShuttleRouteStopEditorSheetState extends State<ShuttleRouteStopEditorSheet> {
  late final TextEditingController _labelController;
  late final TextEditingController _timeController;
  late GeoCoordinate _coordinate;
  String? _photoPath;
  bool _pickingPhoto = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialStop;
    _labelController = TextEditingController(text: initial?.label ?? '');
    final isWorkplace = widget.mode == ShuttleRouteStopEditorMode.workplace;
    _timeController = TextEditingController(
      text: isWorkplace
          ? (initial?.arrivalTime ?? '')
          : (initial?.departureTime ?? ''),
    );
    _coordinate = initial?.coordinate ??
        widget.initialCoordinate ??
        defaultPushMapCenter();
    _photoPath = initial?.photoPath;
  }

  @override
  void dispose() {
    _labelController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  Future<void> _pickOnMap() async {
    final others = widget.siblingStops
        .where((s) => s.id != widget.initialStop?.id)
        .toList();
    final coord = await showShuttleStopCoordinatePicker(
      context,
      initial: _coordinate,
      existingStops: others,
    );
    if (coord == null || !mounted) return;
    setState(() => _coordinate = coord);
  }

  Future<void> _pickFromAddress() async {
    final result = await Navigator.of(context).pushNamed<WorkplaceAddress>(
      AppRoutes.corporateWorkplaceSearch,
    );
    if (result == null || !mounted) return;
    setState(() {
      _coordinate = result.coordinate ?? defaultPushMapCenter();
      if (_labelController.text.trim().isEmpty) {
        _labelController.text = result.shortLabel;
      }
    });
  }

  Future<void> _pickPhoto() async {
    setState(() => _pickingPhoto = true);
    try {
      final path = await ShuttleStopPhotoActions.pickFromGallery(context);
      if (!mounted || path == null) return;
      setState(() => _photoPath = path);
    } finally {
      if (mounted) setState(() => _pickingPhoto = false);
    }
  }

  void _removePhoto() => setState(() => _photoPath = null);

  void _save() {
    final isWorkplace = widget.mode == ShuttleRouteStopEditorMode.workplace;
    final label = _labelController.text.trim();
    if (!isWorkplace && label.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('정류장 이름을 입력해 주세요.')),
      );
      return;
    }
    final time = _timeController.text.trim();
    if (widget.mode == ShuttleRouteStopEditorMode.workplace &&
        (time.isEmpty || !_looksLikeHhMm(time))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('근무지 도착 시각(HH:MM)을 입력해 주세요.')),
      );
      return;
    }
    final base = widget.initialStop;
    final isWorkplaceMode = widget.mode == ShuttleRouteStopEditorMode.workplace;
    Navigator.of(context).pop(
      CommuteRouteStop(
        id: base?.id ?? 'stop_${DateTime.now().millisecondsSinceEpoch}',
        label: isWorkplaceMode
            ? ShuttleRouteStopPolicy.workplaceLabel
            : label,
        coordinate: widget.mode == ShuttleRouteStopEditorMode.detailsOnly ||
                isWorkplaceMode
            ? base!.coordinate
            : _coordinate,
        departureTime: isWorkplaceMode ? null : (time.isEmpty ? null : time),
        arrivalTime: isWorkplaceMode ? time : null,
        photoPath: _photoPath,
      ),
    );
  }

  bool _looksLikeHhMm(String raw) {
    final parts = raw.split(':');
    if (parts.length != 2) return false;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return false;
    return h >= 0 && h <= 23 && m >= 0 && m <= 59;
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto = _photoPath != null && File(_photoPath!).existsSync();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textSecondary.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.mode == ShuttleRouteStopEditorMode.workplace
                ? '근무지 도착 시각'
                : widget.mode == ShuttleRouteStopEditorMode.detailsOnly
                    ? '정류장 편집'
                    : widget.initialStop == null
                        ? '정류장 추가'
                        : '정류장 수정',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            widget.mode == ShuttleRouteStopEditorMode.workplace
                ? '버스 이동 알림 기준의 근무지 도착 시각을 입력하세요.'
                : widget.mode == ShuttleRouteStopEditorMode.detailsOnly
                    ? '이름·탑승 시간·사진을 입력하세요. 위치는 목록에서 정류장을 탭해 조정합니다.'
                    : '지도 상에서 포인트를 직접 선택하고 이름과 사진을 저장하세요.',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary.withValues(alpha: 0.95),
            ),
          ),
          const SizedBox(height: 16),
          if (widget.mode != ShuttleRouteStopEditorMode.workplace) ...[
            TextField(
              controller: _labelController,
              decoration: const InputDecoration(
                labelText: '정류장 이름',
                hintText: '예: 평택중학교 정문앞',
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _timeController,
            decoration: InputDecoration(
              labelText: widget.mode == ShuttleRouteStopEditorMode.workplace
                  ? '근무지 도착 시각 (필수)'
                  : '탑승 시간 (선택)',
              hintText: widget.mode == ShuttleRouteStopEditorMode.workplace
                  ? '예: 08:30'
                  : widget.isLastStopHint
                      ? '마지막 정류장은 비워두면 도착'
                      : '예: 07:30',
            ),
            keyboardType: TextInputType.datetime,
          ),
          if (widget.mode == ShuttleRouteStopEditorMode.full) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickOnMap,
                    icon: const Icon(Icons.map_outlined, size: 18),
                    label: const Text('지도에서 핀'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickFromAddress,
                    icon: const Icon(Icons.search, size: 18),
                    label: const Text('주소 검색'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${_coordinate.latitude.toStringAsFixed(5)}, '
              '${_coordinate.longitude.toStringAsFixed(5)}',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary.withValues(alpha: 0.85),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            '정류장 사진 (선택)',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary.withValues(alpha: 0.95),
            ),
          ),
          const SizedBox(height: 8),
          if (hasPhoto)
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(_photoPath!),
                    height: 120,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton.filledTonal(
                    onPressed: _removePhoto,
                    icon: const Icon(Icons.close, size: 18),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black54,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            )
          else
            OutlinedButton.icon(
              onPressed: _pickingPhoto ? null : _pickPhoto,
              icon: _pickingPhoto
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_a_photo_outlined, size: 18),
              label: const Text('사진 추가'),
            ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _save,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: Text(
              widget.mode == ShuttleRouteStopEditorMode.detailsOnly
                  ? '저장'
                  : widget.initialStop == null
                      ? '정류장 추가'
                      : '저장',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
