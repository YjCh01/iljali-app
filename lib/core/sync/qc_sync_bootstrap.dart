import 'package:map/core/api/iljari_api_client.dart';
import 'package:map/core/geo/geo_coordinate.dart';
import 'package:map/core/sync/member_sanction_store.dart';
import 'package:map/core/compliance/business_verification_status.dart';
import 'package:map/core/config/env_config.dart';
import 'package:map/core/dev/qc_visual_scenario_seeder.dart';
import 'package:map/core/hiring/hiring_application.dart';
import 'package:map/core/hiring/hiring_application_status.dart';
import 'package:map/core/hiring/local_hiring_repository.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/core/session/auth_user.dart';
import 'package:map/core/session/member_type.dart';
import 'package:map/features/corporate/data/datasources/corporate_job_post_local_data_source.dart';
import 'package:map/features/corporate/data/repositories/push_wallet_repository.dart';
import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';
import 'package:map/features/corporate/domain/entities/corporate_member_profile.dart';
import 'package:map/features/corporate/domain/entities/employer_push_wallet.dart';
import 'package:map/features/corporate/domain/entities/push_notification_settings.dart';
import 'package:map/features/corporate/domain/entities/job_post_description_body.dart';
import 'package:map/features/corporate/domain/entities/worker_category.dart';
import 'package:map/features/corporate/domain/utils/job_post_validity.dart';
import 'package:map/features/job_seeker/data/datasources/closed_ghost_pin_local_data_source.dart';
import 'package:map/features/job_seeker/domain/entities/closed_ghost_pin.dart';
import 'package:map/features/job_seeker/domain/entities/job_map_pin_display_tier.dart';

/// 서버 QC DB → 로컬 in-memory·SharedPreferences 동기화
abstract final class QcSyncBootstrap {
  /// 비로그인(게스트) — 공고·고스트핀만 서버에서 pull
  static Future<void> pullPublicCatalogIfEnabled() async {
    if (!EnvConfig.isComplianceApiEnabled) return;

    final client = IljariApiClient();
    if (!client.isEnabled) return;

    try {
      final bootstrap = await client.syncBootstrap();
      await _hydratePosts(bootstrap);
      await _hydrateGhostPins(bootstrap);
    } on Object {
      // offline — 로컬 캐시 유지
    }
  }

  static Future<void> pullIfEnabled() async {
    if (!EnvConfig.isComplianceApiEnabled) return;

    final client = IljariApiClient();
    if (!client.isEnabled) return;

    final user = AuthSession.instance.currentUser;
    final bootstrap = await client.syncBootstrap(
      seekerEmail:
          user?.memberType == MemberType.individual ? user?.email : null,
      memberEmail: user?.email,
      companyKey: user?.corporateProfile?.companyKey,
    );

    await _hydratePosts(bootstrap);
    await _hydrateGhostPins(bootstrap);
    await _mergeApplications(bootstrap);
    await _mergeWallet(bootstrap, user);
    await _persistMemberSanction(bootstrap, user);
    await _enforceMemberSanction(bootstrap, user);
    await QcVisualScenarioSeeder.ensureAfterSync();
  }

  static Future<void> _hydratePosts(Map<String, dynamic> bootstrap) async {
    final posts = bootstrap['posts'] as List<dynamic>? ?? [];
    final entitlements =
        bootstrap['post_entitlements'] as Map<String, dynamic>? ?? {};
    if (posts.isEmpty) return;

    final mapped = <CorporateJobPost>[];
    for (final raw in posts) {
      if (raw is! Map) continue;
      final map = Map<String, dynamic>.from(raw);
      final id = map['id'] as String? ?? '';
      if (id.isEmpty) continue;

      final entRaw = entitlements[id];
      final ent = entRaw is Map ? Map<String, dynamic>.from(entRaw) : null;
      final pinActive = ent?['recruitment_pin_active'] == true;
      final shuttleActive = ent?['shuttle_exposure_active'] == true;
      final tierRaw = ent?['map_pin_tier'] as String?;
      final postedAt = DateTime.tryParse(map['created_at'] as String? ?? '') ??
          DateTime.now();
      final companyKey = map['company_key'] as String? ?? '';
      final companyName = map['company_name'] as String? ?? '';
      final lat = (map['workplace_latitude'] as num?)?.toDouble();
      final lng = (map['workplace_longitude'] as num?)?.toDouble();
      JobPostNotificationSettings? notificationSettings;
      if (lat != null && lng != null) {
        notificationSettings = JobPostNotificationSettings(
          basePoints: [
            PushNotificationBasePoint(
              id: 'workplace_$id',
              coordinate: GeoCoordinate(latitude: lat, longitude: lng),
              addressLabel: map['warehouse_name'] as String? ?? '',
              isPrimary: true,
            ),
          ],
        );
      }

      mapped.add(
        CorporateJobPost(
          id: id,
          title: map['title'] as String? ?? '공고',
          warehouseName: map['warehouse_name'] as String? ?? '',
          hourlyWage: map['hourly_wage'] as String? ?? '',
          workSchedule: map['work_schedule'] as String? ?? '',
          summary: map['summary'] as String? ?? '',
          jobDescription: (map['job_description'] as String?) ??
              (map['summary'] as String? ?? ''),
          descriptionBody: JobPostDescriptionBody.fromJson(
            map['description_body_json'],
          ),
          notificationSettings: notificationSettings,
          status: (map['status'] as String? ?? 'recruiting') == 'closed'
              ? CorporateJobPostStatus.closed
              : CorporateJobPostStatus.recruiting,
          applicantCount: 0,
          postedAt: postedAt,
          expiresAt: JobPostValidity.expiresAtFromRegistration(postedAt),
          workerCategory: WorkerCategory.daily,
          registeredBy: companyKey.isNotEmpty
              ? _syncProfile(companyKey: companyKey, companyName: companyName)
              : null,
          recruiterEmail: (map['posted_by_email'] as String?)?.trim(),
          mapPinDisplayTier: pinActive
              ? (JobMapPinDisplayTierX.tryParseLegacy(tierRaw) ??
                  JobMapPinDisplayTier.packageActive)
              : null,
          hasShuttleRouteOverlay: shuttleActive,
        ),
      );
    }
    CorporateJobPostLocalDataSourceImpl.replaceFromServer(mapped);
  }

  static Future<void> _hydrateGhostPins(Map<String, dynamic> bootstrap) async {
    final raw = bootstrap['ghost_pins'] as List<dynamic>? ?? [];
    final mapped = <ClosedGhostPin>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final pin = ClosedGhostPin.fromJson(Map<String, dynamic>.from(item));
      if (pin.id.isEmpty) continue;
      mapped.add(pin);
    }
    ClosedGhostPinLocalDataSourceImpl.replaceFromServer(mapped);
  }

  static CorporateMemberProfile _syncProfile({
    required String companyKey,
    required String companyName,
  }) {
    return CorporateMemberProfile(
      companyName: companyName.isNotEmpty ? companyName : 'QC기업',
      businessRegistrationNumber: companyKey,
      department: 'QC',
      contactPersonName: 'QC담당',
      handlerCode: '9999',
      verificationStatus: BusinessVerificationStatus.verified,
    );
  }

  static Future<void> _mergeApplications(
    Map<String, dynamic> bootstrap,
  ) async {
    final apps = bootstrap['applications'] as List<dynamic>? ?? [];
    if (apps.isEmpty) return;

    final repo = await LocalHiringRepository.create();
    for (final raw in apps) {
      if (raw is! Map) continue;
      final map = Map<String, dynamic>.from(raw);
      final id = map['id'] as String? ?? '';
      if (id.isEmpty) continue;
      await repo.mergeServerApplication(
        HiringApplication(
          id: id,
          postId: map['post_id'] as String? ?? '',
          postTitle: map['post_title'] as String? ?? '',
          companyName: map['company_name'] as String? ?? '',
          seekerEmail: map['seeker_email'] as String? ?? '',
          seekerName: map['seeker_name'] as String? ?? '',
          seekerPhoneMasked: '010-0000-0000',
          appliedAt: DateTime.tryParse(map['applied_at'] as String? ?? '') ??
              DateTime.now(),
          status: _statusFromApi(map['status'] as String? ?? 'applied'),
          workSchedule: map['work_schedule'] as String? ?? '',
          companyKey: map['company_key'] as String?,
        ),
      );
    }
  }

  static HiringApplicationStatus _statusFromApi(String label) {
    try {
      return HiringApplicationStatus.values.byName(label);
    } catch (_) {
      return HiringApplicationStatus.applied;
    }
  }

  static Future<void> _mergeWallet(
    Map<String, dynamic> bootstrap,
    AuthUser? user,
  ) async {
    final walletRaw = bootstrap['wallet'];
    final companyKey = user?.corporateProfile?.companyKey;
    if (walletRaw is! Map || companyKey == null || companyKey.isEmpty) return;

    final map = Map<String, dynamic>.from(walletRaw);
    final wallet = EmployerPushWallet(
      packageCredits: map['package_credits'] as int? ?? 0,
      cashBalanceKrw: map['cash_balance_krw'] as int? ?? 0,
      signupBonusRemaining: map['signup_bonus_remaining'] as int? ?? 0,
      locationSlotsFromPackages:
          map['location_slots_from_packages'] as int? ?? 0,
      lastFreePushDayKey: map['last_free_push_day_key'] as String?,
      signupBonusExpiresAt: DateTime.tryParse(
        map['signup_bonus_expires_at'] as String? ?? '',
      ),
    );
    final repo = await PushWalletRepository.create();
    await repo.save(companyKey, wallet);
  }

  static Future<void> _persistMemberSanction(
    Map<String, dynamic> bootstrap,
    AuthUser? user,
  ) async {
    final status = bootstrap['member_status'];
    if (user == null || status is! Map) return;
    final store = await MemberSanctionStore.create();
    await store.saveFromBootstrap(
      user.email,
      Map<String, dynamic>.from(status),
    );
  }

  static Future<void> _enforceMemberSanction(
    Map<String, dynamic> bootstrap,
    AuthUser? user,
  ) async {
    final status = bootstrap['member_status'];
    if (status is! Map || user == null) return;
    if (status['is_permanently_banned'] == true ||
        status['is_suspended'] == true) {
      await AuthSession.instance.signOut();
      throw QcMemberSanctionException(
        status['sanction_reason'] as String? ?? '이용이 제한된 계정입니다.',
      );
    }
  }
}

class QcMemberSanctionException implements Exception {
  QcMemberSanctionException(this.message);
  final String message;

  @override
  String toString() => message;
}
