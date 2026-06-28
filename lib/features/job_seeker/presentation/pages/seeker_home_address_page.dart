import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/constants/app_routes.dart';
import 'package:map/core/geo/location_consent_service.dart';
import 'package:map/core/legal/legal_consent_catalog.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/core/widgets/app_back_button.dart';
import 'package:map/features/corporate/domain/entities/workplace_address.dart';
import 'package:map/features/corporate/presentation/widgets/corporate_surface_card.dart';
import 'package:map/features/job_seeker/domain/entities/seeker_member_profile.dart';
import 'package:map/features/job_seeker/domain/utils/seeker_home_address_resolver.dart';
import 'package:map/features/map_dashboard/data/datasources/map_viewport_session_store.dart';

/// 구직자 — 실주소 등록·수정 (지도 중심·매칭용)
class SeekerHomeAddressPage extends StatefulWidget {
  const SeekerHomeAddressPage({super.key});

  @override
  State<SeekerHomeAddressPage> createState() => _SeekerHomeAddressPageState();
}

class _SeekerHomeAddressPageState extends State<SeekerHomeAddressPage> {
  bool _saving = false;

  SeekerMemberProfile? get _profile =>
      AuthSession.instance.currentUser?.seekerProfile;

  Future<void> _editAddress() async {
    final result = await Navigator.of(context).pushNamed<WorkplaceAddress>(
      AppRoutes.corporateWorkplaceSearch,
      arguments: _profile?.homeRoadAddress,
    );
    if (result == null || !mounted) return;

    final granted = await LocationConsentService.ensureGranted(
      context,
      trigger: LocationConsentTrigger.mapBrowse,
    );
    if (!granted || !mounted) return;

    final current = _profile;
    if (current == null) return;

    setState(() => _saving = true);
    final now = DateTime.now();
    final updated = current.copyWith(
      homeRoadAddress: result.roadAddress,
      homeDetailAddress: result.detailAddress,
      homeLatitude: result.coordinate?.latitude,
      homeLongitude: result.coordinate?.longitude,
      locationConsentAcceptedAt: now,
      locationConsentVersion: LegalConsentCatalog.locationBasedVersion,
    );
    await AuthSession.instance.updateSeekerProfile(updated);
    MapViewportSessionStore.instance.forget(MapViewportSessionKeys.seekerHomeMap);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('실주소가 저장되었습니다. 지도가 주소 기준으로 표시됩니다.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final label = SeekerHomeAddressResolver.resolveLabel(_profile);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        leading: const AppBackButton(),
        automaticallyImplyLeading: false,
        title: const Text('실주소'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          const Text(
            '실주소',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            '등록한 주소를 중심으로 지도가 표시됩니다. 출근 확인 시에도 위치 권한을 다시 확인합니다.',
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: AppColors.textSecondary.withValues(alpha: 0.95),
            ),
          ),
          const SizedBox(height: 16),
          CorporateSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  label ?? '등록된 주소가 없습니다',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: label == null
                        ? AppColors.textSecondary
                        : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _saving ? null : _editAddress,
                  icon: const Icon(Icons.edit_location_alt_outlined),
                  label: Text(label == null ? '주소 등록' : '주소 변경'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
