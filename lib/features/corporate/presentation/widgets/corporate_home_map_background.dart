import 'package:flutter/material.dart';

import 'package:map/core/constants/app_colors.dart';

import 'package:map/core/job_board/job_board_refresh.dart';

import 'package:map/core/session/auth_session.dart';

import 'package:map/features/corporate/data/datasources/corporate_job_post_local_data_source.dart';

import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';

import 'package:map/features/corporate/domain/usecases/get_corporate_job_posts_usecase.dart';

import 'package:map/features/commute/data/repositories/commute_route_repository.dart';

import 'package:map/features/corporate/domain/entities/corporate_shuttle_map_overlay.dart';

import 'package:map/features/corporate/domain/services/corporate_shuttle_density_loader.dart';

import 'package:map/features/corporate/domain/utils/corporate_map_content_access_policy.dart';

import 'package:map/features/corporate/presentation/widgets/corporate_home_naver_map.dart';

import 'package:map/features/corporate/presentation/widgets/corporate_map_intel_paywall.dart';

import 'package:map/features/job_seeker/data/datasources/job_map_pins_data_source.dart';

import 'package:map/features/job_seeker/domain/entities/job_map_pin.dart';

import 'package:map/features/job_seeker/domain/usecases/get_job_map_pins_usecase.dart';



/// 기업 홈 — 전체 화면 채용 지도 배경

class CorporateHomeMapBackground extends StatefulWidget {

  const CorporateHomeMapBackground({

    super.key,

    this.focusPostId,

    this.selectedPostId,

    this.onSelectedPinChanged,

    this.onFocusConsumed,

  });



  final String? focusPostId;

  final String? selectedPostId;

  final ValueChanged<JobMapPin?>? onSelectedPinChanged;

  final VoidCallback? onFocusConsumed;



  @override

  State<CorporateHomeMapBackground> createState() =>

      _CorporateHomeMapBackgroundState();

}



class _CorporateHomeMapBackgroundState extends State<CorporateHomeMapBackground> {

  static const _postsSource = CorporateJobPostLocalDataSourceImpl();



  final _getPins = GetJobMapPinsUseCase(const JobMapPinsLocalDataSource());

  final _getPosts = GetCorporateJobPostsUseCase(_postsSource);



  List<JobMapPin> _allPins = [];

  List<CorporateShuttleMapOverlay> _shuttleOverlays = [];

  Set<String> _ownPostIds = {};

  bool _loading = true;

  bool _showAllPins = true;

  JobMapPin? _centerOnPin;

  String? _appliedFocusPostId;



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



  @override

  void didUpdateWidget(CorporateHomeMapBackground oldWidget) {

    super.didUpdateWidget(oldWidget);

    if (widget.focusPostId != oldWidget.focusPostId &&

        widget.focusPostId != null) {

      _appliedFocusPostId = null;

      _applyFocusPostId();

    }

  }



  void _onProfileChanged() => _load();



  JobMapPin? _findPinByPostId(String postId) {

    for (final pin in _allPins) {

      if (pin.post.id == postId) return pin;

    }

    return null;

  }



  void _applyFocusPostId() {

    final id = widget.focusPostId;

    if (id == null || _loading || _appliedFocusPostId == id) return;



    final pin = _findPinByPostId(id);

    if (pin == null || !_ownPostIds.contains(id)) return;



    _appliedFocusPostId = id;

    setState(() {

      _centerOnPin = pin;

      _showAllPins = true;

    });

    widget.onSelectedPinChanged?.call(pin);

    widget.onFocusConsumed?.call();

  }



  Future<void> _load() async {

    JobBoardRefresh.consumeIfDirty();

    final pins = await _getPins();

    final posts = await _getPosts();

    final routeRepo = await CommuteRouteRepository.create();

    final shuttleOverlays = await CorporateShuttleDensityLoader.load(

      routeRepo: routeRepo,

      posts: posts,

      pins: pins,

    );

    final companyKey =

        AuthSession.instance.currentUser?.corporateProfile?.companyKey;



    final ownActive = posts.where((post) {

      if (post.status == CorporateJobPostStatus.closed) return false;

      if (companyKey == null) return true;

      final key = post.registeredBy?.companyKey;

      return key == null || key == companyKey;

    }).toList();



    final ownIds = ownActive.map((p) => p.id).toSet();

    if (!mounted) return;

    setState(() {

      _allPins = pins;

      _shuttleOverlays = shuttleOverlays;

      _ownPostIds = ownIds;

      _loading = false;

    });

    _applyFocusPostId();

  }



  List<JobMapPin> get _visiblePins {

    if (_showAllPins) return _allPins;

    return _allPins.where((p) => _ownPostIds.contains(p.post.id)).toList();

  }



  void _onPinTap(JobMapPin pin) {

    final isOwn = _ownPostIds.contains(pin.post.id);

    if (isOwn) {

      setState(() => _centerOnPin = pin);

      widget.onSelectedPinChanged?.call(pin);

      return;

    }

    final profile = AuthSession.instance.currentUser?.corporateProfile;

    if (CorporateMapContentAccessPolicy.canViewPostContent(

      viewerProfile: profile,

      ownPostIds: _ownPostIds,

      post: pin.post,

    )) {

      setState(() => _centerOnPin = pin);

      widget.onSelectedPinChanged?.call(pin);

      return;

    }

    showCorporateMapIntelPaywall(context);

  }



  void _onShuttleStopTap(CorporateShuttleMapOverlay overlay) {

    final profile = AuthSession.instance.currentUser?.corporateProfile;

    if (CorporateMapContentAccessPolicy.canViewShuttleContent(

      viewerProfile: profile,

      routeCompanyKey: overlay.companyKey,

    )) {

      ScaffoldMessenger.of(context).showSnackBar(

        SnackBar(

          content: Text('셔틀 노선 · ${overlay.route.routeName}'),

          behavior: SnackBarBehavior.floating,

          duration: const Duration(seconds: 2),

        ),

      );

      return;

    }

    showCorporateMapIntelPaywall(context);

  }



  @override

  Widget build(BuildContext context) {

    return Stack(

      fit: StackFit.expand,

      children: [

        if (_loading)

          const ColoredBox(

            color: AppColors.background,

            child: Center(child: CircularProgressIndicator()),

          )

        else

          CorporateHomeNaverMap(
            pins: _visiblePins,
            ownPostIds: _ownPostIds,
            shuttleOverlays: _shuttleOverlays,
            onPinTap: _onPinTap,
            onShuttleStopTap: _onShuttleStopTap,
            selectedPostId: widget.selectedPostId,
            centerOnPin: _centerOnPin,
            onMapBackgroundTap: () => widget.onSelectedPinChanged?.call(null),
          ),

        Positioned(

          left: 16,

          top: 8,

          child: SafeArea(

            bottom: false,

            child: _MapFilterChip(

              label: _showAllPins ? '주변 공고 포함' : '내 공고만',

              onTap: () => setState(() => _showAllPins = !_showAllPins),

            ),

          ),

        ),

      ],

    );

  }

}



class _MapFilterChip extends StatelessWidget {

  const _MapFilterChip({required this.label, required this.onTap});



  final String label;

  final VoidCallback onTap;



  @override

  Widget build(BuildContext context) {

    return Material(

      color: Colors.white.withValues(alpha: 0.94),

      elevation: 2,

      shadowColor: Colors.black26,

      borderRadius: BorderRadius.circular(20),

      child: InkWell(

        onTap: onTap,

        borderRadius: BorderRadius.circular(20),

        child: Padding(

          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),

          child: Row(

            mainAxisSize: MainAxisSize.min,

            children: [

              Icon(

                Icons.layers_outlined,

                size: 16,

                color: AppColors.primary.withValues(alpha: 0.9),

              ),

              const SizedBox(width: 6),

              Text(

                label,

                style: const TextStyle(

                  fontSize: 12,

                  fontWeight: FontWeight.w700,

                ),

              ),

            ],

          ),

        ),

      ),

    );

  }

}


