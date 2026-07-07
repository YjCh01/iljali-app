import 'package:flutter/material.dart';
import 'package:map/core/admin/admin_ops_api_client.dart';
import 'package:map/core/config/env_config.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/constants/app_routes.dart';
import 'package:map/core/sync/local_remote_sync_service.dart';
import 'package:map/features/admin/presentation/widgets/admin_credit_stepper.dart';
import 'package:map/core/widgets/app_back_button.dart';

/// 관리자 Ops — 푸시권·핀·제재·시드
class AdminOpsPage extends StatefulWidget {
  const AdminOpsPage({super.key});

  @override
  State<AdminOpsPage> createState() => _AdminOpsPageState();
}

class _AdminOpsPageState extends State<AdminOpsPage> {
  final _client = AdminOpsApiClient();
  final _companyKeyCtrl = TextEditingController(text: '1000000001');
  int _recruitmentPinGrant = 1;
  int _shuttleStopPinGrant = 1;
  int _pushTicketGrant = 1;
  final _memberEmailCtrl = TextEditingController(text: 'seeker-0001@qc.iljari.co.kr');
  final _postIdCtrl = TextEditingController(text: 'qc_post_real_001');
  final _seekerSeedCountCtrl = TextEditingController(text: '1000');
  final _distributeMaxCtrl = TextEditingController(text: '100');

  bool _busy = false;
  String _status = '';
  List<Map<String, dynamic>> _audit = const [];

  @override
  void initState() {
    super.initState();
    _refreshAudit();
  }

  @override
  void dispose() {
    _companyKeyCtrl.dispose();
    _memberEmailCtrl.dispose();
    _postIdCtrl.dispose();
    _seekerSeedCountCtrl.dispose();
    _distributeMaxCtrl.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action, String okMessage) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _status = '처리 중…';
    });
    try {
      await action();
      if (!mounted) return;
      setState(() => _status = okMessage);
      await _refreshAudit();
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = '오류: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refreshAudit() async {
    if (!_client.isEnabled) return;
    try {
      final logs = await _client.auditLogs(limit: 20);
      if (mounted) setState(() => _audit = logs);
    } on Object {
      // ignore
    }
  }

  @override
  Widget build(BuildContext context) {
    final apiReady = _client.isEnabled;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        leading: const AppBackButton(),
        title: const Text('관리자 Ops'),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(context).pushNamed(AppRoutes.adminCompliance),
            child: const Text('컴플라이언스'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _InfoBanner(
            apiReady: apiReady,
            qcMode: EnvConfig.qcMode,
          ),
          if (_status.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(_status, style: const TextStyle(fontSize: 13)),
          ],
          const SizedBox(height: 16),
          _Section(
            title: '푸시·거점 이용권',
            child: Column(
              children: [
                _Field(label: '사업자번호(BRN)', controller: _companyKeyCtrl),
                AdminCreditStepper(
                  label: '일자리 알림핀',
                  subtitle: '근무지·모집지역 노출',
                  value: _recruitmentPinGrant,
                  onChanged: (v) => setState(() => _recruitmentPinGrant = v),
                ),
                AdminCreditStepper(
                  label: '정류장 표시핀',
                  subtitle: '셔틀 정류장 노출',
                  value: _shuttleStopPinGrant,
                  onChanged: (v) => setState(() => _shuttleStopPinGrant = v),
                ),
                AdminCreditStepper(
                  label: 'PUSH 알림권',
                  subtitle: 'PUSH 1회 발송',
                  value: _pushTicketGrant,
                  onChanged: (v) => setState(() => _pushTicketGrant = v),
                ),
                FilledButton(
                  onPressed: !apiReady || _busy
                      ? null
                      : () => _run(() async {
                            await _client.grantWallet(
                              companyKey: _companyKeyCtrl.text.trim(),
                              packageCredits: _recruitmentPinGrant,
                              shuttleStopCredits: _shuttleStopPinGrant,
                              pushTicketCredits: _pushTicketGrant,
                            );
                          }, '이용권 부여 완료'),
                  child: const Text('선택 수량 부여'),
                ),
              ],
            ),
          ),
          _Section(
            title: '일자리핀 · 정류장 노출',
            child: Column(
              children: [
                _Field(label: '공고 ID', controller: _postIdCtrl),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: !apiReady || _busy
                            ? null
                            : () => _run(() async {
                                  await _client.setJobPin(
                                    postId: _postIdCtrl.text.trim(),
                                    active: true,
                                  );
                                }, '일자리핀 ON'),
                        child: const Text('일자리핀 ON'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: !apiReady || _busy
                            ? null
                            : () => _run(() async {
                                  await _client.setShuttleExposure(
                                    postId: _postIdCtrl.text.trim(),
                                    active: true,
                                  );
                                }, '정류장 노출 ON'),
                        child: const Text('정류장 노출 ON'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _Section(
            title: '회원 제재',
            child: Column(
              children: [
                _Field(label: '이메일', controller: _memberEmailCtrl),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: !apiReady || _busy
                          ? null
                          : () => _run(() async {
                                await _client.sanctionMember(
                                  email: _memberEmailCtrl.text.trim(),
                                  action: 'suspend',
                                  reason: 'QC 이용 제한',
                                  days: 30,
                                );
                              }, '30일 정지'),
                      child: const Text('30일 정지'),
                    ),
                    OutlinedButton(
                      onPressed: !apiReady || _busy
                          ? null
                          : () => _run(() async {
                                await _client.sanctionMember(
                                  email: _memberEmailCtrl.text.trim(),
                                  action: 'permanent_ban',
                                  reason: '영구 제재',
                                );
                              }, '영구 제재'),
                      child: const Text('영구 제재'),
                    ),
                    OutlinedButton(
                      onPressed: !apiReady || _busy
                          ? null
                          : () => _run(() async {
                                await _client.sanctionMember(
                                  email: _memberEmailCtrl.text.trim(),
                                  action: 'lift',
                                );
                              }, '제재 해제'),
                      child: const Text('해제'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _Section(
            title: 'QC 데이터 시드',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Field(
                  label: '가상 구직자 수',
                  controller: _seekerSeedCountCtrl,
                  keyboardType: TextInputType.number,
                ),
                FilledButton(
                  onPressed: !apiReady || _busy
                      ? null
                      : () => _run(() async {
                            final count =
                                int.tryParse(_seekerSeedCountCtrl.text) ?? 1000;
                            await _client.seedSeekers(count: count);
                          }, '구직자 시드 완료'),
                  child: const Text('구직자 1,000명 생성'),
                ),
                const SizedBox(height: 8),
                _Field(
                  label: '공고당 지원 생성 수',
                  controller: _distributeMaxCtrl,
                  keyboardType: TextInputType.number,
                ),
                OutlinedButton(
                  onPressed: !apiReady || _busy
                      ? null
                      : () => _run(() async {
                            final max =
                                int.tryParse(_distributeMaxCtrl.text) ?? 100;
                            await _client.distributeApplications(
                              postId: _postIdCtrl.text.trim(),
                              maxApplications: max,
                            );
                          }, '지원·채팅 샘플 생성'),
                  child: const Text('선택 공고에 지원 분포'),
                ),
                OutlinedButton(
                  onPressed: !apiReady || _busy
                      ? null
                      : () => _run(() async {
                            await LocalRemoteSyncService().pullFromServer();
                          }, '앱 데이터 pull 완료'),
                  child: const Text('서버 → 앱 sync pull'),
                ),
              ],
            ),
          ),
          _Section(
            title: '감사 로그',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final log in _audit)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      '${log['action']} · ${log['target_id']}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                if (_audit.isEmpty)
                  const Text('로그 없음', style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.apiReady, required this.qcMode});

  final bool apiReady;
  final bool qcMode;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: apiReady ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        apiReady
            ? 'Admin API 연결됨 · QC_MODE=${qcMode ? "ON" : "OFF"} · PG=${qcMode ? "mock" : "server"}'
            : 'COMPLIANCE_API_URL / ADMIN_API_KEY 설정 필요',
        style: const TextStyle(fontSize: 12, height: 1.4),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    this.keyboardType,
  });

  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }
}
