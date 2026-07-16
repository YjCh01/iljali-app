import 'package:image_picker/image_picker.dart';
import 'package:map/core/api/iljari_api_client.dart';
import 'package:map/features/job_seeker/presentation/utils/seeker_document_storage.dart';

/// 자격증 사진 — 서버 업로드(성공 시 공개 URL). 오프라인 등으로 실패하면
/// 기기 로컬 저장(모바일 경로 / 웹 base64)으로 폴백해 등록 자체는 막지 않는다.
Future<String?> persistCredentialImage(XFile file, String credentialId) async {
  try {
    final bytes = await file.readAsBytes();
    return await IljariApiClient().uploadCredentialMedia(
      bytes: bytes,
      filename: file.name,
    );
  } on Object {
    return persistSeekerDocumentImage(file, credentialId);
  }
}
