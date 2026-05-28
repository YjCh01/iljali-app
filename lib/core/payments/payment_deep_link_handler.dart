import 'dart:async';

/// PG 결제 완료 딥링크 (`iljari://payment/success?paymentKey=...`)
abstract final class PaymentDeepLinkHandler {
  static final _controller = StreamController<Uri>.broadcast();

  static Stream<Uri> get stream => _controller.stream;

  static void dispatch(Uri uri) {
    if (uri.scheme != 'iljari') return;
    _controller.add(uri);
  }

  static Future<void> initialize() async {
    // app_links는 main.dart에서 listen 후 dispatch 호출
  }
}
