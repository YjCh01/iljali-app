import 'package:map/core/hiring/hiring_application.dart';
import 'package:map/core/hiring/local_hiring_repository.dart';
import 'package:map/features/commute/data/repositories/commute_route_repository.dart';
import 'package:map/features/commute/domain/entities/seeker_shuttle_employer_context.dart';
import 'package:map/features/corporate/data/datasources/corporate_job_post_local_data_source.dart';

/// 출근 예정·채용 확정 구직자의 셔틀 운영 회사·노선 조회
abstract final class SeekerShuttleEmployerLoader {
  static Future<List<SeekerShuttleEmployerContext>> loadForSeeker(
    String seekerEmail,
  ) async {
    final normalized = seekerEmail.trim().toLowerCase();
    if (normalized.isEmpty) return const [];

    final hiringRepo = await LocalHiringRepository.create();
    final scheduled = await hiringRepo.fetchScheduledForSeeker(normalized);
    if (scheduled.isEmpty) return const [];

    const postSource = CorporateJobPostLocalDataSourceImpl();
    final routeRepo = await CommuteRouteRepository.create();

    final grouped = <String, _EmployerAccumulator>{};
    for (final app in scheduled) {
      final resolved = await _resolveCompany(
        app: app,
        postSource: postSource,
      );
      if (resolved == null) continue;
      grouped.putIfAbsent(
        resolved.companyKey,
        () => _EmployerAccumulator(
          companyKey: resolved.companyKey,
          companyName: resolved.companyName,
        ),
      );
      final bucket = grouped[resolved.companyKey]!;
      if (bucket.companyName.isEmpty && resolved.companyName.isNotEmpty) {
        bucket.companyName = resolved.companyName;
      }
      bucket.applications.add(app);
    }

    final contexts = <SeekerShuttleEmployerContext>[];
    for (final bucket in grouped.values) {
      final routes = await routeRepo.loadForCompany(bucket.companyKey);
      if (routes.isEmpty) continue;
      contexts.add(
        SeekerShuttleEmployerContext(
          companyKey: bucket.companyKey,
          companyName: bucket.companyName.isNotEmpty
              ? bucket.companyName
              : bucket.companyKey,
          routes: routes,
          applications: bucket.applications,
        ),
      );
    }

    contexts.sort((a, b) => a.companyName.compareTo(b.companyName));
    return contexts;
  }

  static Future<({String companyKey, String companyName})?> _resolveCompany({
    required HiringApplication app,
    required CorporateJobPostLocalDataSource postSource,
  }) async {
    var companyKey = app.companyKey?.trim() ?? '';
    var companyName = app.companyName.trim();
    if (companyKey.isEmpty) {
      final post = await postSource.findById(app.postId);
      companyKey = post?.registeredBy?.companyKey.trim() ?? '';
      if (companyName.isEmpty) {
        companyName = post?.registeredBy?.companyName.trim() ??
            post?.warehouseName.trim() ??
            '';
      }
    }
    if (companyKey.isEmpty) return null;
    return (companyKey: companyKey, companyName: companyName);
  }
}

class _EmployerAccumulator {
  _EmployerAccumulator({
    required this.companyKey,
    required this.companyName,
  });

  final String companyKey;
  String companyName;
  final List<HiringApplication> applications = [];
}
