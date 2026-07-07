import 'dart:async';

import 'package:flutter/material.dart';
import 'package:map/core/constants/app_routes.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/geo/device_location_service.dart';
import 'package:map/core/geo/location_consent_service.dart';
import 'package:map/core/pilot/bus_location_tower_pilot_service.dart';
import 'package:map/core/pilot/bus_location_tower_pilot_status.dart';
import 'package:map/core/widgets/app_back_button.dart';
import 'package:map/features/chat/domain/services/admin_announcement_room_service.dart';
import 'package:map/features/chat/presentation/pages/admin_announcement_chat_page.dart';
import 'package:map/features/corporate/presentation/widgets/corporate_surface_card.dart';

/// 실시간 버스 위치 관제 — 파일럿 허브 (지정 구직자 전용)
class BusLocationTowerPilotPage extends StatefulWidget {
  const BusLocationTowerPilotPage({super.key});

  @override
  State<BusLocationTowerPilotPage> createState() =>
      _BusLocationTowerPilotPageState();
}

class _BusLocationTowerPilotPageState extends State<BusLocationTowerPilotPage> {
  late Future<BusLocationTowerPilotStatus> _future =
      BusLocationTowerPilotService.refresh(force: true);
  Timer? _pollTimer;
  Timer? _shareTimer;
  var _autoSharing = false;

  @override
  void initState() {
    super.initState();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => _reload(silent: true),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _shareTimer?.cancel();
    super.dispose();
  }

  Future<void> _reload({bool silent = false}) async {
    if (!mounted) return;
    setState(() {
      _future = BusLocationTowerPilotService.refresh(force: true);
    });
    try {
      final status = await _future;
      if (status.arrivedAtWorkplace) {
        _shareTimer?.cancel();
        _autoSharing = false;
      }
    } on Object {
      if (!silent) rethrow;
    }
  }

  Future<void> _requestLocationConsent() async {
    final granted = await LocationConsentService.ensureGranted(
      context,
      trigger: LocationConsentTrigger.mapBrowse,
    );
    if (!granted || !mounted) return;
    await _reload();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('위치정보 동의가 확인되었습니다.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _openOpsChat() async {
    final rooms = await AdminAnnouncementRoomService.fetchNoticeRooms();
    if (!mounted) return;
    if (rooms.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('운영팀 공지 채팅이 아직 없습니다. 채팅 탭을 확인해 주세요.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => AdminAnnouncementChatPage(room: rooms.first),
      ),
    );
  }

  Future<void> _shareCurrentLocation({bool silent = false}) async {
    final granted = await LocationConsentService.ensureGranted(
      context,
      trigger: LocationConsentTrigger.mapBrowse,
    );
    if (!granted || !mounted) return;

    final position = await DeviceLocationService.getCurrentPositionDetailed();
    if (!mounted) return;
    if (position == null) {
      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('현재 위치를 확인할 수 없습니다. GPS와 앱 권한을 확인해 주세요.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    try {
      final updated = await BusLocationTowerPilotService.updatePosition(
        latitude: position.coordinate.latitude,
        longitude: position.coordinate.longitude,
        accuracyMeters: position.accuracyMeters,
      );
      if (!mounted) return;
      setState(() {
        _future = Future.value(updated);
      });
      _ensureAutoSharing();
      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('오늘 셔틀 위치가 업데이트되었습니다.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on Object {
      if (!mounted) return;
      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('위치 공유에 실패했습니다. 잠시 후 다시 시도해 주세요.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _ensureAutoSharing() {
    if (_autoSharing) return;
    _autoSharing = true;
    _shareTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _shareCurrentLocation(silent: true),
    );
  }

  String _routeLabel(BusLocationTowerPilotStatus status) {
    final company = status.companyName.isNotEmpty
        ? status.companyName
        : status.companyKey;
    final route = status.routeName.isNotEmpty ? status.routeName : status.routeId;
    if (company.isEmpty && route.isEmpty) return '오늘 지정 셔틀';
    if (company.isEmpty) return route;
    if (route.isEmpty) return company;
    return '$company · $route';
  }

  String _locationLabel(BusLocationTowerPilotStatus status) {
    final session = status.todaySession;
    final lat = session?['last_latitude'];
    final lng = session?['last_longitude'];
    if (lat == null || lng == null) return '위치 대기 중';
    final accuracy = session?['last_accuracy_m'];
    final accuracyLabel = accuracy is num ? ' · 오차 ${accuracy.round()}m' : '';
    return '${(lat as num).toStringAsFixed(5)}, ${(lng as num).toStringAsFixed(5)}$accuracyLabel';
  }

  String _updatedLabel(BusLocationTowerPilotStatus status) {
    final raw = status.todaySession?['last_updated_at'] as String?;
    final parsed = raw == null ? null : DateTime.tryParse(raw);
    if (parsed == null) return '아직 갱신 전';
    final local = parsed.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$hh:$mm 갱신';
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
        title: const Text(
          '버스 위치 관제',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
      ),
      body: FutureBuilder<BusLocationTowerPilotStatus>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          final status = snapshot.data ?? BusLocationTowerPilotStatus.inactive;
          if (!status.shouldShowEntry) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  '이 기능은 운영팀이 지정한 참여자만 이용할 수 있습니다.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.45,
                    color: AppColors.textSecondary.withValues(alpha: 0.95),
                  ),
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              CorporateSurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.radar_rounded,
                          color: AppColors.primary.withValues(alpha: 0.95),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            status.isDesignated ? '셔틀위치담당자' : '셔틀 위치 확인',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            status.arrivedAtWorkplace
                                ? '근무지 도착'
                                : status.hasLiveLocation
                                    ? '공유 중'
                                    : '대기 중',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (status.workStartTime.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        '근무 시작 ${status.workStartTime} — 해당 시간 이후 위치 추적 중지',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary.withValues(alpha: 0.95),
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Text(
                      status.message,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.45,
                        color: AppColors.textSecondary.withValues(alpha: 0.95),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _StepCard(
                step: 1,
                title: '위치정보 동의',
                subtitle: status.locationConsentGranted
                    ? '동의 완료 — 실시간 전송 연동만 남았습니다.'
                    : '관제를 위해 위치정보 이용 동의가 필요합니다.',
                done: status.locationConsentGranted,
                actionLabel:
                    status.locationConsentGranted ? null : '동의하기',
                onAction: status.locationConsentGranted
                    ? null
                    : _requestLocationConsent,
              ),
              if (status.isDesignated && !status.arrivedAtWorkplace)
                _StepCard(
                  step: 2,
                  title: '오늘 위치 공유',
                  subtitle:
                      '${_routeLabel(status)} · 탑승자 ${status.authorizedRiderCount}명이 확인할 수 있습니다.',
                  done: status.hasLiveLocation,
                  actionLabel:
                      status.hasLiveLocation ? '현재 위치 다시 갱신' : '위치 공유 시작',
                  onAction: () => _shareCurrentLocation(),
                )
              else if (status.isDesignated)
                _StepCard(
                  step: 2,
                  title: '근무지 도착 처리됨',
                  subtitle:
                      '근무 시작시간(${status.workStartTime})에 도착으로 간주되어 위치 공유가 중지되었습니다.',
                  done: true,
                )
              else
                _StepCard(
                  step: 2,
                  title: '같은 셔틀 탑승 확인',
                  subtitle: status.riderStopLabel.isNotEmpty
                      ? '${status.riderStopLabel} · ${status.riderPickupTime} 탑승'
                      : '오늘 같은 회사·같은 셔틀 예약이 확인되었습니다.',
                  done: true,
                  actionLabel: '내 버스 지도 열기',
                  onAction: () => Navigator.of(context).pushNamed(
                    AppRoutes.seekerMyBus,
                  ),
                ),
              _StepCard(
                step: 3,
                title: status.isDesignated ? '탑승자 위치 확인 대기' : '실시간 위치 추적',
                subtitle: status.hasLiveLocation
                    ? '최신 위치: ${_locationLabel(status)} · ${_updatedLabel(status)}'
                    : status.isDesignated
                        ? '위치를 한 번 공유하면 같은 셔틀 탑승자가 확인할 수 있습니다.'
                        : '셔틀위치담당자가 아직 오늘 위치를 공유하지 않았습니다.',
                done: status.hasLiveLocation,
                actionLabel: '새로고침',
                onAction: () => _reload(),
              ),
              _StepCard(
                step: 4,
                title: '운영팀과 일정·노선 조율',
                subtitle: status.chatHint.isNotEmpty
                    ? status.chatHint
                    : '채팅에서 노선·탑승 시간을 맞춰 주세요.',
                done: false,
                actionLabel: '운영팀 채팅 열기',
                onAction: _openOpsChat,
              ),
              const SizedBox(height: 12),
              CorporateSurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      status.hasLiveLocation ? '오늘 셔틀 위치' : '위치 공유 대기',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary.withValues(alpha: 0.95),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      height: 180,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.primaryLight.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.map_outlined,
                              size: 40,
                              color: AppColors.textSecondary.withValues(
                                alpha: 0.55,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              status.hasLiveLocation
                                  ? '${_routeLabel(status)}\n${_locationLabel(status)}\n${_updatedLabel(status)}'
                                  : status.isDesignated
                                      ? '위치 공유 시작 버튼을 누르면\n탑승자에게 최신 위치가 표시됩니다.'
                                      : '담당자가 위치를 공유하면\n이곳에 최신 좌표와 갱신 시각이 표시됩니다.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.4,
                                color: AppColors.textSecondary.withValues(
                                  alpha: 0.85,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.step,
    required this.title,
    required this.subtitle,
    required this.done,
    this.actionLabel,
    this.onAction,
  });

  final int step;
  final String title;
  final String subtitle;
  final bool done;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: CorporateSurfaceCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: done
                  ? AppColors.primary
                  : Colors.grey.shade300,
              child: Text(
                '$step',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: done ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: AppColors.textSecondary.withValues(alpha: 0.95),
                    ),
                  ),
                  if (actionLabel != null && onAction != null) ...[
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton.tonal(
                        onPressed: onAction,
                        child: Text(actionLabel!),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
