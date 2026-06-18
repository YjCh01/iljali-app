import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/hiring/hiring_application.dart';
import 'package:map/core/hiring/hiring_application_status.dart';
import 'package:map/core/hiring/local_hiring_repository.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/core/widgets/empty_state_card.dart';
import 'package:map/features/commute/data/repositories/shuttle_booking_repository.dart';
import 'package:map/features/commute/domain/entities/shuttle_booking.dart';
import 'package:map/features/commute/domain/services/shuttle_reminder_service.dart';
import 'package:map/features/commute/presentation/widgets/shuttle_reminders_banner.dart';
import 'package:map/features/corporate/data/datasources/corporate_job_post_local_data_source.dart';
import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';
import 'package:map/features/corporate/presentation/widgets/corporate_surface_card.dart';
import 'package:map/features/hiring/presentation/pages/application_chat_page.dart';
import 'package:map/features/hiring/presentation/pages/qr_check_in_page.dart';
import 'package:map/features/hiring/presentation/pages/shift_check_in_page.dart';
import 'package:map/features/job_seeker/data/repositories/job_application_repository.dart';
import 'package:map/features/job_seeker/domain/entities/job_application.dart';

/// 구직자 3번 탭 — 내 지원 (Coupang Flex 스타일)
class IndividualApplicationsTab extends StatefulWidget {
  const IndividualApplicationsTab({super.key});

  @override
  State<IndividualApplicationsTab> createState() =>
      _IndividualApplicationsTabState();
}

class _IndividualApplicationsTabState extends State<IndividualApplicationsTab> {
  static final _dateFormat = DateFormat('yyyy.MM.dd');
  static final _dayFormat = DateFormat('M월 d일');

  List<HiringApplication> _hiringItems = [];
  List<JobApplication> _localApps = [];
  Map<String, CorporateJobPost> _postsById = {};
  Map<String, ShuttleBooking> _bookingsById = {};
  List<ShuttleReminder> _reminders = [];
  bool _pastExpanded = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant IndividualApplicationsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final email = AuthSession.instance.currentUser?.email;
    final hiringRepo = await LocalHiringRepository.create();
    final hiringItems = email == null
        ? <HiringApplication>[]
        : await hiringRepo.fetchForSeeker(email);
    final repo = await JobApplicationRepository.create(email);
    final localApps = repo == null ? <JobApplication>[] : await repo.fetchAll();
    final posts = await const CorporateJobPostLocalDataSourceImpl().fetchJobPosts();
    final bookingRepo = await ShuttleBookingRepository.create();
    final bookings = email == null
        ? <ShuttleBooking>[]
        : await bookingRepo.fetchForSeeker(email);
    final reminderService = await ShuttleReminderService.create();
    final reminders = email == null
        ? <ShuttleReminder>[]
        : await reminderService.fetchActiveForSeeker(email);

    if (!mounted) return;
    setState(() {
      _hiringItems = hiringItems;
      _localApps = localApps;
      _postsById = {for (final p in posts) p.id: p};
      _bookingsById = {for (final b in bookings) b.id: b};
      _reminders = reminders;
      _loading = false;
    });
  }

  List<HiringApplication> get _upcoming {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return _hiringItems.where((h) {
      if (h.status != HiringApplicationStatus.scheduled) return false;
      final wd = h.workDate;
      if (wd == null) return true;
      final day = DateTime(wd.year, wd.month, wd.day);
      return !day.isBefore(today);
    }).toList()
      ..sort((a, b) {
        final ad = a.workDate ?? a.appliedAt;
        final bd = b.workDate ?? b.appliedAt;
        return ad.compareTo(bd);
      });
  }

  List<HiringApplication> get _past {
    final upcomingIds = _upcoming.map((h) => h.id).toSet();
    return _hiringItems
        .where((h) => !upcomingIds.contains(h.id))
        .toList();
  }

  ShuttleBooking? _bookingFor(HiringApplication app) {
    final id = app.shuttleBookingId;
    if (id == null) return null;
    return _bookingsById[id];
  }

  Future<void> _openCheckIn(HiringApplication app) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => ShiftCheckInPage(application: app),
      ),
    );
    if (result == true && mounted) await _load();
  }

  Future<void> _openQrCheckIn(HiringApplication app) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => QrCheckInPage(application: app),
      ),
    );
    if (result == true && mounted) await _load();
  }

  Future<void> _openChat(HiringApplication app) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => ApplicationChatPage(applicationId: app.id),
      ),
    );
    if (mounted) await _load();
  }

  String _shiftLabel(HiringApplication app) {
    return switch (app.shiftSlot) {
      'day' => '주간',
      'night' => '야간',
      _ => app.workSchedule,
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const ColoredBox(
        color: AppColors.background,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_hiringItems.isEmpty && _localApps.isEmpty) {
      return ColoredBox(
        color: AppColors.background,
        child: RefreshIndicator(
          onRefresh: _load,
          color: AppColors.primary,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: const [
              SizedBox(height: 120),
              EmptyStateCard(
                icon: Icons.description_outlined,
                title: '아직 지원한 공고가 없습니다',
                message: '지도에서 마음에 드는 일자리에\n지원해 보세요.',
              ),
            ],
          ),
        ),
      );
    }

    return ColoredBox(
      color: AppColors.background,
      child: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.primary,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            ShuttleRemindersBanner(
              reminders: _reminders,
              onDismiss: (r) async {
                final svc = await ShuttleReminderService.create();
                await svc.markRead(r.id);
                await _load();
              },
            ),
            _SectionHeader(
              icon: Icons.event_available,
              title: '오늘·다가오는 근무',
            ),
            const SizedBox(height: 10),
            if (_upcoming.isEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text(
                  '예정된 근무가 없습니다.',
                  style: TextStyle(fontSize: 14),
                ),
              )
            else
              ..._upcoming.map((app) => _UpcomingShiftCard(
                    app: app,
                    dayFormat: _dayFormat,
                    shiftLabel: _shiftLabel(app),
                    booking: _bookingFor(app),
                    post: _postsById[app.postId],
                    onCheckIn: () => _openCheckIn(app),
                    onQrCheckIn: () => _openQrCheckIn(app),
                    onChat: () => _openChat(app),
                  )),
            const SizedBox(height: 20),
            _SectionHeader(
              icon: Icons.directions_bus,
              title: '셔틀 안내',
            ),
            const SizedBox(height: 10),
            ..._buildShuttleSection(),
            const SizedBox(height: 20),
            _SectionHeader(
              icon: Icons.history,
              title: '근무 이력',
              trailing: IconButton(
                onPressed: () => setState(() => _pastExpanded = !_pastExpanded),
                icon: Icon(
                  _pastExpanded ? Icons.expand_less : Icons.expand_more,
                ),
              ),
            ),
            if (_pastExpanded) ...[
              const SizedBox(height: 8),
              ..._past.map(
                (app) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: CorporateSurfaceCard(
                    onTap: () => _openChat(app),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          app.postTitle,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '${app.companyName} · ${app.status.label}',
                          style: const TextStyle(fontSize: 14),
                        ),
                        Text(
                          '지원 ${_dateFormat.format(app.appliedAt)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ] else
              TextButton(
                onPressed: () => setState(() => _pastExpanded = true),
                child: Text('${_past.length}건 보기'),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildShuttleSection() {
    final withShuttle = _upcoming
        .map((app) => (app, _bookingFor(app)))
        .where((e) => e.$2 != null)
        .toList();

    if (withShuttle.isEmpty) {
      return [
        const Text(
          '예정된 셔틀 탑승이 없습니다.',
          style: TextStyle(fontSize: 14),
        ),
      ];
    }

    return withShuttle.map((entry) {
      final app = entry.$1;
      final booking = entry.$2!;
      final post = _postsById[app.postId];
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: CorporateSurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                booking.stopLabel,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Colors.red.shade900,
                ),
              ),
              Text(
                '${booking.pickupTime} 탑승 · ${_dayFormat.format(DateTime.tryParse(booking.shiftDate) ?? DateTime.now())}',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: post?.commuteRouteId == null
                    ? null
                    : () => _showRouteSnack(post!.warehouseName),
                icon: const Icon(Icons.map_outlined),
                label: const Text(
                  '지도에서 보기',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                ),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  void _showRouteSnack(String name) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('지도 탭에서 「$name」 공고 핀을 눌러 노선을 확인하세요.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 22),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _UpcomingShiftCard extends StatelessWidget {
  const _UpcomingShiftCard({
    required this.app,
    required this.dayFormat,
    required this.shiftLabel,
    required this.booking,
    required this.post,
    required this.onCheckIn,
    required this.onQrCheckIn,
    required this.onChat,
  });

  final HiringApplication app;
  final DateFormat dayFormat;
  final String shiftLabel;
  final ShuttleBooking? booking;
  final CorporateJobPost? post;
  final VoidCallback onCheckIn;
  final VoidCallback onQrCheckIn;
  final VoidCallback onChat;

  @override
  Widget build(BuildContext context) {
    final workDay = app.workDate;
    final canCheckIn =
        app.status == HiringApplicationStatus.scheduled && !app.seekerCheckedIn;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: CorporateSurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (workDay != null)
              Text(
                dayFormat.format(workDay),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            Text(
              app.postTitle,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${app.companyName} · $shiftLabel',
              style: const TextStyle(fontSize: 14),
            ),
            if (post != null)
              Text(
                post!.warehouseName,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary.withValues(alpha: 0.95),
                ),
              ),
            if (booking != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.directions_bus, size: 16, color: Colors.red.shade700),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '셔틀 ${booking!.stopLabel} ${booking!.pickupTime}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.red.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 14),
            if (canCheckIn)
              FilledButton(
                onPressed: onCheckIn,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size.fromHeight(52),
                ),
                child: const Text(
                  '출근하기',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
              )
            else if (app.seekerCheckedIn)
              Text(
                '출근 완료 · ${app.checkInMethod?.label ?? 'GPS'}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.green.shade700,
                ),
              ),
            if (canCheckIn) ...[
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: onQrCheckIn,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                ),
                child: const Text(
                  'QR 코드로 출근',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
            const SizedBox(height: 8),
            TextButton(
              onPressed: onChat,
              child: const Text('채팅하기'),
            ),
          ],
        ),
      ),
    );
  }
}
