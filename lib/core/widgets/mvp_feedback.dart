import 'package:flutter/material.dart';

/// MVP 기능 안내 스낵바
void showMvpInfoSnackBar(
  BuildContext context,
  String feature, {
  String? hint,
}) {
  final message = hint != null
      ? '$feature — $hint'
      : '$feature 기능은 준비 중입니다. 지금은 지도·공고·지원을 이용해 주세요.';
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
}
