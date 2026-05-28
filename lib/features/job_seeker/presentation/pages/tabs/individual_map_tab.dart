import 'package:flutter/material.dart';
import 'package:map/core/constants/app_routes.dart';
import 'package:map/features/job_seeker/domain/entities/job_map_pin.dart';
import 'package:map/features/job_seeker/presentation/widgets/job_post_detail_sheet.dart';
import 'package:map/features/job_seeker/presentation/widgets/job_seeker_map_view.dart';
import 'package:map/features/map_dashboard/domain/entities/warehouse.dart';
import 'package:map/features/map_dashboard/presentation/widgets/map_search_bar.dart';

/// 구직자 1번 탭 — 지도 + 공고 클러스터
class IndividualMapTab extends StatefulWidget {
  const IndividualMapTab({
    super.key,
    required this.reloadToken,
    this.onOpenJobsTab,
    this.onApplied,
  });

  final int reloadToken;
  final VoidCallback? onOpenJobsTab;
  final VoidCallback? onApplied;

  @override
  State<IndividualMapTab> createState() => _IndividualMapTabState();
}

class _IndividualMapTabState extends State<IndividualMapTab> {
  JobMapPin? _selectedPin;
  String? _searchFilter;

  @override
  void didUpdateWidget(covariant IndividualMapTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reloadToken != widget.reloadToken) {
      setState(() => _selectedPin = null);
    }
  }

  void _selectPin(JobMapPin pin) {
    if (_searchFilter != null &&
        !pin.post.title.contains(_searchFilter!) &&
        !pin.companyName.contains(_searchFilter!) &&
        !pin.post.warehouseName.contains(_searchFilter!)) {
      return;
    }
    setState(() => _selectedPin = pin);
  }

  void _closeSheet() {
    setState(() => _selectedPin = null);
  }

  Future<void> _openSearch() async {
    final warehouse = await Navigator.of(context).pushNamed(
      AppRoutes.search,
    );
    if (!mounted || warehouse is! Warehouse) return;
    setState(() {
      _searchFilter = warehouse.name;
      _selectedPin = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('「${warehouse.name}」 관련 공고를 지도에서 찾아보세요.'),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: '공고 목록',
          onPressed: widget.onOpenJobsTab ?? () {},
        ),
      ),
    );
  }

  Future<void> _apply() async {
    final pin = _selectedPin;
    if (pin == null) return;
    await showJobApplyDialog(context, pin, onApplied: widget.onApplied);
    if (mounted) _closeSheet();
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedPin;
    final showSheet = selected != null;

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: JobSeekerMapView(
            key: ValueKey(widget.reloadToken),
            searchFilter: _searchFilter,
            onPinTap: _selectPin,
            onMapBackgroundTap: showSheet ? _closeSheet : null,
          ),
        ),
        if (_searchFilter != null)
          Positioned(
            left: 16,
            top: MediaQuery.paddingOf(context).top + 68,
            child: InputChip(
              label: Text('검색: $_searchFilter'),
              onDeleted: () => setState(() => _searchFilter = null),
            ),
          ),
        if (showSheet)
          Positioned.fill(
            child: GestureDetector(
              onTap: _closeSheet,
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
                    : JobPostDetailSheet(
                        pin: selected,
                        onClose: _closeSheet,
                        onApply: _apply,
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
