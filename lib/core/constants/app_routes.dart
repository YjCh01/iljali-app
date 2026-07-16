/// 앱 라우트 경로 상수
abstract final class AppRoutes {
  static const String memberGateway = '/';
  static const String individualLogin = '/login-individual';
  static const String login = '/login';
  static const String signUp = '/signup';
  static const String findAccount = '/auth/find-account';
  static const String resetPassword = '/auth/reset-password';
  static const String home = '/home';
  static const String search = '/search';
  static const String createListing = '/create-listing';
  static const String corporateCreateJobPost = '/corporate/job-post/create';
  static const String corporateJobPostImport = '/corporate/job-post/import';
  static const String corporateJobPostWrite = '/corporate/job-post/write';
  static const String corporateJobPostPublished = '/corporate/job-post/published';
  static const String corporateSelectJobPost = '/corporate/job-post/select';
  static const String corporateEditJobPost = '/corporate/job-post/edit';
  static const String corporateWorkplaceSearch = '/corporate/workplace/search';
  static const String corporatePushBasePoint = '/corporate/push-base-point';
  static const String corporateNotificationPayment =
      '/corporate/notification-payment';
  static const String corporatePushDispatch = '/corporate/push-dispatch';
  static const String corporateWelcomeOnboarding =
      '/corporate/welcome-onboarding';
  static const String corporateProfileSetup = '/corporate/profile-setup';
  static const String corporateMyInfo = '/corporate/my-info';
  static const String corporatePaymentManagement = '/corporate/payment-management';
  static const String corporateTaxDocuments = '/corporate/tax-documents';
  static const String corporateChatReplyMacros = '/corporate/chat-reply-macros';
  static const String corporateInternalApprovalReport =
      '/corporate/internal-approval-report';
  static const String adminCompliance = '/admin/compliance';
  static const String adminHome = '/admin';
  static const String adminOps = '/admin/ops';
  static const String corporatePartnershipSubscription =
      '/corporate/partnership/subscribe';
  static const String corporatePushPackageShop = '/corporate/push-packages';
  static const String corporateWalletCreditLots =
      '/corporate/wallet/credit-lots';
  static const String corporateBranchManagement = '/corporate/branches';
  static const String corporateShuttleRoutes = '/corporate/shuttle-routes';
  static const String corporateShuttleRouteEdit = '/corporate/shuttle-route/edit';
  static const String corporateShuttleStopActivation =
      '/corporate/shuttle-route/stop-activation';
  static const String corporateShuttleStopPayment =
      '/corporate/shuttle-route/stop-payment';
  static const String corporateShuttleLocationOfficer =
      '/corporate/shuttle-location-officer';
  static const String corporateJobPinActivation = '/corporate/job-pin/activation';
  static const String corporatePushTicketUse = '/corporate/push-ticket/use';
  static const String corporateExposureRenewal = '/corporate/exposure-renewal';
  static const String corporateCashCharge = '/corporate/cash-charge';
  static const String corporatePushTicketPurchase =
      '/corporate/push-ticket/purchase';
  static const String corporateShuttleStopMapPick =
      '/corporate/shuttle-route/stop-map-pick';
  static const String corporateShuttleAttendanceHub =
      '/corporate/shuttle-attendance-hub';
  static const String corporateAttendanceHub = '/corporate/attendance-hub';
  static const String corporateRoiDashboard = '/corporate/roi-dashboard';
  static const String corporatePermanentWorkers = '/corporate/permanent-workers';
  static const String corporateTalentSearch = '/corporate/talent-search';
  static const String seekerPushInbox = '/seeker/push-inbox';
  static const String seekerNotificationSettings = '/seeker/notification-settings';
  static const String seekerBusLocationTowerPilot = '/seeker/bus-location-tower';
  static const String seekerMyBus = '/seeker/my-bus';
  static const String seekerMyDocuments = '/seeker/my-documents';
  static const String seekerMyResume = '/seeker/my-resume';
  static const String seekerResumeEdit = '/seeker/resume/edit';
  static const String seekerResumeImport = '/seeker/resume/import';
  static const String seekerProfileOnboarding = '/seeker/profile/onboarding';
  static const String seekerMyCredentials = '/seeker/my-credentials';
  static const String seekerHomeAddress = '/seeker/home-address';
  static const String customerSupport = '/support/customer';
  static const String legalDocuments = '/support/legal';
  static const String publicPricing = '/pricing';
  static const String paymentWebSuccess = '/payment-success';
  static const String paymentWebFail = '/payment-fail';
  static const String socialAuthComplete = '/auth/social-complete';
  /// Debug only — Premium 테마 MVP 미리보기
  static const String premiumThemePreview = '/dev/premium-theme-preview';
}
