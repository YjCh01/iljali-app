import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/features/corporate/domain/entities/push_notification_settings.dart';
import 'package:map/features/corporate/domain/entities/push_package_catalog.dart';
import 'package:map/features/job_seeker/data/repositories/seeker_push_inbox_repository.dart';
import 'package:map/features/job_seeker/domain/entities/seeker_push_notification.dart';
import 'package:map/features/corporate/domain/utils/push_reach_estimator.dart';

/// 공고 등록 완료 후 푸시 알림 전송 진행·완료 화면
class CorporateJobPostPushDispatchPage extends StatefulWidget {
  const CorporateJobPostPushDispatchPage({
    super.key,
    required this.args,
  });

  final PushDispatchArgs args;

  @override
  State<CorporateJobPostPushDispatchPage> createState() =>
      _CorporateJobPostPushDispatchPageState();
}

class _CorporateJobPostPushDispatchPageState
    extends State<CorporateJobPostPushDispatchPage>
    with SingleTickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 2800);

  late final AnimationController _controller;
  late final int _targetReach;
  bool _completed = false;
  int _displayReach = 0;

  @override
  void initState() {
    super.initState();
    _targetReach = PushReachEstimator.estimateRecruitmentRights(
      widget.args.recruitmentSlotCount,
      seed: widget.args.reachSeed,
    );
    _controller = AnimationController(vsync: this, duration: _duration)
      ..addListener(_onProgress)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(() {
            _completed = true;
            _displayReach = _targetReach;
          });
          _recordSeekerPushDelivery();
        }
      });
    _controller.forward();
  }

  void _onProgress() {
    final progress = Curves.easeOutCubic.transform(_controller.value);
    setState(() {
      _displayReach = (_targetReach * progress).round();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _confirm() {
    Navigator.of(context).pop(true);
  }

  Future<void> _recordSeekerPushDelivery() async {
    final title = widget.args.jobTitle;
    if (title == null || title.isEmpty) return;
    final repo = await SeekerPushInboxRepository.create();
    final id = widget.args.jobPostId ??
        'push_${DateTime.now().millisecondsSinceEpoch}';
    await repo.recordPush(
      SeekerPushNotification(
        id: id,
        title: title,
        body:
            '${widget.args.companyName ?? '채용 공고'} · ${PushPackageCatalog.pushRadiusLabel} 반경 모집 알림',
        companyName: widget.args.companyName ?? '채용 기업',
        jobPostId: widget.args.jobPostId,
        receivedAt: DateTime.now(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _completed,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              children: [
                const Spacer(flex: 2),
                Icon(
                  _completed
                      ? Icons.notifications_active_rounded
                      : Icons.send_rounded,
                  size: 56,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  _completed
                      ? '$_targetReach명에게 실시간 공고 알람이\n전송되었습니다'
                      : '푸시 알림을 보내는 중입니다',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    height: 1.4,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                if (!_completed)
                  Text(
                    '$_displayReach명에게 푸시알림 도달 중...',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary.withValues(alpha: 0.95),
                    ),
                  ),
                if (!_completed)
                  Text(
                    '전송 중에는 잠시 기다려 주세요.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary.withValues(alpha: 0.8),
                    ),
                  ),
                if (!_completed) ...[
                  const SizedBox(height: 28),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: _controller.value,
                      minHeight: 8,
                      backgroundColor:
                          AppColors.primaryLight.withValues(alpha: 0.25),
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '모집지역 ${widget.args.recruitmentSlotCount}곳 · '
                    '모집권당 ${PushReachEstimator.minReachPerSlot}~'
                    '${PushReachEstimator.maxReachPerSlot}명 · '
                    '${ExposurePointLabels.radiusUi(widget.args.radiusTier)} · '
                    '구직자 매칭 중',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary.withValues(alpha: 0.85),
                    ),
                  ),
                ],
                const Spacer(flex: 3),
                if (_completed)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _confirm,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        '확인',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
