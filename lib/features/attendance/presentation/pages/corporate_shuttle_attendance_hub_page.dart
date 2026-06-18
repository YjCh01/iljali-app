import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/constants/app_routes.dart';
import 'package:map/core/hiring/hiring_application.dart';
import 'package:map/core/hiring/hiring_application_status.dart';
import 'package:map/core/hiring/local_hiring_repository.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/core/widgets/app_back_button.dart';
import 'package:map/core/widgets/empty_state_card.dart';
import 'package:map/features/attendance/domain/services/daily_attendance_code_service.dart';
import 'package:map/features/attendance/presentation/pages/corporate_attendance_hub_page.dart';
import 'package:map/features/commute/data/repositories/commute_route_repository.dart';
import 'package:map/features/commute/domain/entities/commute_route.dart';
import 'package:map/features/corporate/presentation/widgets/corporate_surface_card.dart';

/// 기업 — 셔틀·근태 통합 허브 (SME)
class CorporateShuttleAttendanceHubPage extends StatefulWidget {
  const CorporateShuttleAttendanceHubPage({super.key});

  @override
  State<CorporateShuttleAttendanceHubPage> createState() =>
      _CorporateShuttleAttendanceHubPageState();
}

class _CorporateShuttleAttendanceHubPageState
    extends State<CorporateShuttleAttendanceHubPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  List<CommuteRoute> _routes = [];
  List<HiringApplication> _applications = [];
  String? _todayCode;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final profile = AuthSession.instance.currentUser?.corporateProfile;
    final companyKey = profile?.companyKey;
    if (companyKey == null) {
      setState(() => _loading = false);
      return;
    }

    final routeRepo = await CommuteRouteRepository.create();
    final hiringRepo = await LocalHiringRepository.create();
    final codeService = await DailyAttendanceCodeService.create();

    final routes = await routeRepo.loadForCompany(companyKey);
    final apps = await hiringRepo.fetchApplicantsForCorporate(
      companyKey: companyKey,
    );
    final code = await codeService.getOrCreateCode(companyKey: companyKey);

    if (!mounted) return;
    setState(() {
      _routes = routes;
      _applications = apps;
      _todayCode = code;
      _loading = false;
    });
  }

  Future<void> _approve(String id) async {
    final repo = await LocalHiringRepository.create();
    await repo.approveApplication(id);
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('지원을 승인했습니다.')),
    );
  }

  Future<void> _reject(String id) async {
    final repo = await LocalHiringRepository.create();
    await repo.reject(id);
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('지원을 거절했습니다.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pending = _applications
        .where((a) => a.status == HiringApplicationStatus.applied)
        .toList();
    final records = _applications
        .where((a) => a.checkedInAt != null || a.employerConfirmedAt != null)
        .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        leading: const AppBackButton(),
        automaticallyImplyLeading: false,
        title: const Text(
          '셔틀·근태 관리',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
          tabs: const [
            Tab(text: '셔틀 노선'),
            Tab(text: '지원자 승인'),
            Tab(text: '출퇴근 기록'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _RoutesTab(
                  routes: _routes,
                  onManage: () => Navigator.of(context)
                      .pushNamed(AppRoutes.corporateShuttleRoutes)
                      .then((_) => _load()),
                ),
                _ApplicantsTab(
                  pending: pending,
                  onApprove: _approve,
                  onReject: _reject,
                ),
                _AttendanceTab(
                  records: records,
                  todayCode: _todayCode,
                  onQrHub: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const CorporateAttendanceHubPage(),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _RoutesTab extends StatelessWidget {
  const _RoutesTab({
    required this.routes,
    required this.onManage,
  });

  final List<CommuteRoute> routes;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => onManage(),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          FilledButton.icon(
            onPressed: onManage,
            icon: const Icon(Icons.edit_road),
            label: const Text(
              '노선 등록·수정',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
          ),
          const SizedBox(height: 16),
          if (routes.isEmpty)
            const EmptyStateCard(
              icon: Icons.directions_bus_outlined,
              title: '등록된 셔틀 노선이 없습니다',
              message: '노선을 등록하고 공고에 연결해 보세요.',
            )
          else
            ...routes.map(
              (r) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: CorporateSurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.routeName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '정류장 ${r.stops.length}곳',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ApplicantsTab extends StatelessWidget {
  const _ApplicantsTab({
    required this.pending,
    required this.onApprove,
    required this.onReject,
  });

  final List<HiringApplication> pending;
  final Future<void> Function(String id) onApprove;
  final Future<void> Function(String id) onReject;

  @override
  Widget build(BuildContext context) {
    if (pending.isEmpty) {
      return const Center(
        child: EmptyStateCard(
          icon: Icons.person_add_alt_1_outlined,
          title: '대기 중인 지원자가 없습니다',
          message: '새 지원이 들어오면 여기에 표시됩니다.',
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: pending.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final app = pending[index];
        return CorporateSurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                app.seekerName,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(app.postTitle, style: const TextStyle(fontSize: 14)),
              if (app.shiftSlot != null) ...[
                const SizedBox(height: 4),
                Text(
                  '교대: ${_shiftLabel(app.shiftSlot!)}',
                  style: const TextStyle(fontSize: 13),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => onReject(app.id),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: const Text(
                        '거절',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => onApprove(app.id),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: const Text(
                        '승인',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  String _shiftLabel(String slot) => switch (slot) {
        'day' => '주간',
        'night' => '야간',
        _ => '상관없음',
      };
}

class _AttendanceTab extends StatelessWidget {
  const _AttendanceTab({
    required this.records,
    required this.todayCode,
    required this.onQrHub,
  });

  final List<HiringApplication> records;
  final String? todayCode;
  final VoidCallback onQrHub;

  static final _timeFormat = DateFormat('HH:mm');

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        CorporateSurfaceCard(
          onTap: onQrHub,
          child: Row(
            children: [
              const Icon(Icons.qr_code, color: AppColors.primary, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '오늘 출근 QR 코드',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      todayCode ?? '------',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 6,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (records.isEmpty)
          const EmptyStateCard(
            icon: Icons.fact_check_outlined,
            title: '출퇴근 기록이 없습니다',
            message: '구직자 출근 후 여기에 표시됩니다.',
          )
        else
          ...records.map((app) {
            final checkIn = app.checkedInAt;
            final method = app.checkInMethod?.label ?? 'GPS';
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: CorporateSurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      app.seekerName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(app.postTitle, style: const TextStyle(fontSize: 13)),
                    const SizedBox(height: 6),
                    if (checkIn != null)
                      Text(
                        '출근 ${_timeFormat.format(checkIn)} · $method',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    if (app.employerConfirmedAt != null)
                      Text(
                        '기업확인 ${_timeFormat.format(app.employerConfirmedAt!)}',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary.withValues(alpha: 0.9),
                        ),
                      ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}
