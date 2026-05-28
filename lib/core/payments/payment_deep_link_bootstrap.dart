import 'package:app_links/app_links.dart';
import 'package:map/core/hiring/insurance_auth_deep_link_handler.dart';
import 'package:map/core/payments/payment_deep_link_handler.dart';

/// 앱 cold/warm start 시 결제·건강보험 간편인증 딥링크 수신
Future<void> initializePaymentDeepLinks() async {
  final appLinks = AppLinks();

  final initial = await appLinks.getInitialLink();
  if (initial != null) {
    _dispatchAll(initial);
  }

  appLinks.uriLinkStream.listen(_dispatchAll);
}

void _dispatchAll(Uri uri) {
  PaymentDeepLinkHandler.dispatch(uri);
  InsuranceAuthDeepLinkHandler.dispatch(uri);
}
