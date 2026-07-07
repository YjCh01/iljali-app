import 'package:map/features/credential/domain/entities/credential_catalog.dart';
import 'package:map/features/job_seeker/domain/entities/seeker_credential_holding.dart';

/// 표준 목록에 없는 구직자 직접 등록 자격증
abstract final class CustomCredentialSupport {
  static const idPrefix = 'custom_';

  static bool isCustomId(String? id) =>
      id != null && id.startsWith(idPrefix);

  static String newId() =>
      '$idPrefix${DateTime.now().microsecondsSinceEpoch}';

  static String displayLabel(SeekerCredentialHolding holding) {
    final custom = holding.customLabel?.trim();
    if (custom != null && custom.isNotEmpty) return custom;
    return CredentialCatalog.findById(holding.credentialId)?.label ??
        holding.credentialId;
  }
}
