import 'package:map/core/config/env_config.dart';
import 'package:map/core/constants/app_routes.dart';
import 'package:map/core/hiring/application_chat_message_repository.dart';
import 'package:map/core/hiring/hiring_application.dart';
import 'package:map/core/api/iljari_api_client.dart';
import 'package:map/features/commute/data/repositories/commute_route_repository.dart';
import 'package:map/features/commute/data/repositories/seeker_shuttle_route_share_consent_repository.dart';
import 'package:map/features/commute/domain/entities/seeker_shuttle_route_share_consent.dart';

/// 채용 확정(출근 예정) 시 — 셔틀 노선이 있으면 채팅·서버에 노선 공유 안내
abstract final class ShuttleRouteShareOnHireSideEffects {
  static Future<void> handle(HiringApplication application) async {
    final companyKey = application.companyKey?.trim() ?? '';
    if (companyKey.isEmpty) return;

    final routeRepo = await CommuteRouteRepository.create();
    final routes = await routeRepo.loadForCompany(companyKey);
    if (routes.isEmpty) return;

    final routeNames = routes.map((r) => r.routeName).take(5).join(', ');
    final extra = routes.length > 5 ? ' 외 ${routes.length - 5}개' : '';

    final chatText = StringBuffer()
      ..writeln('채용이 확정되었습니다. 축하드립니다!')
      ..writeln()
      ..writeln(
        '이 회사는 통근 셔틀버스 노선을 운영 중입니다 (${routes.length}개: $routeNames$extra).',
      )
      ..writeln()
      ..writeln('・자차·도보 이용: 「받지 않음」을 선택하거나 채팅으로 알려 주세요.')
      ..writeln('・셔틀 이용: 앱 「내 버스」에서 노선 공유를 받고, 탑승 노선·정류장을 선택해 주세요.')
      ..writeln(
        '  실시간 버스 위치는 어드민이 승인한 「버스위치 공유 담당」 1명이 위치를 공유하는 방식으로 제공됩니다.',
      )
      ..writeln('  확인에 동의하시면 본인이 담당으로 지정될 경우 위치를 공유하는 데에도 동의하는 것으로 간주됩니다.')
      ..writeln()
      ..writeln('내 버스: ${AppRoutes.seekerMyBus}');

    final chatRepo = await ApplicationChatMessageRepository.create();
    await chatRepo.appendSystemMessage(
      applicationId: application.id,
      text: chatText.toString().trim(),
    );

    final consentRepo = await SeekerShuttleRouteShareConsentRepository.create();
    final existing = await consentRepo.findForCompany(
      seekerEmail: application.seekerEmail,
      companyKey: companyKey,
    );
    if (existing == null) {
      await consentRepo.save(
        SeekerShuttleRouteShareConsent(
          seekerEmail: application.seekerEmail,
          companyKey: companyKey,
          companyName: application.companyName,
          optedIn: false,
          towerParticipationOffered: true,
          offerPending: true,
          applicationId: application.id,
          updatedAt: DateTime.now(),
        ),
      );
    } else if (!existing.optedIn) {
      await consentRepo.save(
        existing.copyWith(
          towerParticipationOffered: true,
          offerPending: true,
          applicationId: application.id,
          updatedAt: DateTime.now(),
        ),
      );
    }

    if (EnvConfig.isComplianceApiEnabled) {
      final client = IljariApiClient();
      if (client.isEnabled) {
        try {
          await client.offerShuttleRouteShare(
            applicationId: application.id,
            companyKey: companyKey,
            companyName: application.companyName,
            routeCount: routes.length,
          );
        } on Object {
          // 로컬·채팅은 유지
        }
      }
    }
  }
}
