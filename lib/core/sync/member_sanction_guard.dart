import 'package:flutter/material.dart';
import 'package:map/core/sync/member_sanction_store.dart';

/// 로그인·동기화 후 제재 UX — 교육 팝업 등
abstract final class MemberSanctionGuard {
  static Future<void> showPendingNotices(
    BuildContext context, {
    required String email,
  }) async {
    if (email.trim().isEmpty || !context.mounted) return;
    final store = await MemberSanctionStore.create();
    if (!store.shouldShowEducationPopup(email) || !context.mounted) return;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('이용 안내'),
        content: const Text(
          '주의 조치가 적용되었습니다.\n'
          '허위 공고·연락 지연·No-show 무시 등 운영 정책을 다시 확인해 주세요.\n'
          '이의제기는 7일 이내 고객센터로 가능합니다.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('확인'),
          ),
        ],
      ),
    );
    await store.clearEducationPopup(email);
  }
}
