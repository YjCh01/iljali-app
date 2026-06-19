import 'package:daum_postcode_search/daum_postcode_search.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:map/core/address/daum_postcode_picker_native.dart'
    if (dart.library.html) 'package:map/core/address/daum_postcode_picker_native_stub.dart';
import 'package:map/core/address/web/daum_postcode_web_layer.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/widgets/app_back_button.dart';

/// Daum 우편번호 — 모바일 WebView · 웹 DOM embed
class DaumPostcodePickerPage extends StatelessWidget {
  const DaumPostcodePickerPage({super.key});

  static Future<DataModel?> show(BuildContext context) {
    return Navigator.of(context).push<DataModel>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const DaumPostcodePickerPage(),
      ),
    );
  }

  void _onComplete(BuildContext context, DataModel result) {
    Navigator.of(context).pop(result);
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
        title: const Text('주소 검색'),
      ),
      body: kIsWeb
          ? DaumPostcodeWebEmbed(
              onComplete: (result) => _onComplete(context, result),
            )
          : DaumPostcodeNativeEmbed(
              onComplete: (result) => _onComplete(context, result),
            ),
    );
  }
}
