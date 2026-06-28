import 'package:map/core/hiring/hiring_application.dart';
import 'package:map/core/hiring/hiring_credential_access.dart';
import 'package:map/core/hiring/local_hiring_repository.dart';
import 'package:map/core/session/auth_user.dart';
import 'package:map/features/corporate/domain/services/seeker_profile_lookup.dart';
import 'package:map/features/credential/domain/entities/credential_catalog.dart';
import 'package:map/features/job_seeker/domain/entities/employer_visible_credential.dart';
import 'package:map/features/job_seeker/domain/entities/resume_item_kind.dart';
import 'package:map/features/job_seeker/domain/entities/seeker_member_profile.dart';
import 'package:map/features/job_seeker/domain/entities/seeker_resume_content.dart';
import 'package:map/features/job_seeker/domain/utils/seeker_age.dart';
import 'package:map/features/job_seeker/domain/utils/seeker_profile_credentials.dart';

/// 이력서 그리드·상세 화면 공통 데이터
class SeekerResumeSnapshot {
  const SeekerResumeSnapshot({
    required this.name,
    this.email,
    required this.genderLabel,
    required this.ageLabel,
    this.birthDateLabel = '-',
    this.nationalityLabel,
    this.phoneMasked,
    this.experienceSummary,
    this.preferredRegions = const [],
    this.preferredJobCategories = const [],
    this.resume = const SeekerResumeContent(),
    this.credentialLabels = const [],
    this.credentials = const [],
    this.canViewCredentialDocuments = false,
    this.credentialsArePostRequirements = false,
    this.disclosedItems,
    this.application,
  });

  final String name;
  final String? email;
  final String genderLabel;
  final String ageLabel;
  final String birthDateLabel;
  final String? nationalityLabel;
  final String? phoneMasked;
  final String? experienceSummary;
  final List<String> preferredRegions;
  final List<String> preferredJobCategories;
  final SeekerResumeContent resume;

  /// @deprecated Prefer [credentials] — 이름만 목록 (하위 호환)
  final List<String> credentialLabels;

  /// 기업회원용 자격증 요약 (보유 여부 · 채용 확정 후 원본)
  final List<EmployerVisibleCredential> credentials;
  final bool canViewCredentialDocuments;
  final bool credentialsArePostRequirements;
  final Set<ResumeItemKind>? disclosedItems;
  final SeekerResumeApplicationSection? application;

  bool get hasBasicIdentity => genderLabel != '-' && ageLabel != '-';

  int get heldCredentialCount =>
      credentials.where((credential) => credential.isHeld).length;

  SeekerResumeContent get visibleResume {
    if (disclosedItems == null) return resume;
    return resume.filtered(disclosedItems!);
  }

  factory SeekerResumeSnapshot.fromAuthUser(AuthUser user) {
    final profile = user.seekerProfile;
    final public = SeekerProfileLookup.forAuthUser(user);
    final credentials = _allHeldCredentials(profile, canViewDocuments: true);
    return SeekerResumeSnapshot(
      name: user.name,
      email: user.email.isNotEmpty ? user.email : null,
      genderLabel: public.genderLabel,
      ageLabel: public.ageLabel,
      birthDateLabel: public.birthDateLabel,
      nationalityLabel: profile?.nationality?.label,
      phoneMasked: user.phone,
      experienceSummary: public.experienceSummary,
      preferredRegions: public.preferredRegions,
      preferredJobCategories: public.preferredJobCategories,
      resume: profile?.resume ?? const SeekerResumeContent(),
      credentialLabels: credentials.map((c) => c.label).toList(),
      credentials: credentials,
      canViewCredentialDocuments: true,
    );
  }

  static List<EmployerVisibleCredential> _allHeldCredentials(
    SeekerMemberProfile? profile, {
    required bool canViewDocuments,
  }) {
    if (profile == null) return const [];
    return profile.completeCredentialHoldings.map((holding) {
      final label = CredentialCatalog.findById(holding.credentialId)?.label ??
          holding.credentialId;
      return EmployerVisibleCredential(
        credentialId: holding.credentialId,
        label: label,
        isHeld: true,
        imagePath: canViewDocuments ? holding.imagePath : null,
      );
    }).toList();
  }

  static List<EmployerVisibleCredential> _employerCredentials({
    required SeekerMemberProfile? profile,
    required List<String> requiredCredentialIds,
    required bool canViewDocuments,
    Set<ResumeItemKind>? disclosed,
  }) {
    if (requiredCredentialIds.isNotEmpty) {
      return requiredCredentialIds.map((id) {
        final holding = profile?.holdingFor(id);
        final label = CredentialCatalog.findById(id)?.label ?? id;
        final held = holding?.isComplete ?? false;
        return EmployerVisibleCredential(
          credentialId: id,
          label: label,
          isHeld: held,
          imagePath: canViewDocuments && held ? holding!.imagePath : null,
        );
      }).toList();
    }

    if (profile == null) return const [];

    final showFromDisclosure = disclosed == null ||
        disclosed.contains(ResumeItemKind.license) ||
        disclosed.contains(ResumeItemKind.certification);
    if (!showFromDisclosure) return const [];

    return _allHeldCredentials(profile, canViewDocuments: canViewDocuments);
  }

  factory SeekerResumeSnapshot.fromApplication(
    HiringApplication application, {
    List<String> postRequiredCredentialIds = const [],
  }) {
    final profile = SeekerProfileLookup.memberProfileForEmail(
      application.seekerEmail,
    );
    final public = SeekerProfileLookup.forEmail(application.seekerEmail);
    final fullResume = profile?.resume ?? const SeekerResumeContent();
    final disclosed = application.disclosedResumeItems.toSet();
    final requiredIds = application.requiredCredentialIds.isNotEmpty
        ? application.requiredCredentialIds
        : postRequiredCredentialIds;
    final canViewDocuments =
        HiringCredentialAccess.canEmployerViewCredentialDocuments(application);
    final credentials = _employerCredentials(
      profile: profile,
      requiredCredentialIds: requiredIds,
      canViewDocuments: canViewDocuments,
      disclosed: disclosed.isEmpty ? null : disclosed,
    );

    return SeekerResumeSnapshot(
      name: application.seekerName,
      genderLabel: public.genderLabel,
      ageLabel: public.ageLabel,
      birthDateLabel: public.birthDateLabel,
      phoneMasked: application.seekerPhoneMasked,
      experienceSummary: public.experienceSummary,
      preferredRegions: public.preferredRegions,
      preferredJobCategories: public.preferredJobCategories,
      resume: fullResume,
      credentialLabels: credentials
          .where((credential) => credential.isHeld)
          .map((credential) => credential.label)
          .toList(),
      credentials: credentials,
      canViewCredentialDocuments: canViewDocuments,
      credentialsArePostRequirements: requiredIds.isNotEmpty,
      disclosedItems: disclosed.isEmpty ? null : disclosed,
      application: SeekerResumeApplicationSection(
        postTitle: application.postTitle,
        companyName: application.companyName,
        workSchedule: application.workSchedule,
        workDateLabel: application.workDate != null
            ? LocalHiringRepository.formatWorkDateFull(application.workDate!)
            : null,
        appliedAtLabel: LocalHiringRepository.formatRelativeTime(
          application.appliedAt,
        ),
        hireConfirmed: canViewDocuments,
      ),
    );
  }

  static SeekerResumeSnapshot fromProfile({
    required String name,
    required SeekerMemberProfile profile,
    String? email,
    String? phone,
    Set<ResumeItemKind>? disclosedItems,
  }) {
    final credentials = _allHeldCredentials(profile, canViewDocuments: true);
    return SeekerResumeSnapshot(
      name: name,
      email: email,
      genderLabel: profile.gender?.resumeLabel ?? '-',
      ageLabel: SeekerAge.formatLabel(profile.dateOfBirth),
      birthDateLabel: SeekerProfileLookup.formatBirthDate(profile.dateOfBirth),
      nationalityLabel: profile.nationality?.label,
      phoneMasked: phone,
      experienceSummary: profile.experienceSummary,
      preferredRegions: profile.preferredRegions,
      preferredJobCategories: profile.preferredJobCategories,
      resume: profile.resume,
      credentialLabels: credentials.map((c) => c.label).toList(),
      credentials: credentials,
      canViewCredentialDocuments: true,
      disclosedItems: disclosedItems,
    );
  }
}

class SeekerResumeApplicationSection {
  const SeekerResumeApplicationSection({
    required this.postTitle,
    required this.companyName,
    required this.workSchedule,
    this.workDateLabel,
    required this.appliedAtLabel,
    this.hireConfirmed = false,
  });

  final String postTitle;
  final String companyName;
  final String workSchedule;
  final String? workDateLabel;
  final String appliedAtLabel;
  final bool hireConfirmed;
}
