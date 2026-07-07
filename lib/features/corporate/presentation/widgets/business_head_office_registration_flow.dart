import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/constants/app_routes.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/features/corporate/domain/entities/corporate_member_profile.dart';
import 'package:map/features/corporate/domain/entities/workplace_address.dart';

/// 공고 작성 중 본사(사업장 소재지) 주소를 내정보 이동 없이 등록
abstract final class BusinessHeadOfficeRegistrationFlow {
  static bool profileNeedsHeadOffice(CorporateMemberProfile? profile) {
    if (profile == null) return false;
    final addr = profile.businessHeadOfficeAddress?.trim();
    return addr == null || addr.isEmpty;
  }

  static bool shouldOfferInlineRegistration(String? message) {
    if (message == null || message.isEmpty) return false;
    return message.contains('본사 주소') ||
        message.contains('사업장 소재지를 찾지') ||
        message.contains('본사(소재지)');
  }

  static Future<bool> saveHeadOffice(WorkplaceAddress address) async {
    final profile = AuthSession.instance.currentUser?.corporateProfile;
    if (profile == null) return false;
    final updated = profile.copyWith(
      businessHeadOfficeAddress: address.roadAddress,
      businessHeadOfficeLatitude: address.coordinate?.latitude,
      businessHeadOfficeLongitude: address.coordinate?.longitude,
    );
    await AuthSession.instance.updateCorporateProfile(updated);
    return true;
  }

  /// 본사 주소가 없으면 등록 다이얼로그 표시. 등록 완료 시 true.
  static Future<bool> ensureRegistered(
    BuildContext context, {
    WorkplaceAddress? suggestedWorkplace,
  }) async {
    if (!profileNeedsHeadOffice(
      AuthSession.instance.currentUser?.corporateProfile,
    )) {
      return true;
    }
    return showRegisterDialog(
      context,
      suggestedWorkplace: suggestedWorkplace,
    );
  }

  static Future<bool> showRegisterDialog(
    BuildContext context, {
    WorkplaceAddress? suggestedWorkplace,
  }) async {
    final registered = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _HeadOfficeRegisterDialog(
        suggestedWorkplace: suggestedWorkplace,
      ),
    );
    return registered == true;
  }
}

class _HeadOfficeRegisterDialog extends StatelessWidget {
  const _HeadOfficeRegisterDialog({this.suggestedWorkplace});

  final WorkplaceAddress? suggestedWorkplace;

  bool get _hasSuggestedWorkplace =>
      suggestedWorkplace != null &&
      suggestedWorkplace!.roadAddress.trim().isNotEmpty;

  Future<void> _pickAndSave(BuildContext context) async {
    final picked = await Navigator.of(context).pushNamed<WorkplaceAddress>(
      AppRoutes.corporateWorkplaceSearch,
      arguments: suggestedWorkplace?.roadAddress,
    );
    if (picked == null || !context.mounted) return;
    final ok = await BusinessHeadOfficeRegistrationFlow.saveHeadOffice(picked);
    if (!context.mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _useSuggested(BuildContext context) async {
    final workplace = suggestedWorkplace;
    if (workplace == null) return;
    final ok =
        await BusinessHeadOfficeRegistrationFlow.saveHeadOffice(workplace);
    if (!context.mounted) return;
    if (ok) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('사업자 본사 주소 등록'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '공고 등록을 위해 사업자등록증상 사업장 소재지(본사)가 필요합니다.\n\n'
              '내정보로 이동하지 않아도, 지금 이 화면에서 바로 등록할 수 있습니다. '
              '작성 중인 공고 내용은 그대로 유지됩니다.',
              style: TextStyle(height: 1.45),
            ),
            if (_hasSuggestedWorkplace) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '입력한 근무지\n${suggestedWorkplace!.displayLabel}',
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (_hasSuggestedWorkplace)
              FilledButton(
                onPressed: () => _useSuggested(context),
                child: const Text('입력한 근무지를 본사 주소로 등록'),
              ),
            if (_hasSuggestedWorkplace) const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _pickAndSave(context),
              icon: const Icon(Icons.search_rounded, size: 18),
              label: const Text('다른 주소 검색·등록'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('나중에'),
        ),
      ],
    );
  }
}
