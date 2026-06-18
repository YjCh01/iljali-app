import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/widgets/app_back_button.dart';
import 'package:map/features/corporate/presentation/widgets/corporate_surface_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 구직자 알림 설정 (로컬 mock, SharedPreferences 영속)
class SeekerNotificationSettingsPage extends StatefulWidget {
  const SeekerNotificationSettingsPage({super.key});

  @override
  State<SeekerNotificationSettingsPage> createState() =>
      _SeekerNotificationSettingsPageState();
}

class _SeekerNotificationSettingsPageState
    extends State<SeekerNotificationSettingsPage> {
  static const _keyPrefix = 'seeker_notif_';

  bool _pushJobAlerts = true;
  bool _pushChatMessages = true;
  bool _pushApplicationUpdates = true;
  bool _emailMarketing = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _pushJobAlerts = prefs.getBool('${_keyPrefix}job_alerts') ?? true;
      _pushChatMessages = prefs.getBool('${_keyPrefix}chat') ?? true;
      _pushApplicationUpdates =
          prefs.getBool('${_keyPrefix}application') ?? true;
      _emailMarketing = prefs.getBool('${_keyPrefix}email_marketing') ?? false;
      _loading = false;
    });
  }

  Future<void> _set(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_keyPrefix$key', value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        leading: const AppBackButton(),
        title: const Text('알림 설정'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                Text(
                  'PUSH 알림',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary.withValues(alpha: 0.95),
                  ),
                ),
                const SizedBox(height: 8),
                _ToggleTile(
                  title: '일자리 알림',
                  subtitle: '근처 새 공고·알림핀 PUSH',
                  value: _pushJobAlerts,
                  onChanged: (v) {
                    setState(() => _pushJobAlerts = v);
                    _set('job_alerts', v);
                  },
                ),
                _ToggleTile(
                  title: '채팅 메시지',
                  subtitle: '기업 담당자 답변',
                  value: _pushChatMessages,
                  onChanged: (v) {
                    setState(() => _pushChatMessages = v);
                    _set('chat', v);
                  },
                ),
                _ToggleTile(
                  title: '지원 현황',
                  subtitle: '합의·출근·근태 안내',
                  value: _pushApplicationUpdates,
                  onChanged: (v) {
                    setState(() => _pushApplicationUpdates = v);
                    _set('application', v);
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  '이메일',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary.withValues(alpha: 0.95),
                  ),
                ),
                const SizedBox(height: 8),
                _ToggleTile(
                  title: '마케팅·이벤트',
                  subtitle: '선택 수신 (언제든 끌 수 있음)',
                  value: _emailMarketing,
                  onChanged: (v) {
                    setState(() => _emailMarketing = v);
                    _set('email_marketing', v);
                  },
                ),
                const SizedBox(height: 20),
                Text(
                  '설정은 이 기기에만 저장됩니다. 실서비스 연동 전 mock입니다.',
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.4,
                    color: AppColors.textSecondary.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
    );
  }
}

class _ToggleTile extends StatelessWidget {
  const _ToggleTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: CorporateSurfaceCard(
        child: SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary.withValues(alpha: 0.95),
            ),
          ),
          value: value,
          activeThumbColor: AppColors.primary,
          onChanged: onChanged,
        ),
      ),
    );
  }
}
