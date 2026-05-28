import 'package:flutter/material.dart';
import 'package:map/core/hiring/commission_calculator.dart';
import 'package:map/core/hiring/hiring_application.dart';
import 'package:map/core/hiring/local_hiring_repository.dart';

/// 출근기록·수수료 결제 회피 시 알림·ARS 에스컬레이션 (MVP — 인앱 시뮬레이션)
class AttendanceEscalationService {
  AttendanceEscalationService._();

  static Future<void> runEscalationPass(BuildContext context) async {
    if (!context.mounted) return;
    final repo = await LocalHiringRepository.create();
    final overdue = await repo.escalateOverdueCommissions();
    if (!context.mounted || overdue.isEmpty) return;

    for (final item in overdue) {
      _showEscalation(context, item);
    }
  }

  static void _showEscalation(BuildContext context, HiringApplication item) {
    final level = item.escalationLevel;
    final message = switch (level) {
      1 =>
        '「${item.seekerName}」 출근 확인 후 수수료 결제가 지연되고 있습니다. 근태 탭에서 결제해 주세요.',
      2 =>
        '수수료 미결제 알림 (2회): ${item.seekerName} · ${CommissionFormatter(item.commissionAmountKrw ?? CommissionCalculator.defaultKrw())}',
      _ =>
        '고객센터 ARS 자동 발신: ${item.companyName} 담당자에게 출근기록·수수료 결제 안내 전화를 걸었습니다.',
    };

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: level >= 3 ? 8 : 5),
          backgroundColor: level >= 3 ? const Color(0xFFB71C1C) : null,
          action: level < 3
              ? SnackBarAction(
                  label: '근태',
                  onPressed: () {},
                )
              : null,
        ),
      );
  }
}

class CommissionFormatter {
  CommissionFormatter(this.amount);
  final int amount;

  @override
  String toString() {
    final formatted = amount.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );
    return '$formatted원';
  }
}
