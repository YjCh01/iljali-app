import 'package:flutter/material.dart';
import 'package:map/features/commute/presentation/pages/seeker_my_bus_page.dart';
import 'package:map/features/job_seeker/presentation/pages/tabs/individual_applications_tab.dart';
import 'package:map/features/job_seeker/presentation/pages/tabs/individual_work_tab.dart';

/// 구직자 — 지원·근무 통합 탭 (내 지원 + 출근·달력)
class IndividualMyJobsTab extends StatefulWidget {
  const IndividualMyJobsTab({
    super.key,
    this.isWorkSegmentActive = false,
    this.initialSegment = 0,
    this.isActive = true,
  });

  final bool isWorkSegmentActive;
  final int initialSegment;
  final bool isActive;

  @override
  State<IndividualMyJobsTab> createState() => _IndividualMyJobsTabState();
}

class _IndividualMyJobsTabState extends State<IndividualMyJobsTab> {
  late int _segment;

  @override
  void initState() {
    super.initState();
    _segment = widget.initialSegment.clamp(0, 2);
  }

  @override
  void didUpdateWidget(covariant IndividualMyJobsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isWorkSegmentActive && _segment != 1) {
      setState(() => _segment = 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: SegmentedButton<int>(
            segments: const [
              ButtonSegment(
                value: 0,
                label: Text('지원 현황'),
                icon: Icon(Icons.description_outlined, size: 18),
              ),
              ButtonSegment(
                value: 1,
                label: Text('근무·출근'),
                icon: Icon(Icons.event_available_outlined, size: 18),
              ),
              ButtonSegment(
                value: 2,
                label: Text('내 버스'),
                icon: Icon(Icons.directions_bus_outlined, size: 18),
              ),
            ],
            selected: {_segment},
            onSelectionChanged: (value) =>
                setState(() => _segment = value.first),
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: IndexedStack(
            index: _segment,
            children: [
              IndividualApplicationsTab(isActive: widget.isActive && _segment == 0),
              IndividualWorkTab(isActive: _segment == 1),
              SeekerMyBusPage(
                embedded: true,
                isActive: widget.isActive && _segment == 2,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 6탭 → 5탭 마이그레이션 (legacy seekerTabIndex)
int normalizeSeekerTabIndex(int raw) {
  if (raw <= 0) return 0;
  if (raw == 1) return 1;
  if (raw == 2 || raw == 3) return 2;
  if (raw == 4) return 3;
  return 4;
}

/// 지원·근무 탭 내부 세그먼트 (0=지원, 1=근무)
int seekerMyJobsSegmentFromLegacyTab(int legacyTab) {
  if (legacyTab == 3) return 1;
  return 0;
}
