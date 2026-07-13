import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:map/core/admin/admin_api_errors.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/features/admin/domain/admin_ops_controller.dart';
import 'package:map/features/admin/presentation/widgets/admin_web_scaffold.dart';

class AdminShuttleParticipantsCard extends StatefulWidget {
  const AdminShuttleParticipantsCard({super.key, required this.controller});

  final AdminOpsController controller;

  @override
  State<AdminShuttleParticipantsCard> createState() =>
      _AdminShuttleParticipantsCardState();
}

class _AdminShuttleParticipantsCardState
    extends State<AdminShuttleParticipantsCard> {
  Map<String, dynamic>? _data;
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final c = widget.controller;
    if (!c.apiReady) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final body = await c.client.getShuttleParticipants();
      if (!mounted) return;
      setState(() {
        _data = body;
        _loading = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _error = AdminApiErrors.format(error);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final counts = _data?['counts'] as Map<String, dynamic>? ?? {};
    final optedIn = _list(_data?['route_share_opted_in']);
    final tower = _list(_data?['tower_participants']);
    final prefs = _list(_data?['shuttle_preferences']);

    return AdminCard(
      title: '셔틀 참여자 현황',
      subtitle: '노선 공유 동의·관제탑 참여·정류장 선택 기록',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            )
          else ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _CountChip(
                  label: '노선 공유 동의',
                  count: counts['opted_in'] as int? ?? optedIn.length,
                  color: AppColors.primary,
                ),
                _CountChip(
                  label: '관제탑 참여',
                  count: counts['tower_participants'] as int? ?? tower.length,
                  color: const Color(0xFF5E35B1),
                ),
                _CountChip(
                  label: '정류장 선택',
                  count: counts['preferences'] as int? ?? prefs.length,
                  color: const Color(0xFF00897B),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _SectionTable(
              title: '노선 공유 동의',
              emptyMessage: '동의한 구직자가 없습니다.',
              rows: optedIn,
              columns: const [
                _Col('이메일', 'seeker_email'),
                _Col('회사', 'company_name'),
                _Col('노선', 'route_id'),
                _Col('관제탑', 'tower_participation_consented'),
              ],
            ),
            const SizedBox(height: 12),
            _SectionTable(
              title: '관제탑 참여 (노선 지정)',
              emptyMessage: '관제탑 참여자가 없습니다.',
              rows: tower,
              columns: const [
                _Col('이메일', 'seeker_email'),
                _Col('회사', 'company_name'),
                _Col('노선', 'route_id'),
                _Col('정류장', 'stop_id'),
              ],
            ),
            const SizedBox(height: 12),
            _SectionTable(
              title: '정류장 선택 (내 버스)',
              emptyMessage: '정류장을 선택한 구직자가 없습니다.',
              rows: prefs,
              columns: const [
                _Col('이메일', 'seeker_email'),
                _Col('회사', 'company_name'),
                _Col('노선', 'route_name'),
                _Col('정류장', 'stop_label'),
                _Col('탑승', 'pickup_time'),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed:
                  !widget.controller.apiReady || _loading ? null : _load,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('새로고침'),
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _list(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList(growable: false);
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        '$label $count명',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _Col {
  const _Col(this.header, this.key);

  final String header;
  final String key;
}

class _SectionTable extends StatelessWidget {
  const _SectionTable({
    required this.title,
    required this.emptyMessage,
    required this.rows,
    required this.columns,
  });

  final String title;
  final String emptyMessage;
  final List<Map<String, dynamic>> rows;
  final List<_Col> columns;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        if (rows.isEmpty)
          Text(
            emptyMessage,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary.withValues(alpha: 0.9),
            ),
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 36,
              dataRowMinHeight: 36,
              dataRowMaxHeight: 48,
              columnSpacing: 16,
              columns: [
                for (final col in columns)
                  DataColumn(label: Text(col.header, style: const TextStyle(fontSize: 12))),
              ],
              rows: [
                for (final row in rows.take(20))
                  DataRow(
                    cells: [
                      for (final col in columns)
                        DataCell(Text(_cellText(row[col.key]), style: const TextStyle(fontSize: 12))),
                    ],
                  ),
              ],
            ),
          ),
        if (rows.length > 20)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '최근 20건만 표시 (전체 ${rows.length}건)',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary.withValues(alpha: 0.85),
              ),
            ),
          ),
      ],
    );
  }

  String _cellText(Object? value) {
    if (value == null) return '—';
    if (value is bool) return value ? 'Y' : 'N';
    final text = '$value';
    if (text.contains('T') && text.length >= 19) {
      try {
        final dt = DateTime.parse(text).toLocal();
        return DateFormat('MM/dd HH:mm').format(dt);
      } on Object {
        return text;
      }
    }
    return text.isEmpty ? '—' : text;
  }
}
