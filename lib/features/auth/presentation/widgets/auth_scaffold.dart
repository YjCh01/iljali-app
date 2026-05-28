import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';

/// Auth 화면 공통 — 짙은 퍼플 배경 + 상단 타이틀
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.body,
    this.bottom,
    this.leading,
  });

  final Widget body;
  final Widget? bottom;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
        backgroundColor: AppColors.authBackground,
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 24, 0),
                child: Row(
                  children: [
                    if (leading != null) leading!,
                    const Spacer(),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '일자리',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 28),
              Expanded(
                child: SingleChildScrollView(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: body,
                ),
              ),
              if (bottom != null) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: bottom!,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
