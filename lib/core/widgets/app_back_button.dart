import 'package:flutter/material.dart';

/// 직전 페이지로만 이동하는 뒤로가기 (로그인 게이트웨이로 점프 방지)
class AppBackButton extends StatelessWidget {
  const AppBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.canPop(context);
    if (!canPop) return const SizedBox(width: 48);

    return IconButton(
      tooltip: '뒤로',
      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
      onPressed: () => Navigator.of(context).pop(),
    );
  }
}

/// 홈/루트 화면 — 뒤로가기 숨김
class AppRootLeading extends StatelessWidget {
  const AppRootLeading({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox(width: 48);
}
