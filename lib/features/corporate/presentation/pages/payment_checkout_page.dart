import 'dart:async';

import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/payments/payment_deep_link_handler.dart';
import 'package:map/core/widgets/app_back_button.dart';
import 'package:map/features/corporate/domain/entities/payment_request.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// PG checkout WebView — Toss 등 redirect 결제
class PaymentCheckoutPage extends StatefulWidget {
  const PaymentCheckoutPage({
    super.key,
    required this.checkoutUrl,
    required this.request,
    this.onSuccess,
    this.onFailure,
  });

  final String checkoutUrl;
  final PaymentRequest request;
  final void Function(String paymentKey)? onSuccess;
  final VoidCallback? onFailure;

  @override
  State<PaymentCheckoutPage> createState() => _PaymentCheckoutPageState();
}

class _PaymentCheckoutPageState extends State<PaymentCheckoutPage> {
  late final WebViewController _controller;
  bool _done = false;
  StreamSubscription<Uri>? _deepLinkSub;

  @override
  void initState() {
    super.initState();
    _deepLinkSub = PaymentDeepLinkHandler.stream.listen((uri) {
      if (uri.host != 'payment') return;
      if (uri.pathSegments.contains('success') ||
          uri.path == '/success' ||
          uri.toString().contains('success')) {
        _finishSuccess(uri.toString());
      } else if (uri.pathSegments.contains('fail') ||
          uri.path == '/fail' ||
          uri.toString().contains('fail')) {
        _finishFailure();
      }
    });
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            final url = request.url;
            if (url.startsWith('iljari://payment/success')) {
              _finishSuccess(url);
              return NavigationDecision.prevent;
            }
            if (url.startsWith('iljari://payment/fail')) {
              _finishFailure();
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.checkoutUrl));
  }

  @override
  void dispose() {
    _deepLinkSub?.cancel();
    super.dispose();
  }

  void _finishSuccess(String url) {
    if (_done) return;
    _done = true;
    final uri = Uri.parse(url);
    final paymentKey = uri.queryParameters['paymentKey'] ??
        uri.queryParameters['paymentKey'] ??
        'confirmed-${widget.request.orderId}';
    widget.onSuccess?.call(paymentKey);
    if (mounted) Navigator.of(context).pop(paymentKey);
  }

  void _finishFailure() {
    if (_done) return;
    _done = true;
    widget.onFailure?.call();
    if (mounted) Navigator.of(context).pop(null);
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
        title: const Text('결제'),
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}
