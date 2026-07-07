import 'package:map/core/session/member_type.dart';
import 'package:map/core/api/iljari_api_client.dart';

/// 인증 API·폼 오류 → 사용자용 한국어 메시지
abstract final class AuthErrorMessage {
  static String fromObject(Object error) {
    if (error is IljariApiException) {
      return loginFailure(error);
    }
    if (error is ArgumentError) {
      final msg = error.message?.toString().trim();
      if (msg != null && msg.isNotEmpty) {
        return _sanitizeRaw(msg);
      }
    }
    return _sanitizeRaw(error.toString());
  }

  static String loginFailure(
    IljariApiException error, {
    MemberType? memberType,
  }) {
    final message = error.message.trim();
    if (_isInvalidCredentials(message)) {
      if (memberType == MemberType.individual) {
        return '이메일 또는 비밀번호가 올바르지 않습니다.\n'
            '비밀번호 찾기를 이용하거나, 기업회원으로 가입했는지 확인해 주세요.';
      }
      return '이메일 또는 비밀번호가 올바르지 않습니다.\n'
          '입력한 정보를 다시 확인해 주세요.';
    }
    if (message.contains('이용 제한')) {
      return message;
    }
    if (message.contains('기업회원')) {
      return message;
    }
    if (message.contains('개인회원')) {
      return message;
    }
    final sanitized = _sanitizeRaw(message);
    return sanitized.isNotEmpty ? sanitized : '로그인에 실패했습니다.';
  }

  static bool _isInvalidCredentials(String message) {
    final lower = message.toLowerCase();
    return message.contains('이메일 또는 비밀번호') ||
        lower.contains('invalid credentials') ||
        lower.contains('incorrect password') ||
        lower.contains('wrong password') ||
        lower.contains('unauthorized') ||
        message.contains('401');
  }

  static String _sanitizeRaw(String raw) {
    var message = raw.trim();
    if (message.isEmpty) return '로그인에 실패했습니다.';

    if (message.contains('Failed to fetch') ||
        message.contains('ClientException') ||
        message.contains('SocketException') ||
        message.contains('Connection refused')) {
      return '서버 연결에 실패했습니다. 네트워크 연결을 확인해 주세요.';
    }

    for (final prefix in [
      'ArgumentError: ',
      'IljariApiException: ',
      'StateError: ',
      'Exception: ',
    ]) {
      if (message.startsWith(prefix)) {
        message = message.substring(prefix.length).trim();
      }
    }

    if (_isInvalidCredentials(message)) {
      return '이메일 또는 비밀번호가 올바르지 않습니다.\n'
          '입력한 정보를 다시 확인해 주세요.';
    }

    return message.isNotEmpty ? message : '로그인에 실패했습니다.';
  }

  /// 휴대폰 인증번호 발송 실패 (가입·찾기·비밀번호 재설정 공통)
  static String phoneSendFailure(Object error) {
    if (error is IljariApiException) {
      final message = error.message.trim();
      if (message == 'rate_limited' || message.contains('잠시 후')) {
        return '잠시 후 다시 시도해 주세요.';
      }
      if (message.startsWith('sms_failed:')) {
        return '문자 발송에 실패했습니다. 잠시 후 다시 시도해 주세요.';
      }
      if (message == 'invalid_phone') {
        return '휴대폰 번호를 확인해 주세요.';
      }
      final sanitized = _sanitizeRaw(message);
      if (sanitized != '로그인에 실패했습니다.') return sanitized;
    }
    return '인증번호 발송에 실패했습니다.';
  }
}
