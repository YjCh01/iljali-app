import 'package:flutter/material.dart';
import 'package:map/core/admin/admin_api_errors.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/features/admin/domain/admin_ops_controller.dart';
import 'package:map/features/admin/presentation/widgets/admin_web_scaffold.dart';

class AdminChatPanel extends StatefulWidget {
  const AdminChatPanel({super.key, required this.controller});

  final AdminOpsController controller;

  @override
  State<AdminChatPanel> createState() => _AdminChatPanelState();
}

class _AdminChatPanelState extends State<AdminChatPanel> {
  final _searchCtrl = TextEditingController(text: 'seeker');
  List<Map<String, dynamic>> _members = const [];
  List<Map<String, dynamic>> _applications = const [];
  List<Map<String, dynamic>> _messages = const [];
  Map<String, dynamic>? _selectedMember;
  Map<String, dynamic>? _selectedApp;
  Map<String, dynamic>? _chatMeta;
  String? _error;
  bool _loadingMembers = false;
  bool _loadingApps = false;
  bool _loadingChat = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _searchMembers() async {
    if (!widget.controller.apiReady) return;
    setState(() {
      _loadingMembers = true;
      _error = null;
    });
    try {
      final list = await widget.controller.client.searchMembers(
        query: _searchCtrl.text.trim(),
        limit: 50,
      );
      if (!mounted) return;
      setState(() {
        _members = list;
        _loadingMembers = false;
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _error = AdminApiErrors.format(e);
        _loadingMembers = false;
      });
    }
  }

  Future<void> _selectMember(Map<String, dynamic> member) async {
    setState(() {
      _selectedMember = member;
      _selectedApp = null;
      _messages = const [];
      _chatMeta = null;
      _loadingApps = true;
      _error = null;
    });
    try {
      final type = '${member['member_type'] ?? 'seeker'}';
      final apps = await widget.controller.client.listApplications(
        seekerEmail: type == 'seeker' ? '${member['email']}' : null,
        companyKey: type == 'seeker'
            ? null
            : '${member['company_key'] ?? ''}',
        limit: 100,
      );
      if (!mounted) return;
      setState(() {
        _applications = apps;
        _loadingApps = false;
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _error = AdminApiErrors.format(e);
        _loadingApps = false;
      });
    }
  }

  Future<void> _selectApplication(Map<String, dynamic> app) async {
    setState(() {
      _selectedApp = app;
      _loadingChat = true;
      _error = null;
    });
    try {
      final body = await widget.controller.client
          .getApplicationChat('${app['id']}');
      if (!mounted) return;
      setState(() {
        _chatMeta = Map<String, dynamic>.from(
          body['application'] as Map? ?? {},
        );
        final list = body['messages'] as List<dynamic>? ?? [];
        _messages = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _loadingChat = false;
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _error = AdminApiErrors.format(e);
        _loadingChat = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    if (!c.apiReady) {
      return const AdminPanelScroll(
        child: Text('API 미설정 — Admin 실행.command 로 실행하세요.'),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminCard(
            title: '이용자 검색',
            subtitle: '구인자·구직자 선택 후 채팅 내역 열람 (어뷰징·부정행위 대응)',
            child: Row(
              children: [
                Expanded(
                  child: AdminField(
                    label: '이메일·이름·회사명',
                    controller: _searchCtrl,
                    hint: 'seeker / corporate / @qc.iljari.co.kr',
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: FilledButton(
                    onPressed: _loadingMembers ? null : _searchMembers,
                    child: const Text('검색'),
                  ),
                ),
              ],
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _error!,
                style: const TextStyle(color: Color(0xFFC62828), fontSize: 13),
              ),
            ),
          const SizedBox(height: 12),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _MemberList(
                  members: _members,
                  selected: _selectedMember,
                  loading: _loadingMembers,
                  onSelect: _selectMember,
                )),
                const SizedBox(width: 12),
                Expanded(child: _ApplicationList(
                  applications: _applications,
                  selected: _selectedApp,
                  loading: _loadingApps,
                  member: _selectedMember,
                  onSelect: _selectApplication,
                )),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: _ChatViewer(
                    meta: _chatMeta,
                    messages: _messages,
                    loading: _loadingChat,
                    application: _selectedApp,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberList extends StatelessWidget {
  const _MemberList({
    required this.members,
    required this.selected,
    required this.loading,
    required this.onSelect,
  });

  final List<Map<String, dynamic>> members;
  final Map<String, dynamic>? selected;
  final bool loading;
  final ValueChanged<Map<String, dynamic>> onSelect;

  @override
  Widget build(BuildContext context) {
    return _PanelFrame(
      title: '회원 (${members.length})',
      loading: loading,
      child: members.isEmpty
          ? const Center(child: Text('검색 후 회원 선택', style: TextStyle(fontSize: 13)))
          : ListView.separated(
              itemCount: members.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final m = members[i];
                final isSel = selected?['email'] == m['email'];
                return ListTile(
                  dense: true,
                  selected: isSel,
                  title: Text(
                    '${m['display_name'] ?? m['email']}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '${m['member_type']} · ${m['email']}',
                    style: const TextStyle(fontSize: 11),
                  ),
                  onTap: () => onSelect(m),
                );
              },
            ),
    );
  }
}

class _ApplicationList extends StatelessWidget {
  const _ApplicationList({
    required this.applications,
    required this.selected,
    required this.loading,
    required this.member,
    required this.onSelect,
  });

  final List<Map<String, dynamic>> applications;
  final Map<String, dynamic>? selected;
  final bool loading;
  final Map<String, dynamic>? member;
  final ValueChanged<Map<String, dynamic>> onSelect;

  @override
  Widget build(BuildContext context) {
    return _PanelFrame(
      title: member == null ? '지원·채팅' : '지원 (${applications.length})',
      loading: loading,
      child: member == null
          ? const Center(child: Text('회원을 먼저 선택', style: TextStyle(fontSize: 13)))
          : applications.isEmpty
              ? const Center(child: Text('지원 내역 없음', style: TextStyle(fontSize: 13)))
              : ListView.separated(
                  itemCount: applications.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final a = applications[i];
                    final isSel = selected?['id'] == a['id'];
                    final msgCount = (a['message_count'] as num?)?.toInt() ?? 0;
                    return ListTile(
                      dense: true,
                      selected: isSel,
                      title: Text(
                        '${a['post_title']}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        '${a['seeker_name']} · ${a['status']} · 채팅 $msgCount',
                        style: const TextStyle(fontSize: 11),
                      ),
                      onTap: () => onSelect(a),
                    );
                  },
                ),
    );
  }
}

class _ChatViewer extends StatelessWidget {
  const _ChatViewer({
    required this.meta,
    required this.messages,
    required this.loading,
    required this.application,
  });

  final Map<String, dynamic>? meta;
  final List<Map<String, dynamic>> messages;
  final bool loading;
  final Map<String, dynamic>? application;

  @override
  Widget build(BuildContext context) {
    return _PanelFrame(
      title: application == null ? '채팅 내용' : '채팅 · ${application!['post_title']}',
      loading: loading,
      child: application == null
          ? const Center(
              child: Text('지원 건을 선택하면 채팅이 표시됩니다', style: TextStyle(fontSize: 13)),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (meta != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    child: Text(
                      '구직 ${meta!['seeker_name']} (${meta!['seeker_email']}) · '
                      '기업 ${meta!['company_name']} · ${meta!['status']}',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary.withValues(alpha: 0.95),
                      ),
                    ),
                  ),
                const Divider(height: 1),
                Expanded(
                  child: messages.isEmpty
                      ? const Center(child: Text('메시지 없음', style: TextStyle(fontSize: 13)))
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: messages.length,
                          itemBuilder: (context, i) {
                            final m = messages[i];
                            return _AdminChatBubble(message: m);
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

class _AdminChatBubble extends StatelessWidget {
  const _AdminChatBubble({required this.message});

  final Map<String, dynamic> message;

  @override
  Widget build(BuildContext context) {
    final role = '${message['sender_role'] ?? 'system'}';
    final isSystem = role == 'system';
    final isSeeker = role == 'seeker';
    final body = '${message['body'] ?? ''}';
    final name = '${message['sender_name'] ?? role}';
    final sentAt = '${message['sent_at'] ?? ''}';

    if (isSystem) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(body, style: const TextStyle(fontSize: 12)),
          ),
        ),
      );
    }

    return Align(
      alignment: isSeeker ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        constraints: const BoxConstraints(maxWidth: 360),
        decoration: BoxDecoration(
          color: isSeeker
              ? AppColors.surface
              : AppColors.primaryLight.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.searchBarBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$name · $role',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary.withValues(alpha: 0.9),
              ),
            ),
            const SizedBox(height: 4),
            Text(body, style: const TextStyle(fontSize: 13, height: 1.35)),
            if (sentAt.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  sentAt.length > 19 ? sentAt.substring(0, 19) : sentAt,
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary.withValues(alpha: 0.7),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PanelFrame extends StatelessWidget {
  const _PanelFrame({
    required this.title,
    required this.child,
    this.loading = false,
  });

  final String title;
  final Widget child;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE8EAED)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              child: Row(
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  const Spacer(),
                  if (loading)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}
