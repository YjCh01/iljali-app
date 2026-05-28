import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:map/features/corporate/domain/entities/payment_method.dart';
import 'package:map/features/corporate/domain/entities/payment_method_option.dart';
import 'package:map/features/corporate/domain/entities/push_notification_settings.dart';
import 'package:map/features/corporate/presentation/pages/corporate_notification_payment_page.dart';
import 'package:map/features/corporate/presentation/widgets/payment/payment_method_list_tile.dart';
import 'package:map/features/corporate/presentation/widgets/payment/payment_method_selection_section.dart';

void main() {
  group('PaymentMethodCatalog', () {
    test('includes PAYCO and Naver-first checkout order', () {
      expect(
        PaymentMethodCatalog.checkoutOrder.first,
        PaymentMethod.naverPay,
      );
      expect(
        PaymentMethodCatalog.checkoutOptions.map((o) => o.method),
        contains(PaymentMethod.payco),
      );
    });
  });

  group('PaymentMethodListTile', () {
    testWidgets('shows selected check indicator on the left', (tester) async {
      final option = PaymentMethodCatalog.byMethod(PaymentMethod.naverPay);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PaymentMethodListTile(
              option: option,
              selected: true,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('네이버페이'), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    });
  });

  group('PaymentMethodSelectionSection', () {
    testWidgets('expands when tapping 다른 결제수단 선택', (tester) async {
      var selected = PaymentMethod.naverPay;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return PaymentMethodSelectionSection(
                  selectedMethod: selected,
                  onMethodSelected: (method) =>
                      setState(() => selected = method),
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('카카오페이'), findsNothing);

      await tester.tap(find.text('다른 결제수단 선택'));
      await tester.pumpAndSettle();

      expect(find.text('카카오페이'), findsOneWidget);
      expect(find.text('PAYCO'), findsOneWidget);
    });
  });

  group('CorporateNotificationPaymentPage', () {
    testWidgets('renders vertical payment method list and total amount',
        (tester) async {
      const bundle = PushPaymentBundle.extraPush(feeKrw: 3300);

      await tester.pumpWidget(
        const MaterialApp(
          home: CorporateNotificationPaymentPage(bundle: bundle),
        ),
      );

      expect(find.text('결제수단'), findsOneWidget);
      expect(find.text('네이버페이'), findsOneWidget);
      expect(find.text('총 결제금액'), findsOneWidget);
      expect(find.text('3,300원'), findsWidgets);
      expect(find.text('지원자 모집하기 (add-on)'), findsOneWidget);
    });

    testWidgets('selects a different payment method from expanded list',
        (tester) async {
      const bundle = PushPaymentBundle.extraPush(feeKrw: 3300);

      await tester.pumpWidget(
        const MaterialApp(
          home: CorporateNotificationPaymentPage(bundle: bundle),
        ),
      );

      await tester.tap(find.text('다른 결제수단 선택'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('카카오페이'));
      await tester.tap(find.text('카카오페이'));
      await tester.pumpAndSettle();

      expect(find.textContaining('카카오페이 결제'), findsOneWidget);
    });
  });
}
