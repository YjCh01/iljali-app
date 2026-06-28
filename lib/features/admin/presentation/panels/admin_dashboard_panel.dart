import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/features/admin/domain/admin_ops_controller.dart';
import 'package:map/features/admin/presentation/widgets/admin_web_scaffold.dart';

class AdminDashboardPanel extends StatefulWidget {
  const AdminDashboardPanel({super.key, required this.controller});

  final AdminOpsController controller;

  @override
  State<AdminDashboardPanel> createState() => _AdminDashboardPanelState();
}

class _AdminDashboardPanelState extends State<AdminDashboardPanel> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChange);
    if (widget.controller.stats == null && widget.controller.apiReady) {
      widget.controller.refreshDashboard();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final stats = c.stats;

    return AdminPanelScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!c.apiReady)
            const AdminCard(
              title: '서버 연결 필요',
              subtitle: 'Admin 실행.command 또는 QC 실행.command 로 시작하세요.',
              child: Text(
                'COMPLIANCE_API_URL=http://api.iljari.app · ADMIN_API_KEY=iljari-admin-dev-key',
                style: TextStyle(fontSize: 13),
              ),
            )
          else ...[
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _StatChip(
                  label: '가상 구직자',
                  value: '${stats?['seekers'] ?? '—'}',
                  icon: Icons.person_outline,
                ),
                _StatChip(
                  label: '공고',
                  value: '${stats?['job_posts'] ?? '—'}',
                  icon: Icons.work_outline,
                ),
                _StatChip(
                  label: '지원',
                  value: '${stats?['applications'] ?? '—'}',
                  icon: Icons.send_outlined,
                ),
                _StatChip(
                  label: '제재 회원',
                  value: '${stats?['suspended_members'] ?? '—'}',
                  icon: Icons.block_outlined,
                ),
              ],
            ),
            const SizedBox(height: 20),
            AdminCard(
              title: '빠른 작업',
              subtitle: '자주 쓰는 QC 시나리오',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: c.busy
                        ? null
                        : () => c.run(
                              () => c.client.seedSeekers(count: 1000),
                              successMessage: '구직자 1,000명 시드 완료',
                            ),
                    icon: const Icon(Icons.group_add_outlined, size: 18),
                    label: const Text('구직자 1,000명'),
                  ),
                  OutlinedButton.icon(
                    onPressed: c.busy
                        ? null
                        : () => c.run(
                              () => c.client.grantWallet(
                                companyKey: '1000000001',
                                packageCredits: 30,
                              ),
                              successMessage: '테스트기업 알파 이용권 +30',
                            ),
                    icon: const Icon(Icons.wallet_outlined, size: 18),
                    label: const Text('알파 +30 이용권'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AdminCard(
              title: '최근 감사 로그',
              child: c.auditLogs.isEmpty
                  ? const Text('로그 없음', style: TextStyle(fontSize: 13))
                  : Column(
                      children: [
                        for (final log in c.auditLogs.take(10))
                          ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              '${log['action']} · ${log['target_id']}',
                              style: const TextStyle(fontSize: 13),
                            ),
                            subtitle: Text(
                              '${log['created_at'] ?? ''}',
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8EAED)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 22),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary.withValues(alpha: 0.95),
            ),
          ),
        ],
      ),
    );
  }
}
