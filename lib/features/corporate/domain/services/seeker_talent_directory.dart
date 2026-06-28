import 'package:map/core/dev/dev_test_accounts.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/core/session/member_type.dart';
import 'package:map/features/auth/data/local/local_individual_auth_store.dart';
import 'package:map/features/corporate/domain/entities/talent_search_entry.dart';
import 'package:map/features/credential/domain/entities/credential_catalog.dart';
import 'package:map/features/job_seeker/domain/entities/seeker_member_profile.dart';

/// 구직자 인재 풀 — 로컬 계정·QC 시드·현재 세션 집계
abstract final class SeekerTalentDirectory {
  static Future<List<TalentSearchEntry>> loadAll() async {
    final byEmail = <String, _SeekerRow>{};

    for (final account in DevTestAccounts.all) {
      if (account.memberType != MemberType.individual) continue;
      final profile = account.verifiedSeekerProfile;
      if (profile == null) continue;
      byEmail[account.email] = _SeekerRow(
        email: account.email,
        displayName: account.displayName,
        profile: profile,
      );
    }

    final localRows = await LocalIndividualAuthStore.listAllAccounts();
    for (final row in localRows) {
      final email = (row['email'] as String?)?.trim().toLowerCase() ?? '';
      if (email.isEmpty) continue;
      final profileJson = row['seekerProfile'];
      if (profileJson is! Map) continue;
      byEmail[email] = _SeekerRow(
        email: email,
        displayName: (row['displayName'] as String?)?.trim() ?? '구직자',
        profile: SeekerMemberProfile.fromJson(
          Map<String, dynamic>.from(profileJson),
        ),
      );
    }

    final current = AuthSession.instance.currentUser;
    if (current != null &&
        current.memberType == MemberType.individual &&
        current.seekerProfile != null) {
      final email = current.email.trim().toLowerCase();
      byEmail[email] = _SeekerRow(
        email: email,
        displayName: current.name,
        profile: current.seekerProfile!,
      );
    }

    return byEmail.values.map(_toEntry).toList();
  }

  static TalentSearchEntry _toEntry(_SeekerRow row) {
    final profile = row.profile;
    final credentialIds =
        profile.credentialHoldings.map((h) => h.credentialId).toList();
    final weekdays = profile.workAvailability.slots
        .map((s) => s.weekday)
        .toSet()
        .toList();

    return TalentSearchEntry(
      seekerEmail: row.email,
      displayNameMasked: maskDisplayName(row.displayName),
      credentialIds: credentialIds,
      credentialLabels: CredentialCatalog.labelsForIds(credentialIds),
      preferredRegions: profile.preferredRegions,
      availableWeekdays: weekdays,
      experienceCount: profile.resume.experiences.length,
      proposalOffersAccepted: profile.proposalOffersAccepted,
    );
  }

  static String maskDisplayName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '구직자';
    if (trimmed.length == 1) return '$trimmed*';
    if (trimmed.length == 2) return '${trimmed[0]}*';
    return '${trimmed[0]}${'*' * (trimmed.length - 2)}${trimmed[trimmed.length - 1]}';
  }
}

final class _SeekerRow {
  const _SeekerRow({
    required this.email,
    required this.displayName,
    required this.profile,
  });

  final String email;
  final String displayName;
  final SeekerMemberProfile profile;
}
