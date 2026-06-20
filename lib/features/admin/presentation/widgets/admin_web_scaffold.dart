import 'package:flutter/material.dart';
import 'package:map/core/config/env_config.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/constants/app_routes.dart';
import 'package:map/features/admin/domain/admin_ops_controller.dart';

enum AdminNavSection {
  dashboard('대시보드', Icons.dashboard_outlined),
  wallet('기업·이용권', Icons.account_balance_wallet_outlined),
  members('회원·제재', Icons.people_outline),
  jobs('공고·핀', Icons.push_pin_outlined),
  qc('QC 시드', Icons.science_outlined),
  audit('감사 로그', Icons.receipt_long_outlined),
  compliance('컴플라이언스', Icons.verified_user_outlined);

  const AdminNavSection(this.label, this.icon);
  final String label;
  final IconData icon;
}

class AdminWebScaffold extends StatelessWidget {
  const AdminWebScaffold({
    super.key,
    required this.section,
    required this.onSectionChanged,
    required this.controller,
    required this.body,
  });

  final AdminNavSection section;
  final ValueChanged<AdminNavSection> onSectionChanged;
  final AdminOpsController controller;
  final Widget body;

  static const _wideBreakpoint = 900.0;
  static const _railWidth = 248.0;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= _wideBreakpoint;
    final apiReady = controller.apiReady;

    if (wide) {
      return Scaffold(
        backgroundColor: const Color(0xFFF0F2F5),
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SideRail(
              width: _railWidth,
              section: section,
              apiReady: apiReady,
              onSectionChanged: onSectionChanged,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _TopBar(section: section, controller: controller),
                  Expanded(child: body),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('관리자 · ${section.label}'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
      ),
      drawer: Drawer(
        child: _NavList(
          section: section,
          apiReady: apiReady,
          onSectionChanged: (s) {
            Navigator.of(context).pop();
            onSectionChanged(s);
          },
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StatusStrip(controller: controller),
          Expanded(child: body),
        ],
      ),
    );
  }
}

class _SideRail extends StatelessWidget {
  const _SideRail({
    required this.width,
    required this.section,
    required this.apiReady,
    required this.onSectionChanged,
  });

  final double width;
  final AdminNavSection section;
  final bool apiReady;
  final ValueChanged<AdminNavSection> onSectionChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1E1245),
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 28, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '일자리 Admin',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'QC · 운영 콘솔',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: apiReady
                      ? const Color(0xFF2E7D32).withValues(alpha: 0.35)
                      : const Color(0xFFC62828).withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  apiReady
                      ? 'API 연결됨 · QC=${EnvConfig.qcMode ? "ON" : "OFF"}'
                      : 'API 미연결 — QC 실행.command 사용',
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
            ),
            Expanded(
              child: _NavList(
                section: section,
                apiReady: apiReady,
                onSectionChanged: onSectionChanged,
                dark: true,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pushNamed(
                  AppRoutes.memberGateway,
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: Colors.white24),
                ),
                child: const Text('일반 앱으로'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavList extends StatelessWidget {
  const _NavList({
    required this.section,
    required this.apiReady,
    required this.onSectionChanged,
    this.dark = false,
  });

  final AdminNavSection section;
  final bool apiReady;
  final ValueChanged<AdminNavSection> onSectionChanged;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        for (final item in AdminNavSection.values)
          if (item != AdminNavSection.compliance)
            _NavTile(
              selected: section == item,
              label: item.label,
              icon: item.icon,
              dark: dark,
              onTap: () => onSectionChanged(item),
            )
          else
            _NavTile(
              selected: false,
              label: item.label,
              icon: item.icon,
              dark: dark,
              onTap: () =>
                  Navigator.of(context).pushNamed(AppRoutes.adminCompliance),
            ),
      ],
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.selected,
    required this.label,
    required this.icon,
    required this.onTap,
    required this.dark,
  });

  final bool selected;
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final bg = selected
        ? (dark ? Colors.white.withValues(alpha: 0.12) : AppColors.primary.withValues(alpha: 0.12))
        : Colors.transparent;
    final fg = dark ? Colors.white : AppColors.textPrimary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        child: ListTile(
          dense: true,
          leading: Icon(icon, color: selected ? AppColors.primaryLight : fg),
          title: Text(
            label,
            style: TextStyle(
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: dark ? Colors.white : AppColors.textPrimary,
              fontSize: 14,
            ),
          ),
          onTap: onTap,
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.section, required this.controller});

  final AdminNavSection section;
  final AdminOpsController controller;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFE8EAED))),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  section.label,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                if (controller.busy)
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  IconButton(
                    tooltip: '새로고침',
                    onPressed: controller.apiReady
                        ? controller.refreshDashboard
                        : null,
                    icon: const Icon(Icons.refresh),
                  ),
              ],
            ),
            _StatusStrip(controller: controller),
          ],
        ),
      ),
    );
  }
}

class _StatusStrip extends StatelessWidget {
  const _StatusStrip({required this.controller});

  final AdminOpsController controller;

  @override
  Widget build(BuildContext context) {
    final msg = controller.statusMessage;
    if (msg.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        msg,
        style: TextStyle(
          fontSize: 13,
          color: controller.statusIsError
              ? const Color(0xFFC62828)
              : const Color(0xFF2E7D32),
        ),
      ),
    );
  }
}

/// 패널 공통 래퍼 — 넓은 화면에서 max-width + 패딩
class AdminPanelScroll extends StatelessWidget {
  const AdminPanelScroll({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: child,
        ),
      ),
    );
  }
}

class AdminCard extends StatelessWidget {
  const AdminCard({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE8EAED)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary.withValues(alpha: 0.9),
                ),
              ),
            ],
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class AdminField extends StatelessWidget {
  const AdminField({
    super.key,
    required this.label,
    required this.controller,
    this.keyboardType,
    this.maxLines = 1,
    this.hint,
  });

  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final int maxLines;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }
}
