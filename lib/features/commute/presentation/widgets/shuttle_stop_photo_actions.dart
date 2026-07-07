import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:map/features/commute/domain/utils/shuttle_stop_photo_storage.dart';

/// 정류장 안내 사진 — 갤러리에서 선택 후 로컬 저장
abstract final class ShuttleStopPhotoActions {
  static Future<String?> pickFromGallery(BuildContext context) async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1280,
      imageQuality: 82,
    );
    if (file == null) return null;
    return ShuttleStopPhotoStorage.persistFromPicker(file);
  }
}
