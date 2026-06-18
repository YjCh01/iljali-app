import 'package:flutter/material.dart';

/// 「급구」 브랜드 마크 — 텍스트 대신 배지·스탬프 형태로 표시
class UrgentHireBadge extends StatelessWidget {
  const UrgentHireBadge({
    super.key,
    this.height = 18,
    this.fontSize = 10.5,
  });

  final double height;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: EdgeInsets.symmetric(horizontal: height * 0.28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF5722), Color(0xFFE53935)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE53935).withValues(alpha: 0.35),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.bolt_rounded,
            size: fontSize + 2,
            color: Colors.white.withValues(alpha: 0.95),
          ),
          SizedBox(width: height * 0.06),
          Text(
            '급구',
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w900,
              height: 1,
              color: Colors.white,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }
}

/// 「급구」 배지 + 알림 보내기 — 버튼·안내 문구용
class UrgentPushActionLabel extends StatelessWidget {
  const UrgentPushActionLabel({
    super.key,
    this.compact = false,
    this.textColor,
    this.fontSize,
  });

  final bool compact;
  final Color? textColor;
  final double? fontSize;

  @override
  Widget build(BuildContext context) {
    final badgeHeight = compact ? 16.0 : 18.0;
    final labelSize = fontSize ?? (compact ? 12.0 : 13.0);
    final color = textColor ?? Colors.white;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        UrgentHireBadge(
          height: badgeHeight,
          fontSize: compact ? 9.5 : 10.5,
        ),
        SizedBox(width: compact ? 4 : 5),
        Text(
          '알림 보내기',
          style: TextStyle(
            fontSize: labelSize,
            fontWeight: FontWeight.w800,
            color: color,
            height: 1.1,
          ),
        ),
      ],
    );
  }
}

/// 급구알림 보내기 안내 스낵바
class UrgentPushHintSnackBarContent extends StatelessWidget {
  const UrgentPushHintSnackBarContent({
    super.key,
    required this.leadText,
  });

  final String leadText;

  @override
  Widget build(BuildContext context) {
    const textStyle = TextStyle(
      color: Colors.white,
      fontSize: 14,
      height: 1.45,
      fontWeight: FontWeight.w500,
    );

    return Text.rich(
      TextSpan(
        style: textStyle,
        children: [
          TextSpan(text: '$leadText\n'),
          const TextSpan(text: '「'),
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: UrgentPushActionLabel(
                compact: true,
                textColor: Colors.white,
                fontSize: 13,
              ),
            ),
          ),
          const TextSpan(text: '」로 PUSH를 보낼 수 있습니다.'),
        ],
      ),
    );
  }
}

/// 알림핀 추가 후 안내
class UrgentPushAddedSnackBarContent extends StatelessWidget {
  const UrgentPushAddedSnackBarContent({super.key});

  @override
  Widget build(BuildContext context) {
    return const UrgentPushHintSnackBarContent(
      leadText: '일자리 알림핀이 추가되었습니다.',
    );
  }
}
