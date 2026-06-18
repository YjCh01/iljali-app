import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/job_board/job_board_refresh.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/features/corporate/data/datasources/corporate_job_post_local_data_source.dart';
import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';
import 'package:map/features/corporate/domain/usecases/get_corporate_job_posts_usecase.dart';
import 'package:map/features/corporate/presentation/widgets/corporate_exposure_mini_map.dart';
import 'package:map/features/job_seeker/data/datasources/job_map_pins_data_source.dart';
import 'package:map/features/job_seeker/domain/entities/job_map_pin.dart';
import 'package:map/features/job_seeker/domain/usecases/get_job_map_pins_usecase.dart';

/// 홈 — 우리 공고 + 주변 채용 mock 지도 (확대 · 패닝 · 핀만)
class CorporateHomeExposureMap extends StatefulWidget {
  const CorporateHomeExposureMap({super.key});

  @override
  State<CorporateHomeExposureMap> createState() =>
      _CorporateHomeExposureMapState();
}

class _CorporateHomeExposureMapState extends State<CorporateHomeExposureMap> {
  static const _postsSource = CorporateJobPostLocalDataSourceImpl();

  final _getPins = GetJobMapPinsUseCase(const JobMapPinsLocalDataSource());
  final _getPosts = const GetCorporateJobPostsUseCase(_postsSource);

  List<JobMapPin> _allPins = [];
  List<JobMapPin> _ownPins = [];
  Set<String> _ownPostIds = {};
  int _ownCount = 0;
  bool _loading = true;
  bool _expanded = false;

  static const _collapsedMapHeight = 248.0;
  static const _expandedMapHeight = 420.0;

  @override
  void initState() {
    super.initState();
    _load();
    AuthSession.instance.corporateProfileRevision.addListener(_onProfileChanged);
  }

  @override
  void dispose() {
    AuthSession.instance.corporateProfileRevision
        .removeListener(_onProfileChanged);
    super.dispose();
  }

  void _onProfileChanged() => _load();

  Future<void> _load() async {
    JobBoardRefresh.consumeIfDirty();
    final pins = await _getPins();
    final posts = await _getPosts();
    final companyKey =
        AuthSession.instance.currentUser?.corporateProfile?.companyKey;

    final ownActive = posts.where((post) {
      if (post.status == CorporateJobPostStatus.closed) return false;
      if (companyKey == null) return true;
      final key = post.registeredBy?.companyKey;
      return key == null || key == companyKey;
    }).toList();

    final ownIds = ownActive.map((p) => p.id).toSet();
    final ownPins = pins.where((pin) => ownIds.contains(pin.post.id)).toList();

    if (!mounted) return;
    setState(() {
      _allPins = pins;
      _ownPins = ownPins;
      _ownPostIds = ownIds;
      _ownCount = ownActive.length;
      _loading = false;
    });
  }

  void _toggleExpanded() => setState(() => _expanded = !_expanded);

  void _onPinTap(JobMapPin pin) {
    final isOwn = _ownPostIds.contains(pin.post.id);
    if (isOwn) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('내 공고 · ${pin.post.title}'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('다른 기업의 채용 공고는 열람할 수 없습니다.'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mapPins = _expanded ? _allPins : _ownPins;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.searchBarBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
              child: Row(
                children: [
                  const Icon(
                    Icons.map_outlined,
                    size: 20,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _loading ? '불러오는 중…' : '채용 현황',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: _expanded ? '지도 접기' : '지도 확대',
                    onPressed: _loading ? null : _toggleExpanded,
                    icon: AnimatedRotation(
                      turns: _expanded ? 0.25 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.textSecondary.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              height: _expanded ? _expandedMapHeight : _collapsedMapHeight,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(16),
                ),
                child: _loading
                    ? const Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : CorporateExposureMiniMap(
                        key: ValueKey('exposure_map_$_expanded'),
                        pins: mapPins,
                        ownPostIds: _ownPostIds,
                        interactive: _expanded,
                        onPinTap: _expanded ? _onPinTap : null,
                        initialZoom: _expanded ? 12.5 : 12.0,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
