import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:map/core/dev/dev_test_data_seeder.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('ensureSeeded survives corrupt hiring prefs', () async {
    SharedPreferences.setMockInitialValues({
      'hiring_applications_v1': jsonEncode([
        {
          'id': 'legacy_bad',
          'postId': 'p1',
          'postTitle': 'old',
          'companyName': 'c',
          'seekerEmail': 'a@b.c',
          'seekerName': 'n',
          'seekerPhoneMasked': '010',
          'appliedAt': DateTime.now().toIso8601String(),
          'status': 'approved',
          'workSchedule': '09-18',
          'employmentType': 'daily',
        },
      ]),
    });

    await expectLater(DevTestDataSeeder.ensureSeeded(), completes);
  });
}
