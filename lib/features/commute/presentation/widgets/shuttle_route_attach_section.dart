import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/constants/app_routes.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/features/commute/data/repositories/commute_route_repository.dart';
import 'package:map/features/commute/domain/entities/commute_route.dart';

/// 공고 작성 — 셔틀 노선 연결 (노선 등록·선택만, 유료 거점 안내 없음)
class ShuttleRouteAttachSection extends StatefulWidget {
  const ShuttleRouteAttachSection({
    super.key,
    this.selectedRouteId,
    required this.onChanged,
    this.embedded = false,
  });

  final String? selectedRouteId;
  final void Function({String? routeId}) onChanged;
  /// 바텀시트 등 — 외곽 카드·「셔틀 노선」 헤더 없이 연결 UI만
  final bool embedded;

  @override
  State<ShuttleRouteAttachSection> createState() =>
      _ShuttleRouteAttachSectionState();
}

class _ShuttleRouteAttachSectionState extends State<ShuttleRouteAttachSection> {
  List<CommuteRoute> _routes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadRoutes();
  }

  Future<void> _loadRoutes() async {
    final profile = AuthSession.instance.currentUser?.corporateProfile;
    if (profile == null) return;
    final repo = await CommuteRouteRepository.create();
    final routes = await repo.loadForCompany(profile.companyKey);
    if (!mounted) return;
    setState(() {
      _routes = routes;
      _loading = false;
    });
  }

  Future<void> _openRouteManager() async {
    await Navigator.of(context).pushNamed(AppRoutes.corporateShuttleRoutes);
    await _loadRoutes();
  }

  Future<void> _createRoute() async {
    final created = await Navigator.of(context).pushNamed<CommuteRoute>(
      AppRoutes.corporateShuttleRouteEdit,
    );
    if (created == null) return;
    await _loadRoutes();
    widget.onChanged(routeId: created.id);
  }

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!widget.embedded) ...[
          const Row(
            children: [
              Icon(Icons.directions_bus_filled_outlined,
                  size: 20, color: AppColors.primary),
              SizedBox(width: 8),
              Text(
                '셔틀 노선',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '셔틀 운행·탑승 안내를 공고에 연결합니다.\n'
            '구직자 지도에 노선·정류장을 표시하려면 연결 후 별도 활성화(일자리 알림핀 1회)가 필요합니다.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary.withValues(alpha: 0.95),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (_loading)
          const Center(child: CircularProgressIndicator(strokeWidth: 2))
        else if (_routes.isEmpty)
          OutlinedButton.icon(
            onPressed: _createRoute,
            icon: const Icon(Icons.add_road_outlined, size: 18),
            label: const Text('셔틀 노선 등록'),
          )
        else
          DropdownButtonFormField<String>(
            value: _routes.any((r) => r.id == widget.selectedRouteId)
                ? widget.selectedRouteId
                : null,
            decoration: const InputDecoration(
              labelText: '연결할 노선',
              isDense: true,
            ),
            items: [
              const DropdownMenuItem<String>(
                value: null,
                child: Text('연결 안 함'),
              ),
              ..._routes.map(
                (r) => DropdownMenuItem(
                  value: r.id,
                  child: Text(r.routeName),
                ),
              ),
            ],
            onChanged: (id) => widget.onChanged(routeId: id),
          ),
        if (_routes.isNotEmpty) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _openRouteManager,
              child: const Text('노선 관리'),
            ),
          ),
        ],
      ],
    );

    if (widget.embedded) {
      return content;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.primaryLight.withValues(alpha: 0.35),
        ),
      ),
      child: content,
    );
  }
}
