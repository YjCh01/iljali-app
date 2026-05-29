import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/hiring/seeker_attendance_gate_service.dart';
import 'package:map/features/job_seeker/presentation/pages/tabs/individual_work_tab.dart';

/// 미출근 잠금 시 안내 다이얼로그
Future<bool> showSeekerAttendanceLockDialog(
  BuildContext context,
  SeekerAttendanceGateResult gate,
) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: const Text('출근 확인 필요'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              gate.message ??
                  '미확인 출근 ${gate.overdueCount}건 — 출근 체크 또는 분쟁 신고 후 이용할 수 있습니다.',
            ),
            const SizedBox(height: 12),
            const Text(
              '근무했으면 GPS 출근 체크를, 근무하지 않았다면 분쟁 신고를 해 주세요.',
              style: TextStyle(fontSize: 12, height: 1.4),
            ),
            if (gate.overdueShifts.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...gate.overdueShifts.map(
                (shift) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '· ${shift.companyName} · ${shift.postTitle}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('닫기'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop(true);
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const _SeekerWorkTabRoute(),
              ),
            );
          },
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          child: const Text('출근 체크하러 가기'),
        ),
      ],
    ),
  ).then((value) => value ?? false);
}

/// 근무 탭으로 이동용 래퍼 (홈 셸 밖에서도 열 수 있게)
class _SeekerWorkTabRoute extends StatelessWidget {
  const _SeekerWorkTabRoute();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('나의 근무'),
      ),
      body: const IndividualWorkTab(isActive: true),
    );
  }
}

/// 지원·채팅 전 구직자 출근 게이트
Future<bool> ensureSeekerAttendanceAccess(
  BuildContext context,
  String seekerEmail,
) async {
  final gate = await SeekerAttendanceGateService().evaluate(seekerEmail);
  if (!gate.isLocked) return true;
  if (!context.mounted) return false;
  await showSeekerAttendanceLockDialog(context, gate);
  return false;
}
