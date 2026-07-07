import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/notifications/push_token_registration_service.dart';
import 'package:map/core/widgets/app_back_button.dart';
import 'package:map/features/corporate/presentation/widgets/corporate_surface_card.dart';

/// 구직자 알림 설정 — 로컬 + 서버 FCM 설정 동기화
class SeekerNotificationSettingsPage extends StatefulWidget {
  const SeekerNotificationSettingsPage({super.key});

  @override
  State<SeekerNotificationSettingsPage> createState() =>
      _SeekerNotificationSettingsPageState();
}

class _SeekerNotificationSettingsPageState
    extends State<SeekerNotificationSettingsPage> {
  bool _pushJobAlerts = true;
  bool _pushChatMessages = true;
  bool _pushApplicationUpdates = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await PushNotificationPreferences.load();
    if (!mounted) return;
    setState(() {
      _pushJobAlerts = prefs.jobAlertsEnabled;
      _pushChatMessages = prefs.chatEnabled;
      _pushApplicationUpdates = prefs.applicationUpdatesEnabled;
      _loading = false;
    });
  }

  Future<void> _saveAll() async {
    final value = PushNotificationPreferences(
      chatEnabled: _pushChatMessages,
      jobAlertsEnabled: _pushJobAlerts,
      applicationUpdatesEnabled: _pushApplicationUpdates,
    );
    await PushNotificationPreferences.save(value);
    await PushTokenRegistrationService.syncPreferences(value);
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
                  subtitle: '근처 새 공고·PUSH 알림권 발송',
                  value: _pushJobAlerts,
                  onChanged: (v) async {
                    setState(() => _pushJobAlerts = v);
                    await _saveAll();
                  },
                ),
                _ToggleTile(
                  title: '채팅 메시지',
                  subtitle: '기업 담당자·구직자 답변',
                  value: _pushChatMessages,
                  onChanged: (v) async {
                    setState(() => _pushChatMessages = v);
                    await _saveAll();
                  },
                ),
                _ToggleTile(
                  title: '지원 현황',
                  subtitle: '합의·출근·근태 안내',
                  value: _pushApplicationUpdates,
                  onChanged: (v) async {
                    setState(() => _pushApplicationUpdates = v);
                    await _saveAll();
                  },
                ),
                const SizedBox(height: 20),
                Text(
                  'PUSH 알림권으로 받는 일자리 알림과 채팅·지원 알림을 '
                  '각각 켜거나 끌 수 있습니다.',
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.45,
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
