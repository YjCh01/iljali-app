import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:map/core/branding/iljari_icon_painter.dart';

/// 1024px 마스터 아이콘 PNG 생성
/// 실행: flutter test tool/export_app_icon_test.dart
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> export({
    required String path,
    required IljariIconPainter painter,
  }) async {
    const size = 1024.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    painter.paint(canvas, const Size(size, size));
    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    expect(byteData, isNotNull);

    final output = File(path);
    await output.parent.create(recursive: true);
    await output.writeAsBytes(byteData!.buffer.asUint8List());
    expect(output.existsSync(), isTrue);
  }

  test('export app icon png assets', () async {
    await export(
      path: 'assets/icon/app_icon_1024.png',
      painter: const IljariIconPainter(),
    );
    await export(
      path: 'assets/icon/app_icon_foreground_1024.png',
      painter: const IljariIconPainter(transparentBackground: true),
    );
  });
}
