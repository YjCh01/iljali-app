import 'package:map/core/compliance/data/compliance_repository.dart';
import 'package:map/core/compliance/services/mock_business_certificate_ocr_service.dart';
import 'package:map/core/compliance/services/ocr_service_factory.dart';
import 'package:map/core/dev/qc_demo_addresses.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/features/corporate/domain/entities/corporate_member_profile.dart';
import 'package:map/features/corporate/domain/entities/workplace_address.dart';
import 'package:map/features/corporate/domain/services/workplace_address_resolver.dart';

/// 공고 등록 — 등록증·내정보에 저장된 사업장 소재지 → [WorkplaceAddress]
class RegisteredBusinessWorkplaceLoadResult {
  const RegisteredBusinessWorkplaceLoadResult.success({
    required this.workplace,
    required this.sourceLabel,
    this.headOfficeSynced = false,
  })  : errorMessage = null,
        isSuccess = true;

  const RegisteredBusinessWorkplaceLoadResult.failure(this.errorMessage)
      : isSuccess = false,
        workplace = null,
        sourceLabel = null,
        headOfficeSynced = false;

  final bool isSuccess;
  final WorkplaceAddress? workplace;
  final String? sourceLabel;
  final String? errorMessage;
  final bool headOfficeSynced;
}

class RegisteredBusinessWorkplaceLoader {
  RegisteredBusinessWorkplaceLoader({
    BusinessCertificateOcrService? ocr,
  }) : _ocr = ocr ?? OcrServiceFactory.create();

  final BusinessCertificateOcrService _ocr;

  Future<RegisteredBusinessWorkplaceLoadResult> load({
    CorporateMemberProfile? profile,
  }) async {
    profile ??= AuthSession.instance.currentUser?.corporateProfile;
    if (profile == null) {
      return const RegisteredBusinessWorkplaceLoadResult.failure(
        '기업 회원 정보가 없습니다.',
      );
    }

    final resolved = await _resolveRawAddress(profile);
    if (resolved == null) {
      return const RegisteredBusinessWorkplaceLoadResult.failure(
        '사업장 소재지를 찾지 못했습니다.\n'
        '가입·내정보에서 사업자등록증을 제출했는지 확인하거나, '
        '내정보에서 본사 주소를 등록해 주세요.',
      );
    }

    final workplace = await WorkplaceAddressResolver.resolve(resolved.address);
    if (workplace == null) {
      return RegisteredBusinessWorkplaceLoadResult.failure(
        '「${resolved.address}」 주소를 지도 좌표로 변환하지 못했습니다.\n'
        '도로명 검색으로 직접 선택해 주세요.',
      );
    }

    var headOfficeSynced = false;
    if (profile.businessHeadOfficeAddress?.trim().isEmpty ?? true) {
      final updated = profile.copyWith(
        businessHeadOfficeAddress: workplace.roadAddress,
        businessHeadOfficeLatitude: workplace.coordinate?.latitude,
        businessHeadOfficeLongitude: workplace.coordinate?.longitude,
      );
      await AuthSession.instance.updateCorporateProfile(updated);
      headOfficeSynced = true;
    }

    return RegisteredBusinessWorkplaceLoadResult.success(
      workplace: workplace,
      sourceLabel: resolved.sourceLabel,
      headOfficeSynced: headOfficeSynced,
    );
  }

  Future<_ResolvedAddress?> _resolveRawAddress(
    CorporateMemberProfile profile,
  ) async {
    final headOffice = profile.businessHeadOfficeAddress?.trim();
    if (headOffice != null &&
        headOffice.isNotEmpty &&
        !QcDemoAddresses.isLegacyDemo(headOffice)) {
      return _ResolvedAddress(
        address: headOffice,
        sourceLabel: '내정보 사업자 소재지',
      );
    }

    final repo = await ComplianceRepository.create();
    final record = await repo.findByBrn(profile.companyKey);
    final saved = record?.registeredBusinessAddress?.trim();
    if (saved != null &&
        saved.isNotEmpty &&
        !QcDemoAddresses.isLegacyDemo(saved)) {
      return _ResolvedAddress(
        address: saved,
        sourceLabel: '등록증 사업장 소재지',
      );
    }

    final imageRef = record?.certificateImageRef?.trim();
    if (record != null && imageRef != null && imageRef.isNotEmpty) {
      final ocr = await _ocr.extractFromImage(
        imageRef: imageRef,
        expectedBrn: profile.companyKey,
        expectedCompanyName: profile.companyName,
      );
      final fromOcr = ocr.businessAddress?.trim();
      if (fromOcr != null &&
          fromOcr.isNotEmpty &&
          !QcDemoAddresses.isLegacyDemo(fromOcr)) {
        await repo.saveBusinessRecord(
          record.copyWith(registeredBusinessAddress: fromOcr),
        );
        return _ResolvedAddress(
          address: fromOcr,
          sourceLabel: '등록증 OCR 사업장 소재지',
        );
      }
    }

    return null;
  }
}

class _ResolvedAddress {
  const _ResolvedAddress({
    required this.address,
    required this.sourceLabel,
  });

  final String address;
  final String sourceLabel;
}
