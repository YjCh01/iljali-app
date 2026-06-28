import 'dart:convert';

import 'package:image_picker/image_picker.dart';

Future<String?> persistSeekerDocumentImage(XFile file, String kind) async {
  final bytes = await file.readAsBytes();
  final mime = file.name.toLowerCase().endsWith('.png')
      ? 'image/png'
      : 'image/jpeg';
  return 'data:$mime;base64,${base64Encode(bytes)}';
}
