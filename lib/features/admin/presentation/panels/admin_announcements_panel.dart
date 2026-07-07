import 'package:flutter/material.dart';
import 'package:map/core/sync/local_remote_sync_service.dart';
import 'package:map/features/admin/domain/admin_ops_controller.dart';
import 'package:map/features/admin/presentation/widgets/admin_web_scaffold.dart';
import 'package:map/features/chat/data/admin_announcement_local_data_source.dart';
import 'package:map/features/chat/domain/entities/admin_announcement.dart';
import 'package:map/features/chat/domain/entities/admin_announcement_audience.dart';

class AdminAnnouncementsPanel extends StatefulWidget {
  const AdminAnnouncementsPanel({super.key, required this.controller});

  final AdminOpsController controller;

  @override
  State<AdminAnnouncementsPanel> createState() =>
      _AdminAnnouncementsPanelState();
}

class _AdminAnnouncementsPanelState extends State<AdminAnnouncementsPanel> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  bool _pushRequested = true;
  AdminAnnouncementAudience _audience = AdminAnnouncementAudience.all;
  bool _loading = false;
  List<AdminAnnouncement> _history = const [];

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChange);
    if (widget.controller.apiReady) _loadHistory();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChange);
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  Future<void> _loadHistory() async {
    if (!widget.controller.apiReady) return;
    setState(() => _loading = true);
    try {
      final raw = await widget.controller.client.listAnnouncements();
      final items = [
        for (final row in raw)
          AdminAnnouncement.fromJson(Map<String, dynamic>.from(row)),
      ];
      if (mounted) setState(() => _history = items);
    } on Object {
      // controller status handles errors on send
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final title = _titleCtrl.text.trim();
    final body = _bodyCtrl.text.trim();
    if (title.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('제목과 본문을 입력해 주세요.')),
      );
      return;
    }

    final c = widget.controller;
    await c.run(() async {
      final response = await c.client.createAnnouncement(
        title: title,
        body: body,
        audience: _audience.apiValue,
        pushRequested: _pushRequested,
      );
      final announcement = response['announcement'];
      if (announcement is Map) {
        final item = AdminAnnouncement.fromJson(
          Map<String, dynamic>.from(announcement),
        );
        AdminAnnouncementLocalDataSourceImpl.upsertLocal(item);
      }
      await LocalRemoteSyncService().pullFromServer();
      return response;
    }, successMessage: '${_audience.label} 대상 공지가 발송되었습니다 (채팅 탭 노출)');

    _titleCtrl.clear();
    _bodyCtrl.clear();
    await _loadHistory();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return AdminPanelScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminCard(
            title: '운영 공지 발송',
            subtitle:
                '선택한 회원 유형의 채팅 탭에 읽기 전용 공지로 표시됩니다. 답장은 불가합니다.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '수신 대상',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                SegmentedButton<AdminAnnouncementAudience>(
                  segments: const [
                    ButtonSegment(
                      value: AdminAnnouncementAudience.all,
                      label: Text('전체'),
                    ),
                    ButtonSegment(
                      value: AdminAnnouncementAudience.seeker,
                      label: Text('개인회원'),
                    ),
                    ButtonSegment(
                      value: AdminAnnouncementAudience.corporate,
                      label: Text('기업회원'),
                    ),
                  ],
                  selected: {_audience},
                  onSelectionChanged: c.busy
                      ? null
                      : (selection) {
                          setState(() => _audience = selection.first);
                        },
                ),
                const SizedBox(height: 16),
                AdminField(
                  label: '제목',
                  controller: _titleCtrl,
                ),
                const SizedBox(height: 12),
                AdminField(
                  label: '본문',
                  controller: _bodyCtrl,
                  maxLines: 12,
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('푸시 발송 요청'),
                  subtitle: const Text(
                    'FCM 연동 — 앱 푸시 + 채팅 탭 공지 + 미읽음 배지',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: _pushRequested,
                  onChanged: c.busy ? null : (v) => setState(() => _pushRequested = v),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: !c.apiReady || c.busy ? null : _send,
                  icon: const Icon(Icons.send_rounded, size: 18),
                  label: Text('${_audience.label} 대상 발송'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AdminCard(
            title: '발송 이력',
            subtitle: '최근 ${ _history.length }건',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: !c.apiReady || _loading ? null : _loadHistory,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('새로고침'),
                  ),
                ),
                if (_loading)
                  const Center(child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ))
                else if (_history.isEmpty)
                  const Text('발송된 공지가 없습니다.')
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _history.length,
                    separatorBuilder: (_, __) => const Divider(height: 20),
                    itemBuilder: (context, index) {
                      final item = _history[index];
                      final sent = item.createdAt?.toLocal().toString() ?? '';
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${item.audience.label} · $sent',
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            item.previewLine,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13, height: 1.4),
                          ),
                        ],
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
