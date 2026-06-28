import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/features/commute/domain/entities/commute_route.dart';
import 'package:map/features/job_seeker/data/repositories/job_bookmark_vault_repository.dart';
import 'package:map/features/job_seeker/domain/entities/job_map_pin.dart';
import 'package:map/features/job_seeker/domain/services/job_post_inquiry_service.dart';
import 'package:map/features/job_seeker/presentation/widgets/job_post_action_grid.dart';
import 'package:map/features/job_seeker/presentation/widgets/job_post_detail_sheet.dart';

/// 공고 상세 — 전체 화면 (콜아웃 → 공고 상세보기)
class JobPostDetailPage extends StatefulWidget {
  const JobPostDetailPage({
    super.key,
    required this.pin,
    this.vaultRepo,
    this.shuttleRoute,
    this.onApplied,
    this.employerPreview = false,
    this.onShowRouteOnMap,
  });

  final JobMapPin pin;
  final JobBookmarkVaultRepository? vaultRepo;
  final CommuteRoute? shuttleRoute;
  final VoidCallback? onApplied;
  final bool employerPreview;
  final VoidCallback? onShowRouteOnMap;

  @override
  State<JobPostDetailPage> createState() => _JobPostDetailPageState();
}

class _JobPostDetailPageState extends State<JobPostDetailPage> {
  final _sheetKey = GlobalKey<JobPostDetailSheetState>();
  bool _isBookmarked = false;
  bool _bookmarkBusy = false;
  bool _hasApplied = false;
  bool _canWithdraw = false;

  void _syncSheetState() {
    final sheet = _sheetKey.currentState;
    if (sheet == null) return;
    setState(() {
      _isBookmarked = sheet.isBookmarked;
      _bookmarkBusy = sheet.vaultBusy;
      _hasApplied = sheet.hasApplied;
      _canWithdraw = sheet.canWithdrawApplication;
    });
  }

  final _inquiry = const JobPostInquiryService();

  void _inquire() {
    if (widget.employerPreview) return;
    _inquiry.openInquiryChat(context, widget.pin).then((_) => _syncSheetState());
  }

  void _apply() {
    _sheetKey.currentState?.applyFromExternal().then((_) => _syncSheetState());
  }

  void _withdraw() {
    _sheetKey.currentState
        ?.withdrawFromExternal()
        .then((_) => _syncSheetState());
  }

  void _bookmark() {
    _sheetKey.currentState?.toggleBookmarkFromExternal();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        title: Text(
          widget.employerPreview ? '구직자 화면 미리보기' : '공고 상세',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
      ),
      body: Column(
        children: [
          if (widget.employerPreview)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: AppColors.primaryLight.withValues(alpha: 0.18),
              child: const Text(
                '내 공고가 구직자 지도·상세 화면에 이렇게 표시됩니다.',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 8),
              child: JobPostDetailSheet(
                key: _sheetKey,
                pin: widget.pin,
                shuttleRoute: widget.shuttleRoute,
                vaultRepo: widget.vaultRepo,
                onClose: () => Navigator.of(context).pop(),
                onApply: () {
                  widget.onApplied?.call();
                  if (mounted) Navigator.of(context).pop();
                },
                onShowRouteOnMap: widget.onShowRouteOnMap,
                embeddedInPage: true,
                onBookmarkStateChanged: (saved) {
                  setState(() {
                    _isBookmarked = saved;
                    _bookmarkBusy = _sheetKey.currentState?.vaultBusy ?? false;
                  });
                },
                onApplicationStateChanged: _syncSheetState,
              ),
            ),
          ),
          JobPostActionGrid(
            previewMode: widget.employerPreview,
            isBookmarked: _isBookmarked,
            bookmarkBusy: _bookmarkBusy,
            hasApplied: _hasApplied,
            canWithdrawApplication: _canWithdraw,
            onInquire: _inquire,
            onApply: _apply,
            onWithdrawApply: _withdraw,
            onBookmark: _bookmark,
          ),
        ],
      ),
    );
  }
}
