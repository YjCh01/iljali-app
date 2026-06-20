import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/constants/app_routes.dart';
import 'package:map/core/dev/dev_auth_service.dart';
import 'package:map/core/dev/dev_test_accounts.dart';
import 'package:map/core/dev/qc_auth_service.dart';
import 'package:map/core/session/member_type.dart';

/// debug 빌드 — 검증 우회 테스트 계정 원탭 로그인
class DevTestLoginPanel extends StatefulWidget {
  const DevTestLoginPanel({super.key});

  @override
  State<DevTestLoginPanel> createState() => _DevTestLoginPanelState();
}

class _DevTestLoginPanelState extends State<DevTestLoginPanel> {
  bool _expanded = false;
  bool _signingIn = false;
  final _qcSeekerEmailCtrl =
      TextEditingController(text: 'seeker-0001@qc.iljari.co.kr');

  @override
  void dispose() {
    _qcSeekerEmailCtrl.dispose();
    super.dispose();
  }

  Future<void> _signIn(DevTestAccount account) async {
    if (_signingIn) return;
    setState(() => _signingIn = true);
    try {
      await DevAuthService.signIn(account);
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.home, (_) => false);
    } catch (e, stack) {
      debugPrint('Dev test login failed: $e\n$stack');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('테스트 로그인 실패: $e'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) setState(() => _signingIn = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!DevAuthService.isEnabled) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextButton.icon(
          onPressed: _signingIn ? null : () => setState(() => _expanded = !_expanded),
          icon: Icon(
            _expanded ? Icons.expand_more : Icons.science_outlined,
            size: 18,
            color: Colors.white.withValues(alpha: 0.75),
          ),
          label: Text(
            _expanded ? '개발 테스트 로그인 닫기' : '개발 테스트 로그인',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (_expanded) ...[
          const SizedBox(height: 4),
          Text(
            '비밀번호 공통: ${DevTestAccounts.sharedPassword}',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: 8),
          ...DevTestAccounts.all.map(
            (account) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _DevAccountButton(
                account: account,
                busy: _signingIn,
                onTap: () => _signIn(account),
              ),
            ),
          ),
          if (QcAuthService.isQcSeekerEmailEnabled) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _qcSeekerEmailCtrl,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.9)),
              decoration: InputDecoration(
                labelText: 'QC 구직자 이메일',
                labelStyle:
                    TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                hintText: 'seeker-0001@qc.iljari.co.kr',
                hintStyle:
                    TextStyle(color: Colors.white.withValues(alpha: 0.4)),
                enabledBorder: OutlineInputBorder(
                  borderSide:
                      BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                ),
              ),
            ),
            const SizedBox(height: 6),
            OutlinedButton(
              onPressed: _signingIn
                  ? null
                  : () => _signInQcSeeker(_qcSeekerEmailCtrl.text),
              child: Text('QC 구직자 (${QcAuthService.qcSeekerPassword})'),
            ),
          ],
          TextButton(
            onPressed: _signingIn
                ? null
                : () => Navigator.of(context).pushNamed(AppRoutes.adminOps),
            child: Text(
              '관리자 Ops',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.75)),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _signInQcSeeker(String email) async {
    if (_signingIn) return;
    setState(() => _signingIn = true);
    try {
      await QcAuthService.signInSeeker(
        email: email,
        password: QcAuthService.qcSeekerPassword,
      );
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.home, (_) => false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('QC 로그인 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _signingIn = false);
    }
  }
}

class _DevAccountButton extends StatelessWidget {
  const _DevAccountButton({
    required this.account,
    required this.busy,
    required this.onTap,
  });

  final DevTestAccount account;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isCorp = account.memberType == MemberType.corporate;
    return Material(
      color: Colors.white.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: busy ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Icon(
                isCorp ? Icons.business_center_outlined : Icons.person_outline,
                size: 20,
                color: isCorp ? AppColors.primaryLight : Colors.white70,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      account.email,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (isCorp)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    '검증완료',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
