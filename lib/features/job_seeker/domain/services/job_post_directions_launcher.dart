import 'package:flutter/material.dart';
import 'package:map/core/constants/app_routes.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/features/job_seeker/domain/entities/job_map_pin.dart';
import 'package:map/features/job_seeker/domain/utils/seeker_home_address_resolver.dart';
import 'package:map/features/job_seeker/presentation/pages/job_post_walking_directions_page.dart';
import 'package:map/features/job_seeker/presentation/utils/seeker_shell_access.dart';
import 'package:map/features/job_seeker/presentation/widgets/seeker_login_prompt_sheet.dart';

/// 공고 상세 길찾기 — 기업 차단·개인 도보(내 주소 → 근무지)
abstract final class JobPostDirectionsLauncher {
  static const corporatePeerBlockedMessage = '다른 기업의 공고입니다.';

  static Future<void> openWalkingFromHome(
    BuildContext context,
    JobMapPin pin, {
    bool employerPreview = false,
  }) async {
    if (employerPreview) return;

    final user = AuthSession.instance.currentUser;
    if (user?.isCorporate == true) {
      _showMessage(context, corporatePeerBlockedMessage);
      return;
    }

    if (!SeekerShellAccess.isSignedInSeeker) {
      await SeekerLoginPromptSheet.show(
        context,
        message:
            '내 주소지에서 근무지까지 도보 길찾기는 로그인 후 이용할 수 있습니다.',
      );
      return;
    }

    final homeLabel = SeekerHomeAddressResolver.resolveLabel(user?.seekerProfile);
    final home = await SeekerHomeAddressResolver.resolveCoordinate(
      profile: user?.seekerProfile,
    );
    if (!context.mounted) return;
    if (home == null || homeLabel == null) {
      final goRegister = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('내 주소지가 필요합니다'),
          content: const Text(
            '도보 길찾기는 더보기에 등록한 실주소(내 주소지)를 출발지로 사용합니다.\n'
            '주소를 등록한 뒤 다시 시도해 주세요.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('닫기'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('주소 등록'),
            ),
          ],
        ),
      );
      if (goRegister == true && context.mounted) {
        await Navigator.of(context).pushNamed(AppRoutes.seekerHomeAddress);
      }
      return;
    }

    final post = pin.post;
    final destinationLabel = post.warehouseName.trim().isNotEmpty
        ? post.warehouseName
        : post.title;
    final destLat = post.workplaceLatitude ??
        (pin.latitude != 0 ? pin.latitude : null);
    final destLng = post.workplaceLongitude ??
        (pin.longitude != 0 ? pin.longitude : null);
    if (destLat == null || destLng == null) {
      _showMessage(context, '근무지 위치 정보가 없어 길찾기를 시작할 수 없습니다.');
      return;
    }

    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => JobPostWalkingDirectionsPage(
          originLabel: homeLabel,
          destinationLabel: destinationLabel,
          originLatitude: home.latitude,
          originLongitude: home.longitude,
          destinationLatitude: destLat,
          destinationLongitude: destLng,
        ),
      ),
    );
  }

  static void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
