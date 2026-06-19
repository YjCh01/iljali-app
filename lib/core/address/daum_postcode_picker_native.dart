import 'package:daum_postcode_search/daum_postcode_search.dart';
import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:webview_flutter/webview_flutter.dart';

typedef DaumPostcodeNativeCompleteCallback = void Function(DataModel data);

/// Daum 우편번호 — Android/iOS WebView embed
class DaumPostcodeNativeEmbed extends StatefulWidget {
  const DaumPostcodeNativeEmbed({
    super.key,
    required this.onComplete,
    this.onError,
  });

  final DaumPostcodeNativeCompleteCallback onComplete;
  final ValueChanged<String>? onError;

  @override
  State<DaumPostcodeNativeEmbed> createState() => _DaumPostcodeNativeEmbedState();
}

class _DaumPostcodeNativeEmbedState extends State<DaumPostcodeNativeEmbed> {
  final _server = DaumPostcodeLocalServer();
  WebViewController? _controller;
  bool _ready = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _startServer();
  }

  Future<void> _startServer() async {
    try {
      await _server.start();
      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..addJavaScriptChannel(
          'DaumPostcodeChannel',
          onMessageReceived: (JavaScriptMessage message) {
            final result =
                DaumPostcodeCallbackParser.fromPostMessage(message.message);
            if (result != null) widget.onComplete(result);
          },
        )
        ..setNavigationDelegate(
          NavigationDelegate(
            onWebResourceError: (error) {
              if (!mounted) return;
              final message = error.description;
              setState(() {
                _errorMessage = message;
                _ready = false;
              });
              widget.onError?.call(message);
            },
          ),
        )
        ..loadRequest(
          Uri.parse('${_server.url}/${DaumPostcodeAssets.jsChannel}'),
        );

      if (!mounted) return;
      setState(() {
        _controller = controller;
        _ready = true;
        _errorMessage = null;
      });
    } on Object catch (error) {
      if (!mounted) return;
      final message = error.toString();
      setState(() {
        _errorMessage = message;
        _ready = false;
      });
      widget.onError?.call(message);
    }
  }

  @override
  void dispose() {
    _server.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: AppColors.primary, size: 48),
              const SizedBox(height: 12),
              Text(
                '주소 검색을 불러오지 못했습니다',
                style: TextStyle(
                  color: AppColors.textPrimary.withValues(alpha: 0.95),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary.withValues(alpha: 0.95),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  setState(() {
                    _errorMessage = null;
                    _ready = false;
                    _controller = null;
                  });
                  _startServer();
                },
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      );
    }

    if (!_ready || _controller == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return WebViewWidget(controller: _controller!);
  }
}
