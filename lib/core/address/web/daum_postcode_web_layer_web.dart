import 'dart:async';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:daum_postcode_search/daum_postcode_search.dart';
import 'package:flutter/material.dart';

typedef DaumPostcodeWebCompleteCallback = void Function(DataModel data);

/// 웹 — 앱과 동일한 postcode.v2.js HTML을 iframe으로 로드
class DaumPostcodeWebEmbed extends StatefulWidget {
  const DaumPostcodeWebEmbed({
    super.key,
    required this.onComplete,
    this.onError,
  });

  final DaumPostcodeWebCompleteCallback onComplete;
  final ValueChanged<String>? onError;

  @override
  State<DaumPostcodeWebEmbed> createState() => _DaumPostcodeWebEmbedState();
}

class _DaumPostcodeWebEmbedState extends State<DaumPostcodeWebEmbed> {
  static int _viewCounter = 0;

  String? _viewType;
  bool _loading = true;
  String? _errorMessage;
  StreamSubscription<html.MessageEvent>? _messageSub;

  @override
  void initState() {
    super.initState();
    _messageSub = html.window.onMessage.listen(_onWindowMessage);
    _registerView();
  }

  void _onWindowMessage(html.MessageEvent event) {
    final data = event.data;
    if (data is! String || data.isEmpty) return;

    try {
      final result = DaumPostcodeCallbackParser.fromPostMessage(data);
      if (result != null) widget.onComplete(result);
    } on Object catch (error) {
      widget.onError?.call(error.toString());
    }
  }

  void _registerView() {
    try {
      final viewType = 'iljari-address-search-${_viewCounter++}';
      ui_web.platformViewRegistry.registerViewFactory(viewType, (int _) {
        final iframe = html.IFrameElement()
          ..src = '/address_search.html'
          ..style.border = '0'
          ..style.width = '100%'
          ..style.height = '100%'
          ..allowFullscreen = true;

        iframe.onError.listen((_) {
          widget.onError?.call('주소 검색 페이지를 불러오지 못했습니다.');
        });

        return iframe;
      });

      setState(() {
        _viewType = viewType;
        _loading = false;
        _errorMessage = null;
      });
    } on Object catch (error) {
      setState(() {
        _loading = false;
        _errorMessage = error.toString();
      });
      widget.onError?.call(error.toString());
    }
  }

  @override
  void dispose() {
    _messageSub?.cancel();
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
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 12),
              const Text(
                '주소 검색을 불러오지 못했습니다',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  setState(() {
                    _errorMessage = null;
                    _loading = true;
                    _viewType = null;
                  });
                  _registerView();
                },
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      );
    }

    if (_loading || _viewType == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return HtmlElementView(viewType: _viewType!);
  }
}

Future<void> ensureDaumPostcodeScriptLoaded() => Future.value();
