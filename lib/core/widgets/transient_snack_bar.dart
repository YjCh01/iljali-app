import 'package:flutter/material.dart';

/// 짧게 보여 주고 사라지는 안내 스낵바 (액션 버튼이 있어도 자동 dismiss)
const kTransientSnackBarDuration = Duration(seconds: 3);

void clearSnackBarQueue(BuildContext context) {
  ScaffoldMessenger.of(context).clearSnackBars();
}

void showTransientSnackBar(
  BuildContext context,
  String message, {
  SnackBarAction? action,
  Duration duration = kTransientSnackBarDuration,
}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: duration,
        action: action,
      ),
    );
}

void showDarkTransientSnackBar(
  BuildContext context,
  String message, {
  Duration duration = kTransientSnackBarDuration,
}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF1A1A1A),
        behavior: SnackBarBehavior.floating,
        duration: duration,
      ),
    );
}
