import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/constants/app_routes.dart';
import 'package:map/core/legal/legal_consent_catalog.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/core/session/member_type.dart';
import 'package:map/features/job_seeker/domain/entities/seeker_member_profile.dart';

/// 약관 버전 변경 시 재동의 게이트
class LegalConsentGate extends StatefulWidget {
  const LegalConsentGate({super.key, required this.child});

  final Widget child;

  @override
  State<LegalConsentGate> createState() => _LegalConsentGateState();
}

class _LegalConsentGateState extends State<LegalConsentGate> {
  bool _blocking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkConsent());
  }

  bool _needsReconsent() {
    final user = AuthSession.instance.currentUser;
    if (user == null) return false;

    if (user.memberType == MemberType.corporate) {
      final profile = user.corporateProfile;
      if (profile == null) return false;
      return !LegalConsentCatalog.corporateConsentCurrent(
        termsVersionAccepted: profile.termsVersionAccepted,
        privacyVersionAccepted: profile.privacyVersionAccepted,
        outsourcingPolicyVersionAccepted: profile.outsourcingPolicyVersionAccepted,
      );
    }

    final seeker = user.seekerProfile;
    if (seeker == null) return false;
    return !LegalConsentCatalog.seekerConsentCurrent(
      termsVersionAccepted: seeker.termsVersionAccepted,
      privacyVersionAccepted: seeker.privacyVersionAccepted,
    );
  }

  Future<void> _checkConsent() async {
    if (!mounted || !_needsReconsent()) return;
    setState(() => _blocking = true);
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('약관이 업데이트되었습니다'),
        content: const Text(
          '서비스 이용약관·개인정보처리방침(및 기업회원 정책)이 '
          '개정되었습니다. 계속 이용하려면 동의가 필요합니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('로그아웃'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(ctx).pushNamed(AppRoutes.legalDocuments),
            child: const Text('전문 보기'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('동의하고 계속'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (accepted == true) {
      await _recordConsent();
      if (mounted) setState(() => _blocking = false);
      return;
    }
    await AuthSession.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.memberGateway,
      (_) => false,
    );
  }

  Future<void> _recordConsent() async {
    final user = AuthSession.instance.currentUser;
    if (user == null) return;
    final now = DateTime.now();

    if (user.memberType == MemberType.corporate) {
      final profile = user.corporateProfile;
      if (profile == null) return;
      await AuthSession.instance.updateCorporateProfile(
        profile.copyWith(
          policyAcceptedAt: now,
          termsVersionAccepted: LegalConsentCatalog.termsVersion,
          privacyVersionAccepted: LegalConsentCatalog.privacyVersion,
          outsourcingPolicyVersionAccepted:
              LegalConsentCatalog.outsourcingPolicyVersion,
        ),
      );
      return;
    }

    final seeker = user.seekerProfile ?? const SeekerMemberProfile(phoneVerified: true);
    await AuthSession.instance.updateSeekerProfile(
      seeker.copyWith(
        termsAcceptedAt: now,
        termsVersionAccepted: LegalConsentCatalog.termsVersion,
        privacyVersionAccepted: LegalConsentCatalog.privacyVersion,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_blocking) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return widget.child;
  }
}
