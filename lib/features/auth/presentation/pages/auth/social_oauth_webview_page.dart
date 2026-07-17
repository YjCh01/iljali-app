import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/features/auth/domain/entities/social_provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// 네이티브(모바일) 소셜 로그인 — 앱 내 WebView로 OAuth를 진행하고, 서버가
/// 최종적으로 [socialAppRedirectUrl]로 리다이렉트하는 순간을 가로채 쿼리파라미터를
/// 반환한다(그 페이지 자체는 웹뷰에 로드하지 않음).
class SocialOAuthWebviewPage extends StatefulWidget {
  const SocialOAuthWebviewPage({
    super.key,
    required this.startUrl,
    required this.provider,
  });

  final String startUrl;
  final SocialProvider provider;

  @override
  State<SocialOAuthWebviewPage> createState() => _SocialOAuthWebviewPageState();
}

class _SocialOAuthWebviewPageState extends State<SocialOAuthWebviewPage> {
  late final WebViewController _controller;
  bool _loading = true;
  String? _errorMessage;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            if (request.url.startsWith(socialAppRedirectUrl())) {
              _finish(request.url);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onPageStarted: (_) {
            if (mounted) setState(() => _loading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onWebResourceError: (error) {
            if (!mounted) return;
            setState(() {
              _loading = false;
              _errorMessage = '${widget.provider.label} 로그인 화면을 불러오지 못했습니다.';
            });
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.startUrl));
  }

  void _finish(String redirectUrl) {
    if (_finished) return;
    _finished = true;
    final params = Uri.parse(redirectUrl).queryParameters;
    Navigator.of(context).pop(params);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        title: Text('${widget.provider.label} 로그인'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _errorMessage != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: AppColors.primary,
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13, height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('닫기'),
                    ),
                  ],
                ),
              ),
            )
          : Stack(
              children: [
                WebViewWidget(controller: _controller),
                if (_loading) const Center(child: CircularProgressIndicator()),
              ],
            ),
    );
  }
}
