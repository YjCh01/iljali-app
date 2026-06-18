import 'dart:math';

import 'package:map/features/corporate/data/repositories/job_post_payment_request_repository.dart';
import 'package:map/features/corporate/domain/entities/job_post_payment_request.dart';
import 'package:map/features/corporate/domain/entities/job_post_payment_request_kind.dart';
import 'package:map/features/corporate/domain/entities/job_post_payment_request_status.dart';
import 'package:map/features/corporate/domain/entities/push_notification_settings.dart';
import 'package:map/features/corporate/domain/services/corporate_payment_access_service.dart';

class JobPostPaymentRequestService {
  JobPostPaymentRequestService({
    JobPostPaymentRequestRepository? repository,
    CorporatePaymentAccessService? accessService,
  })  : _repository = repository,
        _accessService = accessService;

  JobPostPaymentRequestRepository? _repository;
  CorporatePaymentAccessService? _accessService;

  Future<JobPostPaymentRequestRepository> _repo() async =>
      _repository ??= await JobPostPaymentRequestRepository.create();

  Future<CorporatePaymentAccessService> _access() async =>
      _accessService ??= CorporatePaymentAccessService();

  Future<JobPostPaymentRequest> createRequest({
    required String companyKey,
    required String requesterEmail,
    required PushPaymentBundle bundle,
    required JobPostPaymentRequestKind kind,
    required String jobTitle,
    String? jobPostId,
    String? productLabel,
    String? payerEmail,
    String? requesterDisplayName,
  }) async {
    if (!bundle.requiresPayment || bundle.totalAmountKrw <= 0) {
      throw StateError('no_payment_required');
    }

    final payer = payerEmail?.trim().isNotEmpty == true
        ? payerEmail!.trim()
        : await (await _access()).resolvePayerEmail(
            companyKey: companyKey,
            requesterEmail: requesterEmail,
          );
    if (payer == null || payer.isEmpty) {
      throw StateError('payer_not_found');
    }

    final id =
        'jpr-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(9999)}';
    final requesterName = requesterDisplayName?.trim();
    final request = JobPostPaymentRequest(
      id: id,
      companyKey: companyKey.trim(),
      requesterEmail: requesterEmail.trim(),
      requesterDisplayName:
          requesterName != null && requesterName.isNotEmpty
              ? requesterName
              : null,
      payerEmail: payer,
      status: JobPostPaymentRequestStatus.pending,
      jobPostId: jobPostId,
      jobTitle: jobTitle.trim().isEmpty ? '채용 공고' : jobTitle.trim(),
      productLabel: productLabel ?? bundle.productSummary,
      amountKrw: bundle.totalAmountKrw,
      bundle: bundle,
      kind: kind,
      requestedAt: DateTime.now(),
    );
    return (await _repo()).upsert(request);
  }

  Future<List<JobPostPaymentRequest>> listPendingForPayer({
    required String companyKey,
    required String payerEmail,
  }) async {
    return (await _repo()).listPendingForPayer(
      companyKey: companyKey,
      payerEmail: payerEmail,
    );
  }

  Future<JobPostPaymentRequest?> findById(String id) async {
    return (await _repo()).findById(id);
  }

  Future<List<JobPostPaymentRequest>> listMyPending({
    required String companyKey,
    required String requesterEmail,
  }) async {
    return (await _repo()).listPendingForRequester(
      companyKey: companyKey,
      requesterEmail: requesterEmail,
    );
  }

  Future<JobPostPaymentRequest?> markPaid({
    required String id,
    required String transactionId,
  }) async {
    final existing = await (await _repo()).findById(id);
    if (existing == null || !existing.isPending) return existing;
    final updated = existing.copyWith(
      status: JobPostPaymentRequestStatus.paid,
      paidAt: DateTime.now(),
      transactionId: transactionId,
    );
    return (await _repo()).upsert(updated);
  }

  Future<bool> cancel({
    required String id,
    required String requesterEmail,
  }) async {
    return (await _repo()).cancelPending(
      id: id,
      requesterEmail: requesterEmail,
    );
  }
}
