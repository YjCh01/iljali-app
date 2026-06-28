import 'package:web/web.dart' as web;

Future<bool> openExternalUrl(String url) async {
  if (url.trim().isEmpty) return false;
  web.window.open(url, '_blank');
  return true;
}
