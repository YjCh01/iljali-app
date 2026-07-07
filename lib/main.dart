import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:map/app.dart';
import 'package:map/core/config/env_config.dart';
import 'package:map/core/config/naver_map_web_client_id_loader.dart';
import 'package:map/core/constants/app_routes.dart';
import 'package:map/core/dev/qc_local_storage_purge.dart';
import 'package:map/core/utils/naver_map_platform.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/core/session/guest_browse_intent.dart';
import 'package:map/core/session/member_type.dart';
import 'package:map/core/monitoring/error_reporting.dart';
import 'package:map/core/notifications/push_notification_bootstrap.dart';
import 'package:map/core/payments/payment_deep_link_bootstrap.dart';
import 'package:map/core/compliance/services/subscription_renewal_service.dart';
import 'package:map/core/sync/qc_sync_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    usePathUrlStrategy();
    await NaverMapWebClientIdLoader.load();
  }

  if (NaverMapPlatform.shouldUseNativeMap) {
    await FlutterNaverMap().init(
      clientId: EnvConfig.naverMapClientId,
      onAuthFailed: (ex) {
        switch (ex) {
          case NQuotaExceededException(:final message):
            debugPrint('네이버 지도 사용량 초과: $message');
          case NUnauthorizedClientException() ||
                NClientUnspecifiedException() ||
                NAnotherAuthFailedException():
            debugPrint('네이버 지도 인증 실패: $ex');
        }
      },
    );
  }

  await AuthSession.instance.restore();
  if (!EnvConfig.qcMode) {
    await QcLocalStoragePurge.purgeProductionArtifacts();
  }
  if (!EnvConfig.individualEntry &&
      !EnvConfig.isCorporateBrowseEntry &&
      !AuthSession.instance.isLoggedIn) {
    GuestBrowseIntent.useSeeker();
  }
  if (EnvConfig.individualEntry) {
    GuestBrowseIntent.useSeeker();
    if (AuthSession.instance.isLoggedIn &&
        AuthSession.instance.currentUser?.memberType != MemberType.individual) {
      await AuthSession.instance.signOut();
    }
  }
  if (EnvConfig.isCorporateBrowseEntry) {
    GuestBrowseIntent.useCorporate();
    if (AuthSession.instance.isLoggedIn &&
        AuthSession.instance.currentUser?.memberType != MemberType.corporate) {
      await AuthSession.instance.signOut();
    }
  }
  if (AuthSession.instance.isLoggedIn && EnvConfig.isComplianceApiEnabled) {
    try {
      await QcSyncBootstrap.pullIfEnabled();
    } on QcMemberSanctionException {
      // signOut already handled
    } on Object {
      // offline server — keep local data
    }
  } else if (EnvConfig.isComplianceApiEnabled) {
    await QcSyncBootstrap.pullPublicCatalogIfEnabled();
  }
  await initializePaymentDeepLinks();
  await SubscriptionRenewalService().checkAndApplyExpiry();
  await PushNotificationBootstrap.initializeApp();
  if (AuthSession.instance.isLoggedIn) {
    await PushNotificationBootstrap.bindToSession();
  }

  final initialRoute = _resolveInitialRoute();

  await initializeErrorReporting(() {
    runApp(MapApp(initialRoute: initialRoute));
  });
}

String _resolveInitialRoute() {
  if (kIsWeb) {
    final path = Uri.base.path;
    if (path.contains('auth/social-complete')) {
      return AppRoutes.socialAuthComplete;
    }
    if (path.contains('payment-success')) return AppRoutes.paymentWebSuccess;
    if (path.contains('payment-fail')) return AppRoutes.paymentWebFail;
    if (path.contains('/pricing')) return AppRoutes.publicPricing;
  }
  if (EnvConfig.adminEntry) return AppRoutes.adminHome;
  return AppRoutes.home;
}
