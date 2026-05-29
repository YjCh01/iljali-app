import 'package:map/core/compliance/services/mock_nts_business_api_service.dart';
import 'package:map/core/compliance/services/odcloud_nts_business_api_service.dart';
import 'package:map/core/compliance/services/http_nts_business_api_service.dart';
import 'package:map/core/config/env_config.dart';

/// 환경에 맞는 국세청(공공데이터) 검증 클라이언트 선택
abstract final class NtsServiceFactory {
  static NtsBusinessApiService create() {
    if (EnvConfig.isNtsApiConfigured) {
      return OdcloudNtsBusinessApiService(
        serviceKey: EnvConfig.ntsServiceKey,
      );
    }
    if (EnvConfig.isComplianceApiEnabled) {
      return HttpNtsBusinessApiService();
    }
    return const MockNtsBusinessApiService();
  }

  static bool get isMockMode =>
      !EnvConfig.isNtsApiConfigured && !EnvConfig.isComplianceApiEnabled;
}
