import 'package:daum_postcode_search/daum_postcode_search.dart';
import 'package:flutter/material.dart';

typedef DaumPostcodeWebCompleteCallback = void Function(DataModel data);

/// Non-web stub — postcode embed is unavailable outside the browser.
class DaumPostcodeWebEmbed extends StatelessWidget {
  const DaumPostcodeWebEmbed({
    super.key,
    required this.onComplete,
    this.onError,
  });

  final DaumPostcodeWebCompleteCallback onComplete;
  final ValueChanged<String>? onError;

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Daum postcode embed is only available on web.'),
    );
  }
}

Future<void> ensureDaumPostcodeScriptLoaded() => Future.value();
