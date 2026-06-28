import 'package:http/http.dart' as http;
import 'package:map/core/api/iljari_api_client.dart';

/// Admin 웹 — 네트워크/CORS/API 오류를 짧은 한국어로
abstract final class AdminApiErrors {
  static String format(Object error) {
    if (error is IljariApiException) {
      final body = error.message;
      if (body.contains('401')) {
        return 'Admin API 키가 서버와 일치하지 않습니다. 웹·서버 ADMIN_API_KEY를 확인하세요.';
      }
      if (body.contains('503')) {
        return '서버에 ADMIN_API_KEY가 설정되지 않았습니다.';
      }
      if (body.contains('500')) {
        return '서버 내부 오류입니다. API 재배포·DB 마이그레이션 후 다시 시도하세요.';
      }
      return body;
    }
    if (error is http.ClientException) {
      final uri = error.uri?.toString() ?? '';
      if (uri.contains('api.iljari.app')) {
        return 'api.iljari.app에 연결할 수 없습니다. (네트워크·CORS·서버 다운)\n'
            '브라우저에서 https://api.iljari.app/health 가 열리는지 확인하세요.';
      }
      return error.message;
    }
    return '$error';
  }
}
