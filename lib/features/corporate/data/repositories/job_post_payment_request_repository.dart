import 'dart:convert';

import 'package:map/features/corporate/domain/entities/job_post_payment_request.dart';
import 'package:map/features/corporate/domain/entities/job_post_payment_request_status.dart';
import 'package:shared_preferences/shared_preferences.dart';

class JobPostPaymentRequestRepository {
  JobPostPaymentRequestRepository(this._prefs);

  final SharedPreferences _prefs;
  static const _key = 'job_post_payment_requests_v1';

  static Future<JobPostPaymentRequestRepository> create() async {
    final prefs = await SharedPreferences.getInstance();
    return JobPostPaymentRequestRepository(prefs);
  }

  List<JobPostPaymentRequest> _readAll() {
    final raw = _prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    return decoded
        .whereType<Map>()
        .map((item) => JobPostPaymentRequest.fromJson(item.cast<String, dynamic>()))
        .toList();
  }

  Future<void> _writeAll(List<JobPostPaymentRequest> items) async {
    await _prefs.setString(
      _key,
      jsonEncode(items.map((item) => item.toJson()).toList()),
    );
  }

  Future<List<JobPostPaymentRequest>> listForCompany(String companyKey) async {
    final key = companyKey.trim();
    return _readAll()
        .where((item) => item.companyKey.trim() == key)
        .toList()
      ..sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
  }

  Future<List<JobPostPaymentRequest>> listPendingForPayer({
    required String companyKey,
    required String payerEmail,
  }) async {
    final payer = payerEmail.trim().toLowerCase();
    return (await listForCompany(companyKey))
        .where(
          (item) =>
              item.status == JobPostPaymentRequestStatus.pending &&
              item.payerEmail.trim().toLowerCase() == payer,
        )
        .toList();
  }

  Future<List<JobPostPaymentRequest>> listPendingForRequester({
    required String companyKey,
    required String requesterEmail,
  }) async {
    final requester = requesterEmail.trim().toLowerCase();
    return (await listForCompany(companyKey))
        .where(
          (item) =>
              item.status == JobPostPaymentRequestStatus.pending &&
              item.requesterEmail.trim().toLowerCase() == requester,
        )
        .toList();
  }

  Future<JobPostPaymentRequest?> findPendingDuplicate({
    required String companyKey,
    required String requesterEmail,
    required String kind,
    String? jobPostId,
  }) async {
    for (final item in await listPendingForRequester(
      companyKey: companyKey,
      requesterEmail: requesterEmail,
    )) {
      if (item.kind.name != kind) continue;
      if (jobPostId != null &&
          item.jobPostId != null &&
          item.jobPostId != jobPostId) {
        continue;
      }
      return item;
    }
    return null;
  }

  Future<JobPostPaymentRequest?> findById(String id) async {
    for (final item in _readAll()) {
      if (item.id == id) return item;
    }
    return null;
  }

  Future<JobPostPaymentRequest> upsert(JobPostPaymentRequest request) async {
    final all = _readAll();
    final index = all.indexWhere((item) => item.id == request.id);
    if (index >= 0) {
      all[index] = request;
    } else {
      all.add(request);
    }
    await _writeAll(all);
    return request;
  }

  Future<bool> cancelPending({
    required String id,
    required String requesterEmail,
  }) async {
    final all = _readAll();
    final index = all.indexWhere((item) => item.id == id);
    if (index < 0) return false;
    final item = all[index];
    if (item.requesterEmail.trim().toLowerCase() !=
        requesterEmail.trim().toLowerCase()) {
      return false;
    }
    if (item.status != JobPostPaymentRequestStatus.pending) return false;
    all[index] = item.copyWith(status: JobPostPaymentRequestStatus.cancelled);
    await _writeAll(all);
    return true;
  }
}
