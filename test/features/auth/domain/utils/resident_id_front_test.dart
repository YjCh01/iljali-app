import 'package:flutter_test/flutter_test.dart';
import 'package:map/features/auth/domain/utils/resident_id_front.dart';
import 'package:map/features/job_seeker/domain/entities/seeker_member_profile.dart';

void main() {
  group('ResidentIdFront', () {
    test('validate accepts 7 digits with valid date', () {
      expect(ResidentIdFront.validate('9001011').isValid, isTrue);
      expect(ResidentIdFront.validate('900101-1').isValid, isTrue);
    });

    test('validate rejects incomplete input', () {
      expect(ResidentIdFront.validate('900101').isValid, isFalse);
    });

    test('validate rejects invalid calendar date', () {
      expect(ResidentIdFront.validate('9002311').isValid, isFalse);
    });

    test('parse derives birth date gender and nationality', () {
      final domesticMale = ResidentIdFront.tryParse('9001011');
      expect(domesticMale?.birthDate, DateTime(1990, 1, 1));
      expect(domesticMale?.gender, SeekerGender.male);
      expect(domesticMale?.nationality, SeekerNationality.domestic);

      final domesticFemale2000 = ResidentIdFront.tryParse('0503154');
      expect(domesticFemale2000?.birthDate, DateTime(2005, 3, 15));
      expect(domesticFemale2000?.gender, SeekerGender.female);

      final foreign = ResidentIdFront.tryParse('8801015');
      expect(foreign?.nationality, SeekerNationality.foreign);
    });

    test('formatDisplay inserts hyphen after 6 digits', () {
      expect(ResidentIdFront.formatDisplay('9001011'), '900101-1');
    });
  });
}
