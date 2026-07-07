import 'package:flutter/material.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/core/session/member_type.dart';
import 'package:map/features/job_seeker/presentation/widgets/seeker_login_prompt_sheet.dart';

/// 공고 열람·지원 — 개인회원 vs 기업회원 역할 분리
///
/// - **기업회원**: 본문 열람(내/타사 공고) OK · 지원·문의·북마크 불가
/// - **개인회원**: 열람 + 지원·문의·북마크 OK
abstract final class SeekerJobActionsPolicy {
  static bool get isSignedInCorporate {
    final user = AuthSession.instance.currentUser;
    return user != null && user.memberType == MemberType.corporate;
  }

  static bool get isSignedInSeeker {
    final user = AuthSession.instance.currentUser;
    return user != null && user.memberType == MemberType.individual;
  }

  /// 지원·문의·북마크·길찾기 등 구직자 액션
  static bool get canPerformSeekerActions => isSignedInSeeker;

  /// [employerPreview] — 기업이 자사 공고 구직자 화면 미리보기
  static bool showSeekerActionUi({required bool employerPreview}) =>
      !employerPreview && canPerformSeekerActions;

  /// 지원 플로우 진입 전 — false면 스낵바/로그인 유도 후 중단
  static Future<bool> ensureCanApply(BuildContext context) async {
    if (canPerformSeekerActions) return true;
    if (!context.mounted) return false;

    if (isSignedInCorporate) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              '기업회원 계정에서는 지원할 수 없습니다. '
              '개인회원으로 로그인해 주세요.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      return false;
    }

    await SeekerLoginPromptSheet.show(
      context,
      message: '지원하려면 개인회원 로그인 또는 회원가입이 필요합니다.',
    );
    return false;
  }
}
