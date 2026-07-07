import 'package:flutter_test/flutter_test.dart';
import 'package:map/core/config/free_exposure_launch_policy.dart';
import 'package:map/features/commute/domain/entities/commute_route_demo.dart';
import 'package:map/features/commute/domain/services/shuttle_overlay_activation_service.dart';
import 'package:map/features/corporate/data/datasources/corporate_job_post_local_data_source.dart';
import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';
import 'package:map/features/corporate/domain/entities/corporate_member_profile.dart';
import 'package:map/features/corporate/domain/entities/employer_push_wallet.dart';
import 'package:map/features/corporate/domain/entities/exposure_activation_credit_mode.dart';
import 'package:map/features/corporate/domain/entities/exposure_activation_source.dart';
import 'package:map/features/corporate/domain/services/exposure_activation_service.dart';
import 'package:map/features/job_seeker/domain/entities/job_map_pin_display_tier.dart';

void main() {
  group('ShuttleOverlayActivationService', () {
    const profile = CorporateMemberProfile(
      companyName: '테스트',
      businessRegistrationNumber: '123',
      department: 'HR',
      contactPersonName: 'Kim',
      handlerCode: '0001',
      pushWallet: EmployerPushWallet(
        packageCredits: 2,
        locationSlotsFromPackages: 2,
        lifetimePackagesPurchased: 2,
      ),
    );

    CorporateJobPost basePost({
      bool overlay = false,
      String? routeId,
      bool noRoute = false,
    }) {
      return CorporateJobPost(
        id: 'post-overlay-1',
        title: '물류',
        warehouseName: '센터',
        hourlyWage: '10,000원',
        workSchedule: '09-18',
        summary: 'x',
        status: CorporateJobPostStatus.recruiting,
        applicantCount: 0,
        postedAt: DateTime(2026, 6, 1),
        registeredBy: profile,
        mapPinDisplayTier: JobMapPinDisplayTier.standard,
        commuteRouteId:
            noRoute ? null : (routeId ?? CommuteRouteDemoIds.daisoSejong),
        hasShuttleRouteOverlay: overlay,
      );
    }

    setUp(() {
      CorporateJobPostLocalDataSourceImpl.clearInMemoryStoreForTest();
      FreeExposureLaunchPolicy.resetCache();
      FreeExposureLaunchPolicy.forceInactiveForTest();
    });

    test('rejects when no commute route is connected', () async {
      final service = ShuttleOverlayActivationService();
      final result = await service.activate(
        post: basePost(noRoute: true),
        profile: profile,
        mode: ExposureActivationCreditMode.exposureOnly,
      );

      expect(result.success, isFalse);
      expect(result.message, contains('노선'));
      expect(result.needsShop, isFalse);
    });

    test('rejects when overlay is already active', () async {
      final service = ShuttleOverlayActivationService();
      final result = await service.activate(
        post: basePost(overlay: true),
        profile: profile,
        mode: ExposureActivationCreditMode.exposureOnly,
      );

      expect(result.success, isFalse);
      expect(result.message, contains('이미'));
    });

    test('activates overlay with exposure-only credit', () async {
      const dataSource = CorporateJobPostLocalDataSourceImpl();
      final post = basePost();
      await dataSource.createJobPost(post);

      final service = ShuttleOverlayActivationService(
        dataSource: dataSource,
        exposureActivationService: ExposureActivationService(),
      );

      final result = await service.activate(
        post: post,
        profile: profile,
        mode: ExposureActivationCreditMode.exposureOnly,
      );

      expect(result.success, isTrue);
      expect(result.updatedPost?.hasShuttleRouteOverlay, isTrue);
      expect(
        result.updatedPost?.shuttleOverlayActivationSource,
        ExposureActivationSource.credit,
      );
      expect(result.includedPushTarget, isNull);

      final stored = await dataSource.findById(post.id);
      expect(stored?.hasShuttleRouteOverlay, isTrue);
    });
  });
}
