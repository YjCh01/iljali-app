import 'dart:convert';
import 'dart:io';

import 'package:map/core/admin/admin_ops_api_client.dart';

/// 실기업 공고 JSON bulk import
///
/// Usage:
///   dart run scripts/import_qc_jobs.dart server/fixtures/jobs.example.json
Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln('Usage: dart run scripts/import_qc_jobs.dart <jobs.json>');
    exit(1);
  }

  final path = args.first;
  final file = File(path);
  if (!file.existsSync()) {
    stderr.writeln('File not found: $path');
    exit(1);
  }

  final decoded = jsonDecode(file.readAsStringSync());
  final posts = decoded is List
      ? decoded.cast<Map<String, dynamic>>()
      : (decoded as Map)['posts'] as List<dynamic>;

  final client = AdminOpsApiClient();
  if (!client.isEnabled) {
    stderr.writeln('Set COMPLIANCE_API_URL + ADMIN_API_KEY via dart-define');
    exit(1);
  }

  final result = await client.bulkImportJobs(
    posts.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
  );
  stdout.writeln('imported: $result');
}
