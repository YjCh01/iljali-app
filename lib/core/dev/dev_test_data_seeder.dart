import 'package:map/core/dev/dev_test_accounts.dart';
import 'package:map/core/hiring/application_chat_message.dart';
import 'package:map/core/hiring/application_chat_message_repository.dart';
import 'package:map/core/hiring/hiring_application.dart';
import 'package:map/core/hiring/hiring_application_status.dart';
import 'package:map/core/hiring/local_hiring_repository.dart';
import 'package:map/features/job_seeker/data/repositories/job_application_repository.dart';
import 'package:map/features/job_seeker/domain/entities/job_application.dart';
import 'package:map/features/corporate/data/datasources/corporate_job_post_local_data_source.dart';
import 'package:map/features/corporate/data/repositories/corporate_account_registry.dart';
import 'package:map/features/corporate/domain/entities/corporate_member_profile.dart';
import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';
import 'package:map/features/corporate/data/repositories/company_bonus_ledger_repository.dart';
import 'package:map/features/corporate/data/repositories/push_wallet_repository.dart';
import 'package:map/features/corporate/domain/entities/employer_push_wallet.dart';
import 'package:map/features/corporate/domain/entities/worker_category.dart';
import 'package:map/features/commute/data/repositories/commute_route_repository.dart';
import 'package:map/features/commute/data/repositories/shuttle_booking_repository.dart';
import 'package:map/features/commute/domain/entities/commute_route_demo.dart';
import 'package:map/features/commute/domain/entities/shuttle_booking.dart';
import 'package:map/features/commute/domain/services/shuttle_reminder_service.dart';
import 'package:map/features/corporate/domain/utils/job_post_validity.dart';
import 'package:map/features/job_seeker/domain/entities/job_map_pin_display_tier.dart';

/// 개발 테스트 계정용 채용·채팅·근태 시드 데이터 (idempotent).
abstract final class DevTestDataSeeder {
  static const _postAlphaId = 'test_post_corp_alpha_warehouse';
  static const _postBetaId = 'test_post_corp_beta_kitchen';

  /// 기업 α + 구직 α — 근무합의 완료 · 출근 예정 (근태 탭 카드)
  static const appCorpAlphaSeekerAlphaScheduled = 'test_app_corp_alpha_seeker_alpha';

  /// seeker-alpha 셔틀 예약 (다이소 세종 데모)
  static const shuttleBookingSeekerAlpha = 'test_shuttle_booking_seeker_alpha';

  /// 기업 α + 구직 β — 채팅 중 (합의 진행 중)
  static const appCorpAlphaSeekerBetaChatting = 'test_app_corp_alpha_seeker_beta';

  /// 기업 β + 구직 β — 근무합의 완료 · 출근 예정
  static const appCorpBetaSeekerBetaScheduled = 'test_app_corp_beta_seeker_beta';

  static Future<void> ensureSeeded() async {
    await _ensureCorporateRegistry();
    await _ensureDevPushWallets();
    await _ensureSeedJobPosts();
    await _ensureShuttleDemo();
    final repo = await LocalHiringRepository.create();
    final now = DateTime.now();
    final workDate = DateTime(now.year, now.month, now.day);

    final shiftDateIso =
        '${workDate.year}-${workDate.month.toString().padLeft(2, '0')}-${workDate.day.toString().padLeft(2, '0')}';

    await repo.ensureSeedApplication(
      HiringApplication(
        id: appCorpAlphaSeekerAlphaScheduled,
        postId: _postAlphaId,
        postTitle: '[테스트] 물류 보조 (알파)',
        companyName: DevTestAccounts.corpAlpha.companyName!,
        seekerEmail: DevTestAccounts.seekerAlpha.email,
        seekerName: DevTestAccounts.seekerAlpha.displayName,
        seekerPhoneMasked: DevTestAccounts.seekerAlpha.phone!,
        appliedAt: now.subtract(const Duration(days: 2)),
        status: HiringApplicationStatus.scheduled,
        workSchedule: '09:00-18:00',
        employmentType: JobEmploymentType.daily,
        workDate: workDate,
        companyKey: DevTestAccounts.corpAlpha.verifiedCorporateProfile!.companyKey,
        seekerWorkAgreedAt: now.subtract(const Duration(days: 1)),
        employerWorkAgreedAt: now.subtract(const Duration(days: 1)),
        commissionAmountKrw: 15000,
        selectedShiftDate: shiftDateIso,
        shiftSlot: 'day',
        shuttleBookingId: shuttleBookingSeekerAlpha,
        preferredStopId: 'stop_jamsil',
      ),
    );

    await _ensureShuttleBookingDemo(now, workDate, shiftDateIso);

    await repo.ensureSeedApplication(
      HiringApplication(
        id: appCorpAlphaSeekerBetaChatting,
        postId: _postAlphaId,
        postTitle: '[테스트] 물류 보조 (알파)',
        companyName: DevTestAccounts.corpAlpha.companyName!,
        seekerEmail: DevTestAccounts.seekerBeta.email,
        seekerName: DevTestAccounts.seekerBeta.displayName,
        seekerPhoneMasked: DevTestAccounts.seekerBeta.phone!,
        appliedAt: now.subtract(const Duration(hours: 6)),
        status: HiringApplicationStatus.chatting,
        workSchedule: '10:00-19:00',
        employmentType: JobEmploymentType.daily,
        companyKey: DevTestAccounts.corpAlpha.verifiedCorporateProfile!.companyKey,
        seekerWorkAgreedAt: now.subtract(const Duration(hours: 2)),
      ),
    );

    await _ensureSeekerApplicationRecords(now);
    await _ensureChatMessages(now);

    await repo.ensureSeedApplication(
      HiringApplication(
        id: appCorpBetaSeekerBetaScheduled,
        postId: _postBetaId,
        postTitle: '[테스트] 주방 보조 (베타)',
        companyName: DevTestAccounts.corpBeta.companyName!,
        seekerEmail: DevTestAccounts.seekerBeta.email,
        seekerName: DevTestAccounts.seekerBeta.displayName,
        seekerPhoneMasked: DevTestAccounts.seekerBeta.phone!,
        appliedAt: now.subtract(const Duration(days: 1)),
        status: HiringApplicationStatus.scheduled,
        workSchedule: '08:00-17:00',
        employmentType: JobEmploymentType.daily,
        workDate: workDate.add(const Duration(days: 1)),
        companyKey: DevTestAccounts.corpBeta.verifiedCorporateProfile!.companyKey,
        seekerWorkAgreedAt: now.subtract(const Duration(hours: 12)),
        employerWorkAgreedAt: now.subtract(const Duration(hours: 12)),
        commissionAmountKrw: 15000,
      ),
    );
  }

  static Future<void> _ensureShuttleBookingDemo(
    DateTime now,
    DateTime workDate,
    String shiftDateIso,
  ) async {
    final bookingRepo = await ShuttleBookingRepository.create();
    final booking = ShuttleBooking(
      id: shuttleBookingSeekerAlpha,
      seekerEmail: DevTestAccounts.seekerAlpha.email,
      postId: _postAlphaId,
      routeId: CommuteRouteDemoIds.daisoSejong,
      stopId: 'stop_jamsil',
      stopLabel: '잠실역 2번 출구',
      pickupTime: '07:30',
      shiftDate: shiftDateIso,
      createdAt: now.subtract(const Duration(days: 1)),
    );
    await bookingRepo.ensureSeed(booking);
    final reminderService = await ShuttleReminderService.create();
    await reminderService.scheduleForBooking(booking);
  }

  static Future<void> _ensureShuttleDemo() async {
    final profile = DevTestAccounts.corpAlpha.verifiedCorporateProfile!;
    final routeRepo = await CommuteRouteRepository.create();
    await routeRepo.ensureDemoDaisoSejongRoute(profile.companyKey);

    const dataSource = CorporateJobPostLocalDataSourceImpl();
    final existing = await dataSource.findById(_postAlphaId);
    if (existing == null) return;
    await dataSource.updateJobPost(
      existing.copyWith(
        warehouseName: '다이소 세종물류센터',
        commuteRouteId: CommuteRouteDemoIds.daisoSejong,
        hasShuttleRouteOverlay: true,
        mapPinDisplayTier: JobMapPinDisplayTier.packageActive,
      ),
    );
  }

  static Future<void> _ensureSeedJobPosts() async {
    const dataSource = CorporateJobPostLocalDataSourceImpl();
    final now = DateTime.now();
    final posts = <CorporateJobPost>[
      _seedPost(
        id: _postAlphaId,
        title: '[테스트] 물류 보조 (알파)',
        profile: DevTestAccounts.corpAlpha.verifiedCorporateProfile!,
        hourlyWage: '12,000원',
        workSchedule: '09:00-18:00',
        summary: '개발 테스트용 물류 보조 공고 — 지도 핀·지원·채팅 시나리오',
        postedAt: now,
      ),
      _seedPost(
        id: _postBetaId,
        title: '[테스트] 주방 보조 (베타)',
        profile: DevTestAccounts.corpBeta.verifiedCorporateProfile!,
        hourlyWage: '11,500원',
        workSchedule: '08:00-17:00',
        summary: '개발 테스트용 주방 보조 공고',
        postedAt: now.subtract(const Duration(hours: 3)),
      ),
    ];

    for (final post in posts) {
      final existing = await dataSource.findById(post.id);
      if (existing != null) continue;
      await dataSource.createJobPost(post);
    }
  }

  static CorporateJobPost _seedPost({
    required String id,
    required String title,
    required CorporateMemberProfile profile,
    required String hourlyWage,
    required String workSchedule,
    required String summary,
    required DateTime postedAt,
  }) {
    return CorporateJobPost(
      id: id,
      title: title,
      warehouseName: id == _postAlphaId
          ? '다이소 세종물류센터'
          : (profile.businessHeadOfficeAddress ??
              '경기도 화성시 동탄대로 123'),
      hourlyWage: hourlyWage,
      workSchedule: workSchedule,
      summary: summary,
      jobDescription: summary,
      status: CorporateJobPostStatus.recruiting,
      applicantCount: 1,
      postedAt: postedAt,
      expiresAt: JobPostValidity.expiresAtFromRegistration(postedAt),
      workerCategory: WorkerCategory.daily,
      paymentDate: postedAt.add(const Duration(days: 7)),
      registeredBy: profile,
      mapPinDisplayTier: id == _postAlphaId
          ? JobMapPinDisplayTier.packageActive
          : null,
      commuteRouteId:
          id == _postAlphaId ? CommuteRouteDemoIds.daisoSejong : null,
      hasShuttleRouteOverlay: id == _postAlphaId,
    );
  }

  static Future<void> _ensureSeekerApplicationRecords(DateTime now) async {
    final alphaRepo =
        await JobApplicationRepository.create(DevTestAccounts.seekerAlpha.email);
    final betaRepo =
        await JobApplicationRepository.create(DevTestAccounts.seekerBeta.email);
    if (alphaRepo == null || betaRepo == null) return;

    final shiftDateIso =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    await alphaRepo.add(
      JobApplication(
        postId: _postAlphaId,
        title: '[테스트] 물류 보조 (알파)',
        company: DevTestAccounts.corpAlpha.companyName!,
        appliedAt: now.subtract(const Duration(days: 2)),
        status: HiringApplicationStatus.scheduled.label,
        companyKey:
            DevTestAccounts.corpAlpha.verifiedCorporateProfile!.companyKey,
        selectedShiftDate: shiftDateIso,
        shiftSlot: 'day',
        shuttleBookingId: shuttleBookingSeekerAlpha,
        preferredStopId: 'stop_jamsil',
      ),
    );

    await betaRepo.add(
      JobApplication(
        postId: _postAlphaId,
        title: '[테스트] 물류 보조 (알파)',
        company: DevTestAccounts.corpAlpha.companyName!,
        appliedAt: now.subtract(const Duration(hours: 6)),
        status: HiringApplicationStatus.chatting.label,
        companyKey:
            DevTestAccounts.corpAlpha.verifiedCorporateProfile!.companyKey,
      ),
    );
    await betaRepo.add(
      JobApplication(
        postId: _postBetaId,
        title: '[테스트] 주방 보조 (베타)',
        company: DevTestAccounts.corpBeta.companyName!,
        appliedAt: now.subtract(const Duration(days: 1)),
        status: HiringApplicationStatus.scheduled.label,
        companyKey:
            DevTestAccounts.corpBeta.verifiedCorporateProfile!.companyKey,
      ),
    );
  }

  static Future<void> _ensureChatMessages(DateTime now) async {
    final chatRepo = await ApplicationChatMessageRepository.create();

    await _seedChatIfEmpty(
      chatRepo,
      applicationId: appCorpAlphaSeekerBetaChatting,
      messages: [
        ApplicationChatMessage(
          fromEmployer: true,
          text:
              '안녕하세요, ${DevTestAccounts.corpAlpha.companyName} 채용 담당입니다.\n'
              '「[테스트] 물류 보조 (알파)」 지원 감사합니다.',
          sentAt: now.subtract(const Duration(hours: 5)),
        ),
        ApplicationChatMessage(
          fromEmployer: false,
          text: '안녕하세요, ${DevTestAccounts.seekerBeta.displayName}입니다.\n'
              '다음 주 화요일 근무 가능합니다. 시간 확인 부탁드립니다.',
          sentAt: now.subtract(const Duration(hours: 4, minutes: 40)),
        ),
        ApplicationChatMessage(
          fromEmployer: true,
          text: '10:00–19:00 일정으로 합의드리면 됩니다.\n'
              '확정해 주시면 근무합의를 진행하겠습니다.',
          sentAt: now.subtract(const Duration(hours: 4, minutes: 10)),
        ),
      ],
    );

    await _seedChatIfEmpty(
      chatRepo,
      applicationId: appCorpAlphaSeekerAlphaScheduled,
      messages: [
        ApplicationChatMessage(
          fromEmployer: true,
          text: '근무합의가 완료되었습니다.\n출근 당일 앱에서 출근 확인해 주세요.',
          sentAt: now.subtract(const Duration(days: 1, hours: 2)),
        ),
        ApplicationChatMessage(
          fromEmployer: false,
          text: '네, 잠실역 2번 출구 07:30 셔틀 탑승 예정입니다.',
          sentAt: now.subtract(const Duration(days: 1, hours: 1, minutes: 45)),
        ),
        ApplicationChatMessage(
          fromEmployer: true,
          text: '셔틀 예약 확인했습니다. 당일 뵙겠습니다.',
          sentAt: now.subtract(const Duration(days: 1, hours: 1, minutes: 20)),
          isSystem: false,
        ),
      ],
    );

    await _seedChatIfEmpty(
      chatRepo,
      applicationId: appCorpBetaSeekerBetaScheduled,
      messages: [
        ApplicationChatMessage(
          fromEmployer: true,
          text:
              '안녕하세요, ${DevTestAccounts.corpBeta.companyName}입니다.\n'
              '「[테스트] 주방 보조 (베타)」 지원 감사합니다.',
          sentAt: now.subtract(const Duration(hours: 20)),
        ),
        ApplicationChatMessage(
          fromEmployer: false,
          text: '${DevTestAccounts.seekerBeta.displayName}입니다. '
              '내일 08:00 출근 가능합니다.',
          sentAt: now.subtract(const Duration(hours: 19, minutes: 30)),
        ),
        ApplicationChatMessage(
          fromEmployer: true,
          text: '확인했습니다. 근무합의 완료되었습니다.',
          sentAt: now.subtract(const Duration(hours: 19)),
        ),
      ],
    );
  }

  static Future<void> _seedChatIfEmpty(
    ApplicationChatMessageRepository chatRepo, {
    required String applicationId,
    required List<ApplicationChatMessage> messages,
  }) async {
    final existing = await chatRepo.load(applicationId);
    if (existing.isNotEmpty) return;
    await chatRepo.saveAll(applicationId, messages);
  }

  static Future<void> _ensureDevPushWallets() async {
    const alphaWallet = EmployerPushWallet(
      packageCredits: 10,
      locationSlotsFromPackages: 10,
      lifetimePackagesPurchased: 10,
    );
    const betaWallet = EmployerPushWallet(
      packageCredits: 5,
      locationSlotsFromPackages: 5,
      lifetimePackagesPurchased: 5,
    );

    final walletRepo = await PushWalletRepository.create();
    final ledger = await CompanyBonusLedgerRepository.create();
    final alphaKey =
        DevTestAccounts.corpAlpha.verifiedCorporateProfile!.companyKey;
    final betaKey =
        DevTestAccounts.corpBeta.verifiedCorporateProfile!.companyKey;

    final alphaExisting = await walletRepo.load(alphaKey);
    if (alphaExisting.lifetimePackagesPurchased == 0) {
      await walletRepo.save(alphaKey, alphaWallet);
    }
    final betaExisting = await walletRepo.load(betaKey);
    if (betaExisting.lifetimePackagesPurchased == 0) {
      await walletRepo.save(betaKey, betaWallet);
    }

    await ledger.tryClaimSignupBonus(alphaKey);
    await ledger.tryClaimSignupBonus(betaKey);
    await ledger.tryClaimVerificationBonus(alphaKey);
    await ledger.tryClaimVerificationBonus(betaKey);
  }

  static Future<void> _ensureCorporateRegistry() async {
    final registry = await CorporateAccountRegistry.create();
    for (final account in [DevTestAccounts.corpAlpha, DevTestAccounts.corpBeta]) {
      final brn = account.businessRegistrationNumber!;
      final existing = await registry.existingCodesForCompany(brn);
      if (existing.contains(account.handlerCode)) continue;
      await registry.registerHandler(
        companyName: account.companyName!,
        businessRegistrationNumber: brn,
        department: account.department!,
        contactPersonName: account.contactPersonName!,
      );
    }
  }
}
