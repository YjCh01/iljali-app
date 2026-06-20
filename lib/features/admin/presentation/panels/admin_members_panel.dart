import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/features/admin/domain/admin_ops_controller.dart';
import 'package:map/features/admin/presentation/widgets/admin_web_scaffold.dart';

class AdminMembersPanel extends StatefulWidget {
  const AdminMembersPanel({super.key, required this.controller});

  final AdminOpsController controller;

  @override
  State<AdminMembersPanel> createState() => _AdminMembersPanelState();
}

class _AdminMembersPanelState extends State<AdminMembersPanel> {
  final _searchCtrl = TextEditingController(text: 'seeker');
  final _emailCtrl = TextEditingController(text: 'seeker-0001@qc.iljari.co.kr');
  final _reasonCtrl = TextEditingController(text: 'QC 이용 제한');

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChange);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChange);
    _searchCtrl.dispose();
    _emailCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  Future<void> _search() async {
    await widget.controller.searchMembers(_searchCtrl.text);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final members = c.members;

    return AdminPanelScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminCard(
            title: '회원 검색',
            child: Row(
              children: [
                Expanded(
                  child: AdminField(
                    label: '이메일 검색',
                    controller: _searchCtrl,
                    hint: 'seeker 또는 @qc.iljari.co.kr',
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: FilledButton(
                    onPressed: !c.apiReady || c.busy ? null : _search,
                    child: const Text('검색'),
                  ),
                ),
              ],
            ),
          ),
          if (members.isNotEmpty) ...[
            const SizedBox(height: 12),
            AdminCard(
              title: '검색 결과 (${members.length}명)',
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('이메일')),
                    DataColumn(label: Text('이름')),
                    DataColumn(label: Text('유형')),
                    DataColumn(label: Text('상태')),
                  ],
                  rows: [
                    for (final m in members)
                      DataRow(
                        cells: [
                          DataCell(
                            Text(
                              '${m['email']}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          DataCell(Text('${m['display_name'] ?? ''}')),
                          DataCell(Text('${m['member_type'] ?? ''}')),
                          DataCell(
                            Text(
                              m['is_permanently_banned'] == true
                                  ? '영구제재'
                                  : m['is_suspended'] == true
                                      ? '정지'
                                      : '정상',
                              style: TextStyle(
                                color: m['is_suspended'] == true ||
                                        m['is_permanently_banned'] == true
                                    ? const Color(0xFFC62828)
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                        onSelectChanged: (_) {
                          _emailCtrl.text = '${m['email']}';
                          setState(() {});
                        },
                      ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          AdminCard(
            title: '제재 처리',
            subtitle: '선택 회원 또는 아래 이메일 직접 입력',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AdminField(label: '대상 이메일', controller: _emailCtrl),
                AdminField(label: '사유', controller: _reasonCtrl),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: !c.apiReady || c.busy
                          ? null
                          : () => c.run(
                                () => c.client.sanctionMember(
                                  email: _emailCtrl.text.trim(),
                                  action: 'suspend',
                                  reason: _reasonCtrl.text.trim(),
                                  days: 30,
                                ),
                                successMessage: '30일 정지 적용',
                              ).then((_) => _search()),
                      child: const Text('30일 정지'),
                    ),
                    OutlinedButton(
                      onPressed: !c.apiReady || c.busy
                          ? null
                          : () => c.run(
                                () => c.client.sanctionMember(
                                  email: _emailCtrl.text.trim(),
                                  action: 'permanent_ban',
                                  reason: _reasonCtrl.text.trim(),
                                ),
                                successMessage: '영구 제재 적용',
                              ).then((_) => _search()),
                      child: const Text('영구 제재'),
                    ),
                    FilledButton(
                      onPressed: !c.apiReady || c.busy
                          ? null
                          : () => c.run(
                                () => c.client.sanctionMember(
                                  email: _emailCtrl.text.trim(),
                                  action: 'lift',
                                ),
                                successMessage: '제재 해제',
                              ).then((_) => _search()),
                      child: const Text('제재 해제'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
