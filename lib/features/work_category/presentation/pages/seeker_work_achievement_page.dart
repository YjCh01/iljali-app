import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/core/widgets/app_back_button.dart';
import 'package:map/features/corporate/presentation/widgets/corporate_surface_card.dart';
import 'package:map/features/work_category/domain/entities/seeker_work_achievement.dart';
import 'package:map/features/work_category/domain/services/work_achievement_service.dart';
import 'package:map/features/work_category/presentation/widgets/seeker_work_achievement_grid.dart';

/// 구직자 업무 업적 전체 보기
class SeekerWorkAchievementPage extends StatefulWidget {
  const SeekerWorkAchievementPage({super.key});

  @override
  State<SeekerWorkAchievementPage> createState() =>
      _SeekerWorkAchievementPageState();
}

class _SeekerWorkAchievementPageState extends State<SeekerWorkAchievementPage> {
  SeekerWorkAchievementSummary? _summary;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final email = AuthSession.instance.currentUser?.email;
    if (email == null) {
      setState(() {
        _summary = null;
        _loading = false;
      });
      return;
    }
    final service = WorkAchievementService();
    final summary = await service.loadSummary(email);
    if (!mounted) return;
    setState(() {
      _summary = summary;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summary;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: const AppBackButton(),
        title: const Text(
          '내 업무 업적',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                CorporateSurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '현장 경험 업적',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        summary == null
                            ? '로그인 후 업적을 확인할 수 있습니다.'
                            : '완료한 현장 ${summary.totalCompletions}회 · '
                                '달성 카테고리 ${summary.earnedEntries.length}종',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary.withValues(alpha: 0.95),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (summary != null) ...[
                  Text(
                    '달성한 업무',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary.withValues(alpha: 0.95),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (summary.earnedEntries.isEmpty)
                    CorporateSurfaceCard(
                      child: Text(
                        '출근 확인이 완료된 근무가 쌓이면\n'
                        '물류·청소·행사 등 업적 아이콘이 채워집니다.',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.45,
                          color: AppColors.textSecondary.withValues(alpha: 0.95),
                        ),
                      ),
                    )
                  else
                    CorporateSurfaceCard(
                      child: SeekerWorkAchievementGrid(
                        summary: summary,
                        showLocked: false,
                        iconSize: 52,
                      ),
                    ),
                  const SizedBox(height: 20),
                  Text(
                    '전체 카테고리',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary.withValues(alpha: 0.95),
                    ),
                  ),
                  const SizedBox(height: 10),
                  CorporateSurfaceCard(
                    child: SeekerWorkAchievementGrid(
                      summary: summary,
                      showLocked: true,
                      iconSize: 44,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '아이콘을 터치하면 업무명이 표시됩니다. '
                    '숫자는 해당 업무 완료 누적 횟수입니다.',
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.4,
                      color: AppColors.textSecondary.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}
