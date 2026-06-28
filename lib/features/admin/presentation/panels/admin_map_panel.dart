import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:map/core/admin/admin_api_errors.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/utils/naver_map_platform.dart';
import 'package:map/features/admin/domain/admin_map_pin_factory.dart';
import 'package:map/features/admin/domain/admin_ops_controller.dart';
import 'package:map/features/admin/presentation/widgets/admin_web_scaffold.dart';
import 'package:map/features/commute/data/repositories/commute_route_repository.dart';
import 'package:map/features/corporate/data/datasources/corporate_job_post_local_data_source.dart';
import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';
import 'package:map/features/corporate/domain/entities/corporate_shuttle_map_overlay.dart';
import 'package:map/features/corporate/domain/services/corporate_shuttle_density_loader.dart';
import 'package:map/features/corporate/presentation/widgets/corporate_home_naver_map.dart';
import 'package:map/features/job_seeker/data/datasources/closed_ghost_pin_local_data_source.dart';
import 'package:map/features/job_seeker/domain/entities/closed_ghost_pin.dart';
import 'package:map/features/job_seeker/domain/entities/job_map_pin.dart';
import 'package:map/features/job_seeker/domain/entities/job_map_pin_display_tier.dart';
import 'package:map/features/job_seeker/domain/factories/closed_ghost_job_map_pin_factory.dart';

class AdminMapPanel extends StatefulWidget {
  const AdminMapPanel({super.key, required this.controller});

  final AdminOpsController controller;

  @override
  State<AdminMapPanel> createState() => _AdminMapPanelState();
}

class _AdminMapPanelState extends State<AdminMapPanel> {
  List<JobMapPin> _pins = const [];
  List<ClosedGhostPin> _ghostPins = const [];
  List<CorporateShuttleMapOverlay> _shuttleOverlays = const [];
  Map<String, CorporateJobPost> _mergedPostsById = const {};
  JobMapPin? _selected;
  Map<String, dynamic>? _selectedDetail;
  String? _error;
  bool _loading = false;
  bool _detailLoading = false;
  bool _shuttleLayerEnabled = true;
  bool _shuttleSelectedOnly = false;
  bool _ghostPlacementMode = false;

  List<JobMapPin> get _mapPins => [
        ..._pins,
        ..._ghostPins.map(
          (ghost) => ClosedGhostJobMapPinFactory.fromAdminPin(
            ghost,
            sourcePost: _mergedPostsById[ghost.sourcePostId ?? ''],
          ),
        ),
      ];

  static const _localPosts = CorporateJobPostLocalDataSourceImpl();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChange);
    _load();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChange);
    super.dispose();
  }

  void _onControllerChange() {
    if (widget.controller.apiConnected && _pins.isEmpty && !_loading) {
      _load();
    }
  }

  Future<void> _selectPin(JobMapPin pin) async {
    setState(() {
      _selected = pin;
      _selectedDetail = null;
      _detailLoading = !pin.isClosedGhost;
    });
    if (pin.isClosedGhost) return;
    try {
      final detail =
          await widget.controller.client.getJobMapDetail(pin.post.id);
      if (!mounted) return;
      setState(() {
        _selectedDetail = detail;
        _detailLoading = false;
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _error = AdminApiErrors.format(e);
        _detailLoading = false;
      });
    }
  }

  Future<void> _load() async {
    if (!widget.controller.apiReady) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final jobs = await widget.controller.client.listMapJobs();
      if (!mounted) return;
      setState(() {
        _pins = AdminMapPinFactory.fromServerJobs(jobs);
        _loading = false;
      });
      await _loadGhostPins();
      await _reloadShuttleOverlays();
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _error = AdminApiErrors.format(e);
        _loading = false;
      });
    }
  }

  Future<void> _loadGhostPins() async {
    if (!widget.controller.apiConnected) {
      final local = await const ClosedGhostPinLocalDataSourceImpl().fetchAll();
      if (!mounted) return;
      setState(() => _ghostPins = local);
      return;
    }
    try {
      final raw = await widget.controller.client.listGhostPins();
      if (!mounted) return;
      final mapped = raw
          .map((json) => ClosedGhostPin.fromJson(json))
          .where((pin) => pin.id.isNotEmpty)
          .toList();
      ClosedGhostPinLocalDataSourceImpl.replaceFromServer(mapped);
      setState(() => _ghostPins = mapped);
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _error = AdminApiErrors.format(e));
    }
  }

  Future<void> _placeGhostPin(double latitude, double longitude) async {
    final c = widget.controller;
    try {
      if (c.apiConnected) {
        await c.run(
          () => c.client.createGhostPin(
            latitude: latitude,
            longitude: longitude,
            label: '마감유령핀',
          ),
          successMessage: '마감유령핀 배치 완료',
        );
      } else {
        final pin = ClosedGhostPin(
          id: 'ghost_local_${DateTime.now().millisecondsSinceEpoch}',
          latitude: latitude,
          longitude: longitude,
          label: '마감유령핀',
          createdAt: DateTime.now(),
        );
        ClosedGhostPinLocalDataSourceImpl.upsertLocal(pin);
      }
      await _loadGhostPins();
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _error = AdminApiErrors.format(e));
    }
  }

  Future<void> _deleteSelectedGhost() async {
    final selected = _selected;
    if (selected == null || !selected.isClosedGhost) return;
    final ghostId = selected.ghostPinId;
    if (ghostId == null || ghostId.isEmpty) return;
    final c = widget.controller;
    try {
      if (c.apiConnected) {
        await c.run(
          () => c.client.deleteGhostPin(ghostId),
          successMessage: '마감유령핀 삭제',
        );
      } else {
        ClosedGhostPinLocalDataSourceImpl.removeLocal(ghostId);
      }
      if (!mounted) return;
      setState(() => _selected = null);
      await _loadGhostPins();
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _error = AdminApiErrors.format(e));
    }
  }

  Future<void> _seedSampleJobs() async {
    final raw =
        await rootBundle.loadString('assets/fixtures/jobs.example.json');
    final list = (jsonDecode(raw) as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    await widget.controller.run(
      () => widget.controller.client.bulkImportJobs(list),
      successMessage: '샘플 공고 등록 완료',
    );
    await _load();
  }

  Future<void> _reloadShuttleOverlays() async {
    if (_pins.isEmpty) {
      if (mounted) setState(() => _shuttleOverlays = const []);
      return;
    }
    final posts = <CorporateJobPost>[];
    final byId = <String, CorporateJobPost>{};
    for (final pin in _pins) {
      final post = await _localPosts.findById(pin.post.id) ?? pin.post;
      posts.add(post);
      byId[pin.post.id] = post;
    }
    final routeRepo = await CommuteRouteRepository.create();
    final overlays = await CorporateShuttleDensityLoader.load(
      routeRepo: routeRepo,
      posts: posts,
      pins: _pins,
    );
    if (!mounted) return;
    setState(() {
      _shuttleOverlays = overlays;
      _mergedPostsById = byId;
    });
  }

  List<CorporateShuttleMapOverlay> get _visibleShuttleOverlays {
    if (!_shuttleLayerEnabled) return const [];
    if (!_shuttleSelectedOnly || _selected == null) return _shuttleOverlays;
    final post =
        _mergedPostsById[_selected!.post.id] ?? _selected!.post;
    final routeIds = post.effectiveLinkedCommuteRouteIds.toSet();
    if (routeIds.isEmpty) return const [];
    return _shuttleOverlays
        .where((overlay) => routeIds.contains(overlay.route.id))
        .toList();
  }

  String get _mapModeLabel {
    if (NaverMapPlatform.shouldUseWebMap) {
      return '네이버 실지도 (앱과 동일)';
    }
    return 'mock 지도 — naver_map_client_id.txt 확인';
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;

    if (!c.apiReady) {
      return const AdminPanelScroll(
        child: Text('API 미설정 — Admin 실행.command 로 실행하세요.'),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                '서버 공고 ${_pins.length}건 · 유령 ${_ghostPins.length}건',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: NaverMapPlatform.shouldUseWebMap
                      ? const Color(0xFFE8F5E9)
                      : const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _mapModeLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: NaverMapPlatform.shouldUseWebMap
                        ? const Color(0xFF2E7D32)
                        : const Color(0xFFE65100),
                  ),
                ),
              ),
              if (_pins.isEmpty && !c.busy) ...[
                const SizedBox(width: 12),
                FilledButton.tonal(
                  onPressed: c.apiConnected ? _seedSampleJobs : null,
                  child: const Text('샘플 공고 불러오기'),
                ),
              ],
              const Spacer(),
              if (_loading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                IconButton(
                  tooltip: '새로고침',
                  onPressed: _load,
                  icon: const Icon(Icons.refresh),
                ),
            ],
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                _error!,
                style: const TextStyle(color: Color(0xFFC62828), fontSize: 13),
              ),
            ),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilterChip(
                label: const Text('마감유령핀 배치', style: TextStyle(fontSize: 12)),
                selected: _ghostPlacementMode,
                onSelected: (v) => setState(() => _ghostPlacementMode = v),
              ),
              if (_ghostPlacementMode)
                Text(
                  '지도를 클릭해 회색 마감유령핀을 배치하세요.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary.withValues(alpha: 0.9),
                  ),
                ),
              FilterChip(
                label: const Text('셔틀 노선', style: TextStyle(fontSize: 12)),
                selected: _shuttleLayerEnabled,
                onSelected: (v) => setState(() => _shuttleLayerEnabled = v),
              ),
              FilterChip(
                label: const Text('선택 공고만', style: TextStyle(fontSize: 12)),
                selected: _shuttleSelectedOnly,
                onSelected: _selected == null
                    ? null
                    : (v) => setState(() => _shuttleSelectedOnly = v),
              ),
              Text(
                '셔틀 ${_visibleShuttleOverlays.length}건',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 3,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFE8EAED)),
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CorporateHomeNaverMap(
                            pins: _mapPins,
                            ownPostIds: const {},
                            shuttleOverlays: _visibleShuttleOverlays,
                            selectedPostId: _selected?.mapMarkerId ??
                                _selected?.post.id,
                            centerOnPin: _selected,
                            onPinTap: _selectPin,
                            onMapCoordinateTap: _ghostPlacementMode
                                ? _placeGhostPin
                                : null,
                          ),
                          if (_pins.isEmpty && !_loading)
                            Container(
                              color: Colors.white.withValues(alpha: 0.72),
                              alignment: Alignment.center,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    '등록된 공고가 없습니다',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Admin 재실행 시 샘플이 자동 등록됩니다',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textSecondary
                                          .withValues(alpha: 0.9),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  FilledButton(
                                    onPressed: c.apiConnected && !c.busy
                                        ? _seedSampleJobs
                                        : null,
                                    child: const Text('샘플 공고 불러오기'),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: _JobDetailCard(
                    pin: _selected,
                    detail: _selectedDetail,
                    loading: _detailLoading,
                    onTogglePin: c.apiConnected &&
                            _selected != null &&
                            !_selected!.isClosedGhost
                        ? () => _togglePin(c)
                        : null,
                    onToggleShuttle: c.apiConnected &&
                            _selected != null &&
                            !_selected!.isClosedGhost
                        ? () => _toggleShuttle(c)
                        : null,
                    onDeleteGhost: _selected?.isClosedGhost == true
                        ? _deleteSelectedGhost
                        : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _togglePin(AdminOpsController c) async {
    final pin = _selected!;
    final active = pin.displayTier != JobMapPinDisplayTier.packageActive;
    await c.run(
      () => c.client.setJobPin(
        postId: pin.post.id,
        active: active,
        mapPinTier: active ? 'packageActive' : 'standard',
      ),
      successMessage: active ? '핀 활성화' : '핀 비활성화',
    );
    await _load();
    if (_selected != null) {
      await _selectPin(_selected!);
    }
  }

  Future<void> _toggleShuttle(AdminOpsController c) async {
    final pin = _selected!;
    final active = !pin.post.hasShuttleRouteOverlay;
    await c.run(
      () => c.client.setShuttleExposure(
        postId: pin.post.id,
        active: active,
      ),
      successMessage: active ? '셔틀 노출 ON' : '셔틀 노출 OFF',
    );
    await _load();
    if (_selected != null) {
      await _selectPin(_selected!);
    }
  }
}

class _JobDetailCard extends StatelessWidget {
  const _JobDetailCard({
    required this.pin,
    required this.detail,
    required this.loading,
    this.onTogglePin,
    this.onToggleShuttle,
    this.onDeleteGhost,
  });

  final JobMapPin? pin;
  final Map<String, dynamic>? detail;
  final bool loading;
  final VoidCallback? onTogglePin;
  final VoidCallback? onToggleShuttle;
  final VoidCallback? onDeleteGhost;

  @override
  Widget build(BuildContext context) {
    if (pin == null) {
      return AdminCard(
        title: '공고 상세',
        subtitle: '지도에서 핀을 선택하세요',
        child: Text(
          '핀 색: 회색=일반 · 하늘=고시급 · 보라=유료핀 · 연회색×=마감유령핀',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary.withValues(alpha: 0.9),
          ),
        ),
      );
    }

    final post = pin!.post;

    if (pin!.isClosedGhost) {
      return AdminCard(
        title: '마감유령핀',
        subtitle: pin!.companyName,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              ClosedGhostJobMapPinFactory.message,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Color(0xFF616161),
              ),
            ),
            const SizedBox(height: 12),
            _row('ID', pin!.ghostPinId ?? pin!.mapMarkerId),
            _row(
              '좌표',
              '${pin!.latitude.toStringAsFixed(5)}, '
              '${pin!.longitude.toStringAsFixed(5)}',
            ),
            if (pin!.post.id.isNotEmpty) _row('연결 공고', pin!.post.id),
            if (onDeleteGhost != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: onDeleteGhost,
                child: const Text('마감유령핀 삭제'),
              ),
            ],
          ],
        ),
      );
    }

    final poster = Map<String, dynamic>.from(detail?['poster'] as Map? ?? {});
    final applicants = (detail?['recent_applicants'] as List<dynamic>? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final viewCount = detail?['view_count'] ?? 0;
    final mapImpressions = detail?['map_impression_count'] ?? 0;
    final appCount = detail?['application_count'] ?? post.applicantCount;

    return AdminCard(
      title: post.title,
      subtitle: pin!.companyName,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else ...[
            _sectionTitle('등록자'),
            _row('이름', '${poster['name'] ?? detail?['posted_by_name'] ?? '-'}'),
            _row(
              '역할',
              '${poster['org_role_label'] ?? detail?['posted_by_role'] ?? '-'}',
            ),
            _row(
              '이메일',
              '${poster['email'] ?? detail?['posted_by_email'] ?? '-'}',
            ),
            if ('${poster['phone'] ?? ''}'.isNotEmpty)
              _row('전화', '${poster['phone']}'),
            const SizedBox(height: 12),
            _sectionTitle('성과'),
            _row('상세 열람', '$viewCount회'),
            _row('지도 노출', '$mapImpressions회'),
            _row('지원', '$appCount명'),
            if (detail?['applications_by_status'] is Map)
              for (final entry
                  in (detail!['applications_by_status'] as Map).entries)
                _row('  · ${entry.key}', '${entry.value}명'),
            const SizedBox(height: 12),
            _sectionTitle('공고 정보'),
          ],
          _row('ID', post.id),
          _row('근무지', post.warehouseName),
          _row('시급', post.hourlyWage),
          _row('근무', post.workSchedule),
          _row('상태', post.status.name),
          _row('핀 등급', pin!.displayTier.label),
          if (post.hasShuttleRouteOverlay) _row('셔틀', '노출 중'),
          if (!loading && applicants.isNotEmpty) ...[
            const SizedBox(height: 12),
            _sectionTitle('최근 지원자'),
            for (final a in applicants)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '${a['seeker_name']} · ${a['status']} · ${a['seeker_email']}',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
          ],
          const SizedBox(height: 12),
          if (post.summary.isNotEmpty)
            Text(
              post.summary,
              style: const TextStyle(fontSize: 13, height: 1.4),
            ),
          if (onTogglePin != null || onToggleShuttle != null) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (onTogglePin != null)
                  OutlinedButton(
                    onPressed: onTogglePin,
                    child: Text(
                      pin!.displayTier == JobMapPinDisplayTier.packageActive
                          ? '유료 핀 해제'
                          : '유료 핀 활성화',
                    ),
                  ),
                if (onToggleShuttle != null)
                  OutlinedButton(
                    onPressed: onToggleShuttle,
                    child: Text(
                      pin!.post.hasShuttleRouteOverlay
                          ? '셔틀 노출 OFF'
                          : '셔틀 노출 ON',
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary.withValues(alpha: 0.9),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
