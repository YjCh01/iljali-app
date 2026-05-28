import 'package:map/core/config/env_config.dart';
import 'package:map/features/corporate/data/datasources/workplace_address_kakao_data_source.dart';
import 'package:map/features/corporate/data/datasources/workplace_address_local_data_source.dart';
import 'package:map/features/corporate/data/datasources/workplace_address_remote_data_source.dart';

/// 주소 검색: 서버(Juso) → Kakao 직접 → 로컬 샘플
abstract final class WorkplaceAddressDataSourceFactory {
  static WorkplaceAddressDataSource create() {
    if (EnvConfig.isComplianceApiEnabled) {
      return _ChainedAddressDataSource(
        primary: WorkplaceAddressRemoteDataSource(),
        secondary: EnvConfig.isKakaoAddressConfigured
            ? WorkplaceAddressKakaoDataSource()
            : const WorkplaceAddressLocalDataSource(),
      );
    }
    if (EnvConfig.isKakaoAddressConfigured) {
      return WorkplaceAddressKakaoDataSource();
    }
    return const WorkplaceAddressLocalDataSource();
  }
}

class _ChainedAddressDataSource implements WorkplaceAddressDataSource {
  _ChainedAddressDataSource({
    required this.primary,
    required this.secondary,
  });

  final WorkplaceAddressDataSource primary;
  final WorkplaceAddressDataSource secondary;

  @override
  Future<WorkplaceAddressSearchResult> search(String query) async {
    final primaryResult = await primary.search(query);
    if (primaryResult.addresses.isNotEmpty) return primaryResult;

    final secondaryResult = await secondary.search(query);
    if (secondaryResult.addresses.isNotEmpty) {
      return WorkplaceAddressSearchResult(
        addresses: secondaryResult.addresses,
        mock: secondaryResult.mock,
        message: primaryResult.message ?? secondaryResult.message,
      );
    }

    return WorkplaceAddressSearchResult(
      addresses: const [],
      mock: primaryResult.mock || secondaryResult.mock,
      message: primaryResult.message ??
          secondaryResult.message ??
          '검색 결과가 없습니다. JUSO/Kakao API 키를 확인해 주세요.',
    );
  }
}
