import 'package:flutter/material.dart';
import 'package:map/features/admin/domain/admin_ops_controller.dart';
import 'package:map/features/admin/presentation/panels/admin_audit_panel.dart';
import 'package:map/features/admin/presentation/panels/admin_chat_panel.dart';
import 'package:map/features/admin/presentation/panels/admin_dashboard_panel.dart';
import 'package:map/features/admin/presentation/panels/admin_jobs_panel.dart';
import 'package:map/features/admin/presentation/panels/admin_map_panel.dart';
import 'package:map/features/admin/presentation/panels/admin_members_panel.dart';
import 'package:map/features/admin/presentation/panels/admin_qc_panel.dart';
import 'package:map/features/admin/presentation/widgets/admin_web_scaffold.dart';

/// 관리자 웹 콘솔 — Mac 16:9 넓은 화면 최적화
class AdminWebShellPage extends StatefulWidget {
  const AdminWebShellPage({super.key});

  @override
  State<AdminWebShellPage> createState() => _AdminWebShellPageState();
}

class _AdminWebShellPageState extends State<AdminWebShellPage> {
  final _controller = AdminOpsController();
  AdminNavSection _section = AdminNavSection.dashboard;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onControllerChange);
    if (_controller.apiReady) {
      _controller.refreshDashboard();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChange);
    _controller.dispose();
    super.dispose();
  }

  void _onControllerChange() {
    if (mounted) setState(() {});
  }

  Widget _buildPanel() {
    switch (_section) {
      case AdminNavSection.dashboard:
        return AdminDashboardPanel(controller: _controller);
      case AdminNavSection.map:
        return AdminMapPanel(controller: _controller);
      case AdminNavSection.members:
        return AdminMembersPanel(controller: _controller);
      case AdminNavSection.chat:
        return AdminChatPanel(controller: _controller);
      case AdminNavSection.jobs:
        return AdminJobsPanel(controller: _controller);
      case AdminNavSection.qc:
        return AdminQcPanel(controller: _controller);
      case AdminNavSection.audit:
        return AdminAuditPanel(controller: _controller);
      case AdminNavSection.compliance:
        return AdminDashboardPanel(controller: _controller);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminWebScaffold(
      section: _section,
      onSectionChanged: (s) => setState(() => _section = s),
      controller: _controller,
      body: _buildPanel(),
    );
  }
}
