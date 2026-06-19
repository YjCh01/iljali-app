import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:map/app.dart';
import 'package:map/core/config/env_config.dart';
import 'package:map/core/constants/app_routes.dart';
import 'package:map/core/utils/naver_map_platform.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/core/payments/payment_deep_link_bootstrap.dart';
import 'package:map/core/compliance/services/subscription_renewal_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
  await initializePaymentDeepLinks();
  await SubscriptionRenewalService().checkAndApplyExpiry();

  runApp(
    MapApp(
      initialRoute: AuthSession.instance.isLoggedIn
          ? AppRoutes.home
          : AppRoutes.memberGateway,
    ),
  );
}