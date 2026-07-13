import 'dart:convert';

import 'package:map/core/api/iljari_api_client.dart';
import 'package:map/core/config/env_config.dart';
import 'package:map/features/commute/domain/entities/commute_route.dart';
import 'package:map/features/commute/domain/entities/commute_route_demo.dart';
import 'package:map/features/corporate/data/datasources/corporate_job_post_local_data_source.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 기업(companyKey)별 셔틀·통근 노선 — 서버 원본 + 로컬 캐시
class CommuteRouteRepository {
  CommuteRouteRepository(this._prefs);

  final SharedPreferences _prefs;

  static Future<CommuteRouteRepository> create() async {
    final prefs = await SharedPreferences.getInstance();
    return CommuteRouteRepository(prefs);
  }

  String _listKey(String companyKey) => 'commute_routes_cache_$companyKey';

  bool get _useRemote =>
      EnvConfig.isComplianceApiEnabled && IljariApiClient().isEnabled;

  Future<List<CommuteRoute>> loadForCompany(String companyKey) async {
    if (_useRemote) {
      try {
        final client = IljariApiClient();
        var remote = await client.fetchCommuteRoutes(companyKey);
        if (remote.isEmpty) {
          final local = await _loadLocalIncludingInactive(companyKey);
          if (local.isNotEmpty) {
            for (final route in local) {
              await client.upsertCommuteRoute(route.toJson());
            }
            remote = await client.fetchCommuteRoutes(companyKey);
          }
        }
        final routes = remote
            .map((e) => CommuteRoute.fromJson(e))
            .where((r) => r.active)
            .toList();
        await _writeLocalCache(companyKey, routes);
        return routes;
      } on Object {
        // 네트워크 실패 시 캐시 폴백
      }
    }
    return _loadLocalActive(companyKey);
  }

  Future<List<CommuteRoute>> loadAllActive() async {
    if (_useRemote) {
      // 원격 전체 스캔 없음 — 캐시 키 순회
    }
    final keys = _prefs.getKeys().where((k) => k.startsWith('commute_routes_cache_'));
    final routes = <CommuteRoute>[];
    for (final key in keys) {
      final companyKey = key.replaceFirst('commute_routes_cache_', '');
      routes.addAll(await loadForCompany(companyKey));
    }
    return routes;
  }

  Future<CommuteRoute?> findById(String routeId) async {
    if (_useRemote) {
      try {
        final client = IljariApiClient();
        final json = await client.fetchCommuteRouteById(routeId);
        if (json != null) {
          final route = CommuteRoute.fromJson(json);
          final all = await _loadLocalIncludingInactive(route.companyKey);
          final index = all.indexWhere((r) => r.id == route.id);
          if (index >= 0) {
            all[index] = route;
          } else {
            all.add(route);
          }
          await _writeLocalCache(route.companyKey, all);
          return route;
        }
      } on Object {
        // 캐시 폴백
      }
    }
    final keys = _prefs.getKeys().where((k) => k.startsWith('commute_routes_cache_'));
    for (final key in keys) {
      for (final route in await _loadLocalIncludingInactive(
        key.replaceFirst('commute_routes_cache_', ''),
      )) {
        if (route.id == routeId) return route;
      }
    }
    return null;
  }

  Future<void> save(String companyKey, List<CommuteRoute> routes) async {
    if (_useRemote) {
      final client = IljariApiClient();
      for (final route in routes) {
        await client.upsertCommuteRoute(route.toJson());
      }
    }
    await _writeLocalCache(companyKey, routes);
  }

  Future<CommuteRoute> upsert(CommuteRoute route) async {
    var saved = route;
    if (_useRemote) {
      final json = await IljariApiClient().upsertCommuteRoute(route.toJson());
      saved = CommuteRoute.fromJson(json);
    }
    final all = await _loadLocalIncludingInactive(saved.companyKey);
    final index = all.indexWhere((r) => r.id == saved.id);
    if (index == -1) {
      all.add(saved);
    } else {
      all[index] = saved;
    }
    await _writeLocalCache(saved.companyKey, all);
    return saved;
  }

  /// 서버에 저장된 정류장으로 도로 추종 polyline을 다시 계산
  Future<CommuteRoute?> refreshGeometry(CommuteRoute route) async {
    if (!_useRemote) return route;
    try {
      final json = await IljariApiClient().refreshCommuteRouteGeometry(
        routeId: route.id,
        companyKey: route.companyKey,
      );
      final saved = CommuteRoute.fromJson(json);
      final all = await _loadLocalIncludingInactive(saved.companyKey);
      final index = all.indexWhere((r) => r.id == saved.id);
      if (index == -1) {
        all.add(saved);
      } else {
        all[index] = saved;
      }
      await _writeLocalCache(saved.companyKey, all);
      return saved;
    } on Object {
      return null;
    }
  }

  Future<void> deactivate(String companyKey, String routeId) async {
    if (_useRemote) {
      await IljariApiClient().deleteCommuteRoute(
        routeId: routeId,
        companyKey: companyKey,
        hard: false,
      );
    }
    final all = await _loadLocalIncludingInactive(companyKey);
    final index = all.indexWhere((r) => r.id == routeId);
    if (index == -1) return;
    all[index] = all[index].copyWith(active: false);
    await _writeLocalCache(companyKey, all);
  }

  Future<void> remove(String companyKey, String routeId) async {
    if (_useRemote) {
      await IljariApiClient().deleteCommuteRoute(
        routeId: routeId,
        companyKey: companyKey,
        hard: true,
      );
    }
    final all = await _loadLocalIncludingInactive(companyKey);
    all.removeWhere((r) => r.id == routeId);
    await _writeLocalCache(companyKey, all);
    await _clearLinkedJobPosts(routeId);
  }

  Future<void> _clearLinkedJobPosts(String routeId) async {
    final normalized = routeId.trim();
    if (normalized.isEmpty) return;
    final dataSource = const CorporateJobPostLocalDataSourceImpl();
    final posts = await dataSource.fetchJobPosts();
    for (final post in posts) {
      if (post.commuteRouteId?.trim() != normalized) continue;
      await dataSource.updateJobPost(
        post.copyWith(
          commuteRouteId: null,
          hasShuttleRouteOverlay: false,
        ),
      );
    }
  }

  Future<List<CommuteRoute>> _loadLocalActive(String companyKey) async {
    return (await _loadLocalIncludingInactive(companyKey))
        .where((r) => r.active)
        .toList();
  }

  Future<List<CommuteRoute>> _loadLocalIncludingInactive(String companyKey) async {
    final raw = _prefs.getString(_listKey(companyKey));
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => CommuteRoute.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _writeLocalCache(
    String companyKey,
    List<CommuteRoute> routes,
  ) async {
    await _prefs.setString(
      _listKey(companyKey),
      jsonEncode(routes.map((r) => r.toJson()).toList()),
    );
  }

  Future<CommuteRoute> ensureDemoDaisoSejongRoute(String companyKey) async {
    final demo = CommuteRouteDemo.daisoSejongForCompany(companyKey);
    final existing = await findById(demo.id);
    if (existing != null) return existing;
    await upsert(demo);
    return demo;
  }
}
