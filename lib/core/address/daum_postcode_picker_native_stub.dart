import 'package:daum_postcode_search/daum_postcode_search.dart';
import 'package:flutter/material.dart';

typedef DaumPostcodeNativeCompleteCallback = void Function(DataModel data);

/// Stub — native WebView postcode is unavailable on web builds.
class DaumPostcodeNativeEmbed extends StatelessWidget {
  const DaumPostcodeNativeEmbed({
    super.key,
    required this.onComplete,
    this.onError,
  });

  final DaumPostcodeNativeCompleteCallback onComplete;
  final ValueChanged<String>? onError;

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
