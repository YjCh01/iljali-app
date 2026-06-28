import 'package:flutter/material.dart';
import 'package:map/core/hiring/hiring_application.dart';
import 'package:map/core/hiring/local_hiring_repository.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/features/commute/data/repositories/shuttle_booking_repository.dart';
import 'package:map/features/job_seeker/data/repositories/job_application_repository.dart';

/// 구직자 지원 취소 — 채용·지원·셔틀 예약 정리
abstract final class SeekerApplicationWithdrawService {
  static Future<HiringApplication?> findActive({
    required String postId,
    String? seekerEmail,
  }) async {
    final email = seekerEmail ?? AuthSession.instance.currentUser?.email;
    if (email == null || email.isEmpty) return null;
    final repo = await LocalHiringRepository.create();
    return repo.findActiveForPost(postId: postId, seekerEmail: email);
  }

  static Future<bool> canWithdraw(String postId, {String? seekerEmail}) async {
    final application = await findActive(postId: postId, seekerEmail: seekerEmail);
    if (application == null) return false;
    return LocalHiringRepository.canSeekerWithdraw(application);
  }

  static Future<bool> confirmAndWithdraw(
    BuildContext context, {
    required String postId,
    String? postTitle,
    String? seekerEmail,
  }) async {
    final email = seekerEmail ?? AuthSession.instance.currentUser?.email;
    if (email == null || email.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그인 후 지원 취소할 수 있습니다.')),
        );
      }
      return false;
    }

    final hiringRepo = await LocalHiringRepository.create();
    final application = await hiringRepo.findActiveForPost(
      postId: postId,
      seekerEmail: email,
    );
    if (application == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('취소할 지원 내역이 없습니다.')),
        );
      }
      return false;
    }

    final blockReason =
        LocalHiringRepository.seekerWithdrawBlockReason(application);
    if (blockReason != null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(blockReason)),
        );
      }
      return false;
    }

    final title = postTitle ?? application.postTitle;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('지원 취소'),
        content: Text(
          '「$title」 공고 지원을 취소할까요?\n'
          '취소하면 기업과의 채팅·셔틀 예약도 함께 해제됩니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('닫기'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade700,
            ),
            child: const Text('지원 취소'),
          ),
        ],
      ),
    );
    if (confirmed != true) return false;

    await hiringRepo.withdrawBySeeker(postId: postId, seekerEmail: email);

    final appRepo = await JobApplicationRepository.create(email);
    await appRepo?.removeByPostId(postId);

    final bookingId = application.shuttleBookingId;
    if (bookingId != null && bookingId.isNotEmpty) {
      final shuttleRepo = await ShuttleBookingRepository.create();
      await shuttleRepo.removeById(bookingId);
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('지원을 취소했습니다.')),
      );
    }
    return true;
  }
}
