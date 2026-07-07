import 'package:flutter/material.dart';
import 'package:map/features/job_seeker/domain/factories/closed_ghost_job_map_pin_factory.dart';

/// 마감유령핀(어드민 배치·만료 무료 공고) 탭 시 사용자 안내
abstract final class ClosedGhostPinFeedback {
  static const message = ClosedGhostJobMapPinFactory.message;

  static void showSnackBar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
