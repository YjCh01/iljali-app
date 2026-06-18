import 'package:map/core/api/iljari_api_client.dart';
import 'package:map/core/config/env_config.dart';

/// 로컬 ↔ 서버 동기화 스텁 (API URL 없으면 no-op)
class LocalRemoteSyncService {
  LocalRemoteSyncService({IljariApiClient? client})
      : _client = client ?? IljariApiClient();

  final IljariApiClient _client;

  bool get isEnabled =>
      EnvConfig.isComplianceApiEnabled && _client.isEnabled;

  /// 로컬 변경분을 서버로 push (스텁 — 성공 시 true)
  Future<bool> pushLocalChanges() async {
    if (!isEnabled) return false;
    try {
      await _client.listJobPosts();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 서버에서 pull (스텁 — 성공 시 목록 반환, 실패·비활성 시 빈 목록)
  Future<List<Map<String, dynamic>>> pullJobPosts() async {
    if (!isEnabled) return const [];
    try {
      return await _client.listJobPosts();
    } catch (_) {
      return const [];
    }
  }

  /// 지원·채팅 동기화 시도 (스텁)
  Future<bool> syncHiringAndChat({
    String? seekerEmail,
    String? companyKey,
  }) async {
    if (!isEnabled) return false;
    try {
      await _client.listApplications(
        seekerEmail: seekerEmail,
        companyKey: companyKey,
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}
