import 'package:flutter/material.dart';
import 'package:map/core/config/product_feature_flags.dart';
import 'package:map/core/constants/app_routes.dart';
import 'package:map/core/constants/app_strings.dart';
import 'package:map/core/session/member_type.dart';
import 'package:map/core/theme/app_theme.dart';
import 'package:map/features/admin/presentation/pages/admin_compliance_dashboard_page.dart';
import 'package:map/features/auth/presentation/pages/auth/login_page.dart';
import 'package:map/features/auth/presentation/pages/auth/member_login_gateway_page.dart';
import 'package:map/features/auth/presentation/pages/auth/signup_page.dart';
import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';
import 'package:map/features/corporate/domain/entities/job_post_write_draft.dart';
import 'package:map/features/corporate/presentation/pages/corporate_create_job_post_page.dart';
import 'package:map/features/corporate/presentation/pages/corporate_edit_job_post_page.dart';
import 'package:map/features/corporate/domain/entities/push_notification_settings.dart';
import 'package:map/features/corporate/domain/entities/workplace_address.dart';
import 'package:map/features/corporate/presentation/pages/corporate_job_post_write_page.dart';
import 'package:map/features/corporate/domain/entities/internal_approval_report.dart';
import 'package:map/features/corporate/domain/entities/job_post_payment_record.dart';
import 'package:map/features/corporate/presentation/pages/corporate_internal_approval_report_page.dart';
import 'package:map/features/corporate/domain/utils/push_reach_estimator.dart';
import 'package:map/features/corporate/presentation/pages/corporate_job_post_push_dispatch_page.dart';
import 'package:map/features/corporate/presentation/pages/corporate_notification_payment_page.dart';
import 'package:map/features/corporate/presentation/pages/corporate_branch_management_page.dart';
import 'package:map/features/corporate/presentation/pages/corporate_roi_dashboard_page.dart';
import 'package:map/features/corporate/presentation/pages/corporate_permanent_workers_page.dart';
import 'package:map/features/corporate/presentation/pages/corporate_profile_setup_page.dart';
import 'package:map/features/corporate/presentation/pages/corporate_welcome_onboarding_page.dart';
import 'package:map/features/corporate/presentation/pages/push_package_shop_page.dart';
import 'package:map/features/corporate/presentation/pages/push_notification_base_point_page.dart';
import 'package:map/features/corporate/presentation/pages/workplace_address_search_page.dart';
import 'package:map/features/home/presentation/pages/role_based_home_page.dart';
import 'package:map/features/job_seeker/presentation/pages/health_insurance_verification_page.dart';
import 'package:map/features/job_seeker/presentation/pages/seeker_push_inbox_page.dart';
import 'package:map/features/listings/presentation/pages/create_listing_page.dart';
import 'package:map/features/map_dashboard/presentation/pages/warehouse_search_page.dart';

class MapApp extends StatelessWidget {
  const MapApp({
    super.key,
    this.initialRoute = AppRoutes.memberGateway,
  });

  final String initialRoute;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      initialRoute: initialRoute,
      onGenerateRoute: _onGenerateRoute,
    );
  }

  Route<dynamic>? _onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.memberGateway:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const MemberLoginGatewayPage(),
        );
      case AppRoutes.login:
        final memberType = settings.arguments as MemberType?;
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => LoginPage(
            memberType: memberType ?? MemberType.individual,
          ),
        );
      case AppRoutes.signUp:
        final memberType = settings.arguments as MemberType?;
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => SignUpPage(
            memberType: memberType ?? MemberType.individual,
          ),
        );
      case AppRoutes.home:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const RoleBasedHomePage(),
        );
      case AppRoutes.search:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const WarehouseSearchPage(),
        );
      case AppRoutes.createListing:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const CreateListingPage(),
        );
      case AppRoutes.corporateCreateJobPost:
        return MaterialPageRoute<bool?>(
          settings: settings,
          builder: (_) => const CorporateCreateJobPostPage(),
        );
      case AppRoutes.corporateJobPostWrite:
        final draft = settings.arguments as JobPostWriteDraft?;
        return MaterialPageRoute<bool?>(
          settings: settings,
          builder: (_) => CorporateJobPostWritePage(
            draft: draft ?? const JobPostWriteDraft(),
          ),
        );
      case AppRoutes.corporateSelectJobPost:
        return MaterialPageRoute<bool?>(
          settings: settings,
          builder: (_) => const CorporateSelectJobPostPage(),
        );
      case AppRoutes.corporateEditJobPost:
        final post = settings.arguments as CorporateJobPost?;
        if (post == null) {
          return MaterialPageRoute<bool?>(
            settings: settings,
            builder: (_) => const CorporateSelectJobPostPage(),
          );
        }
        return MaterialPageRoute<bool?>(
          settings: settings,
          builder: (_) => CorporateEditJobPostPage(post: post),
        );
      case AppRoutes.corporateWorkplaceSearch:
        final initialQuery = settings.arguments as String?;
        return MaterialPageRoute<WorkplaceAddress>(
          settings: settings,
          builder: (_) => WorkplaceAddressSearchPage(
            initialQuery: initialQuery,
          ),
        );
      case AppRoutes.corporatePushBasePoint:
        final args = settings.arguments as PushBasePointArgs?;
        return MaterialPageRoute<JobPostNotificationSettings>(
          settings: settings,
          builder: (_) => PushNotificationBasePointPage(
            initialSettings: args?.initialSettings,
            workplaceHint: args?.workplace,
          ),
        );
      case AppRoutes.corporateNotificationPayment:
        final bundle = settings.arguments as PushPaymentBundle?;
        if (bundle == null || !bundle.requiresPayment) {
          return MaterialPageRoute<PaymentCompletionResult>(
            settings: settings,
            builder: (_) => const Scaffold(
              body: Center(child: Text('결제 정보가 없습니다.')),
            ),
          );
        }
        return MaterialPageRoute<PaymentCompletionResult>(
          settings: settings,
          builder: (_) => CorporateNotificationPaymentPage(bundle: bundle),
        );
      case AppRoutes.corporateWelcomeOnboarding:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const CorporateWelcomeOnboardingPage(),
        );
      case AppRoutes.corporateProfileSetup:
        return MaterialPageRoute<bool>(
          settings: settings,
          builder: (_) => const CorporateProfileSetupPage(),
        );
      case AppRoutes.corporateInternalApprovalReport:
        final report = settings.arguments as InternalApprovalReport?;
        if (report == null) {
          return MaterialPageRoute<bool>(
            settings: settings,
            builder: (_) => const Scaffold(
              body: Center(child: Text('보고서 정보가 없습니다.')),
            ),
          );
        }
        return MaterialPageRoute<bool>(
          settings: settings,
          builder: (_) => CorporateInternalApprovalReportPage(report: report),
        );
      case AppRoutes.corporatePartnershipSubscription:
        return MaterialPageRoute<bool>(
          settings: settings,
          builder: (_) => const PushPackageShopPage(),
        );
      case AppRoutes.corporatePushPackageShop:
        final initialOfferId = settings.arguments as String?;
        return MaterialPageRoute<bool>(
          settings: settings,
          builder: (_) => PushPackageShopPage(initialOfferId: initialOfferId),
        );
      case AppRoutes.adminCompliance:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const AdminComplianceDashboardPage(),
        );
      case AppRoutes.corporateBranchManagement:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const CorporateBranchManagementPage(),
        );
      case AppRoutes.corporateRoiDashboard:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const CorporateRoiDashboardPage(),
        );
      case AppRoutes.corporatePermanentWorkers:
        if (!ProductFeatureFlags.isPermanentHireEnabled) {
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const Scaffold(
              body: Center(child: Text('상시직 채용 기능은 준비 중입니다.')),
            ),
          );
        }
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const CorporatePermanentWorkersPage(),
        );
      case AppRoutes.seekerHealthInsurance:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const HealthInsuranceVerificationPage(),
        );
      case AppRoutes.seekerPushInbox:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const SeekerPushInboxPage(),
        );
      case AppRoutes.corporatePushDispatch:
        final raw = settings.arguments;
        final PushDispatchArgs? dispatchArgs = switch (raw) {
          PushDispatchArgs args => args,
          PushRadiusTier tier => PushDispatchArgs(
              radiusTier: tier,
              recruitmentSlotCount: 1,
            ),
          _ => null,
        };
        if (dispatchArgs == null ||
            dispatchArgs.radiusTier == PushRadiusTier.radius0km) {
          return MaterialPageRoute<bool>(
            settings: settings,
            builder: (_) => const Scaffold(
              body: Center(child: Text('푸시 설정 정보가 없습니다.')),
            ),
          );
        }
        return MaterialPageRoute<bool>(
          settings: settings,
          builder: (_) => CorporateJobPostPushDispatchPage(args: dispatchArgs),
        );
      default:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const MemberLoginGatewayPage(),
        );
    }
  }
}
