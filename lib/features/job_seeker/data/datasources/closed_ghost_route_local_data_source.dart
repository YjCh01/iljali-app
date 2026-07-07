import 'package:map/features/job_seeker/domain/entities/closed_ghost_route.dart';

abstract class ClosedGhostRouteLocalDataSource {
  Future<List<ClosedGhostRoute>> fetchAll();
}

class ClosedGhostRouteLocalDataSourceImpl
    implements ClosedGhostRouteLocalDataSource {
  const ClosedGhostRouteLocalDataSourceImpl();

  static final List<ClosedGhostRoute> _routes = [];

  static void replaceFromServer(List<ClosedGhostRoute> routes) {
    _routes
      ..clear()
      ..addAll(routes);
  }

  static void upsertLocal(ClosedGhostRoute route) {
    final index = _routes.indexWhere((r) => r.id == route.id);
    if (index >= 0) {
      _routes[index] = route;
    } else {
      _routes.add(route);
    }
  }

  static void removeLocal(String id) {
    _routes.removeWhere((r) => r.id == id);
  }

  @override
  Future<List<ClosedGhostRoute>> fetchAll() async =>
      List.unmodifiable(_routes);
}
