import 'package:map/core/config/env_config.dart';
import 'package:map/core/hiring/application_chat_message.dart';
import 'package:map/core/hiring/application_chat_message_repository.dart';
import 'package:map/core/hiring/hiring_application.dart';
import 'package:map/core/hiring/hiring_application_status.dart';
import 'package:map/core/hiring/local_hiring_repository.dart';
import 'package:map/features/corporate/data/datasources/corporate_job_post_local_data_source.dart';
import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';
import 'package:map/features/job_seeker/data/repositories/job_bookmark_vault_repository.dart';
import 'package:map/features/job_seeker/domain/entities/job_map_pin.dart';
import 'package:map/features/job_seeker/domain/entities/job_map_pin_display_tier.dart';

/// QC 눈검증 — 테스트기업 알파 공고 + QC구직자 0001 지원·채팅·출근 시나리오
abstract final class QcVisualScenario {
  static const applicationId = 'qc_app_alpha_seeker_0001';
  static const seekerEmail = 'seeker-0001@qc.iljari.co.kr';
  static const seekerName = 'QC구직자 0001';
  static const companyKey = '1000000001';
  static const companyName = '테스트기업 알파';
  static const postId = 'qc_post_real_001';
}

abstract final class QcVisualScenarioSeeder {
  static Future<void> ensureAfterSync() async {
    if (!EnvConfig.isComplianceApiEnabled && !EnvConfig.qcMode) return;

    final post = await _resolvePost();
    if (post == null) return;

    final now = DateTime.now();
    final workDate = DateTime(now.year, now.month, now.day);
    final shiftDateIso =
        '${workDate.year}-${workDate.month.toString().padLeft(2, '0')}-${workDate.day.toString().padLeft(2, '0')}';

    final repo = await LocalHiringRepository.create();
    await repo.ensureSeedApplication(
      HiringApplication(
        id: QcVisualScenario.applicationId,
        postId: post.id,
        postTitle: post.title,
        companyName: post.registeredBy?.companyName ?? QcVisualScenario.companyName,
        seekerEmail: QcVisualScenario.seekerEmail,
        seekerName: QcVisualScenario.seekerName,
        seekerPhoneMasked: '010-****-0001',
        appliedAt: now.subtract(const Duration(days: 1)),
        status: HiringApplicationStatus.scheduled,
        workSchedule: post.workSchedule,
        employmentType: JobEmploymentType.daily,
        workDate: workDate,
        companyKey: QcVisualScenario.companyKey,
        recruiterEmail: 'recruit-alpha@qc.iljari.co.kr',
        seekerWorkAgreedAt: now.subtract(const Duration(hours: 6)),
        employerWorkAgreedAt: now.subtract(const Duration(hours: 5)),
        commissionAmountKrw: 15000,
        selectedShiftDate: shiftDateIso,
        shiftSlot: 'night',
        workplaceLatitude: 37.2792,
        workplaceLongitude: 127.4425,
      ),
    );

    await _ensureChatMessages(now, post.title);
    await _ensureVaultBookmark(post);
  }

  static Future<CorporateJobPost?> _resolvePost() async {
    const dataSource = CorporateJobPostLocalDataSourceImpl();
    final synced = await dataSource.findById(QcVisualScenario.postId);
    if (synced != null) return synced;

    final all = await dataSource.fetchJobPosts();
    for (final post in all) {
      final profile = post.registeredBy;
      final key = profile?.companyKey ?? profile?.businessRegistrationNumber;
      if (key == QcVisualScenario.companyKey) return post;
    }
    return null;
  }

  static Future<void> _ensureChatMessages(DateTime now, String postTitle) async {
    final chatRepo = await ApplicationChatMessageRepository.create();
    final existing =
        await chatRepo.load(QcVisualScenario.applicationId);
    if (existing.isNotEmpty) return;

    await chatRepo.saveAll(QcVisualScenario.applicationId, [
      ApplicationChatMessage(
        fromEmployer: true,
        text:
            '안녕하세요, ${QcVisualScenario.companyName} 채용 담당입니다.\n'
            '「$postTitle」 지원 감사합니다.',
        sentAt: now.subtract(const Duration(hours: 3)),
      ),
      ApplicationChatMessage(
        fromEmployer: false,
        text: '안녕하세요, ${QcVisualScenario.seekerName}입니다.\n'
            '근무 일정 확인 부탁드립니다.',
        sentAt: now.subtract(const Duration(hours: 2, minutes: 45)),
      ),
      ApplicationChatMessage(
        fromEmployer: true,
        text: '근무합의가 완료되었습니다.\n출근 당일 앱에서 출근 확인해 주세요.',
        sentAt: now.subtract(const Duration(hours: 2)),
      ),
    ]);
  }

  static Future<void> _ensureVaultBookmark(CorporateJobPost post) async {
    final vaultRepo =
        await JobBookmarkVaultRepository.create(QcVisualScenario.seekerEmail);
    if (vaultRepo == null) return;
    if (await vaultRepo.isBookmarked(post.id)) return;

    final pin = JobMapPin(
      post: post,
      latitude: 37.2792,
      longitude: 127.4425,
      companyName: post.registeredBy?.companyName ?? QcVisualScenario.companyName,
      displayTier: post.mapPinDisplayTier ?? JobMapPinDisplayTier.packageActive,
    );
    await vaultRepo.saveBookmark(pin);
  }
}
