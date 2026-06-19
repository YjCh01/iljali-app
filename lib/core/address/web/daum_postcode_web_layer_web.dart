import 'dart:async';
import 'dart:html' as html;
import 'dart:js_util' as js_util;
import 'dart:ui_web' as ui_web;

import 'package:daum_postcode_search/daum_postcode_search.dart';
import 'package:flutter/material.dart';

typedef DaumPostcodeWebCompleteCallback = void Function(DataModel data);

Future<void>? _scriptLoadFuture;

Future<void> ensureDaumPostcodeScriptLoaded() {
  if (_scriptLoadFuture != null) return _scriptLoadFuture!;
  _scriptLoadFuture = _loadScript();
  return _scriptLoadFuture!;
}

Future<void> _loadScript() {
  if (_isPostcodeReady()) return Future.value();

  final existing = html.document.querySelector('script[data-iljari-daum-postcode]');
  if (existing != null && _isPostcodeReady()) {
    return Future.value();
  }

  final completer = Completer<void>();
  final script = html.ScriptElement()
    ..type = 'text/javascript'
    ..src =
        'https://t1.kakaocdn.net/mapjsapi/bundle/postcode/prod/postcode.v2.js';
  script.dataset['iljari-daum-postcode'] = '1';
  script.onLoad.listen((_) {
    if (!completer.isCompleted) completer.complete();
  });
  script.onError.listen((_) {
    if (!completer.isCompleted) {
      completer.completeError(Exception('Daum Postcode JS load failed'));
    }
  });
  html.document.head!.append(script);
  return completer.future;
}

bool _isPostcodeReady() {
  final kakao = js_util.getProperty<Object?>(html.window, 'kakao');
  if (kakao == null) return false;
  return js_util.getProperty<Object?>(kakao, 'Postcode') != null;
}

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

  @override
  void initState() {
    super.initState();
    _registerView();
  }

  Future<void> _registerView() async {
    try {
      await ensureDaumPostcodeScriptLoaded();
      if (!mounted) return;

      final viewType = 'iljari-daum-postcode-${_viewCounter++}';
      ui_web.platformViewRegistry.registerViewFactory(viewType, (int _) {
        final container = html.DivElement()
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.margin = '0'
          ..style.padding = '0';

        _embedPostcode(container);
        return container;
      });

      setState(() {
        _viewType = viewType;
        _loading = false;
        _errorMessage = null;
      });
    } on Object catch (error) {
      if (!mounted) return;
      final message = error.toString();
      setState(() {
        _loading = false;
        _errorMessage = message;
      });
      widget.onError?.call(message);
    }
  }

  void _embedPostcode(html.DivElement container) {
    final kakao = js_util.getProperty<Object>(html.window, 'kakao');
    final postcodeCtor = js_util.getProperty<Object>(kakao, 'Postcode');
    final options = js_util.jsify({
      'oncomplete': js_util.allowInterop((dynamic data) {
        final dartified = js_util.dartify(data);
        if (dartified is! Map) return;
        final model = DaumPostcodeCallbackParser.fromMap(
          Map<String, dynamic>.from(dartified),
        );
        if (model != null) widget.onComplete(model);
      }),
      'width': '100%',
      'height': '100%',
      'maxSuggestItems': 5,
      'hideMapBtn': true,
      'hideEngBtn': false,
    });
    final postcode = js_util.callConstructor(postcodeCtor, [options]);
    js_util.callMethod(postcode, 'embed', [container]);
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _errorMessage!,
            textAlign: TextAlign.center,
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
