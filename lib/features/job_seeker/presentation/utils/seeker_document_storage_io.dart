import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

Future<String?> persistSeekerDocumentImage(XFile file, String kind) async {
  final dir = await getApplicationDocumentsDirectory();
  final docsDir = Directory('${dir.path}/seeker_docs');
  if (!await docsDir.exists()) {
    await docsDir.create(recursive: true);
  }
  final ext = file.path.toLowerCase().endsWith('.png') ? '.png' : '.jpg';
  final name = '${kind}_${DateTime.now().millisecondsSinceEpoch}$ext';
  final dest = File('${docsDir.path}/$name');
  await File(file.path).copy(dest.path);
  return dest.path;
}
