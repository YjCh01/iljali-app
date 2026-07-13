import 'package:flutter/material.dart';
import 'package:map/core/theme/app_theme.dart';
import 'package:map/features/design/presentation/pages/pin_visual_verify_page.dart';

void main() {
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const PinVisualVerifyPage(),
    ),
  );
}
