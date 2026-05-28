import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/constants/app_strings.dart';
import 'package:map/core/hiring/insurance_auth_flow_helper.dart';
import 'package:map/core/hiring/insurance_auth_provider.dart';
import 'package:map/core/hiring/insurance_verification_log.dart';
import 'package:map/core/hiring/local_permanent_employment_repository.dart';
import 'package:map/core/hiring/permanent_commission_calculator.dart';
import 'package:map/core/hiring/permanent_employment_record.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/core/widgets/app_back_button.dart';
import 'package:map/features/corporate/presentation/widgets/corporate_surface_card.dart';

class _EmploymentVerificationItem {
  const _EmploymentVerificationItem({
    required this.record,
    this.latest,
    this.history = const [],
  });

  final PermanentEmploymentRecord record;
  final InsuranceVerificationLog? latest;
  final List<InsuranceVerificationLog> history;
}

/// 구직자 — 건강보험 재직 인증 (간편인증 + CODEF/Hyphen)
class HealthInsuranceVerificationPage extends StatefulWidget {
  const HealthInsuranceVerificationPage({super.key});

  @override
  State<HealthInsuranceVerificationPage> createState() =>
      _HealthInsuranceVerificationPageState();
}

class _HealthInsuranceVerificationPageState
    extends State<HealthInsuranceVerificationPage> {
  final _flowHelper = InsuranceAuthFlowHelper();
  final _workplaceController = TextEditingController();
  InsuranceAuthProvider _provider = InsuranceAuthProvider.naver;
  bool _employed = true;
  bool _loading = true;
  bool _submitting = false;
  String? _selectedEmploymentId;
  List<_EmploymentVerificationItem> _items = [];
  List<PermanentCommissionNotification> _notifications = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _workplaceController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final email = AuthSession.instance.currentUser?.email;
    if (email == null) {
      setState(() => _loading = false);
      return;
    }

    final repo = await LocalPermanentEmploymentRepository.create();
    await repo.processDueBillingCycles();
    final records = await repo.fetchForSeeker(email);
    final items = <_EmploymentVerificationItem>[];
    for (final record in records) {
      final localHistory = (await repo.fetchVerifications())
          .where((log) => log.employmentId == record.id)
          .toList()
        ..sort((a, b) => b.verifiedAt.compareTo(a.verifiedAt));

      items.add(
        _EmploymentVerificationItem(
          record: record,
          latest: localHistory.isEmpty ? null : localHistory.first,
          history: localHistory,
        ),
      );
    }

    final notifications = await repo.fetchNotifications(seekerEmail: email);

    if (!mounted) return;
    setState(() {
      _items = items;
      _notifications = notifications;
      _selectedEmploymentId = items.isEmpty ? null : items.first.record.id;
      if (items.isNotEmpty) {
        _workplaceController.text = items.first.record.companyName;
      }
      _loading = false;
    });
  }

  Future<void> _submit() async {
    final employmentId = _selectedEmploymentId;
    final email = AuthSession.instance.currentUser?.email;
    if (employmentId == null || email == null) return;

    final item = _items.firstWhere((e) => e.record.id == employmentId);
    setState(() => _submitting = true);

    try {
      final result = await _flowHelper.run(
        context: context,
        employmentId: employmentId,
        employerCompanyName: item.record.companyName,
        seekerEmail: email,
        provider: _provider,
        workplaceNameFallback: _workplaceController.text,
        currentlyEmployedFallback: _employed,
      );

      final repo = await LocalPermanentEmploymentRepository.create();
      await repo.saveVerification(result.log);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message ?? '처리되었습니다.'),
          behavior: SnackBarBehavior.floating,
        ),
      );

      if (result.success) await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('인증 오류: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final remote = _flowHelper.isRemoteEnabled;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        leading: const AppBackButton(),
        automaticallyImplyLeading: false,
        title: const Text('건강보험 재직 인증'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  '건강보험 자격득실 확인',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  AppStrings.permanentCommissionNote,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: AppColors.primary.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  remote
                      ? '간편인증 후 CODEF/Hyphen으로 자격득실확인서를 조회합니다. '
                          '사업장명이 채용 회사와 일치해야 30일 주기 수수료 청구가 진행됩니다.'
                      : '간편인증(네이버·카카오·토스·PASS)으로 재직을 확인합니다. '
                          '서버 연동 시 자격득실확인서가 자동 조회됩니다.',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color: AppColors.textSecondary.withValues(alpha: 0.95),
                  ),
                ),
                if (_expiringNotifications.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _ExpiryBanner(notifications: _expiringNotifications),
                ],
                const SizedBox(height: 16),
                if (_items.isEmpty)
                  CorporateSurfaceCard(
                    child: Text(
                      '상시직 채용 등록 후 인증할 수 있습니다.',
                      style: TextStyle(
                        color: AppColors.textSecondary.withValues(alpha: 0.95),
                      ),
                    ),
                  )
                else ...[
                  ..._items.map((item) => _EmploymentCard(
                        item: item,
                        selected: item.record.id == _selectedEmploymentId,
                        onTap: () => setState(
                          () => _selectedEmploymentId = item.record.id,
                        ),
                      )),
                  const SizedBox(height: 16),
                  const Text(
                    '간편인증 수단',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: InsuranceAuthProvider.values.map((provider) {
                      final selected = _provider == provider;
                      return ChoiceChip(
                        label: Text(provider.label),
                        selected: selected,
                        onSelected: _submitting
                            ? null
                            : (_) => setState(() => _provider = provider),
                        selectedColor:
                            AppColors.primary.withValues(alpha: 0.15),
                        labelStyle: TextStyle(
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                          color: selected
                              ? AppColors.primary
                              : AppColors.textPrimary,
                        ),
                      );
                    }).toList(),
                  ),
                  if (!remote) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _workplaceController,
                      decoration: const InputDecoration(
                        labelText: '확인서 사업장명 (로컬 테스트)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('현재 재직 중'),
                      value: _employed,
                      onChanged: (v) => setState(() => _employed = v),
                    ),
                  ],
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _submitting ? null : _submit,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: Text(
                      _submitting
                          ? '인증 중...'
                          : '${_provider.label}로 재직 인증',
                    ),
                  ),
                  if (_selectedHistory.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const Text(
                      '인증 이력',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    ..._selectedHistory.map(
                      (log) => _HistoryTile(log: log),
                    ),
                  ],
                ],
              ],
            ),
    );
  }

  List<InsuranceVerificationLog> get _selectedHistory {
    if (_selectedEmploymentId == null) return [];
    for (final item in _items) {
      if (item.record.id == _selectedEmploymentId) {
        return item.history;
      }
    }
    return [];
  }

  List<PermanentCommissionNotification> get _expiringNotifications {
    return _notifications
        .where(
          (n) =>
              n.title.contains('재인증') ||
              n.title.contains('인증 필요') ||
              n.title.contains('미청구'),
        )
        .take(3)
        .toList();
  }
}

class _EmploymentCard extends StatelessWidget {
  const _EmploymentCard({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _EmploymentVerificationItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final latest = item.latest;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: CorporateSurfaceCard(
        onTap: onTap,
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: AppColors.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.record.companyName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    '입사 ${DateFormat('yyyy.MM.dd').format(item.record.hireDate)} · '
                    '월 ${PermanentCommissionCalculator.formatKrw(item.record.monthlySalaryKrw)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary.withValues(alpha: 0.95),
                    ),
                  ),
                  if (latest != null)
                    Text(
                      latest.status == InsuranceVerificationStatus.verified
                          ? '인증 ${DateFormat('yyyy.MM.dd').format(latest.expiresAt)}까지 유효'
                          : '인증 실패 · 재시도 필요',
                      style: TextStyle(
                        fontSize: 11,
                        color: latest.status ==
                                InsuranceVerificationStatus.verified
                            ? AppColors.primary
                            : Colors.red.shade700,
                      ),
                    )
                  else
                    Text(
                      '재직 인증 필요',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.orange.shade800,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.log});

  final InsuranceVerificationLog log;

  @override
  Widget build(BuildContext context) {
    final verified = log.status == InsuranceVerificationStatus.verified;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: CorporateSurfaceCard(
        child: Row(
          children: [
            Icon(
              verified ? Icons.check_circle_outline : Icons.cancel_outlined,
              size: 18,
              color: verified ? AppColors.primary : Colors.red.shade700,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${DateFormat('yyyy.MM.dd HH:mm').format(log.verifiedAt)} · '
                    '${log.authProvider ?? log.method}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    verified
                        ? '${log.workplaceName} · ${DateFormat('yyyy.MM.dd').format(log.expiresAt)}까지'
                        : log.rejectionReason ?? '인증 실패',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary.withValues(alpha: 0.95),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpiryBanner extends StatelessWidget {
  const _ExpiryBanner({required this.notifications});

  final List<PermanentCommissionNotification> notifications;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.notifications_active_outlined,
                  size: 18, color: Colors.orange.shade800),
              const SizedBox(width: 6),
              Text(
                '인증 알림',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Colors.orange.shade900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ...notifications.map(
            (n) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                n.body,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: Colors.orange.shade900.withValues(alpha: 0.9),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
