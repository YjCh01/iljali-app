import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

/// 정류장 안내 사진 — 로컬 저장
abstract final class ShuttleStopPhotoStorage {
  static Future<String?> persistFromPicker(XFile file) async {
    final dir = await getApplicationDocumentsDirectory();
    final shuttleDir = Directory('${dir.path}/shuttle_stops');
    if (!await shuttleDir.exists()) {
      await shuttleDir.create(recursive: true);
    }
    final name = 'stop_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final dest = File('${shuttleDir.path}/$name');
    await File(file.path).copy(dest.path);
    return dest.path;
  }
}
