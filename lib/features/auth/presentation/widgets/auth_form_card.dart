import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';

/// Auth 폼 — 둥근 화이트 카드 (웹에서는 최대 너비 제한)
class AuthFormCard extends StatelessWidget {
  const AuthFormCard({
    super.key,
    required this.child,
    this.maxWidth = 420,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
          decoration: BoxDecoration(
            color: AppColors.authCard,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
