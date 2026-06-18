import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:map/core/dev/dev_auth_service.dart';
import 'package:map/core/dev/dev_test_accounts.dart';
import 'package:map/core/dev/dev_test_data_seeder.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/features/corporate/data/datasources/corporate_job_post_local_data_source.dart';
import 'package:map/features/corporate/presentation/pages/corporate_home_shell_page.dart';
import 'package:map/features/corporate/presentation/widgets/corporate_bottom_nav.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    CorporateJobPostLocalDataSourceImpl.clearInMemoryStoreForTest();
    await AuthSession.instance.signOut();
  });

  testWidgets('dev corp alpha job posts tab finishes loading', (tester) async {
    await DevAuthService.signIn(DevTestAccounts.corpAlpha);
    await tester.pumpWidget(const MaterialApp(home: CorporateHomeShellPage()));
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    final icons = find.descendant(of: find.byType(CorporateBottomNav), matching: find.byType(Icon));
    await tester.tap(icons.at(1));
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.textContaining('[테스트]'), findsWidgets);
  });
}
