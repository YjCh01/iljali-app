import 'package:flutter/material.dart';
import 'package:map/core/admin/admin_ops_api_client.dart';
import 'package:map/core/api/iljari_api_client.dart';
import 'package:map/core/compliance/business_verification_status.dart';
import 'package:map/core/compliance/data/compliance_api_client.dart';
import 'package:map/core/compliance/data/compliance_repository.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/features/corporate/presentation/widgets/corporate_surface_card.dart';

/// Admin 회원 패널 — 사업자등록증 검토·승격 (서버 우선, 레거시 review API fallback)
class AdminCompanyVerificationCard extends StatefulWidget {
  const AdminCompanyVerificationCard({
    super.key,
    required this.companyKey,
    this.companyName,
    this.adminClient,
    /// 기업 디렉터리에 노출된 회원 — qc_members 기준 서버 가입 완료
    this.registeredOnServer = false,
  });

  final String companyKey;
  final String? companyName;
  final AdminOpsApiClient? adminClient;
  final bool registeredOnServer;

  @override
  State<AdminCompanyVerificationCard> createState() =>
      _AdminCompanyVerificationCardState();
}

class _AdminCompanyVerificationCardState
    extends State<AdminCompanyVerificationCard> {
  bool _loading = true;
  bool _busy = false;
  BusinessVerificationStatus? _status;
  String? _reason;
  bool _needsReview = false;
  bool _loadedFromServer = false;
  String? _loadError;
  String? _dataSource;

  AdminOpsApiClient get _admin => widget.adminClient ?? AdminOpsApiClient();
  ComplianceApiClient get _compliance => ComplianceApiClient();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant AdminCompanyVerificationCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.companyKey != widget.companyKey ||
        oldWidget.registeredOnServer != widget.registeredOnServer) {
      _load();
    }
  }

  String _normalizeBrn(String raw) =>
      raw.replaceAll(RegExp(r'[^0-9]'), '');

  BusinessVerificationStatus? _statusFromApi(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return BusinessVerificationStatus.values.byName(raw);
    } on Object {
      return null;
    }
  }

  void _applyRecord({
    required BusinessVerificationStatus? status,
    required bool needsReview,
    String? reason,
    required bool fromServer,
    String? source,
  }) {
    _status = status;
    _needsReview = needsReview;
    _reason = reason;
    _loadedFromServer = fromServer;
    _dataSource = source;
  }

  bool _recordNeedsReview(Map<String, dynamic> record) {
    if (record['admin_review_approved'] == true) return false;
    final status = '${record['verification_status'] ?? ''}';
    if (status == 'rejected' || status == 'suspended') return false;
    if (record['requires_admin_review'] == true) return true;
    return status == 'pending' || status == 'adminReviewRequired';
  }

  Future<void> _loadFromComplianceRecords() async {
    if (!_compliance.isEnabled) return;
    final record = await _compliance.findBusinessRecord(widget.companyKey);
    if (record == null || !mounted) return;
    final status = _statusFromApi(record['verification_status'] as String?);
    final needsReview = _recordNeedsReview(record);
    setState(() {
      _loading = false;
      _applyRecord(
        status: status,
        needsReview: needsReview,
        reason: record['admin_review_reason'] as String?,
        fromServer: true,
        source: 'compliance/business-records',
      );
    });
  }

  Future<void> _loadPendingMemberFallback() async {
    if (!widget.registeredOnServer || !mounted) return;
    setState(() {
      _loading = false;
      _applyRecord(
        status: BusinessVerificationStatus.pending,
        needsReview: true,
        reason: '앱 가입 완료 — 등록증·사업자 승인 대기',
        fromServer: true,
        source: 'qc_members (검증 API 미배포)',
      );
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
      _dataSource = null;
    });

    if (_admin.isEnabled) {
      try {
        final data = await _admin.getCompanyVerification(widget.companyKey);
        if (!mounted) return;
        setState(() {
          _loading = false;
          _applyRecord(
            status: _statusFromApi(data['verification_status'] as String?),
            needsReview: data['needs_admin_approval'] as bool? ?? false,
            reason: data['admin_review_reason'] as String?,
            fromServer: true,
            source: 'admin/ops/verification',
          );
        });
        return;
      } on IljariApiException catch (e) {
        if (!mounted) return;
        setState(() => _loadError = e.toString());
        await _loadFromComplianceRecords();
        if (!mounted || _loadedFromServer) return;
        await _loadPendingMemberFallback();
        if (!mounted || _loadedFromServer) return;
      } on Object catch (e) {
        if (!mounted) return;
        setState(() => _loadError = e.toString());
      }
    }

    if (_compliance.isEnabled && !_loadedFromServer) {
      await _loadFromComplianceRecords();
      if (!mounted || _loadedFromServer) return;
    }

    if (widget.registeredOnServer && !_loadedFromServer) {
      await _loadPendingMemberFallback();
      if (!mounted || _loadedFromServer) return;
    }

    final repo = await ComplianceRepository.create();
    final record = await repo.findByBrn(widget.companyKey);
    if (!mounted) return;
    final status = record?.status;
    setState(() {
      _loading = false;
      _applyRecord(
        status: status,
        needsReview: status == BusinessVerificationStatus.pending ||
            status == BusinessVerificationStatus.adminReviewRequired,
        reason: record?.adminReviewReason,
        fromServer: false,
        source: record != null ? '브라우저 로컬' : null,
      );
    });
  }

  Future<void> _approveViaLegacyReview() async {
    await _compliance.adminReviewCompany(
      companyKey: _normalizeBrn(widget.companyKey),
      approved: true,
      reason: '관리자 승인 완료',
    );
  }

  Future<void> _approve() async {
    setState(() => _busy = true);
    try {
      var usedLegacy = false;
      if (_admin.isEnabled) {
        try {
          await _admin.approveCompanyVerification(widget.companyKey);
        } on IljariApiException catch (e) {
          final msg = e.toString();
          if (msg.contains('404') && _compliance.isEnabled) {
            await _approveViaLegacyReview();
            usedLegacy = true;
          } else {
            rethrow;
          }
        }
      } else if (_compliance.isEnabled) {
        await _approveViaLegacyReview();
        usedLegacy = true;
      } else {
        final repo = await ComplianceRepository.create();
        await repo.approveAdminReview(widget.companyKey);
      }
      await _syncSessionIfMatch();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            usedLegacy
                ? '${widget.companyName ?? widget.companyKey} 승인 (레거시 review API)'
                : '${widget.companyName ?? widget.companyKey} 승인',
          ),
        ),
      );
      await _load();
    } on Object catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('승인 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _syncSessionIfMatch() async {
    final profile = AuthSession.instance.currentUser?.corporateProfile;
    if (profile == null ||
        profile.companyKey != _normalizeBrn(widget.companyKey)) {
      return;
    }
    final updated = profile.copyWith(
      adminReviewApproved: true,
      verificationStatus: BusinessVerificationStatus.verified,
    );
    await AuthSession.instance.updateCorporateProfile(updated);
  }

  String _statusLabel() {
    final status = _status;
    if (status != null) return status.label;
    if (_loadedFromServer && !_needsReview) return '검증 완료 또는 승인 불필요';
    if (widget.registeredOnServer) return '미인증 (승인 대기)';
    return '기록 없음 (앱 가입·제출 후 표시)';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: LinearProgressIndicator(minHeight: 2),
      );
    }

    return CorporateSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '사업자 검증',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            _statusLabel(),
            style: const TextStyle(fontSize: 13),
          ),
          if (_loadedFromServer && _dataSource != null) ...[
            const SizedBox(height: 4),
            Text(
              '데이터: $_dataSource',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary.withValues(alpha: 0.85),
              ),
            ),
          ],
          if (_loadError != null) ...[
            const SizedBox(height: 4),
            Text(
              '검증 API 조회 실패 — fallback 사용 중',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary.withValues(alpha: 0.9),
              ),
            ),
          ],
          if (_reason != null && _reason!.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              _reason!,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary.withValues(alpha: 0.95),
              ),
            ),
          ],
          if (_needsReview) ...[
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _busy ? null : _approve,
              child: Text(_busy ? '처리 중...' : '등록증 승인 · 유료 서비스 해제'),
            ),
          ] else if (_status == BusinessVerificationStatus.verified) ...[
            const SizedBox(height: 4),
            Text(
              '관리자 승인 완료',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary.withValues(alpha: 0.95),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
