import 'package:map/features/credential/domain/entities/credential_catalog.dart';
import 'package:map/features/job_seeker/domain/entities/resume_item_kind.dart';
import 'package:map/features/job_seeker/domain/entities/seeker_credential_holding.dart';
import 'package:map/features/job_seeker/domain/entities/seeker_member_profile.dart';

extension SeekerProfileCredentialsX on SeekerMemberProfile {
  SeekerCredentialHolding? holdingFor(String credentialId) {
    for (final h in credentialHoldings) {
      if (h.credentialId == credentialId) return h;
    }
    return null;
  }

  List<SeekerCredentialHolding> get completeCredentialHoldings =>
      credentialHoldings.where((h) => h.isComplete).toList();

  bool hasResumeContentFor(ResumeItemKind kind) {
    return switch (kind) {
      ResumeItemKind.education => resume.educations.isNotEmpty,
      ResumeItemKind.experience => resume.experiences.isNotEmpty,
      ResumeItemKind.license ||
      ResumeItemKind.certification =>
        completeCredentialHoldings.isNotEmpty,
      ResumeItemKind.selfIntroduction =>
        resume.selfIntroduction.trim().isNotEmpty,
    };
  }

  int countForResumeKind(ResumeItemKind kind) => switch (kind) {
        ResumeItemKind.education => resume.educations.length,
        ResumeItemKind.experience => resume.experiences.length,
        ResumeItemKind.license || ResumeItemKind.certification =>
          completeCredentialHoldings.length,
        ResumeItemKind.selfIntroduction =>
          resume.selfIntroduction.trim().isEmpty ? 0 : 1,
      };

  SeekerMemberProfile upsertCredentialHolding(SeekerCredentialHolding holding) {
    final list = List<SeekerCredentialHolding>.from(credentialHoldings);
    final index = list.indexWhere((h) => h.credentialId == holding.credentialId);
    if (index >= 0) {
      list[index] = holding;
    } else {
      list.add(holding);
    }
    return copyWith(credentialHoldings: list);
  }

  SeekerMemberProfile removeCredentialHolding(String credentialId) {
    return copyWith(
      credentialHoldings:
          credentialHoldings.where((h) => h.credentialId != credentialId).toList(),
    );
  }

  /// 이력서 상세용 라벨 목록
  List<String> credentialLabelsForDisplay({Set<String>? onlyIds}) {
    return completeCredentialHoldings
        .where((h) => onlyIds == null || onlyIds.contains(h.credentialId))
        .map((h) => CredentialCatalog.findById(h.credentialId)?.label ?? h.credentialId)
        .toList();
  }
}
