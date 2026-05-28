import 'dart:async';

/// 간편인증 완료 딥링크 (`iljari://insurance-auth/success?session_id=...`)
abstract final class InsuranceAuthDeepLinkHandler {
  static final _controller = StreamController<Uri>.broadcast();

  static Stream<Uri> get stream => _controller.stream;

  static void dispatch(Uri uri) {
    if (uri.scheme != 'iljari') return;
    if (!uri.host.contains('insurance-auth')) return;
    _controller.add(uri);
  }
}
