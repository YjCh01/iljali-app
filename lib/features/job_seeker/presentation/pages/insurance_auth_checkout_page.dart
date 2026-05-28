import 'dart:async';

import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/hiring/insurance_auth_deep_link_handler.dart';
import 'package:map/core/widgets/app_back_button.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Barocert/PortOne 간편인증 WebView
class InsuranceAuthCheckoutPage extends StatefulWidget {
  const InsuranceAuthCheckoutPage({
    super.key,
    required this.authUrl,
    required this.sessionId,
  });

  final String authUrl;
  final String sessionId;

  @override
  State<InsuranceAuthCheckoutPage> createState() =>
      _InsuranceAuthCheckoutPageState();
}

class _InsuranceAuthCheckoutPageState extends State<InsuranceAuthCheckoutPage> {
  late final WebViewController _controller;
  bool _done = false;
  StreamSubscription<Uri>? _deepLinkSub;

  @override
  void initState() {
    super.initState();
    _deepLinkSub = InsuranceAuthDeepLinkHandler.stream.listen((uri) {
      final sessionId = uri.queryParameters['session_id'];
      if (sessionId != null && sessionId != widget.sessionId) return;

      if (uri.path.contains('success') || uri.host.contains('success')) {
        _finish(success: true);
      } else if (uri.path.contains('fail') || uri.host.contains('fail')) {
        _finish(success: false);
      }
    });

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            final url = request.url;
            if (url.startsWith('iljari://insurance-auth/success')) {
              _finish(success: true);
              return NavigationDecision.prevent;
            }
            if (url.startsWith('iljari://insurance-auth/fail')) {
              _finish(success: false);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.authUrl));
  }

  @override
  void dispose() {
    _deepLinkSub?.cancel();
    super.dispose();
  }

  void _finish({required bool success}) {
    if (_done) return;
    _done = true;
    if (mounted) Navigator.of(context).pop(success);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        leading: const AppBackButton(),
        automaticallyImplyLeading: false,
        title: const Text('간편인증'),
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}
