import 'package:flutter_test/flutter_test.dart';
import 'package:map/core/api/iljari_api_client.dart';
import 'package:map/features/auth/data/repositories/individual_auth_repository.dart';

void main() {
  group('IndividualAuthRepository helpers', () {
    test('rejects corporate member type on individual login', () {
      expect(
        () => IndividualAuthRepository.ensureIndividualMemberTypeForTest({
          'member_type': 'corporate',
        }),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('기업회원'),
          ),
        ),
      );
    });

    test('allows seeker member type', () {
      expect(
        () => IndividualAuthRepository.ensureIndividualMemberTypeForTest({
          'member_type': 'seeker',
        }),
        returnsNormally,
      );
    });

    test('login error message hints password and member type', () {
      final msg = IndividualAuthRepository.loginErrorMessageForTest(
        IljariApiException('이메일 또는 비밀번호가 올바르지 않습니다.'),
      );
      expect(msg, contains('비밀번호 찾기'));
      expect(msg, contains('기업회원'));
    });
  });
}
