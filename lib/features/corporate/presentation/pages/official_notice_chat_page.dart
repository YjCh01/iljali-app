import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/constants/app_routes.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/core/widgets/app_back_button.dart';
import 'package:map/features/corporate/domain/entities/corporate_chat_room.dart';
import 'package:map/features/corporate/domain/services/exposure_renewal_service.dart';
import 'package:map/features/corporate/presentation/pages/exposure_renewal_page.dart';
import 'package:map/features/corporate/presentation/widgets/corporate_surface_card.dart';

/// 채팅 탭 — 일자리 공식 알림 (노출 만료·연장 안내)
class OfficialNoticeChatPage extends StatelessWidget {
  const OfficialNoticeChatPage({super.key, required this.room});

  final CorporateChatRoom room;

  Future<void> _dismiss(BuildContext context) async {
    final companyKey =
        AuthSession.instance.currentUser?.corporateProfile?.companyKey;
    final jobPostId = room.jobPostId;
    if (companyKey != null &&
        companyKey.isNotEmpty &&
        jobPostId != null &&
        jobPostId.isNotEmpty) {
      await ExposureRenewalNoticeService().dismissNotice(
        companyKey: companyKey,
        jobPostId: jobPostId,
      );
    }
    if (context.mounted) Navigator.of(context).pop(false);
  }

  Future<void> _openRenewal(BuildContext context) async {
    final jobPostId = room.jobPostId;
    if (jobPostId == null || jobPostId.isEmpty) return;
    final renewed = await Navigator.of(context).pushNamed<bool>(
      AppRoutes.corporateExposureRenewal,
      arguments: ExposureRenewalArgs(jobPostId: jobPostId),
    );
    if (context.mounted && renewed == true) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = room.fullMessageBody ?? room.lastMessage;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        leading: const AppBackButton(),
        title: const Text(
          '일자리 공식 알림',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          CorporateSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  room.jobTitle,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  body,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.55,
                    color: AppColors.textPrimary.withValues(alpha: 0.92),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () => _openRenewal(context),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              '연장하기',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () => _dismiss(context),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text('아니오 · 나중에'),
          ),
        ],
      ),
    );
  }
}
