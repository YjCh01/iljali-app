import 'package:flutter/material.dart';
import 'package:map/features/admin/domain/admin_ops_controller.dart';
import 'package:map/features/admin/presentation/widgets/admin_web_scaffold.dart';

/// 위치정보의 이용ㆍ제공사실 확인 자료 취급대장 — 위치정보법 전자기록 열람.
class AdminLocationUsageLogPanel extends StatefulWidget {
  const AdminLocationUsageLogPanel({super.key, required this.controller});

  final AdminOpsController controller;

  @override
  State<AdminLocationUsageLogPanel> createState() =>
      _AdminLocationUsageLogPanelState();
}

class _AdminLocationUsageLogPanelState
    extends State<AdminLocationUsageLogPanel> {
  String? _usageType;

  static const _usageTypeLabels = {
    'map_view': '지도 노출',
    'checkin_verify': '출근ㆍ근태 위치검증',
    'push_radius': '반경 PUSH',
  };

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChange);
    if (widget.controller.apiReady) {
      widget.controller.refreshLocationUsageLogs();
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
    final logs = widget.controller.locationUsageLogs;
    return AdminPanelScroll(
      child: AdminCard(
        title: '위치정보 취급대장',
        subtitle: '이용자 위치정보의 이용ㆍ제공사실 확인 자료 (위치정보법 전자기록)',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                DropdownButton<String?>(
                  value: _usageType,
                  hint: const Text('전체 유형'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('전체 유형')),
                    for (final entry in _usageTypeLabels.entries)
                      DropdownMenuItem(
                        value: entry.key,
                        child: Text(entry.value),
                      ),
                  ],
                  onChanged: (value) {
                    setState(() => _usageType = value);
                    widget.controller.refreshLocationUsageLogs(
                      usageType: value,
                    );
                  },
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: widget.controller.apiReady
                      ? () => widget.controller
                          .refreshLocationUsageLogs(usageType: _usageType)
                      : null,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('새로고침'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (logs.isEmpty)
              const Text('기록 없음')
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('대상')),
                    DataColumn(label: Text('취득경로')),
                    DataColumn(label: Text('제공 서비스')),
                    DataColumn(label: Text('제공받는자')),
                    DataColumn(label: Text('위치')),
                    DataColumn(label: Text('이용일시')),
                  ],
                  rows: [
                    for (final log in logs)
                      DataRow(
                        cells: [
                          DataCell(
                            SizedBox(
                              width: 200,
                              child: Text(
                                '${log['subject_label'] ?? ''}\n${log['subject_email'] ?? ''}',
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                          ),
                          DataCell(Text(
                            '${log['acquisition_path'] ?? ''}',
                            style: const TextStyle(fontSize: 11),
                          )),
                          DataCell(
                            SizedBox(
                              width: 260,
                              child: Text(
                                '${log['service_description'] ?? ''}',
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                          ),
                          DataCell(Text(
                            '${log['recipient_label'] ?? ''}',
                            style: const TextStyle(fontSize: 11),
                          )),
                          DataCell(Text(
                            log['latitude'] != null && log['longitude'] != null
                                ? '${log['latitude']}, ${log['longitude']}'
                                : '-',
                            style: const TextStyle(fontSize: 11),
                          )),
                          DataCell(Text(
                            '${log['created_at'] ?? ''}',
                            style: const TextStyle(fontSize: 11),
                          )),
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
