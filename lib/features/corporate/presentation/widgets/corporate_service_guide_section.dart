import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/features/corporate/presentation/widgets/job_post_import_labels.dart';

/// 더보기 탭 — AI·숏폼 톤 서비스 안내 (릴스형 가로 스와이프)
class CorporateServiceGuideSection extends StatefulWidget {
  const CorporateServiceGuideSection({super.key});

  @override
  State<CorporateServiceGuideSection> createState() =>
      _CorporateServiceGuideSectionState();
}

class _CorporateServiceGuideSectionState
    extends State<CorporateServiceGuideSection> {
  static const _clipHeight = 300.0;
  static const _clipGap = 12.0;

  final _scrollController = ScrollController();
  int _page = 0;
  bool _isSnapping = false;

  static List<_ShortClipData> get _clips {
    return [
      _ShortClipData(
        hook: '공고 등록은 무료입니다.',
        bodyLines: const [
          '등록 시 지도 위 근무지에 공고가 표시됩니다.',
          '근무지 외 다른 곳에 공고를 알리려면',
          '일자리 알림핀 ▽',
          '통근버스 노선표를 지도에 표시하려면',
          '정류장 표시핀 ▼',
          '알림핀과 표시핀을 활성화하고',
          '추가로 PUSH 메시지를 보낼 수도 있습니다!',
        ],
        tags: ['#일자리알림핀', '#정류장표시핀', '#PUSH이용권'],
        durationLabel: '0:14',
        gradient: const [Color(0xFF4A148C), Color(0xFF8E24AA)],
      ),
    ];
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_syncPageFromScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_syncPageFromScroll)
      ..dispose();
    super.dispose();
  }

  double _clipWidth(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (_clips.length <= 1) return width - 40;
    return (width - 40) * 0.76;
  }

  double _pageStride(BuildContext context) => _clipWidth(context) + _clipGap;

  void _syncPageFromScroll() {
    if (!_scrollController.hasClients) return;
    final stride = _pageStride(context);
    if (stride <= 0) return;
    final next = (_scrollController.offset / stride).round().clamp(
          0,
          _clips.length - 1,
        );
    if (next != _page) setState(() => _page = next);
  }

  Future<void> _snapToNearestPage() async {
    if (!_scrollController.hasClients || _isSnapping) return;
    final stride = _pageStride(context);
    if (stride <= 0) return;
    final next = (_scrollController.offset / stride).round().clamp(
          0,
          _clips.length - 1,
        );
    final target = next * stride;
    if ((_scrollController.offset - target).abs() < 0.5) {
      if (mounted && next != _page) setState(() => _page = next);
      return;
    }
    _isSnapping = true;
    try {
      await _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
      if (mounted && next != _page) setState(() => _page = next);
    } finally {
      _isSnapping = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final clips = _clips;
    final clipWidth = _clipWidth(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 12),
          child: Row(
            children: [
              const AiSparkleMark(size: 16, badge: true),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  '60초로 보는 일자리',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (clips.length > 1)
                Text(
                  '${_page + 1}/${clips.length}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary.withValues(alpha: 0.85),
                  ),
                ),
            ],
          ),
        ),
        if (clips.length > 1) ...[
          _StoryProgressBar(
            count: clips.length,
            activeIndex: _page,
          ),
          const SizedBox(height: 12),
        ],
        NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification.metrics.axis != Axis.horizontal) return false;
            if (notification is ScrollEndNotification) {
              _snapToNearestPage();
            }
            return true;
          },
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(
              dragDevices: {
                PointerDeviceKind.touch,
                PointerDeviceKind.mouse,
                PointerDeviceKind.stylus,
                PointerDeviceKind.trackpad,
              },
            ),
            child: SizedBox(
              height: _clipHeight,
              child: ListView.separated(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                clipBehavior: Clip.none,
                itemCount: clips.length,
                separatorBuilder: (_, __) => const SizedBox(width: _clipGap),
                itemBuilder: (context, index) {
                  return SizedBox(
                    width: clipWidth,
                    child: _ShortClipCard(data: clips[index]),
                  );
                },
              ),
            ),
          ),
        ),
        if (clips.length > 1)
          Center(
            child: Text(
              '← 스와이프 →',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary.withValues(alpha: 0.75),
              ),
            ),
          ),
      ],
    );
  }
}

class _StoryProgressBar extends StatelessWidget {
  const _StoryProgressBar({
    required this.count,
    required this.activeIndex,
  });

  final int count;
  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(count, (index) {
        final active = index == activeIndex;
        final past = index < activeIndex;
        return Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            margin: EdgeInsets.only(right: index < count - 1 ? 4 : 0),
            height: 3,
            decoration: BoxDecoration(
              color: active
                  ? AppColors.primary
                  : past
                      ? AppColors.primary.withValues(alpha: 0.45)
                      : AppColors.searchBarBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }
}

class _ShortClipData {
  const _ShortClipData({
    required this.hook,
    required this.tags,
    required this.durationLabel,
    required this.gradient,
    this.subline,
    this.bodyLines,
    this.legacyLine,
    this.iljariLine,
    this.showAi = false,
    this.topicBadge,
    this.topicIcon,
  });

  final String hook;
  final String? subline;
  final List<String>? bodyLines;
  final String? legacyLine;
  final String? iljariLine;
  final List<String> tags;
  final String durationLabel;
  final List<Color> gradient;
  final bool showAi;
  final String? topicBadge;
  final IconData? topicIcon;
}

class _ShortClipCard extends StatelessWidget {
  const _ShortClipCard({required this.data});

  final _ShortClipData data;

  static const _titleBlockHeight = 50.0;
  static const _titleBodyGap = 10.0;
  static const _chromeBottomGap = 14.0;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: data.gradient,
              ),
            ),
          ),
          Positioned(
            top: -28,
            right: -18,
            child: Icon(
              Icons.play_circle_filled_rounded,
              size: 120,
              color: Colors.white.withValues(alpha: 0.06),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.28),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.play_arrow_rounded,
                            size: 14,
                            color: Colors.white.withValues(alpha: 0.95),
                          ),
                          Text(
                            data.durationLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white.withValues(alpha: 0.95),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (data.showAi) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.auto_awesome_rounded,
                              size: 11,
                              color: Colors.white.withValues(alpha: 0.95),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              'AI',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Colors.white.withValues(alpha: 0.95),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (data.topicBadge != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (data.topicIcon != null) ...[
                              Icon(
                                data.topicIcon,
                                size: 11,
                                color: Colors.white.withValues(alpha: 0.95),
                              ),
                              const SizedBox(width: 3),
                            ],
                            Text(
                              data.topicBadge!,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Colors.white.withValues(alpha: 0.95),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const Spacer(),
                    Icon(
                      Icons.volume_off_rounded,
                      size: 16,
                      color: Colors.white.withValues(alpha: 0.55),
                    ),
                  ],
                ),
                const SizedBox(height: _chromeBottomGap),
                SizedBox(
                  height: _titleBlockHeight,
                  width: double.infinity,
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Text(
                      data.hook,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 20,
                        height: 1.22,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: _titleBodyGap),
                Expanded(
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: _buildBody(),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: data.tags
                      .map(
                        (tag) => Text(
                          tag,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white.withValues(alpha: 0.72),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (data.bodyLines != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < data.bodyLines!.length; i++) ...[
            if (i > 0) const SizedBox(height: 3),
            Text(
              data.bodyLines![i],
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                height: 1.32,
                fontWeight: _bodyLineEmphasis(data.bodyLines![i])
                    ? FontWeight.w800
                    : FontWeight.w600,
                color: Colors.white.withValues(
                  alpha: _bodyLineEmphasis(data.bodyLines![i]) ? 0.98 : 0.9,
                ),
              ),
            ),
          ],
        ],
      );
    }
    if (data.subline != null) {
      return Text(
        data.subline!,
        maxLines: 8,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11.5,
          height: 1.4,
          fontWeight: FontWeight.w600,
          color: Colors.white.withValues(alpha: 0.9),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _ContrastLine(
          label: '기존',
          text: data.legacyLine ?? '',
          dimmed: true,
        ),
        const SizedBox(height: 6),
        _ContrastLine(
          label: '일자리',
          text: data.iljariLine ?? '',
          dimmed: false,
        ),
      ],
    );
  }
}

bool _bodyLineEmphasis(String line) {
  return line.contains('알림핀') ||
      line.contains('표시핀') ||
      line.contains('PUSH');
}

class _ContrastLine extends StatelessWidget {
  const _ContrastLine({
    required this.label,
    required this.text,
    required this.dimmed,
  });

  final String label;
  final String text;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 2),
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: dimmed
                ? Colors.black.withValues(alpha: 0.22)
                : Colors.white.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: Colors.white.withValues(alpha: dimmed ? 0.75 : 0.98),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5,
              height: 1.35,
              fontWeight: dimmed ? FontWeight.w500 : FontWeight.w700,
              color: Colors.white.withValues(alpha: dimmed ? 0.72 : 0.95),
            ),
          ),
        ),
      ],
    );
  }
}
