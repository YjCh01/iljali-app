import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/constants/app_routes.dart';
import 'package:map/features/corporate/data/datasources/corporate_job_post_local_data_source.dart';
import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';
import 'package:map/features/corporate/domain/entities/push_notification_settings.dart';
import 'package:map/features/corporate/domain/entities/workplace_address.dart';
import 'package:map/features/corporate/presentation/navigation/push_base_point_args.dart';
import 'package:map/features/corporate/presentation/widgets/corporate_job_post_optional_services_panel.dart';

WorkplaceAddress workplaceFromJobPost(CorporateJobPost post) {
  final settings = post.notificationSettings;
  final primary =
      settings != null && settings.basePoints.isNotEmpty
          ? settings.basePoints.first
          : null;
  return WorkplaceAddress(
    roadAddress: post.warehouseName,
    coordinate: primary?.coordinate,
    detailAddress: primary?.addressLabel,
  );
}

/// 공고 — 유료 서비스 시트 (등록 직후 · 목록 · 수정 공통)
Future<void> showCorporateJobPostOptionalServicesSheet(
  BuildContext context, {
  required CorporateJobPost post,
  WorkplaceAddress? workplace,
  ValueChanged<CorporateJobPost>? onPostUpdated,
}) {
  final resolvedWorkplace = workplace ?? workplaceFromJobPost(post);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetContext) {
      return CorporateJobPostOptionalServicesSheet(
        post: post,
        workplace: resolvedWorkplace,
        onPostUpdated: onPostUpdated,
      );
    },
  );
}

class CorporateJobPostOptionalServicesSheet extends StatefulWidget {
  const CorporateJobPostOptionalServicesSheet({
    super.key,
    required this.post,
    required this.workplace,
    this.onPostUpdated,
  });

  final CorporateJobPost post;
  final WorkplaceAddress workplace;
  final ValueChanged<CorporateJobPost>? onPostUpdated;

  @override
  State<CorporateJobPostOptionalServicesSheet> createState() =>
      _CorporateJobPostOptionalServicesSheetState();
}

class _CorporateJobPostOptionalServicesSheetState
    extends State<CorporateJobPostOptionalServicesSheet> {
  final _dataSource = const CorporateJobPostLocalDataSourceImpl();
  late CorporateJobPost _post;
  late JobPostNotificationSettings? _notificationSettings;
  late String? _shuttleRouteId;
  late List<String> _linkedShuttleRouteIds;
  late bool _hasShuttleRouteOverlay;

  @override
  void initState() {
    super.initState();
    _hydrateFrom(widget.post);
  }

  void _hydrateFrom(CorporateJobPost post) {
    _post = post;
    _notificationSettings = post.notificationSettings;
    _linkedShuttleRouteIds = _linkedRouteIdsFrom(post);
    _shuttleRouteId = _linkedShuttleRouteIds.isNotEmpty
        ? _linkedShuttleRouteIds.first
        : (post.commuteRouteId?.trim().isNotEmpty == true
            ? post.commuteRouteId
            : null);
    _hasShuttleRouteOverlay = post.hasShuttleRouteOverlay;
  }

  List<String> _linkedRouteIdsFrom(CorporateJobPost post) {
    final fromList = post.effectiveLinkedCommuteRouteIds;
    if (fromList.isNotEmpty) return fromList;
    return [
      for (final entry in post.shuttleRegisteredStopIdsByRoute.entries)
        if (entry.value.isNotEmpty) entry.key.trim(),
    ].where((id) => id.isNotEmpty).toList(growable: false);
  }

  CorporateJobPost _buildPersistedPost() {
    return _post.copyWith(
      notificationSettings: _notificationSettings,
      commuteRouteId: _shuttleRouteId ?? '',
      linkedCommuteRouteIds: _linkedShuttleRouteIds,
      shuttleRegisteredStopIdsByRoute: _post.shuttleRegisteredStopIdsByRoute,
      shuttlePaidStopIdsByRoute: _post.shuttlePaidStopIdsByRoute,
      shuttleExposurePaidAt: _post.shuttleExposurePaidAt,
      hasShuttleRouteOverlay:
          _linkedShuttleRouteIds.isEmpty ? false : _hasShuttleRouteOverlay,
    );
  }

  Future<void> _persist() async {
    final updated = _buildPersistedPost();
    await _dataSource.updateJobPost(updated);
    if (!mounted) return;
    setState(() => _post = updated);
    widget.onPostUpdated?.call(updated);
  }

  Future<void> _configurePushNotification() async {
    final result =
        await Navigator.of(context).pushNamed<JobPostNotificationSettings>(
      AppRoutes.corporatePushBasePoint,
      arguments: PushBasePointArgs(
        initialSettings: _notificationSettings,
        workplace: widget.workplace,
      ),
    );
    if (result == null || !mounted) return;
    setState(() => _notificationSettings = result);
    await _persist();
  }

  Future<void> _onNotificationSettingsChanged(
    JobPostNotificationSettings settings,
  ) async {
    setState(() => _notificationSettings = settings);
    await _persist();
  }

  Future<void> _onShuttleRouteChanged({
    String? routeId,
    bool? hasShuttleRouteOverlay,
    List<String>? linkedRouteIds,
  }) async {
    final fresh = await _dataSource.findById(_post.id);
    setState(() {
      if (fresh != null) {
        _post = fresh;
        _linkedShuttleRouteIds = _linkedRouteIdsFrom(fresh);
        _shuttleRouteId = _linkedShuttleRouteIds.isNotEmpty
            ? _linkedShuttleRouteIds.first
            : null;
        _hasShuttleRouteOverlay = fresh.hasShuttleRouteOverlay;
        _notificationSettings = fresh.notificationSettings;
      }
      if (linkedRouteIds != null) {
        _linkedShuttleRouteIds = linkedRouteIds;
        _shuttleRouteId =
            linkedRouteIds.isNotEmpty ? linkedRouteIds.first : null;
      } else if (routeId != null || hasShuttleRouteOverlay == null) {
        _shuttleRouteId = routeId;
        _linkedShuttleRouteIds =
            routeId == null ? const [] : [routeId];
      }
      if (routeId == null &&
          (linkedRouteIds == null || linkedRouteIds.isEmpty)) {
        _hasShuttleRouteOverlay = false;
        _linkedShuttleRouteIds = const [];
        _shuttleRouteId = null;
      } else if (hasShuttleRouteOverlay != null) {
        _hasShuttleRouteOverlay = hasShuttleRouteOverlay;
      }
    });
    await _persist();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.88,
        minChildSize: 0.45,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textSecondary.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 8, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '유료 서비스',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _post.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary
                                  .withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: CorporateJobPostOptionalServicesPanel(
                    notificationSettings: _notificationSettings,
                    onConfigurePins: _configurePushNotification,
                    onNotificationSettingsChanged:
                        _onNotificationSettingsChanged,
                    shuttleRouteId: _shuttleRouteId,
                    hasShuttleRouteOverlay: _hasShuttleRouteOverlay,
                    onShuttleRouteChanged: _onShuttleRouteChanged,
                    workplaceReady: widget.workplace.roadAddress.trim().isNotEmpty,
                    jobTitle: _post.title,
                    jobPostId: _post.id,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
