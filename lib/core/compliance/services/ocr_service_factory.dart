import 'package:map/core/compliance/services/clova_business_certificate_ocr_service.dart';
import 'package:map/core/compliance/services/mock_business_certificate_ocr_service.dart';
import 'package:map/core/config/env_config.dart';

abstract final class OcrServiceFactory {
  static BusinessCertificateOcrService create() {
    if (EnvConfig.isClovaOcrConfigured) {
      return ClovaBusinessCertificateOcrService();
    }
    return const MockBusinessCertificateOcrService();
  }
}
