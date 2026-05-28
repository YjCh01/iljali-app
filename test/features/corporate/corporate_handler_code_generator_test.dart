import 'package:flutter_test/flutter_test.dart';
import 'package:map/features/corporate/domain/utils/corporate_handler_code_generator.dart';

void main() {
  test('CorporateHandlerCodeGenerator assigns sequential 4-digit codes', () {
    expect(CorporateHandlerCodeGenerator.nextCode([]), '1001');
    expect(
      CorporateHandlerCodeGenerator.nextCode(['1001']),
      '1002',
    );
    expect(
      CorporateHandlerCodeGenerator.nextCode(['1001', '1002', '1004']),
      '1003',
    );
  });
}
