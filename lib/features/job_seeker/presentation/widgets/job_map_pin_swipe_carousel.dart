import 'package:flutter/material.dart';
import 'package:map/features/job_seeker/domain/entities/map_callout_item.dart';
import 'package:map/features/job_seeker/presentation/widgets/job_map_pin_callout_card.dart';
import 'package:map/features/job_seeker/presentation/widgets/shuttle_stop_callout_card.dart';

/// 핀 탭 시 — 당근마켓 동네지도처럼 인근 핀(공고핀·정류장핀)을 가로로 스와이프해 이동
class JobMapPinSwipeCarousel extends StatefulWidget {
  const JobMapPinSwipeCarousel({
    super.key,
    required this.items,
    required this.initialIndex,
    required this.onClose,
    required this.onViewDetail,
    required this.onPageChanged,
    this.employerPreview = false,
  });

  /// 거리순으로 정렬된 인근 핀 목록 (탭한 핀이 포함됨) — 공고핀·정류장핀 혼합
  final List<MapCalloutItem> items;
  final int initialIndex;
  final VoidCallback onClose;
  final ValueChanged<MapCalloutItem> onViewDetail;

  /// 스와이프로 다른 핀이 화면 중앙에 오면 호출 (지도 카메라 이동 등에 사용)
  final ValueChanged<MapCalloutItem> onPageChanged;
  final bool employerPreview;

  @override
  State<JobMapPinSwipeCarousel> createState() =>
      _JobMapPinSwipeCarouselState();
}

class _JobMapPinSwipeCarouselState extends State<JobMapPinSwipeCarousel> {
  late final PageController _controller = PageController(
    viewportFraction: 0.92,
    initialPage: widget.initialIndex,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 196,
      child: PageView.builder(
        controller: _controller,
        itemCount: widget.items.length,
        onPageChanged: (index) => widget.onPageChanged(widget.items[index]),
        itemBuilder: (context, index) {
          final item = widget.items[index];
          return switch (item) {
            JobPinCalloutItem() => JobMapPinCalloutCard(
                pin: item.pin,
                compact: true,
                employerPreview: widget.employerPreview,
                onClose: widget.onClose,
                onViewDetail: () => widget.onViewDetail(item),
              ),
            ShuttleStopCalloutItem() => ShuttleStopCalloutCard(
                item: item,
                onClose: widget.onClose,
                onViewLinkedJob: () => widget.onViewDetail(item),
              ),
          };
        },
      ),
    );
  }
}
