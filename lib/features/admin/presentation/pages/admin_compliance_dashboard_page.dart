import 'package:flutter/material.dart';
import 'package:map/core/compliance/business_verification_status.dart';
import 'package:map/core/compliance/data/compliance_api_client.dart';
import 'package:map/core/compliance/data/compliance_repository.dart';
import 'package:map/core/compliance/services/abuse_detection_service.dart';
import 'package:map/core/compliance/services/admin_outsourcing_roi_watchlist.dart';
import 'package:map/core/compliance/verified_business_record.dart';
import 'package:map/core/config/env_config.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/hiring/local_hiring_repository.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/core/widgets/app_back_button.dart';
import 'package:map/features/corporate/domain/entities/premium_partnership_tier.dart';
import 'package:map/features/corporate/domain/services/roi_metrics_service.dart';
import 'package:map/features/corporate/domain/entities/corporate_member_profile.dart';

/// 관리자 — 이상행위·사업자 검토 대시보드
class AdminComplianceDashboardPage extends StatefulWidget {
  const AdminComplianceDashboardPage({super.key});

  @override
  State<AdminComplianceDashboardPage> createState() =>
      _AdminComplianceDashboardPageState();
}

class _AdminComplianceDashboardPageState
    extends State<AdminComplianceDashboardPage> {
  List<Map<String, dynamic>> _flags = [];
  List<VerifiedBusinessRecord> _businessRecords = [];
  List<AbuseAlert> _liveAlerts = [];
  List<Map<String, dynamic>> _enterpriseInquiries = [];
  Set<String> _outsourcingRoiWatchlist = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final compliance = await ComplianceRepository.create();
    final hiring = await LocalHiringRepository.create();
    final apps = await hiring.fetchAll();
    final detector = AbuseDetectionService(repository: compliance);

    final alerts = <AbuseAlert>[];
    final brns = apps.map((a) => a.companyKey).whereType<String>().toSet();
    for (final brn in brns) {
      alerts.addAll(await detector.analyzeApplications(apps, companyKey: brn));
    }

    final flags = await compliance.fetchAbuseFlags();
    final records = await compliance.fetchAllBusinessRecords();
    final watchlist = await AdminOutsourcingRoiWatchlist.load();

    if (!mounted) return;
    setState(() {
      _flags = flags;
      _enterpriseInquiries =
          flags.where((f) => f['type'] == 'enterprise_inquiry').toList();
      _businessRecords = records;
      _liveAlerts = alerts;
      _outsourcingRoiWatchlist = watchlist;
      _loading = false;
    });
  }

  Future<void> _approve(VerifiedBusinessRecord record) async {
    final repo = await ComplianceRepository.create();
    await repo.approveAdminReview(record.businessRegistrationNumber);
    if (EnvConfig.isComplianceApiEnabled) {
      try {
        await ComplianceApiClient().adminReviewCompany(
          companyKey: record.businessRegistrationNumber,
          approved: true,
        );
      } on Object {
        // 로컬 승인은 유지
      }
    }
    await _syncSessionIfMatch(record.businessRegistrationNumber, approved: true);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${record.companyName} 승인 처리')),
      );
      await _load();
    }
  }

  Future<void> _reject(VerifiedBusinessRecord record) async {
    final repo = await ComplianceRepository.create();
    await repo.rejectAdminReview(record.businessRegistrationNumber);
    if (EnvConfig.isComplianceApiEnabled) {
      try {
        await ComplianceApiClient().adminReviewCompany(
          companyKey: record.businessRegistrationNumber,
          approved: false,
        );
      } on Object {}
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${record.companyName} 거부 처리')),
      );
      await _load();
    }
  }

  Future<void> _suspend(VerifiedBusinessRecord record) async {
    final repo = await ComplianceRepository.create();
    await repo.suspendCompany(record.businessRegistrationNumber);
    if (EnvConfig.isComplianceApiEnabled) {
      try {
        await ComplianceApiClient().adminSuspendCompany(
          record.businessRegistrationNumber,
        );
      } on Object {}
    }
    await _syncSessionIfMatch(record.businessRegistrationNumber, suspended: true);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${record.companyName} 계정 정지')),
      );
      await _load();
    }
  }

  Future<void> _syncSessionIfMatch(
    String brn, {
    bool approved = false,
    bool suspended = false,
  }) async {
    final user = AuthSession.instance.currentUser;
    final profile = user?.corporateProfile;
    if (profile == null || profile.companyKey != brn.replaceAll(RegExp(r'[^0-9]'), '')) {
      return;
    }
    CorporateMemberProfile updated;
    if (suspended) {
      updated = profile.copyWith(
        isSuspended: true,
        verificationStatus: BusinessVerificationStatus.suspended,
      );
    } else if (approved) {
      updated = profile.copyWith(
        adminReviewApproved: true,
        verificationStatus: BusinessVerificationStatus.verified,
        isEnterpriseOutsourcingEdition: profile.requiresAdminReview,
      );
    } else {
      return;
    }
    await AuthSession.instance.updateCorporateProfile(updated);
  }

  static String _normalizeBrn(String brn) =>
      brn.replaceAll(RegExp(r'[^0-9]'), '');

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
        title: const Text('컴플라이언스 대시보드'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.primary,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                children: [
                  const Text(
                    '실시간 이상행위',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  if (_liveAlerts.isEmpty)
                    const Text('감지된 이상 패턴 없음')
                  else
                    ..._liveAlerts.map(
                      (a) => _AlertTile(
                        title: a.type.name,
                        message: a.message,
                        severity: a.severity.name,
                      ),
                    ),
                  const SizedBox(height: 24),
                  const Text(
                    'Enterprise 견적 요청',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  if (_enterpriseInquiries.isEmpty)
                    const Text('대기 중인 견적 요청 없음')
                  else
                    ..._enterpriseInquiries.map(
                      (f) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        color: AppColors.primaryLight.withValues(alpha: 0.12),
                        child: ListTile(
                          title: Text(f['companyName']?.toString() ?? '기업'),
                          subtitle: Text(
                            '${f['contactPerson'] ?? ''} · ${f['department'] ?? ''}\n'
                            '${f['message'] ?? ''}',
                          ),
                          isThreeLine: true,
                          trailing: OutlinedButton(
                            onPressed: () {
                              final brn = f['brn']?.toString();
                              if (brn == null) return;
                              VerifiedBusinessRecord? matched;
                              for (final r in _businessRecords) {
                                if (r.businessRegistrationNumber == brn) {
                                  matched = r;
                                  break;
                                }
                              }
                              if (matched != null) _approve(matched);
                            },
                            child: const Text('승인 검토'),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                  const Text(
                    '협력사 · 아웃소싱 대비 절감',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '체크한 기업만 BASIC(10,000원) 대비 수수료 절감액을 표시합니다. '
                    '일반 기업 ROI 화면에는 노출되지 않습니다.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: AppColors.textSecondary.withValues(alpha: 0.95),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_businessRecords.isEmpty)
                    const Text('등록된 기업 없음')
                  else
                    ..._businessRecords.map(
                      (record) => _OutsourcingRoiMonitorTile(
                        record: record,
                        watched: _outsourcingRoiWatchlist.contains(
                          _normalizeBrn(record.businessRegistrationNumber),
                        ),
                        onToggle: (enabled) async {
                          final key =
                              _normalizeBrn(record.businessRegistrationNumber);
                          await AdminOutsourcingRoiWatchlist.toggle(
                            key,
                            enabled,
                          );
                          if (!mounted) return;
                          setState(() {
                            if (enabled) {
                              _outsourcingRoiWatchlist.add(key);
                            } else {
                              _outsourcingRoiWatchlist.remove(key);
                            }
                          });
                        },
                      ),
                    ),
                  const SizedBox(height: 24),
                  const Text(
                    '사업자 검증 (관리자 검토)',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  if (_businessRecords.isEmpty)
                    const Text('등록된 검증 기록 없음')
                  else
                    ..._businessRecords.map(
                      (record) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                record.companyName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${record.businessRegistrationNumber} · ${record.industryName ?? ''}\n'
                                '${record.status.label}'
                                '${record.requiresAdminReview ? ' · Enterprise·관리자 승인 필요' : ''}',
                                style: const TextStyle(height: 1.4),
                              ),
                              if (record.requiresAdminReview &&
                                  record.status !=
                                      BusinessVerificationStatus.verified) ...[
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  children: [
                                    OutlinedButton(
                                      onPressed: () => _approve(record),
                                      child: const Text('승인'),
                                    ),
                                    OutlinedButton(
                                      onPressed: () => _reject(record),
                                      child: const Text('거부'),
                                    ),
                                  ],
                                ),
                              ],
                              if (record.status !=
                                  BusinessVerificationStatus.suspended) ...[
                                const SizedBox(height: 6),
                                TextButton(
                                  onPressed: () => _suspend(record),
                                  child: const Text(
                                    '계정 정지',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                  const Text(
                    '플래그 이력',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  if (_flags.isEmpty)
                    const Text('플래그 없음')
                  else
                    ..._flags.take(20).map(
                          (f) => _AlertTile(
                            title: f['type']?.toString() ?? 'flag',
                            message: f['message']?.toString() ?? '',
                            severity: f['severity']?.toString() ?? 'low',
                          ),
                        ),
                ],
              ),
            ),
    );
  }
}

class _OutsourcingRoiMonitorTile extends StatefulWidget {
  const _OutsourcingRoiMonitorTile({
    required this.record,
    required this.watched,
    required this.onToggle,
  });

  final VerifiedBusinessRecord record;
  final bool watched;
  final ValueChanged<bool> onToggle;

  @override
  State<_OutsourcingRoiMonitorTile> createState() =>
      _OutsourcingRoiMonitorTileState();
}

class _OutsourcingRoiMonitorTileState extends State<_OutsourcingRoiMonitorTile> {
  RoiMetrics? _metrics;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.watched) _loadMetrics();
  }

  @override
  void didUpdateWidget(covariant _OutsourcingRoiMonitorTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.watched && !oldWidget.watched) {
      _loadMetrics();
    } else if (!widget.watched) {
      setState(() => _metrics = null);
    }
  }

  Future<void> _loadMetrics() async {
    setState(() => _loading = true);
    final key = widget.record.businessRegistrationNumber
        .replaceAll(RegExp(r'[^0-9]'), '');
    final metrics = await RoiMetricsService().computeForCompany(
      companyKey: key,
      tier: PremiumPartnershipTier.starter,
      subscriptionActive: true,
    );
    if (!mounted) return;
    setState(() {
      _metrics = metrics;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final metrics = _metrics;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.record.companyName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
                Switch(
                  value: widget.watched,
                  activeColor: AppColors.primary,
                  onChanged: widget.onToggle,
                ),
              ],
            ),
            Text(
              '${widget.record.businessRegistrationNumber} · '
              '${widget.record.industryName ?? ''}',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary.withValues(alpha: 0.95),
              ),
            ),
            if (widget.watched) ...[
              const SizedBox(height: 10),
              if (_loading)
                const LinearProgressIndicator(minHeight: 2)
              else if (metrics == null)
                const Text('집계 불가')
              else if (metrics.commissionSavingsVsBasicKrw <= 0 ||
                  !metrics.hasCheckIns)
                Text(
                  metrics.hasCheckIns
                      ? '출근 ${metrics.checkIns}건 · 절감 데이터 없음'
                      : '출근 데이터 없음 · 공고·채용 후 다시 확인',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary.withValues(alpha: 0.95),
                  ),
                )
              else
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.activeBasicBadgeBg.withValues(alpha: 0.55),
                        AppColors.primaryLight.withValues(alpha: 0.35),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '아웃소싱(BASIC 10,000원) 대비 절감',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.activeBasicBadgeText,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        metrics.savingsHeadline,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AlertTile extends StatelessWidget {
  const _AlertTile({
    required this.title,
    required this.message,
    required this.severity,
  });

  final String title;
  final String message;
  final String severity;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text('$title · $severity'),
        subtitle: Text(message),
      ),
    );
  }
}
