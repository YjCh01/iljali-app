import 'package:flutter/material.dart';

import 'package:map/core/widgets/adaptive_sheet.dart';
import 'package:map/core/constants/app_colors.dart';

import 'package:map/core/constants/app_routes.dart';

import 'package:map/core/session/auth_session.dart';

import 'package:map/features/map_dashboard/data/datasources/map_camera_holder.dart';

import 'package:map/features/map_dashboard/domain/entities/warehouse.dart';

import 'package:map/features/map_dashboard/presentation/widgets/map_search_bar.dart';

import 'package:map/features/map_dashboard/presentation/widgets/naver_map_background.dart';

import 'package:map/features/map_dashboard/presentation/widgets/warehouse_bottom_sheet.dart';



/// 메인 대시보드 — 네이버 지도 + 검색바 + 바텀 카드

class MainDashboardPage extends StatefulWidget {

  const MainDashboardPage({super.key});



  @override

  State<MainDashboardPage> createState() => _MainDashboardPageState();

}



class _MainDashboardPageState extends State<MainDashboardPage> {

  Warehouse? _selectedWarehouse;



  void _selectWarehouse(Warehouse warehouse) {

    setState(() => _selectedWarehouse = warehouse);

  }



  void _closeBottomSheet() {

    setState(() => _selectedWarehouse = null);

  }



  Future<void> _openSearch() async {

    final warehouse = await Navigator.of(context).pushNamed(

      AppRoutes.search,

    );

    if (!mounted || warehouse is! Warehouse) return;



    await MapCameraHolder.instance.focusWarehouse(warehouse);

    _selectWarehouse(warehouse);

  }



  Future<void> _applyWarehouse() async {

    final warehouse = _selectedWarehouse;

    if (warehouse == null) return;



    final user = AuthSession.instance.currentUser;

    final confirmed = await showDialog<bool>(

      context: context,

      builder: (context) => AlertDialog(

        title: const Text('지원 확인'),

        content: Column(

          mainAxisSize: MainAxisSize.min,

          crossAxisAlignment: CrossAxisAlignment.start,

          children: [

            Text(

              warehouse.name,

              style: const TextStyle(fontWeight: FontWeight.w700),

            ),

            const SizedBox(height: 8),

            Text(warehouse.jobSummary),

            if (user != null) ...[

              const SizedBox(height: 12),

              Text('지원자: ${user.name}'),

              Text(user.email),

            ],

          ],

        ),

        actions: [

          TextButton(

            onPressed: () => Navigator.of(context).pop(false),

            child: const Text('취소'),

          ),

          FilledButton(

            onPressed: () => Navigator.of(context).pop(true),

            child: const Text('지원하기'),

          ),

        ],

      ),

    );



    if (confirmed != true || !mounted) return;



    _closeBottomSheet();



    ScaffoldMessenger.of(context)

      ..hideCurrentSnackBar()

      ..showSnackBar(

        SnackBar(

          content: Text('${warehouse.name} 지원이 접수되었습니다.'),

          behavior: SnackBarBehavior.floating,

          duration: const Duration(seconds: 2),

        ),

      );

  }



  Future<void> _logout() async {
    await AuthSession.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.memberGateway,
      (_) => false,
    );
  }



  void _showProfileMenu() {

    final user = AuthSession.instance.currentUser;

    showAdaptiveSheet<void>(

      context: context,

      builder: (context) => SafeArea(

        child: Padding(

          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),

          child: Column(

            mainAxisSize: MainAxisSize.min,

            crossAxisAlignment: CrossAxisAlignment.stretch,

            children: [

              Center(

                child: Container(

                  width: 44,

                  height: 4,

                  decoration: BoxDecoration(

                    color: AppColors.primaryLight.withValues(alpha: 0.5),

                    borderRadius: BorderRadius.circular(2),

                  ),

                ),

              ),

              const SizedBox(height: 16),

              Text(

                user?.name ?? '게스트',

                style: const TextStyle(

                  fontSize: 18,

                  fontWeight: FontWeight.w700,

                ),

              ),

              if (user?.email != null) ...[

                const SizedBox(height: 4),

                Text(

                  user!.email,

                  style: TextStyle(

                    color: AppColors.textSecondary.withValues(alpha: 0.9),

                  ),

                ),

              ],

              const SizedBox(height: 20),

              OutlinedButton(

                onPressed: () {

                  Navigator.of(context).pop();

                  _logout();

                },

                child: const Text('로그아웃'),

              ),

            ],

          ),

        ),

      ),

    );

  }



  @override

  Widget build(BuildContext context) {

    final selected = _selectedWarehouse;

    final showSheet = selected != null;



    return Scaffold(

      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: NaverMapBackground(

              onWarehouseTap: _selectWarehouse,

              onMapBackgroundTap: showSheet ? _closeBottomSheet : null,

            ),

          ),

          if (showSheet)

            Positioned.fill(

              child: GestureDetector(

                onTap: _closeBottomSheet,

                child: Container(color: Colors.black.withValues(alpha: 0.12)),

              ),

            ),

          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: Padding(
              padding: const EdgeInsets.only(right: 56),
              child: MapSearchBar(onTap: _openSearch),
            ),
          ),

          Positioned(

            top: 0,

            right: 16,

            child: SafeArea(

              bottom: false,

              child: Padding(

                padding: const EdgeInsets.only(top: 12),

                child: Material(

                  elevation: 2,

                  shadowColor: Colors.black26,

                  borderRadius: BorderRadius.circular(24),

                  color: AppColors.searchBarBackground,

                  child: InkWell(

                    onTap: _showProfileMenu,

                    borderRadius: BorderRadius.circular(24),

                    child: Container(

                      width: 48,

                      height: 48,

                      alignment: Alignment.center,

                      decoration: BoxDecoration(

                        borderRadius: BorderRadius.circular(24),

                        border: Border.all(color: AppColors.searchBarBorder),

                      ),

                      child: const Icon(

                        Icons.person_outline,

                        color: AppColors.textSecondary,

                      ),

                    ),

                  ),

                ),

              ),

            ),

          ),

          Positioned(

            left: 0,

            right: 0,

            bottom: 0,

            child: AnimatedSlide(

              duration: const Duration(milliseconds: 280),

              curve: Curves.easeOutCubic,

              offset: showSheet ? Offset.zero : const Offset(0, 1),

              child: AnimatedOpacity(

                duration: const Duration(milliseconds: 220),

                opacity: showSheet ? 1 : 0,

                child: IgnorePointer(

                  ignoring: !showSheet,

                  child: selected == null

                      ? const SizedBox.shrink()

                      : WarehouseBottomSheet(

                          warehouse: selected,

                          onBack: _closeBottomSheet,

                          onApply: _applyWarehouse,

                        ),

                ),

              ),

            ),

          ),

        ],

      ),

    );

  }

}


