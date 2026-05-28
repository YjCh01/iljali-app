import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';

class CorporateJobPostSpeedDial extends StatefulWidget {
  const CorporateJobPostSpeedDial({
    super.key,
    required this.onCreate,
    required this.onEdit,
  });

  final VoidCallback onCreate;
  final VoidCallback onEdit;

  @override
  State<CorporateJobPostSpeedDial> createState() =>
      _CorporateJobPostSpeedDialState();
}

class _CorporateJobPostSpeedDialState extends State<CorporateJobPostSpeedDial>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late final AnimationController _controller;
  late final Animation<double> _expandAnimation;

  static const _fabSize = 56.0;
  static const _edgeInset = 16.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _expandAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    if (_expanded) {
      _controller.reverse().then((_) {
        if (mounted) setState(() => _expanded = false);
      });
    } else {
      setState(() => _expanded = true);
      _controller.forward();
    }
  }

  void _close() {
    if (!_expanded) return;
    _controller.reverse().then((_) {
      if (mounted) setState(() => _expanded = false);
    });
  }

  void _handleAction(VoidCallback action) {
    _close();
    action();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (_expanded)
          Positioned.fill(
            child: GestureDetector(
              onTap: _close,
              behavior: HitTestBehavior.opaque,
              child: Container(color: Colors.black.withValues(alpha: 0.08)),
            ),
          ),
        Positioned(
          right: _edgeInset,
          bottom: _edgeInset,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (_expanded)
                SizeTransition(
                  sizeFactor: _expandAnimation,
                  axisAlignment: 1,
                  child: FadeTransition(
                    opacity: _expandAnimation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.15),
                        end: Offset.zero,
                      ).animate(_expandAnimation),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Material(
                          color: AppColors.surface,
                          elevation: 6,
                          shadowColor: Colors.black26,
                          borderRadius: BorderRadius.circular(16),
                          clipBehavior: Clip.antiAlias,
                          child: IntrinsicWidth(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _SpeedDialMenuItem(
                                  icon: Icons.post_add_outlined,
                                  label: '공고 등록',
                                  onTap: () => _handleAction(widget.onCreate),
                                ),
                                Divider(
                                  height: 1,
                                  color: AppColors.searchBarBorder
                                      .withValues(alpha: 0.8),
                                ),
                                _SpeedDialMenuItem(
                                  icon: Icons.edit_outlined,
                                  label: '공고 수정',
                                  onTap: () => _handleAction(widget.onEdit),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              _MainFab(
                expanded: _expanded,
                size: _fabSize,
                onTap: _toggle,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SpeedDialMenuItem extends StatelessWidget {
  const _SpeedDialMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: AppColors.primary),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MainFab extends StatelessWidget {
  const _MainFab({
    required this.expanded,
    required this.size,
    required this.onTap,
  });

  final bool expanded;
  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary,
      shape: const CircleBorder(),
      elevation: 4,
      shadowColor: AppColors.primary.withValues(alpha: 0.35),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: size,
          height: size,
          child: AnimatedRotation(
            turns: expanded ? 0.125 : 0,
            duration: const Duration(milliseconds: 220),
            child: Icon(
              expanded ? Icons.close_rounded : Icons.add_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
        ),
      ),
    );
  }
}
