import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:map/core/branding/iljari_icon_painter.dart';

void main() {
  testWidgets('IljariAppIcon renders logo elements', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: IljariAppIcon(size: 200),
          ),
        ),
      ),
    );

    expect(find.byType(IljariAppIcon), findsOneWidget);
  });
}
