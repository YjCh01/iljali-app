import 'package:flutter_test/flutter_test.dart';
import 'package:map/core/api/iljari_api_client.dart';
import 'package:map/core/session/member_type.dart';
import 'package:map/features/auth/domain/utils/auth_error_message.dart';

void main() {
  group('AuthErrorMessage', () {
    test('maps invalid credentials to Korean dialog copy', () {
      final msg = AuthErrorMessage.loginFailure(
        IljariApiException('Unauthorized'),
        memberType: MemberType.corporate,
      );
      expect(msg, contains('이메일 또는 비밀번호'));
      expect(msg, isNot(contains('Unauthorized')));
    });

    test('individual login hints password reset and corporate account', () {
      final msg = AuthErrorMessage.loginFailure(
        IljariApiException('이메일 또는 비밀번호가 올바르지 않습니다.'),
        memberType: MemberType.individual,
      );
      expect(msg, contains('비밀번호 찾기'));
      expect(msg, contains('기업회원'));
    });

    test('maps network errors to Korean', () {
      final msg = AuthErrorMessage.fromObject(
        Exception('ClientException: Failed to fetch'),
      );
      expect(msg, contains('서버 연결'));
    });

    test('phone send maps rate_limited to gentle retry', () {
      final msg = AuthErrorMessage.phoneSendFailure(
        IljariApiException('rate_limited'),
      );
      expect(msg, '잠시 후 다시 시도해 주세요.');
      expect(msg, isNot(contains('60초')));
    });
  });
}
