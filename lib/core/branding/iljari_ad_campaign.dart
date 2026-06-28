import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';

/// 일자리 브랜드 광고 카피 — 앱·웹 공통
abstract final class IljariAdCampaign {
  static const lines = <String>[
    '내 근처에서 찾고,',
    '우리집 앞에서 타고.',
    '내 주변 일자리!',
  ];

  static const headline = '내 주변 일자리!';

  static String get body => lines.join('\n');
}

enum IljariAdCampaignStyle {
  /// 로그인 게이트웨이·로딩 — 밝은 글자
  onDark,

  /// 폼 카드·더보기 리스트 — 기본 텍스트
  onLight,

  /// 더보기 상단 그라데이션 배너
  bannerCard,
}

/// 3줄 광고 카피 — 로그인·로딩·더보기
class IljariAdCampaignCopy extends StatelessWidget {
  const IljariAdCampaignCopy({
    super.key,
    this.style = IljariAdCampaignStyle.onDark,
    this.textAlign = TextAlign.center,
  });

  final IljariAdCampaignStyle style;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    if (style == IljariAdCampaignStyle.bannerCard) {
      return const IljariAdCampaignBanner();
    }

    final leadColor = switch (style) {
      IljariAdCampaignStyle.onDark =>
        Colors.white.withValues(alpha: 0.82),
      IljariAdCampaignStyle.onLight =>
        AppColors.textSecondary.withValues(alpha: 0.95),
      IljariAdCampaignStyle.bannerCard => Colors.white,
    };
    final headlineColor = switch (style) {
      IljariAdCampaignStyle.onDark => Colors.white,
      IljariAdCampaignStyle.onLight => AppColors.primary,
      IljariAdCampaignStyle.bannerCard => Colors.white,
    };

    return Column(
      crossAxisAlignment: switch (textAlign) {
        TextAlign.center => CrossAxisAlignment.center,
        TextAlign.start => CrossAxisAlignment.start,
        TextAlign.end => CrossAxisAlignment.end,
        _ => CrossAxisAlignment.center,
      },
      children: [
        Text(
          IljariAdCampaign.lines[0],
          textAlign: textAlign,
          style: TextStyle(
            fontSize: style == IljariAdCampaignStyle.onLight ? 14 : 15,
            height: 1.45,
            fontWeight: FontWeight.w600,
            color: leadColor,
          ),
        ),
        Text(
          IljariAdCampaign.lines[1],
          textAlign: textAlign,
          style: TextStyle(
            fontSize: style == IljariAdCampaignStyle.onLight ? 14 : 15,
            height: 1.45,
            fontWeight: FontWeight.w600,
            color: leadColor,
          ),
        ),
        Text(
          IljariAdCampaign.lines[2],
          textAlign: textAlign,
          style: TextStyle(
            fontSize: style == IljariAdCampaignStyle.onLight ? 17 : 18,
            height: 1.35,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.3,
            color: headlineColor,
          ),
        ),
      ],
    );
  }
}

/// 더보기 탭 상단 광고 배너
class IljariAdCampaignBanner extends StatelessWidget {
  const IljariAdCampaignBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Stack(
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF4A148C),
                  Color(0xFF6A1B9A),
                  Color(0xFF00838F),
                ],
              ),
            ),
            child: SizedBox(width: double.infinity, height: 132),
          ),
          Positioned(
            right: -12,
            top: -8,
            child: Icon(
              Icons.near_me_rounded,
              size: 88,
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          Positioned(
            left: -8,
            bottom: -12,
            child: Icon(
              Icons.directions_bus_rounded,
              size: 72,
              color: Colors.white.withValues(alpha: 0.07),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '일자리',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.white.withValues(alpha: 0.95),
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const IljariAdCampaignCopy(
                  style: IljariAdCampaignStyle.onDark,
                  textAlign: TextAlign.start,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
