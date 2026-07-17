import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:map/core/config/product_feature_flags.dart';
import 'package:map/core/constants/app_routes.dart';
import 'package:map/core/geo/geo_coordinate.dart';
import 'package:map/core/navigation/global_navigator.dart';
import 'package:map/core/constants/app_strings.dart';
import 'package:map/core/session/member_type.dart';
import 'package:map/core/theme/app_theme.dart';
import 'package:map/core/widgets/web_centered_site_frame.dart';
import 'package:map/features/admin/presentation/pages/admin_compliance_dashboard_page.dart';
import 'package:map/features/admin/presentation/pages/admin_web_shell_page.dart';
import 'package:map/features/auth/presentation/pages/auth/find_account_page.dart';
import 'package:map/features/auth/presentation/pages/auth/login_page.dart';
import 'package:map/features/auth/presentation/pages/auth/member_login_gateway_page.dart';
import 'package:map/features/auth/presentation/pages/auth/reset_password_page.dart';
import 'package:map/features/auth/presentation/pages/auth/signup_page.dart';
import 'package:map/features/auth/presentation/pages/auth/social_auth_complete_page.dart';
import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';
import 'package:map/features/design/presentation/pages/premium_theme_preview_page.dart';
import 'package:map/features/design/presentation/pages/pin_visual_verify_page.dart';
import 'package:map/features/corporate/domain/entities/job_post_write_draft.dart';
import 'package:map/features/corporate/presentation/navigation/corporate_job_post_flow_result.dart';
import 'package:map/features/corporate/presentation/pages/corporate_job_post_import_page.dart';
import 'package:map/features/corporate/presentation/navigation/push_base_point_args.dart';
import 'package:map/features/corporate/presentation/pages/corporate_job_post_write_page.dart';
import 'package:map/features/corporate/presentation/pages/corporate_edit_job_post_page.dart';
import 'package:map/features/corporate/presentation/navigation/corporate_edit_job_post_args.dart';
import 'package:map/features/corporate/domain/entities/push_notification_settings.dart';
import 'package:map/features/corporate/domain/entities/workplace_address.dart';
import 'package:map/features/corporate/presentation/navigation/corporate_job_post_published_args.dart';
import 'package:map/features/corporate/presentation/pages/corporate_job_post_published_page.dart';
import 'package:map/features/corporate/domain/entities/internal_approval_report.dart';
import 'package:map/features/corporate/domain/entities/job_post_payment_record.dart';
import 'package:map/features/corporate/domain/entities/job_post_payment_request_kind.dart';
import 'package:map/features/corporate/presentation/pages/corporate_internal_approval_report_page.dart';
import 'package:map/features/corporate/domain/utils/push_reach_estimator.dart';
import 'package:map/features/corporate/presentation/pages/corporate_job_post_push_dispatch_page.dart';
import 'package:map/features/corporate/presentation/pages/corporate_notification_payment_args.dart';
import 'package:map/features/corporate/presentation/pages/corporate_notification_payment_page.dart';
import 'package:map/features/corporate/presentation/pages/corporate_branch_management_page.dart';
import 'package:map/features/corporate/presentation/pages/corporate_shuttle_location_officer_page.dart';
import 'package:map/features/corporate/presentation/pages/corporate_roi_dashboard_page.dart';
import 'package:map/features/corporate/presentation/pages/corporate_talent_search_page.dart';
import 'package:map/features/corporate/presentation/pages/chat_reply_macro_settings_page.dart';
import 'package:map/features/corporate/presentation/pages/corporate_my_info_page.dart';
import 'package:map/features/corporate/presentation/pages/corporate_payment_management_page.dart';
import 'package:map/features/corporate/domain/entities/tax_document_type.dart';
import 'package:map/features/corporate/presentation/pages/corporate_tax_documents_page.dart';
import 'package:map/features/corporate/presentation/pages/corporate_profile_setup_page.dart';
import 'package:map/features/corporate/presentation/pages/corporate_welcome_onboarding_page.dart';
import 'package:map/features/corporate/presentation/pages/corporate_cash_charge_page.dart';
import 'package:map/features/corporate/presentation/pages/exposure_renewal_page.dart';
import 'package:map/features/corporate/presentation/pages/push_package_shop_page.dart';
import 'package:map/features/corporate/presentation/pages/wallet_credit_lots_page.dart';
import 'package:map/features/corporate/presentation/pages/job_pin_activation_page.dart';
import 'package:map/features/corporate/presentation/pages/push_notification_base_point_page.dart';
import 'package:map/core/legal/legal_consent_gate.dart';
import 'package:map/features/corporate/presentation/pages/payment_web_callback_page.dart';
import 'package:map/features/corporate/presentation/pages/push_ticket_purchase_page.dart';
import 'package:map/features/corporate/presentation/pages/push_ticket_use_page.dart';
import 'package:map/features/commute/domain/entities/commute_route.dart';
import 'package:map/features/attendance/presentation/pages/corporate_attendance_hub_page.dart';
import 'package:map/features/attendance/presentation/pages/corporate_shuttle_attendance_hub_page.dart';
import 'package:map/features/commute/domain/entities/commute_route_stop.dart';
import 'package:map/features/commute/presentation/pages/shuttle_route_edit_page.dart';
import 'package:map/features/commute/presentation/pages/bus_location_tower_pilot_page.dart';
import 'package:map/features/commute/presentation/pages/seeker_my_bus_page.dart';
import 'package:map/features/commute/presentation/pages/shuttle_stop_activation_page.dart';
import 'package:map/features/commute/presentation/pages/shuttle_stop_payment_page.dart';
import 'package:map/features/commute/presentation/pages/shuttle_stop_map_picker_page.dart';
import 'package:map/features/corporate/presentation/pages/workplace_address_search_page.dart';
import 'package:map/features/home/presentation/pages/role_based_home_page.dart';
import 'package:map/features/job_seeker/presentation/pages/tabs/individual_my_jobs_tab.dart';
import 'package:map/features/job_seeker/presentation/pages/seeker_notification_settings_page.dart';
import 'package:map/features/job_seeker/presentation/pages/seeker_my_documents_page.dart';
import 'package:map/features/job_seeker/presentation/pages/seeker_my_resume_page.dart';
import 'package:map/features/job_seeker/presentation/pages/seeker_profile_onboarding_args.dart';
import 'package:map/features/job_seeker/presentation/pages/seeker_profile_onboarding_flow.dart';
import 'package:map/features/job_seeker/presentation/pages/seeker_home_address_page.dart';
import 'package:map/features/job_seeker/presentation/pages/seeker_my_credentials_page.dart';
import 'package:map/features/job_seeker/presentation/pages/seeker_resume_import_page.dart';
import 'package:map/features/job_seeker/presentation/pages/seeker_resume_section_pages.dart';
import 'package:map/features/job_seeker/presentation/pages/seeker_push_inbox_page.dart';
import 'package:map/features/marketing/presentation/pages/public_pricing_page.dart';
import 'package:map/features/support/presentation/pages/customer_support_page.dart';
import 'package:map/features/support/presentation/pages/legal_documents_page.dart';
import 'package:map/features/listings/presentation/pages/create_listing_page.dart';
import 'package:map/features/map_dashboard/presentation/pages/warehouse_search_page.dart';

/// TEMP 핀 색/모양 검증 — `flutter run -t lib/main_pin_verify.dart` 로 재확인.
/// 일반 앱 기동은 false 유지.
bool kPinDesignPreview = false;

class MapApp extends StatelessWidget {
  const MapApp({
    super.key,
    this.initialRoute = AppRoutes.memberGateway,
  });

  final String initialRoute;

  @override
  Widget build(BuildContext context) {
    // TEMP: 지도 핀 색/모양 검증 화면
    if (kPinDesignPreview) {
      return MaterialApp(
        title: AppStrings.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const PinVisualVerifyPage(),
      );
    }

    return MaterialApp(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: scaffoldMessengerKey,
      initialRoute: initialRoute,
      onGenerateRoute: _onGenerateRoute,
      builder: (context, child) {
        if (child == null) return const SizedBox.shrink();
        return WebCenteredSiteFrame(child: child);
      },
    );
  }

  Route<dynamic>? _onGenerateRoute(RouteSettings settings) {
    // 웹 딥링크 — initialRoute만으로는 URL이 안 맞는 경우가 있어 Uri.base 우선
    if (kIsWeb) {
      final path = Uri.base.path;
      if (path.contains('auth/social-complete')) {
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const SocialAuthCompletePage(),
        );
      }
      if (path.contains('payment-success')) {
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const PaymentWebCallbackPage(success: true),
        );
      }
      if (path.contains('payment-fail')) {
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const PaymentWebCallbackPage(success: false),
        );
      }
      if (path.contains('/pricing')) {
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const PublicPricingPage(),
        );
      }
    }

    switch (settings.name) {
      case AppRoutes.memberGateway:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const MemberLoginGatewayPage(),
        );
      case AppRoutes.individualLogin:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const LoginPage(
            memberType: MemberType.individual,
          ),
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
      case AppRoutes.findAccount:
        final findMemberType = settings.arguments as MemberType?;
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => FindAccountPage(
            initialMemberType: findMemberType ?? MemberType.individual,
          ),
        );
      case AppRoutes.resetPassword:
        final resetMemberType = settings.arguments as MemberType?;
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => ResetPasswordPage(
            initialMemberType: resetMemberType ?? MemberType.individual,
          ),
        );
      case AppRoutes.home:
        final args = settings.arguments;
        final rawTab = args is Map ? (args['seekerTabIndex'] as int? ?? 0) : 0;
        final seekerTabIndex = normalizeSeekerTabIndex(rawTab);
        final seekerMyJobsSegment = args is Map
            ? (args['seekerMyJobsSegment'] as int? ??
                seekerMyJobsSegmentFromLegacyTab(rawTab))
            : 0;
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => LegalConsentGate(
            child: RoleBasedHomePage(
              initialSeekerTabIndex: seekerTabIndex,
              initialSeekerMyJobsSegment: seekerMyJobsSegment,
            ),
          ),
        );
      case AppRoutes.paymentWebSuccess:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const PaymentWebCallbackPage(success: true),
        );
      case AppRoutes.paymentWebFail:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const PaymentWebCallbackPage(success: false),
        );
      case AppRoutes.socialAuthComplete:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const SocialAuthCompletePage(),
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
        final draft = settings.arguments as JobPostWriteDraft?;
        return MaterialPageRoute<CorporateJobPostFlowResult>(
          settings: settings,
          builder: (_) => CorporateJobPostWritePage(
            draft: draft ??
                JobPostWriteDraft(
                  workerCategory: ProductFeatureFlags.defaultWorkerCategory,
                ),
          ),
        );
      case AppRoutes.corporateJobPostImport:
        return MaterialPageRoute<bool?>(
          settings: settings,
          builder: (_) => const CorporateJobPostImportPage(),
        );
      case AppRoutes.corporateJobPostWrite:
        final draft = settings.arguments as JobPostWriteDraft?;
        return MaterialPageRoute<CorporateJobPostFlowResult>(
          settings: settings,
          builder: (_) => CorporateJobPostWritePage(
            draft: draft ?? const JobPostWriteDraft(),
          ),
        );
      case AppRoutes.corporateJobPostPublished:
        final args = settings.arguments;
        CorporateJobPost? post;
        WorkplaceAddress? workplace;
        if (args is CorporateJobPostPublishedArgs) {
          post = args.post;
          workplace = args.workplace;
        } else if (args is CorporateJobPost) {
          post = args;
          workplace = WorkplaceAddress(roadAddress: args.warehouseName);
        }
        if (post == null) {
          return MaterialPageRoute<CorporateJobPostFlowResult>(
            settings: settings,
            builder: (_) => const CorporateSelectJobPostPage(),
          );
        }
        final publishedPost = post;
        final publishedWorkplace = workplace ??
            WorkplaceAddress(roadAddress: publishedPost.warehouseName);
        return MaterialPageRoute<CorporateJobPostFlowResult>(
          settings: settings,
          builder: (_) => CorporateJobPostPublishedPage(
            post: publishedPost,
            workplace: publishedWorkplace,
          ),
        );
      case AppRoutes.corporateSelectJobPost:
        return MaterialPageRoute<bool?>(
          settings: settings,
          builder: (_) => const CorporateSelectJobPostPage(),
        );
      case AppRoutes.corporateEditJobPost:
        final args = settings.arguments;
        final CorporateJobPost? post;
        var asCopy = false;
        if (args is CorporateEditJobPostArgs) {
          post = args.post;
          asCopy = args.asCopy;
        } else {
          post = args as CorporateJobPost?;
        }
        if (post == null) {
          return MaterialPageRoute<bool?>(
            settings: settings,
            builder: (_) => const CorporateSelectJobPostPage(),
          );
        }
        return MaterialPageRoute<bool?>(
          settings: settings,
          builder: (_) => CorporateEditJobPostPage(
            post: post!,
            asCopy: asCopy,
          ),
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
        PushPaymentBundle? bundle;
        String? paymentRequestId;
        JobPostPaymentRequestKind? paymentKind;
        final args = settings.arguments;
        if (args is CorporateNotificationPaymentArgs) {
          bundle = args.bundle;
          paymentRequestId = args.paymentRequestId;
          paymentKind = args.paymentKind;
        } else if (args is PushPaymentBundle) {
          bundle = args;
          paymentKind = args.paymentKind;
        }
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
          builder: (_) => CorporateNotificationPaymentPage(
            bundle: bundle!,
            paymentRequestId: paymentRequestId,
            paymentKind: paymentKind,
          ),
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
      case AppRoutes.corporateMyInfo:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const CorporateMyInfoPage(),
        );
      case AppRoutes.corporatePaymentManagement:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const CorporatePaymentManagementPage(),
        );
      case AppRoutes.corporateTaxDocuments:
        final initialFilter = settings.arguments is TaxDocumentType
            ? settings.arguments as TaxDocumentType
            : null;
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => CorporateTaxDocumentsPage(initialFilter: initialFilter),
        );
      case AppRoutes.corporateChatReplyMacros:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const ChatReplyMacroSettingsPage(),
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
      case AppRoutes.corporateWalletCreditLots:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const WalletCreditLotsPage(),
        );
      case AppRoutes.adminCompliance:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const AdminComplianceDashboardPage(),
        );
      case AppRoutes.adminHome:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const AdminWebShellPage(),
        );
      case AppRoutes.adminOps:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const AdminWebShellPage(),
        );
      case AppRoutes.corporateBranchManagement:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const CorporateBranchManagementPage(),
        );
      case AppRoutes.corporateShuttleRoutes:
        final shuttleArgs = settings.arguments as ShuttleRouteListArgs?;
        return MaterialPageRoute<CommuteRoute>(
          settings: settings,
          builder: (_) => ShuttleRouteListPage(args: shuttleArgs),
        );
      case AppRoutes.corporateShuttleLocationOfficer:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const CorporateShuttleLocationOfficerPage(),
        );
      case AppRoutes.corporateShuttleRouteEdit:
        CommuteRoute? existing;
        Set<String> lockedStopIds = const {};
        GeoCoordinate? initialWorkplaceCoordinate;
        WorkplaceAddress? initialWorkplaceHint;
        final editArgs = settings.arguments;
        if (editArgs is ShuttleRouteEditArgs) {
          existing = editArgs.route;
          lockedStopIds = editArgs.lockedStopIds;
          initialWorkplaceCoordinate = editArgs.workplaceCoordinate;
          initialWorkplaceHint = editArgs.workplaceHint;
        } else if (editArgs is CommuteRoute) {
          existing = editArgs;
        }
        return MaterialPageRoute<CommuteRoute>(
          settings: settings,
          builder: (_) => ShuttleRouteEditPage(
            existing: existing,
            lockedStopIds: lockedStopIds,
            initialWorkplaceCoordinate: initialWorkplaceCoordinate,
            initialWorkplaceHint: initialWorkplaceHint,
          ),
        );
      case AppRoutes.corporateJobPinActivation:
        final jobPinArgs = settings.arguments as JobPinActivationArgs?;
        return MaterialPageRoute<JobPostNotificationSettings>(
          settings: settings,
          builder: (_) => JobPinActivationPage(args: jobPinArgs),
        );
      case AppRoutes.corporateShuttleStopActivation:
        final activationArgs = settings.arguments as ShuttleStopActivationArgs?;
        return MaterialPageRoute<ShuttleStopActivationPageResult?>(
          settings: settings,
          builder: (_) => ShuttleStopActivationPage(args: activationArgs),
        );
      case AppRoutes.corporateShuttleStopPayment:
        final paymentArgs = settings.arguments as ShuttleStopPaymentArgs?;
        return MaterialPageRoute<ShuttleStopPaymentPageResult?>(
          settings: settings,
          builder: (_) => ShuttleStopPaymentPage(args: paymentArgs),
        );
      case AppRoutes.corporateExposureRenewal:
        final renewalArgs = settings.arguments as ExposureRenewalArgs?;
        return MaterialPageRoute<bool>(
          settings: settings,
          builder: (_) => ExposureRenewalPage(args: renewalArgs),
        );
      case AppRoutes.corporateCashCharge:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const CorporateCashChargePage(),
        );
      case AppRoutes.corporatePushTicketUse:
        final useArgs = settings.arguments as PushTicketUseArgs;
        return MaterialPageRoute<bool>(
          settings: settings,
          builder: (_) => PushTicketUsePage(args: useArgs),
        );
      case AppRoutes.corporatePushTicketPurchase:
        final purchaseArgs = settings.arguments as PushTicketPurchaseArgs?;
        return MaterialPageRoute<bool>(
          settings: settings,
          builder: (_) => PushTicketPurchasePage(args: purchaseArgs),
        );
      case AppRoutes.corporateShuttleStopMapPick:
        final existingStops =
            settings.arguments as List<CommuteRouteStop>? ?? const [];
        return MaterialPageRoute<ShuttleStopPickResult>(
          settings: settings,
          builder: (_) => ShuttleStopMapPickerPage(
            existingStops: existingStops,
          ),
        );
      case AppRoutes.corporateShuttleAttendanceHub:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const CorporateShuttleAttendanceHubPage(),
        );
      case AppRoutes.corporateAttendanceHub:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const CorporateAttendanceHubPage(),
        );
      case AppRoutes.corporateRoiDashboard:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const CorporateRoiDashboardPage(),
        );
      case AppRoutes.corporatePermanentWorkers:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const Scaffold(
            body: Center(child: Text('상시직 채용 기능은 준비 중입니다.')),
          ),
        );
      case AppRoutes.corporateTalentSearch:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const CorporateTalentSearchPage(),
        );
      case AppRoutes.seekerPushInbox:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const SeekerPushInboxPage(),
        );
      case AppRoutes.seekerNotificationSettings:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const SeekerNotificationSettingsPage(),
        );
      case AppRoutes.seekerBusLocationTowerPilot:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const BusLocationTowerPilotPage(),
        );
      case AppRoutes.seekerMyBus:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const SeekerMyBusPage(),
        );
      case AppRoutes.seekerMyDocuments:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const SeekerMyDocumentsPage(),
        );
      case AppRoutes.seekerMyResume:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const SeekerMyResumePage(),
        );
      case AppRoutes.seekerResumeEdit:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const SeekerResumeEditHubPage(),
        );
      case AppRoutes.seekerResumeImport:
        return MaterialPageRoute<bool>(
          settings: settings,
          builder: (_) => const SeekerResumeImportPage(),
        );
      case AppRoutes.seekerProfileOnboarding:
        final onboardingArgs =
            SeekerProfileOnboardingArgs.from(settings.arguments);
        return MaterialPageRoute<bool>(
          settings: settings,
          builder: (_) => SeekerProfileOnboardingFlow(
            forJobApply: onboardingArgs.forJobApply,
          ),
        );
      case AppRoutes.seekerMyCredentials:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const SeekerMyCredentialsPage(),
        );
      case AppRoutes.seekerHomeAddress:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const SeekerHomeAddressPage(),
        );
      case AppRoutes.publicPricing:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const PublicPricingPage(),
        );
      case AppRoutes.premiumThemePreview:
        if (!premiumThemePreviewEnabled) {
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const MemberLoginGatewayPage(),
          );
        }
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const PremiumThemePreviewPage(),
        );
      case AppRoutes.customerSupport:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const CustomerSupportPage(),
        );
      case AppRoutes.legalDocuments:
        final legalArgs = settings.arguments;
        final initialDocumentId = legalArgs is Map
            ? legalArgs['initialDocumentId'] as String?
            : null;
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => LegalDocumentsPage(
            initialDocumentId: initialDocumentId,
          ),
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
              body: Center(child: Text('PUSH 설정 정보가 없습니다.')),
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
