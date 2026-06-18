import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:map/core/geo/geo_coordinate.dart';
import 'package:map/features/commute/domain/entities/commute_route_stop.dart';
import 'package:map/features/commute/domain/services/shuttle_stop_activation_service.dart';
import 'package:map/features/corporate/domain/entities/corporate_member_profile.dart';
import 'package:map/features/corporate/domain/entities/employer_push_wallet.dart';
import 'package:map/features/corporate/domain/entities/exposure_activation_credit_mode.dart';
import 'package:map/features/corporate/domain/services/exposure_activation_service.dart';
import 'package:map/features/corporate/domain/services/push_wallet_service.dart';

void main() {
  group('ShuttleStopActivationService', () {
    const profile = CorporateMemberProfile(
      companyName: '테스트',
      businessRegistrationNumber: '123',
      department: 'HR',
      contactPersonName: 'Kim',
      handlerCode: '0001',
      pushWallet: EmployerPushWallet(
        packageCredits: 10,
        locationSlotsFromPackages: 10,
        lifetimePackagesPurchased: 10,
      ),
    );

    CommuteRouteStop stop(String id) => CommuteRouteStop(
          id: id,
          label: id,
          coordinate: const GeoCoordinate(latitude: 37.0, longitude: 127.0),
        );

    testWidgets('activateSelectedBatch rejects empty selection', (tester) async {
      ShuttleStopActivationResult? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              WidgetsBinding.instance.addPostFrameCallback((_) async {
                result = await ShuttleStopActivationService().activateSelectedBatch(
                  context: context,
                  profile: profile,
                  routeSelections: const [],
                );
              });
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(result, isNotNull);
      expect(result!.success, isFalse);
      expect(result!.message, contains('선택'));
    });

    testWidgets('activates pending stops across routes with wallet credits',
        (tester) async {
      ShuttleStopActivationResult? result;
      final walletService = PushWalletService();
      final exposureService = _AutoExposureOnlyService(walletService);

      final routeOneStops = [stop('a1'), stop('a2'), stop('a3')];
      final routeTwoStops = [stop('b1'), stop('b2'), stop('b3')];

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              WidgetsBinding.instance.addPostFrameCallback((_) async {
                result = await ShuttleStopActivationService(
                  walletService: walletService,
                  exposureActivationService: exposureService,
                ).activateSelectedBatch(
                  context: context,
                  profile: profile,
                  routeSelections: [
                    (
                      routeId: 'route-one',
                      stops: routeOneStops,
                      selectedStopIds: {'a1', 'a2', 'a3'},
                    ),
                    (
                      routeId: 'route-two',
                      stops: routeTwoStops,
                      selectedStopIds: {'b1', 'b2', 'b3'},
                    ),
                  ],
                );
              });
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(result, isNotNull);
      expect(result!.success, isTrue);
      expect(result!.updatedStopsByRouteId?['route-one'],
          everyElement(predicate<CommuteRouteStop>((s) => s.exposureActivated)));
      expect(result!.updatedStopsByRouteId?['route-two'],
          everyElement(predicate<CommuteRouteStop>((s) => s.exposureActivated)));
    });
  });
}

class _AutoExposureOnlyService extends ExposureActivationService {
  _AutoExposureOnlyService(PushWalletService walletService)
      : super(walletService: walletService);

  @override
  Future<ExposureActivationCreditMode?> pickCreditMode(
    BuildContext context, {
    required EmployerPushWallet wallet,
    String title = '이용권 선택',
    String? subtitle,
  }) async {
    return ExposureActivationCreditMode.exposureOnly;
  }
}
