import 'package:flutter/material.dart';
import 'package:map/features/admin/domain/admin_ops_controller.dart';
import 'package:map/features/admin/presentation/widgets/admin_web_scaffold.dart';

class AdminAuditPanel extends StatefulWidget {
  const AdminAuditPanel({super.key, required this.controller});

  final AdminOpsController controller;

  @override
  State<AdminAuditPanel> createState() => _AdminAuditPanelState();
}

class _AdminAuditPanelState extends State<AdminAuditPanel> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChange);
    if (widget.controller.apiReady) {
      widget.controller.refreshAudit(limit: 100);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final logs = widget.controller.auditLogs;
    return AdminPanelScroll(
      child: AdminCard(
        title: '감사 로그',
        subtitle: 'Admin Ops 조작 기록 (최근 100건)',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: widget.controller.apiReady
                    ? () => widget.controller.refreshAudit(limit: 100)
                    : null,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('새로고침'),
              ),
            ),
            if (logs.isEmpty)
              const Text('로그 없음')
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('시각')),
                    DataColumn(label: Text('action')),
                    DataColumn(label: Text('target')),
                    DataColumn(label: Text('detail')),
                  ],
                  rows: [
                    for (final log in logs)
                      DataRow(
                        cells: [
                          DataCell(Text('${log['created_at'] ?? ''}', style: const TextStyle(fontSize: 11))),
                          DataCell(Text('${log['action']}')),
                          DataCell(Text('${log['target_id']}')),
                          DataCell(
                            SizedBox(
                              width: 280,
                              child: Text(
                                '${log['detail_json'] ?? ''}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
