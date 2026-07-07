import 'package:map/core/hiring/hiring_application.dart';
import 'package:map/features/commute/domain/entities/commute_route.dart';

/// 채용 확정 구직자 — 통근버스 노선을 등록한 근무 회사
class SeekerShuttleEmployerContext {
  const SeekerShuttleEmployerContext({
    required this.companyKey,
    required this.companyName,
    required this.routes,
    required this.applications,
  });

  final String companyKey;
  final String companyName;
  final List<CommuteRoute> routes;
  final List<HiringApplication> applications;

  bool get hasRoutes => routes.isNotEmpty;
}
