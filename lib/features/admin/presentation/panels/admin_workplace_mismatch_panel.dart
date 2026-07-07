import 'package:flutter/material.dart';
import 'package:map/core/compliance/data/workplace_mismatch_flag_repository.dart';
import 'package:map/core/compliance/services/workplace_mismatch_admin_service.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/features/admin/domain/admin_ops_controller.dart';
import 'package:map/features/admin/presentation/widgets/admin_web_scaffold.dart';

/// 어드민 — 사업자 소재지 vs 공고 근무지 불일치 검토
class AdminWorkplaceMismatchPanel extends StatefulWidget {
  const AdminWorkplaceMismatchPanel({super.key, required this.controller});

  final AdminOpsController controller;

  @override
  State<AdminWorkplaceMismatchPanel> createState() =>
      _AdminWorkplaceMismatchPanelState();
}

class _AdminWorkplaceMismatchPanelState
    extends State<AdminWorkplaceMismatchPanel> {
  List<Map<String, dynamic>> _pending = const [];
  var _loading = true;
  String? _actingFlagId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final pending = await WorkplaceMismatchFlagRepository.fetchPending(
      adminClient: widget.controller.client,
    );
    if (!mounted) return;
    setState(() {
      _pending = pending;
      _loading = false;
    });
  }

  Future<void> _approve(String flagId) async {
    setState(() => _actingFlagId = flagId);
    final error =
        await WorkplaceMismatchAdminService.approveStatedWorkplacePost(
      flagId: flagId,
      adminClient: widget.controller.client,
    );
    if (!mounted) return;
    setState(() => _actingFlagId = null);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('기재된 근무지로 공고를 게시했습니다.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return AdminPanelScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '근무지·본사 주소 불일치',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              IconButton(
                onPressed: _loading ? null : _load,
                icon: const Icon(Icons.refresh_rounded),
                tooltip: '새로고침',
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '사업자 소재지와 공고 근무지가 다른 기업회원의 공고입니다. '
            '「기재된 근무지 그대로 공고 진행」을 누르면 해당 근무지로 모집 공고가 게시됩니다.',
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: AppColors.textSecondary.withValues(alpha: 0.95),
            ),
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_pending.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '검토 대기 중인 근무지 불일치 공고가 없습니다.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary.withValues(alpha: 0.9),
                ),
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.92,
              ),
              itemCount: _pending.length,
              itemBuilder: (context, index) {
                final flag = _pending[index];
                return _MismatchReviewCard(
                  flag: flag,
                  busy: _actingFlagId == flag['id'],
                  onApprove: () => _approve('${flag['id']}'),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _MismatchReviewCard extends StatelessWidget {
  const _MismatchReviewCard({
    required this.flag,
    required this.busy,
    required this.onApprove,
  });

  final Map<String, dynamic> flag;
  final bool busy;
  final VoidCallback onApprove;

  @override
  Widget build(BuildContext context) {
    final companyName = '${flag['companyName'] ?? ''}'.trim();
    final companyKey = '${flag['companyKey'] ?? ''}'.trim();
    final postTitle = '${flag['postTitle'] ?? '공고'}'.trim();
    final headOffice = '${flag['headOfficeAddress'] ?? ''}'.trim();
    final workplace = '${flag['workplaceAddress'] ?? ''}'.trim();
    final distance = flag['distanceMeters'];

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.orange.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              companyName.isNotEmpty ? companyName : companyKey,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
            if (companyKey.isNotEmpty && companyName.isNotEmpty)
              Text(
                companyKey,
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary.withValues(alpha: 0.85),
                ),
              ),
            const SizedBox(height: 6),
            Text(
              postTitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 10),
            _AddressLine(label: '본사', value: headOffice),
            const SizedBox(height: 6),
            _AddressLine(label: '근무지', value: workplace),
            if (distance is num && distance > 0) ...[
              const SizedBox(height: 6),
              Text(
                '직선 거리 약 ${distance.round()}m',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.orange.shade800,
                ),
              ),
            ],
            const Spacer(),
            FilledButton.tonalIcon(
              onPressed: busy ? null : onApprove,
              icon: busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_circle_outline_rounded, size: 18),
              label: const Text(
                '기재된 근무지 그대로 공고 진행',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
              ),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
                backgroundColor: AppColors.primaryLight.withValues(alpha: 0.35),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddressLine extends StatelessWidget {
  const _AddressLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return RichText(
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: TextStyle(
          fontSize: 11,
          height: 1.35,
          color: AppColors.textSecondary.withValues(alpha: 0.95),
        ),
        children: [
          TextSpan(
            text: '$label · ',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          TextSpan(text: value.isEmpty ? '-' : value),
        ],
      ),
    );
  }
}
