import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';

/// 외부 공고 가져오기 — 공통 문구·AI 아이콘
abstract final class JobPostImportCopy {
  static const ctaLabel = '다른 곳에 올린 공고 쉽게 가져오기';
  static const pageTitle = '공고 가져오기';
  static const registerFromImport = '가져온 내용으로 등록하기';
}

/// AI 기능 표시용 스파클 아이콘 (텍스트 "AI" 대신 사용)
class AiSparkleMark extends StatelessWidget {
  const AiSparkleMark({
    super.key,
    this.size = 18,
    this.color,
    this.badge = false,
  });

  final double size;
  final Color? color;
  final bool badge;

  @override
  Widget build(BuildContext context) {
    final tone = color ?? AppColors.primary;
    final icon = Icon(Icons.auto_awesome_rounded, size: size, color: tone);
    if (!badge) return icon;
    return Container(
      padding: EdgeInsets.all(size * 0.22),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: icon,
    );
  }
}

/// 배너·버튼 라벨 — 아이콘 + 가져오기 문구
class JobPostImportTitle extends StatelessWidget {
  const JobPostImportTitle({
    super.key,
    this.style,
    this.showBadge = true,
  });

  final TextStyle? style;
  final bool showBadge;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.max,
      children: [
        if (showBadge) ...[
          AiSparkleMark(size: 16, badge: true),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            JobPostImportCopy.ctaLabel,
            style: style ??
                const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
          ),
        ),
      ],
    );
  }
}
