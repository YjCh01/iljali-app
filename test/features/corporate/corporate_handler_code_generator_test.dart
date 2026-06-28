import 'package:flutter_test/flutter_test.dart';
import 'package:map/features/corporate/domain/utils/corporate_handler_code_generator.dart';

void main() {
  test('CorporateHandlerCodeGenerator issues 6-char alphanumeric codes', () {
    final code = CorporateHandlerCodeGenerator.nextCode([]);
    expect(code.length, CorporateHandlerCodeGenerator.codeLength);
    expect(RegExp(r'^[A-Z0-9]+$').hasMatch(code), isTrue);
    expect(code.contains('0'), isFalse);
    expect(code.contains('O'), isFalse);
  });

  test('CorporateHandlerCodeGenerator avoids collisions within company', () {
    final first = CorporateHandlerCodeGenerator.nextCode([]);
    final second = CorporateHandlerCodeGenerator.nextCode([first]);
    expect(second, isNot(first));

    final third = CorporateHandlerCodeGenerator.nextCode([first, second]);
    expect(third, isNot(first));
    expect(third, isNot(second));
  });

  test('CorporateHandlerCodeGenerator treats codes case-insensitively', () {
    final code = CorporateHandlerCodeGenerator.nextCode(['abc123']);
    expect(code.toUpperCase(), isNot('ABC123'));
  });
}
