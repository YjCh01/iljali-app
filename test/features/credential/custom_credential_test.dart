import 'package:flutter_test/flutter_test.dart';
import 'package:map/features/credential/domain/custom_credential_support.dart';
import 'package:map/features/job_seeker/domain/entities/seeker_credential_holding.dart';

void main() {
  test('custom credential round-trip json', () {
    const holding = SeekerCredentialHolding(
      credentialId: 'custom_123',
      customLabel: '바리스타 자격증',
      imagePath: '/path/photo.jpg',
    );
    final restored = SeekerCredentialHolding.fromJson(holding.toJson());
    expect(restored.credentialId, 'custom_123');
    expect(restored.customLabel, '바리스타 자격증');
    expect(CustomCredentialSupport.displayLabel(restored), '바리스타 자격증');
  });
}
