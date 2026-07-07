import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';

/// 로그인·인증 실패 안내 팝업
Future<void> showAuthErrorDialog(
  BuildContext context, {
  required String message,
  String title = '로그인 실패',
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      content: Text(
        message,
        style: TextStyle(
          fontSize: 14,
          height: 1.5,
          color: AppColors.textSecondary.withValues(alpha: 0.95),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('확인'),
        ),
      ],
    ),
  );
}
