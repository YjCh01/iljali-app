import 'dart:async';

import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/constants/app_routes.dart';
import 'package:map/core/geo/geo_coordinate.dart';
import 'package:map/core/hiring/local_hiring_repository.dart';
import 'package:map/core/pilot/bus_location_tower_pilot_service.dart';
import 'package:map/core/pilot/bus_location_tower_pilot_status.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/core/widgets/app_back_button.dart';
import 'package:map/features/commute/data/repositories/commute_route_repository.dart';
import 'package:map/features/commute/data/repositories/seeker_shuttle_commute_preference_repository.dart';
import 'package:map/features/commute/domain/entities/commute_route.dart';
import 'package:map/features/commute/domain/entities/commute_route_stop.dart';
import 'package:map/features/commute/domain/entities/seeker_shuttle_commute_preference.dart';
import 'package:map/features/commute/domain/entities/seeker_shuttle_employer_context.dart';
import 'package:map/features/commute/domain/services/seeker_shuttle_commute_link_service.dart';
import 'package:map/features/commute/domain/services/seeker_shuttle_employer_loader.dart';
import 'package:map/features/commute/data/repositories/seeker_commute_tower_consent_repository.dart';
import 'package:map/features/commute/data/repositories/seeker_shuttle_route_share_consent_repository.dart';
import 'package:map/features/commute/domain/entities/seeker_commute_tower_consent.dart';
import 'package:map/features/commute/domain/entities/seeker_shuttle_route_share_consent.dart';
import 'package:map/features/commute/domain/entities/shuttle_commute_consent_copy.dart';
import 'package:map/features/commute/domain/utils/shuttle_route_schedule.dart';
import 'package:map/features/commute/domain/utils/shuttle_route_stop_policy.dart';
import 'package:map/features/commute/presentation/widgets/shuttle_commute_consent_dialog.dart';
import 'package:map/features/commute/domain/utils/shuttle_bus_eta_estimator.dart';
import 'package:map/features/commute/domain/utils/shuttle_bus_timeline_position.dart';
import 'package:map/features/commute/domain/utils/shuttle_route_polyline_geometry.dart';
import 'package:map/features/commute/presentation/widgets/shuttle_bus_live_map_view.dart';
import 'package:map/features/commute/presentation/widgets/shuttle_route_vertical_tracker.dart';
import 'package:map/features/commute/presentation/widgets/shuttle_stop_selection_grid.dart';
import 'package:map/features/corporate/presentation/widgets/corporate_surface_card.dart';

/// 통근 셔틀 — 회사 노선·정류장 선택 + 실시간 위치(가능 시)
class SeekerMyBusPage extends StatefulWidget {
  const SeekerMyBusPage({
    super.key,
    this.embedded = false,
    this.isActive = true,
  });

  final bool embedded;
  final bool isActive;

  @override
  State<SeekerMyBusPage> createState() => _SeekerMyBusPageState();
}

class _SeekerMyBusPageState extends State<SeekerMyBusPage> {
  late Future<SeekerMyBusViewModel> _future = _load();
  Timer? _pollTimer;
  Timer? _countdownTimer;
  Duration? _eta;
  var _tick = 0;
  String? _focusRouteId;
  final _selectedRouteByCompany = <String, String>{};
  final _consentPromptedCompanies = <String>{};

  @override
  void initState() {
    super.initState();
    _startPolling();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _eta == null) return;
      setState(() {
        _tick++;
        if (_eta!.inSeconds > 0) {
          _eta = Duration(seconds: _eta!.inSeconds - 1);
        }
      });
    });
  }

  @override
  void didUpdateWidget(covariant SeekerMyBusPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _reload();
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      if (widget.isActive) _reload(silent: true);
    });
  }

  Future<SeekerMyBusViewModel> _load() async {
    final email = AuthSession.instance.currentUser?.email.trim().toLowerCase() ??
        '';
    final pilotStatus = email.isEmpty
        ? BusLocationTowerPilotStatus.inactive
        : await BusLocationTowerPilotService.refresh(force: true);

    final employers = email.isEmpty
        ? const <SeekerShuttleEmployerContext>[]
        : await SeekerShuttleEmployerLoader.loadForSeeker(email);

    final scheduledCount = email.isEmpty
        ? 0
        : (await (await LocalHiringRepository.create())
                .fetchScheduledForSeeker(email))
            .length;

    final prefRepo = await SeekerShuttleCommutePreferenceRepository.create();
    final preferences = email.isEmpty
        ? const <SeekerShuttleCommutePreference>[]
        : await prefRepo.fetchForSeeker(email);

    final consentRepo = await SeekerShuttleRouteShareConsentRepository.create();
    final routeShareConsents = email.isEmpty
        ? const <SeekerShuttleRouteShareConsent>[]
        : await consentRepo.fetchMergedForSeeker(email);

    final towerRepo = await SeekerCommuteTowerConsentRepository.create();
    final towerConsents = email.isEmpty
        ? const <SeekerCommuteTowerConsent>[]
        : await towerRepo.fetchForSeeker(email);

    for (final pref in preferences) {
      _selectedRouteByCompany.putIfAbsent(pref.companyKey, () => pref.routeId);
    }

    final optedInEmployers = employers
        .where(
          (e) => routeShareConsents.any(
            (c) => c.companyKey == e.companyKey && c.optedIn,
          ),
        )
        .toList();

    final tracking = await _resolveTrackingContext(
      pilotStatus: pilotStatus,
      employers: optedInEmployers,
      preferences: preferences,
      focusRouteId: _focusRouteId,
    );

    if (mounted) {
      await _maybePromptOfficerSharingStart(
        pilotStatus: pilotStatus,
        preferences: preferences,
        routeShareConsents: routeShareConsents,
      );
    }

    Duration? eta;
    if (tracking.stop != null) {
      final route = tracking.route;
      ShuttleRoutePolylineGeometry? geometry;
      int? stopIndex;
      if (route != null) {
        final orderedStops = ShuttleBusTimelinePosition.orderedStops(route);
        stopIndex = orderedStops.indexWhere((s) => s.id == tracking.stop!.id);
        if (stopIndex >= 0) {
          geometry = ShuttleRoutePolylineGeometry.build(
            points: route.effectivePolylinePoints,
            stops: orderedStops,
          );
        } else {
          stopIndex = null;
        }
      }
      eta = ShuttleBusEtaEstimator.etaToStop(
        busPosition: tracking.busPosition,
        stopPosition: tracking.stop!.coordinate,
        routeGeometry: geometry,
        stopIndex: stopIndex,
      );
    }

    return SeekerMyBusViewModel(
      seekerEmail: email,
      pilotStatus: pilotStatus,
      employers: employers,
      optedInEmployers: optedInEmployers,
      preferences: preferences,
      routeShareConsents: routeShareConsents,
      towerConsents: towerConsents,
      tracking: tracking,
      eta: eta,
      scheduledWorkCount: scheduledCount,
    );
  }

  /// 오늘 지정된 버스위치 공유 담당 본인에게만 — 관제 화면으로 위치 공유를 시작하도록 안내.
  /// (일반 탑승자는 위치를 공유하지 않고 보기만 하므로 이 안내가 해당되지 않음)
  Future<void> _maybePromptOfficerSharingStart({
    required BusLocationTowerPilotStatus pilotStatus,
    required List<SeekerShuttleCommutePreference> preferences,
    required List<SeekerShuttleRouteShareConsent> routeShareConsents,
  }) async {
    if (!pilotStatus.isDesignated) return;
    if (pilotStatus.hasLiveLocation || pilotStatus.arrivedAtWorkplace) return;
    if (pilotStatus.companyKey.isEmpty || pilotStatus.routeId.isEmpty) return;
    final email = AuthSession.instance.currentUser?.email;
    if (email == null || email.isEmpty) return;

    final towerRepo = await SeekerCommuteTowerConsentRepository.create();
    final consent = await towerRepo.findForRoute(
      seekerEmail: email,
      companyKey: pilotStatus.companyKey,
      routeId: '',
    );
    if (consent == null || consent.trackingEnabled) return;

    final route = await (await CommuteRouteRepository.create())
        .findById(pilotStatus.routeId);
    if (route == null) return;

    final firstTime = ShuttleRouteSchedule.firstStopDepartureTime(route);
    if (firstTime == null) return;
    final now = DateTime.now();
    final parts = firstTime.split(':');
    final departure = DateTime(
      now.year,
      now.month,
      now.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
    if (now.isBefore(departure)) return;

    final agreed = await showShuttleCommuteConsentDialog(
      context,
      title: ShuttleCommuteConsentCopy.trackingOnPromptTitle,
      body: ShuttleCommuteConsentCopy.trackingOnPromptBody,
      acceptLabel: '관제 화면 열기',
      declineLabel: '나중에',
    );
    if (!mounted) return;

    await towerRepo.save(
      consent.copyWith(
        trackingEnabled: true,
        trackingEnabledAt: DateTime.now(),
      ),
    );
    if (agreed != true || !mounted) return;
    await Navigator.of(context).pushNamed(AppRoutes.seekerBusLocationTowerPilot);
  }

  Future<void> _promptRouteShareIfNeeded(SeekerMyBusViewModel model) async {
    for (final employer in model.employers) {
      final consent = model.consentForCompany(employer.companyKey);
      if (consent?.offerPending != true) continue;
      if (_consentPromptedCompanies.contains(employer.companyKey)) continue;
      _consentPromptedCompanies.add(employer.companyKey);
      final optedIn = await showShuttleRouteShareOptInDialog(context);
      if (!mounted) return;
      final email = model.seekerEmail;
      if (email.isEmpty) return;
      await _saveRouteShareConsent(
        email: email,
        employer: employer,
        optedIn: optedIn == true,
      );
      if (!mounted) return;
      await _reload();
      return;
    }
  }

  Future<void> _reload({bool silent = false}) async {
    if (!mounted) return;
    setState(() {
      _future = _load();
    });
    try {
      final model = await _future;
      if (!mounted) return;
      setState(() => _eta = model.eta);
    } on Object {
      if (!silent) rethrow;
    }
  }

  Future<void> _selectStop({
    required SeekerShuttleEmployerContext employer,
    required CommuteRoute route,
    required CommuteRouteStop stop,
  }) async {
    final email = AuthSession.instance.currentUser?.email;
    if (email == null || email.isEmpty) return;

    final preference = await SeekerShuttleCommuteLinkService.saveStopSelection(
      seekerEmail: email,
      companyKey: employer.companyKey,
      companyName: employer.companyName,
      route: route,
      stop: stop,
      applications: employer.applications,
    );

    final prefRepo = await SeekerShuttleCommutePreferenceRepository.create();
    await prefRepo.save(preference);

    if (!mounted) return;
    setState(() {
      _focusRouteId = route.id;
      _selectedRouteByCompany[employer.companyKey] = route.id;
    });
    await _reload();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${route.routeName} · ${stop.label} 탑승으로 저장했습니다.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _saveRouteShareConsent({
    required String email,
    required SeekerShuttleEmployerContext employer,
    required bool optedIn,
  }) async {
    final repo = await SeekerShuttleRouteShareConsentRepository.create();
    final consent = SeekerShuttleRouteShareConsent(
      seekerEmail: email,
      companyKey: employer.companyKey,
      companyName: employer.companyName,
      optedIn: optedIn,
      towerParticipationOffered: true,
      towerParticipationConsented: optedIn,
      offerPending: false,
      updatedAt: DateTime.now(),
    );
    await repo.save(consent);
    await repo.syncToServer(consent);

    if (optedIn) {
      final towerRepo = await SeekerCommuteTowerConsentRepository.create();
      await towerRepo.save(
        SeekerCommuteTowerConsent(
          seekerEmail: email.trim().toLowerCase(),
          companyKey: employer.companyKey,
          routeId: '',
          stopId: '',
          role: SeekerCommuteTowerRole.shuttleParticipant,
          consentedAt: DateTime.now(),
        ),
      );
    } else {
      await (await SeekerShuttleCommutePreferenceRepository.create())
          .removeForCompany(seekerEmail: email, companyKey: employer.companyKey);
    }
  }

  Future<void> _setRouteShare({
    required SeekerShuttleEmployerContext employer,
    required bool optedIn,
  }) async {
    final email = AuthSession.instance.currentUser?.email;
    if (email == null || email.isEmpty) return;
    await _saveRouteShareConsent(
      email: email,
      employer: employer,
      optedIn: optedIn,
    );
    if (!mounted) return;
    await _reload();
  }

  Future<_TrackingContext> _resolveTrackingContext({
    required BusLocationTowerPilotStatus pilotStatus,
    required List<SeekerShuttleEmployerContext> employers,
    required List<SeekerShuttleCommutePreference> preferences,
    required String? focusRouteId,
  }) async {
    SeekerShuttleCommutePreference? pref;
    if (focusRouteId != null) {
      for (final p in preferences) {
        if (p.routeId == focusRouteId) {
          pref = p;
          break;
        }
      }
    }
    pref ??= preferences.isNotEmpty ? preferences.first : null;

    CommuteRoute? route;
    CommuteRouteStop? stop;

    if (pref != null) {
      for (final employer in employers) {
        for (final r in employer.routes) {
          if (r.id != pref.routeId) continue;
          route = r;
          stop = _findStop(r, pref);
          break;
        }
        if (route != null) break;
      }
      if (route == null) {
        final repo = await CommuteRouteRepository.create();
        route = await repo.findById(pref.routeId);
        if (route != null) stop = _findStop(route, pref);
      }
    } else if (pilotStatus.enabled && pilotStatus.routeId.isNotEmpty) {
      for (final employer in employers) {
        for (final r in employer.routes) {
          if (r.id == pilotStatus.routeId) {
            route = r;
            break;
          }
        }
        if (route != null) break;
      }
      route ??= await (await CommuteRouteRepository.create())
          .findById(pilotStatus.routeId);
      stop = route == null ? null : _stopFromPilot(route, pilotStatus);
    }

    return _TrackingContext(
      preference: pref,
      route: route,
      stop: stop,
      workplace: route != null && route.stops.isNotEmpty
          ? ShuttleRouteStopPolicy.splitRouteStops(route.stops).workplace.coordinate
          : null,
      busPosition: _busPosition(
        status: pilotStatus,
        pref: pref,
        route: route,
      ),
      pilotMatches: pilotStatus.enabled &&
          pref != null &&
          pref.routeId == pilotStatus.routeId,
      pilotStatus: pilotStatus,
      withinTrackingWindow: route != null &&
          ShuttleRouteSchedule.isWithinSeekerTrackingWindow(route, DateTime.now()),
    );
  }

  CommuteRouteStop? _findStop(
    CommuteRoute route,
    SeekerShuttleCommutePreference pref,
  ) {
    for (final s in route.stops) {
      if (s.id == pref.stopId) return s;
    }
    for (final s in route.stops) {
      if (s.label == pref.stopLabel) return s;
    }
    return null;
  }

  CommuteRouteStop? _stopFromPilot(
    CommuteRoute route,
    BusLocationTowerPilotStatus status,
  ) {
    final label = status.riderStopLabel.trim();
    if (label.isEmpty) return null;
    for (final s in route.stops) {
      if (s.label == label) return s;
    }
    return null;
  }

  GeoCoordinate? _busPosition({
    required BusLocationTowerPilotStatus status,
    required SeekerShuttleCommutePreference? pref,
    required CommuteRoute? route,
  }) {
    if (route != null &&
        !ShuttleRouteSchedule.isWithinSeekerTrackingWindow(route, DateTime.now())) {
      return null;
    }
    if (!status.hasLiveLocation) return null;
    if (pref != null && status.routeId.isNotEmpty && pref.routeId != status.routeId) {
      return null;
    }
    if (route != null && status.routeId.isNotEmpty && route.id != status.routeId) {
      return null;
    }
    final session = status.todaySession;
    final lat = session?['last_latitude'];
    final lng = session?['last_longitude'];
    if (lat is! num || lng is! num) return null;
    return GeoCoordinate(latitude: lat.toDouble(), longitude: lng.toDouble());
  }

  @override
  Widget build(BuildContext context) {
    final body = FutureBuilder<SeekerMyBusViewModel>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        final model = snapshot.data;
        if (model == null) {
          return _EmptyState(
            embedded: widget.embedded,
            signedIn: false,
            hasScheduledWork: false,
          );
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (model.hasPendingShuttleOffer) {
            _promptRouteShareIfNeeded(model);
          }
        });

        if (!model.hasShuttleAccess) {
          return _EmptyState(
            embedded: widget.embedded,
            signedIn: model.seekerEmail.isNotEmpty,
            hasScheduledWork: model.scheduledWorkCount > 0,
          );
        }

        return RefreshIndicator(
          onRefresh: _reload,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              20,
              widget.embedded ? 8 : 16,
              20,
              24,
            ),
            children: [
              if (model.tracking.preference != null &&
                  model.tracking.withinTrackingWindow)
                _TrackingPanel(
                  model: model,
                  eta: _eta ?? model.eta,
                  tick: _tick,
                ),
              if (model.tracking.preference != null &&
                  !model.tracking.withinTrackingWindow) ...[
                CorporateSurfaceCard(
                  child: Text(
                    '실시간 버스 위치는 첫 정류장 운행 ${ShuttleRouteSchedule.seekerTrackingLead.inMinutes}분 전부터 '
                    '근무지 도착 ${ShuttleRouteSchedule.seekerTrackingTrail.inMinutes}분 후까지 표시됩니다.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: AppColors.textSecondary.withValues(alpha: 0.9),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (model.employers.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  '통근버스 노선 · 정류장 선택',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '노선 공유에 동의한 회사의 모든 노선이 표시됩니다. '
                  '회사당 탑승할 노선 1개와 정류장 1곳을 선택해 주세요.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: AppColors.textSecondary.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 12),
                ...model.employers.expand(
                  (employer) => _employerSections(model, employer),
                ),
              ] else if (model.pilotStatus.shouldShowEntry) ...[
                _PilotOnlyHint(status: model.pilotStatus),
              ],
            ],
          ),
        );
      },
    );

    if (widget.embedded) return body;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        leading: const AppBackButton(),
        title: const Text(
          '내 버스',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        actions: [
          IconButton(
            onPressed: _reload,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: '새로고침',
          ),
        ],
      ),
      body: body,
    );
  }

  List<Widget> _employerSections(
    SeekerMyBusViewModel model,
    SeekerShuttleEmployerContext employer,
  ) {
    final consent = model.consentForCompany(employer.companyKey);
    final optedIn = consent?.optedIn == true;
    final offerPending = consent?.offerPending == true;

    if (consent != null && !optedIn && !offerPending) {
      return [
        Padding(
          padding: const EdgeInsets.only(bottom: 8, top: 4),
          child: Text(
            employer.companyName,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
        ),
        CorporateSurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                ShuttleCommuteConsentCopy.routeShareDeclineNote,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () => _setRouteShare(employer: employer, optedIn: true),
                child: const Text('노선 공유 다시 받기'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
      ];
    }

    if (consent == null || offerPending) {
      return [
        Padding(
          padding: const EdgeInsets.only(bottom: 8, top: 4),
          child: Text(
            employer.companyName,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
        ),
        CorporateSurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                offerPending
                    ? '채팅으로 통근 노선 공유 안내를 받으셨습니다.'
                    : '합격하신 회사의 통근 노선을 공유받으시겠습니까?',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                ShuttleCommuteConsentCopy.routeShareBody,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: AppColors.textSecondary.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () =>
                          _setRouteShare(employer: employer, optedIn: false),
                      child: const Text('받지 않음'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: () =>
                          _setRouteShare(employer: employer, optedIn: true),
                      child: const Text('공유 받기'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
      ];
    }

    final pref = model.preferenceForCompany(employer.companyKey);
    final selectedRouteId = _selectedRouteByCompany[employer.companyKey] ??
        pref?.routeId ??
        (employer.routes.isNotEmpty ? employer.routes.first.id : '');
    CommuteRoute? selectedRoute;
    for (final route in employer.routes) {
      if (route.id == selectedRouteId) {
        selectedRoute = route;
        break;
      }
    }
    selectedRoute ??= employer.routes.isNotEmpty ? employer.routes.first : null;

    return [
      Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 4),
        child: Text(
          employer.companyName,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      if (selectedRoute != null)
        CorporateSurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                value: selectedRoute.id,
                decoration: const InputDecoration(
                  labelText: '탑승 노선 (1개 선택)',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final route in employer.routes)
                    DropdownMenuItem(
                      value: route.id,
                      child: Text(route.routeName),
                    ),
                ],
                onChanged: (routeId) {
                  if (routeId == null) return;
                  setState(() {
                    _selectedRouteByCompany[employer.companyKey] = routeId;
                  });
                },
              ),
              const SizedBox(height: 12),
              ShuttleStopSelectionGrid(
                route: selectedRoute,
                selectedStopId: pref?.routeId == selectedRoute.id
                    ? pref?.stopId
                    : null,
                savedPreference:
                    pref?.routeId == selectedRoute.id ? pref : null,
                onStopSelected: (stop) => _selectStop(
                  employer: employer,
                  route: selectedRoute!,
                  stop: stop,
                ),
              ),
            ],
          ),
        ),
      const SizedBox(height: 10),
    ];
  }
}

class SeekerMyBusViewModel {
  const SeekerMyBusViewModel({
    required this.seekerEmail,
    required this.pilotStatus,
    required this.employers,
    required this.optedInEmployers,
    required this.preferences,
    required this.routeShareConsents,
    required this.towerConsents,
    required this.tracking,
    required this.eta,
    required this.scheduledWorkCount,
  });

  final String seekerEmail;
  final BusLocationTowerPilotStatus pilotStatus;
  final List<SeekerShuttleEmployerContext> employers;
  final List<SeekerShuttleEmployerContext> optedInEmployers;
  final List<SeekerShuttleCommutePreference> preferences;
  final List<SeekerShuttleRouteShareConsent> routeShareConsents;
  final List<SeekerCommuteTowerConsent> towerConsents;
  final _TrackingContext tracking;
  final Duration? eta;
  final int scheduledWorkCount;

  bool get hasShuttleAccess =>
      pilotStatus.shouldShowEntry || employers.isNotEmpty;

  bool get hasPendingShuttleOffer => employers.any(
        (e) => consentForCompany(e.companyKey)?.offerPending == true,
      );

  SeekerShuttleRouteShareConsent? consentForCompany(String companyKey) {
    for (final c in routeShareConsents) {
      if (c.companyKey == companyKey) return c;
    }
    return null;
  }

  SeekerShuttleCommutePreference? preferenceForCompany(String companyKey) {
    for (final pref in preferences) {
      if (pref.companyKey == companyKey) return pref;
    }
    return null;
  }

  SeekerShuttleCommutePreference? preferenceForRoute(
    String companyKey,
    String routeId,
  ) {
    final pref = preferenceForCompany(companyKey);
    if (pref != null && pref.routeId == routeId) return pref;
    return null;
  }
}

class _TrackingContext {
  const _TrackingContext({
    required this.preference,
    required this.route,
    required this.stop,
    required this.workplace,
    required this.busPosition,
    required this.pilotMatches,
    required this.pilotStatus,
    required this.withinTrackingWindow,
  });

  final SeekerShuttleCommutePreference? preference;
  final CommuteRoute? route;
  final CommuteRouteStop? stop;
  final GeoCoordinate? workplace;
  final GeoCoordinate? busPosition;
  final bool pilotMatches;
  final BusLocationTowerPilotStatus pilotStatus;
  final bool withinTrackingWindow;
}

class _TrackingPanel extends StatefulWidget {
  const _TrackingPanel({
    required this.model,
    required this.eta,
    required this.tick,
  });

  final SeekerMyBusViewModel model;
  final Duration? eta;
  final int tick;

  @override
  State<_TrackingPanel> createState() => _TrackingPanelState();
}

class _TrackingPanelState extends State<_TrackingPanel> {
  var _showMap = false;

  @override
  Widget build(BuildContext context) {
    final model = widget.model;
    final pref = model.tracking.preference!;
    final status = model.tracking.pilotStatus;
    final route = model.tracking.route;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (route != null)
          ShuttleRouteVerticalTracker(
            route: route,
            companyName: pref.companyName,
            busPosition: model.tracking.withinTrackingWindow
                ? model.tracking.busPosition
                : null,
            myStopId: pref.stopId,
            etaToMyStop: widget.eta,
            onOpenMap: () => setState(() => _showMap = !_showMap),
            isPositionStale: status.isLocationStale,
            lastUpdatedAt: status.lastLocationUpdatedAt,
          ),
        if (_showMap && route != null) ...[
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              height: 240,
              child: ShuttleBusLiveMapView(
                key: ValueKey(
                  'bus_map_${model.tracking.busPosition?.latitude}_'
                  '${model.tracking.busPosition?.longitude}_${widget.tick}',
                ),
                route: route,
                busPosition: model.tracking.busPosition,
                highlightStop: model.tracking.stop,
                workplace: model.tracking.workplace,
              ),
            ),
          ),
        ],
        if (status.isDesignated && !status.arrivedAtWorkplace) ...[
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: () => Navigator.of(context).pushNamed(
              AppRoutes.seekerBusLocationTowerPilot,
            ),
            icon: const Icon(Icons.share_location_outlined),
            label: const Text('위치 공유 관제 열기'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
        ],
        const SizedBox(height: 16),
      ],
    );
  }
}

class _PilotOnlyHint extends StatelessWidget {
  const _PilotOnlyHint({required this.status});

  final BusLocationTowerPilotStatus status;

  @override
  Widget build(BuildContext context) {
    return CorporateSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            status.title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            status.message.isNotEmpty
                ? status.message
                : '운영팀 파일럿 참여자입니다.',
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: AppColors.textSecondary.withValues(alpha: 0.95),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: () => Navigator.of(context).pushNamed(
              status.isDesignated
                  ? AppRoutes.seekerBusLocationTowerPilot
                  : AppRoutes.seekerMyBus,
            ),
            icon: const Icon(Icons.open_in_new_rounded),
            label: Text(status.isDesignated ? '관제 허브 열기' : '위치 확인'),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.embedded,
    required this.signedIn,
    required this.hasScheduledWork,
  });

  final bool embedded;
  final bool signedIn;
  final bool hasScheduledWork;

  @override
  Widget build(BuildContext context) {
    final message = !signedIn
        ? '로그인 후 이용할 수 있습니다.'
        : hasScheduledWork
            ? '근무 회사의 통근버스 노선이 등록되면\n여기에서 정류장을 선택할 수 있습니다.'
            : '통근버스를 운영하는 회사로 채용이 확정되면\n노선과 정류장을 선택하고 도착 시간을 확인할 수 있습니다.';

    final content = Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            Icons.directions_bus_outlined,
            size: 48,
            color: AppColors.primaryLight.withValues(alpha: 0.9),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.45,
              color: AppColors.textSecondary.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
    if (embedded) {
      return LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(child: content),
            ),
          );
        },
      );
    }
    return Center(child: content);
  }
}
