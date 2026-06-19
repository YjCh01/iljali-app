import 'dart:convert';



import 'package:map/features/commute/domain/entities/commute_route.dart';

import 'package:map/features/commute/domain/entities/commute_route_demo.dart';

import 'package:map/features/corporate/data/datasources/corporate_job_post_local_data_source.dart';

import 'package:shared_preferences/shared_preferences.dart';



/// 기업(companyKey)별 셔틀·통근 노선 로컬 저장

class CommuteRouteRepository {

  CommuteRouteRepository(this._prefs);



  final SharedPreferences _prefs;



  static Future<CommuteRouteRepository> create() async {

    final prefs = await SharedPreferences.getInstance();

    return CommuteRouteRepository(prefs);

  }



  String _listKey(String companyKey) => 'commute_routes_$companyKey';



  Future<List<CommuteRoute>> loadForCompany(String companyKey) async {

    final raw = _prefs.getString(_listKey(companyKey));

    if (raw == null || raw.isEmpty) return [];

    try {

      final list = jsonDecode(raw) as List<dynamic>;

      return list

          .map((e) => CommuteRoute.fromJson(e as Map<String, dynamic>))

          .where((r) => r.active)

          .toList();

    } catch (_) {

      return [];

    }

  }



  /// 모든 기업의 활성 노선

  Future<List<CommuteRoute>> loadAllActive() async {

    final keys =

        _prefs.getKeys().where((k) => k.startsWith('commute_routes_'));

    final routes = <CommuteRoute>[];

    for (final key in keys) {

      final raw = _prefs.getString(key);

      if (raw == null || raw.isEmpty) continue;

      try {

        final list = jsonDecode(raw) as List<dynamic>;

        routes.addAll(

          list

              .map((e) => CommuteRoute.fromJson(e as Map<String, dynamic>))

              .where((r) => r.active),

        );

      } catch (_) {

        continue;

      }

    }

    return routes;

  }



  Future<CommuteRoute?> findById(String routeId) async {

    final keys =

        _prefs.getKeys().where((k) => k.startsWith('commute_routes_'));

    for (final key in keys) {

      final raw = _prefs.getString(key);

      if (raw == null) continue;

      try {

        final list = jsonDecode(raw) as List<dynamic>;

        for (final item in list) {

          final route = CommuteRoute.fromJson(item as Map<String, dynamic>);

          if (route.id == routeId) return route;

        }

      } catch (_) {

        continue;

      }

    }

    return null;

  }



  Future<void> save(String companyKey, List<CommuteRoute> routes) async {

    await _prefs.setString(

      _listKey(companyKey),

      jsonEncode(routes.map((r) => r.toJson()).toList()),

    );

  }



  Future<void> upsert(CommuteRoute route) async {

    final all = await _loadAllIncludingInactive(route.companyKey);

    final index = all.indexWhere((r) => r.id == route.id);

    if (index == -1) {

      all.add(route);

    } else {

      all[index] = route;

    }

    await _prefs.setString(

      _listKey(route.companyKey),

      jsonEncode(all.map((r) => r.toJson()).toList()),

    );

  }



  Future<void> deactivate(String companyKey, String routeId) async {

    final all = await _loadAllIncludingInactive(companyKey);

    final index = all.indexWhere((r) => r.id == routeId);

    if (index == -1) return;

    all[index] = all[index].copyWith(active: false);

    await save(companyKey, all);

  }



  /// 노선 완전 삭제 (목록·저장소에서 제거)

  Future<void> remove(String companyKey, String routeId) async {

    final all = await _loadAllIncludingInactive(companyKey);

    all.removeWhere((r) => r.id == routeId);

    await _prefs.setString(

      _listKey(companyKey),

      jsonEncode(all.map((r) => r.toJson()).toList()),

    );

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



  Future<List<CommuteRoute>> _loadAllIncludingInactive(String companyKey) async {

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



  /// 개발 데모 노선 시드 (idempotent)

  Future<CommuteRoute> ensureDemoDaisoSejongRoute(String companyKey) async {

    final demo = CommuteRouteDemo.daisoSejongForCompany(companyKey);

    final existing = await findById(demo.id);

    if (existing != null) return existing;

    await upsert(demo);

    return demo;

  }

}


