import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/constants/app_routes.dart';
import 'package:map/features/corporate/data/datasources/corporate_chat_local_data_source.dart';
import 'package:map/features/corporate/domain/entities/corporate_chat_room.dart';
import 'package:map/features/corporate/domain/usecases/get_corporate_chat_rooms_usecase.dart';
import 'package:map/features/corporate/presentation/widgets/corporate_chat_room_card.dart';
import 'package:map/features/corporate/presentation/widgets/corporate_surface_card.dart';

/// 기업회원 6번 탭 — 예약·추가 기능
class CorporateMoreTab extends StatefulWidget {
  const CorporateMoreTab({super.key});

  @override
  State<CorporateMoreTab> createState() => _CorporateMoreTabState();
}

class _CorporateMoreTabState extends State<CorporateMoreTab> {
  final _getMoreMenu = const GetCorporateMoreMenuUseCase(
    CorporateChatLocalDataSourceImpl(),
  );

  List<CorporateMoreMenuItem> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await _getMoreMenu();
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const ColoredBox(
        color: AppColors.background,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return ColoredBox(
      color: AppColors.background,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          Text(
            '추가 기능',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary.withValues(alpha: 0.95),
            ),
          ),
          const SizedBox(height: 10),
          ..._items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: CorporateMoreMenuCard(
                item: item,
                onTap: () => showCorporateComingSoonSnackBar(context, item.title),
              ),
            ),
          ),
          const SizedBox(height: 8),
          CorporateSurfaceCard(
            onTap: () => Navigator.of(context)
                .pushNamed(AppRoutes.corporatePushPackageShop),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '유료 지역 푸시권',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '5,000원/회 · 10회 45,000원 · 30회 120,000원 · 100회 350,000원 · 황금핀은 100회 팩 전용',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: AppColors.textSecondary.withValues(alpha: 0.95),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          CorporateSurfaceCard(
            onTap: () =>
                Navigator.of(context).pushNamed(AppRoutes.corporateBranchManagement),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Multi-지점 관리',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '본사·지역·매장 계층 · 플랜별 지점 한도 · 공고·ROI 연동',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: AppColors.textSecondary.withValues(alpha: 0.95),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          CorporateSurfaceCard(
            onTap: () =>
                Navigator.of(context).pushNamed(AppRoutes.corporateRoiDashboard),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ROI 대시보드',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '출근 확인(10,000원/건) 대비 절감 · PDF 내보내기',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: AppColors.textSecondary.withValues(alpha: 0.95),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          CorporateSurfaceCard(
            onTap: () =>
                Navigator.of(context).pushNamed(AppRoutes.adminCompliance),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '컴플라이언스 대시보드',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '사업자 검증·이상행위·아웃소싱 의심 패턴 모니터링 (관리자)',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: AppColors.textSecondary.withValues(alpha: 0.95),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          CorporateSurfaceCard(
            onTap: () => showCorporateComingSoonSnackBar(context, '예약된 메뉴'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '예약된 메뉴',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '향후 관리자·기업 설정 기능이 이 영역에 추가됩니다.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: AppColors.textSecondary.withValues(alpha: 0.95),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
