import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/features/commute/domain/entities/shuttle_commute_consent_copy.dart';

/// 노선 공유 + 관제탑 프로세스 참여 동의 (통합)
Future<bool?> showShuttleRouteShareOptInDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: const Text(
        ShuttleCommuteConsentCopy.routeShareTitle,
        style: TextStyle(fontWeight: FontWeight.w800),
      ),
      content: const SingleChildScrollView(
        child: Text(
          ShuttleCommuteConsentCopy.routeShareBody,
          style: TextStyle(fontSize: 14, height: 1.45),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('받지 않음'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('공유 받기 · 참여 동의'),
        ),
      ],
    ),
  );
}

/// 통근 동의 확인 다이얼로그
Future<bool?> showShuttleCommuteConsentDialog(
  BuildContext context, {
  required String title,
  required String body,
  String acceptLabel = '동의',
  String declineLabel = '동의하지 않음',
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      content: SingleChildScrollView(
        child: Text(
          body,
          style: TextStyle(
            fontSize: 14,
            height: 1.45,
            color: AppColors.textSecondary.withValues(alpha: 0.95),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(declineLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(acceptLabel),
        ),
      ],
    ),
  );
}
