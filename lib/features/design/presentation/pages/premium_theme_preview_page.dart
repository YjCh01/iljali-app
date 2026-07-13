import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:map/core/theme/premium_theme.dart';

/// Premium 테마 MVP — 4화면 목업 (프로덕션 테마 비침범).
///
/// Debug: `/dev/premium-theme-preview` 또는 로그인 QC 패널 링크.
class PremiumThemePreviewPage extends StatefulWidget {
  const PremiumThemePreviewPage({super.key});

  @override
  State<PremiumThemePreviewPage> createState() =>
      _PremiumThemePreviewPageState();
}

class _PremiumThemePreviewPageState extends State<PremiumThemePreviewPage> {
  int _tab = 0;
  bool _dark = false;

  @override
  Widget build(BuildContext context) {
    final brightness = _dark ? Brightness.dark : Brightness.light;
    return Theme(
      data: PremiumTheme.forBrightness(brightness),
      child: Material(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _PreviewHeader(
                dark: _dark,
                onToggleDark: () => setState(() => _dark = !_dark),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: _ScreenPicker(
                  index: _tab,
                  onChanged: (i) => setState(() => _tab = i),
                ),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: PremiumTheme.duration,
                  switchInCurve: PremiumTheme.curve,
                  switchOutCurve: PremiumTheme.curve,
                  child: switch (_tab) {
                    0 => const _PremiumHomePreview(key: ValueKey('home')),
                    1 => const _PremiumMapPreview(key: ValueKey('map')),
                    2 => const _PremiumJobDetailPreview(key: ValueKey('job')),
                    3 => const _PremiumProfilePreview(key: ValueKey('profile')),
                    _ => const SizedBox.shrink(),
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewHeader extends StatelessWidget {
  const _PreviewHeader({required this.dark, required this.onToggleDark});

  final bool dark;
  final VoidCallback onToggleDark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Premium Theme MVP', style: theme.textTheme.titleLarge),
                Text(
                  'SME 구독 · 전문 기능직 · 미리보기 전용',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: dark ? '라이트 모드' : '다크 모드 (OLED)',
            onPressed: onToggleDark,
            icon: Icon(dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
          ),
          if (Navigator.of(context).canPop())
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close),
            ),
        ],
      ),
    );
  }
}

class _ScreenPicker extends StatelessWidget {
  const _ScreenPicker({required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  static const _labels = ['Home', 'Map', 'Job', 'Profile'];

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final border = dark ? PremiumColors.borderDark : PremiumColors.borderLight;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(_labels.length, (i) {
          final selected = i == index;
          return Padding(
            padding: EdgeInsets.only(right: i == _labels.length - 1 ? 0 : 8),
            child: GestureDetector(
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: PremiumTheme.duration,
                curve: PremiumTheme.curve,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: selected
                      ? PremiumColors.primary.withValues(alpha: dark ? 0.22 : 0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: selected ? PremiumColors.primary : border,
                    width: 1,
                  ),
                ),
                child: Text(
                  _labels[i],
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? PremiumColors.primary
                        : Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ─── Home ───────────────────────────────────────────────────────────────────

class _PremiumHomePreview extends StatelessWidget {
  const _PremiumHomePreview({super.key});

  static const _heroTag = 'premium-job-card-0';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final border = dark ? PremiumColors.borderDark : PremiumColors.borderLight;

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      children: [
        Text('오늘의\n프리미엄 일자리', style: theme.textTheme.displayLarge),
        const SizedBox(height: 8),
        Text(
          '전문 기능직 · SME 파트너 공고',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 32),
        Text('추천', style: theme.textTheme.titleMedium),
        const SizedBox(height: 16),
        _BorderCard(
          border: border,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('용접 · CNC · 전기', style: theme.textTheme.bodyMedium),
              const SizedBox(height: 6),
              Text('삼성전자 협력사 A', style: theme.textTheme.titleMedium),
              const SizedBox(height: 20),
              Row(
                children: [
                  Text(
                    '월 320',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontFamily: 'monospace',
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    '만원',
                    style: theme.textTheme.bodyMedium?.copyWith(fontSize: 15),
                  ),
                  const Spacer(),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: PremiumColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text('700m', style: theme.textTheme.bodyMedium),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Hero(
          tag: _heroTag,
          child: Material(
            color: Colors.transparent,
            child: _BorderCard(
              border: border,
              onTap: () => _openJobDetail(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('바리스타 · 로스팅', style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 6),
                  Text('스페셜티 카페 B', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Text(
                        '시급 13,500',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontFamily: 'monospace',
                          letterSpacing: -0.5,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.arrow_forward,
                        size: 18,
                        color: theme.textTheme.bodyMedium?.color,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '탭 → Hero 300ms 상세 전환',
                    style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 32),
        Text('내 주변', style: theme.textTheme.titleMedium),
        const SizedBox(height: 16),
        _BorderCard(
          border: border,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('셔틀 12분', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text('강남 → 판교 Tech Park', style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
              const Icon(Icons.directions_bus_outlined, color: PremiumColors.primary),
            ],
          ),
        ),
      ],
    );
  }

  void _openJobDetail(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: PremiumTheme.duration,
        reverseTransitionDuration: PremiumTheme.duration,
        pageBuilder: (_, __, ___) => Theme(
          data: Theme.of(context),
          child: _PremiumJobDetailPreview(heroTag: _heroTag),
        ),
        transitionsBuilder: (_, animation, __, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: PremiumTheme.curve,
          );
          return FadeTransition(opacity: curved, child: child);
        },
      ),
    );
  }
}

// ─── Map ────────────────────────────────────────────────────────────────────

class _PremiumMapPreview extends StatelessWidget {
  const _PremiumMapPreview({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      fit: StackFit.expand,
      children: [
        // 지도 placeholder
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: dark
                  ? [const Color(0xFF1E1B4B), PremiumColors.backgroundDark]
                  : [const Color(0xFFEEF2FF), const Color(0xFFFAFAFA)],
            ),
          ),
          child: CustomPaint(painter: _MapGridPainter(dark: dark)),
        ),
        // 보라 핀
        ...const [
          (0.28, 0.32),
          (0.62, 0.28),
          (0.45, 0.48),
          (0.72, 0.55),
        ].map((p) => Positioned(
              left: MediaQuery.sizeOf(context).width * p.$1 - 14,
              top: MediaQuery.sizeOf(context).height * 0.35 * p.$2 + 40,
              child: _MapPin(selected: p.$1 == 0.45),
            )),
        Positioned(
          left: 20,
          right: 20,
          top: 12,
          child: _GlassCapsule(
            child: Row(
              children: [
                const Icon(Icons.search, size: 20, color: PremiumColors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '근무지 · 역 · 노선 검색',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: _GlassBottomSheet(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: (dark ? Colors.white : Colors.black)
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  '스페셜티 카페 B',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text('바리스타 · 주 5일 · 시급 13,500', style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Text(
                      '13,500',
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(
                            fontSize: 28,
                            fontFamily: 'monospace',
                            letterSpacing: -1,
                          ),
                    ),
                    Text('원/시', style: Theme.of(context).textTheme.bodyMedium),
                    const Spacer(),
                    TextButton(
                      onPressed: () {},
                      child: const Text('상세'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MapPin extends StatelessWidget {
  const _MapPin({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: selected ? 36 : 28,
          height: selected ? 36 : 28,
          decoration: BoxDecoration(
            color: PremiumColors.primary,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: PremiumColors.primary.withValues(alpha: 0.35),
                blurRadius: selected ? 16 : 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            Icons.work_outline,
            size: selected ? 18 : 14,
            color: Colors.white,
          ),
        ),
        if (selected)
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              color: PremiumColors.primary.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
          ),
      ],
    );
  }
}

class _MapGridPainter extends CustomPainter {
  _MapGridPainter({required this.dark});

  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = (dark ? Colors.white : PremiumColors.primary)
          .withValues(alpha: 0.06)
      ..strokeWidth = 1;
    const step = 48.0;
    for (var x = 0.0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _MapGridPainter oldDelegate) =>
      oldDelegate.dark != dark;
}

// ─── Job detail ─────────────────────────────────────────────────────────────

class _PremiumJobDetailPreview extends StatelessWidget {
  const _PremiumJobDetailPreview({super.key, this.heroTag});

  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final border = dark ? PremiumColors.borderDark : PremiumColors.borderLight;

    final body = ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 120),
      children: [
        if (heroTag == null) ...[
          Text('Job Detail', style: theme.textTheme.bodyMedium),
          const SizedBox(height: 8),
        ],
        Text('바리스타 · 로스팅', style: theme.textTheme.bodyMedium),
        const SizedBox(height: 8),
        Text('스페셜티 카페 B', style: theme.textTheme.displayLarge?.copyWith(fontSize: 28)),
        const SizedBox(height: 32),
        Text('급여', style: theme.textTheme.bodyMedium),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              '13,500',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 48,
                fontWeight: FontWeight.w700,
                letterSpacing: -2,
                height: 1,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: 6),
            Text('원/시', style: theme.textTheme.titleMedium),
          ],
        ),
        const SizedBox(height: 32),
        _BorderCard(
          border: border,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('근무 조건', style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              Text('주 5일 · 09:00–18:00 · 판교', style: theme.textTheme.bodyLarge),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _BorderCard(
          border: border,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('우대', style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              Text('SCA · 로스팅 2년+ · 영어 가능', style: theme.textTheme.bodyLarge),
            ],
          ),
        ),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        leading: heroTag != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
      ),
      body: heroTag != null
          ? Hero(
              tag: heroTag!,
              child: Material(color: Colors.transparent, child: body),
            )
          : body,
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: SizedBox(
          height: 56,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: PremiumColors.accent,
              foregroundColor: PremiumColors.backgroundDark,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {},
            child: const Text(
              '지원하기',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Profile ────────────────────────────────────────────────────────────────

class _PremiumProfilePreview extends StatelessWidget {
  const _PremiumProfilePreview({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final border = dark ? PremiumColors.borderDark : PremiumColors.borderLight;

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      children: [
        Text('김민수', style: theme.textTheme.displayLarge?.copyWith(fontSize: 32)),
        const SizedBox(height: 6),
        Text('용접 · CNC · 7년', style: theme.textTheme.bodyLarge),
        const SizedBox(height: 8),
        Text('seeker@example.com', style: theme.textTheme.bodyMedium),
        const SizedBox(height: 40),
        Row(
          children: [
            Expanded(
              child: _StatBlock(
                value: '24',
                label: '완료',
                border: border,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatBlock(
                value: '98%',
                label: '출근율',
                border: border,
              ),
            ),
          ],
        ),
        const SizedBox(height: 40),
        Text('경력', style: theme.textTheme.titleMedium),
        const SizedBox(height: 16),
        _TextRow(title: '삼성전자 협력사', subtitle: '용접 · 2021–2024'),
        _TextRow(title: '현대중공업', subtitle: 'CNC · 2018–2021'),
        const SizedBox(height: 32),
        Text('자격', style: theme.textTheme.titleMedium),
        const SizedBox(height: 16),
        _TextRow(title: '용접기능사', subtitle: '2020 · 한국산업인력공단'),
        const SizedBox(height: 32),
        _BorderCard(
          border: border,
          child: Row(
            children: [
              Expanded(
                child: Text('Premium 구독', style: theme.textTheme.titleMedium),
              ),
              Text(
                '활성',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: PremiumColors.primary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatBlock extends StatelessWidget {
  const _StatBlock({
    required this.value,
    required this.label,
    required this.border,
  });

  final String value;
  final String label;
  final Color border;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        border: Border.all(color: border, width: 1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 44,
              fontWeight: FontWeight.w700,
              letterSpacing: -2,
              height: 1,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(label, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _TextRow extends StatelessWidget {
  const _TextRow({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(subtitle, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

// ─── Shared ─────────────────────────────────────────────────────────────────

class _BorderCard extends StatelessWidget {
  const _BorderCard({
    required this.border,
    required this.child,
    this.onTap,
  });

  final Color border;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? PremiumColors.surfaceDark
            : PremiumColors.surfaceLight,
        border: Border.all(color: border, width: 1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
    if (onTap == null) return card;
    return GestureDetector(onTap: onTap, child: card);
  }
}

class _GlassBottomSheet extends StatelessWidget {
  const _GlassBottomSheet({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
          decoration: BoxDecoration(
            color: (dark ? PremiumColors.surfaceDark : Colors.white)
                .withValues(alpha: dark ? 0.82 : 0.72),
            border: Border(
              top: BorderSide(
                color: (dark ? Colors.white : Colors.black).withValues(alpha: 0.08),
              ),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _GlassCapsule extends StatelessWidget {
  const _GlassCapsule({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: (dark ? PremiumColors.surfaceDark : Colors.white)
                .withValues(alpha: 0.75),
            border: Border.all(
              color: (dark ? Colors.white : Colors.black).withValues(alpha: 0.06),
            ),
            borderRadius: BorderRadius.circular(999),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Debug 라우트 게이트
bool get premiumThemePreviewEnabled => kDebugMode;
