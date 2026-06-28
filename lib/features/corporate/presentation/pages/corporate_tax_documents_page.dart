import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:map/core/config/product_feature_flags.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/constants/app_routes.dart';
import 'package:map/core/widgets/adaptive_sheet.dart';
import 'package:map/core/widgets/transient_snack_bar.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/core/widgets/app_back_button.dart';
import 'package:map/features/corporate/data/repositories/corporate_tax_document_repository.dart';
import 'package:map/features/corporate/domain/entities/corporate_tax_document.dart';
import 'package:map/features/corporate/domain/entities/tax_document_type.dart';
import 'package:map/features/corporate/domain/services/corporate_tax_document_service.dart';
import 'package:map/features/corporate/presentation/widgets/corporate_surface_card.dart';
import 'package:share_plus/share_plus.dart';

/// 결제 증빙 — 거래명세서·세금계산서·현금영수증
class CorporateTaxDocumentsPage extends StatefulWidget {
  const CorporateTaxDocumentsPage({super.key, this.initialFilter});

  final TaxDocumentType? initialFilter;

  @override
  State<CorporateTaxDocumentsPage> createState() =>
      _CorporateTaxDocumentsPageState();
}

class _CorporateTaxDocumentsPageState extends State<CorporateTaxDocumentsPage> {
  List<CorporateTaxDocument> _documents = [];
  bool _loading = true;
  TaxDocumentType? _filter;

  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter;
    _load();
  }

  Future<void> _load() async {
    final profile = AuthSession.instance.currentUser?.corporateProfile;
    if (profile == null) {
      setState(() {
        _documents = [];
        _loading = false;
      });
      return;
    }
    final repo = await CorporateTaxDocumentRepository.create();
    final docs = await repo.listForCompany(profile.companyKey);
    if (!mounted) return;
    setState(() {
      _documents = docs;
      _loading = false;
    });
  }

  List<CorporateTaxDocument> get _filtered {
    if (_filter == null) return _documents;
    return _documents.where((d) => d.type == _filter).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        leading: const AppBackButton(),
        automaticallyImplyLeading: false,
        title: const Text('결제 증빙'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Text(
                    ProductFeatureFlags.isHiringCommissionEnabled
                        ? '채용 수수료·알림핀 등 결제 시 자동 발행된 거래명세서·세금계산서·현금영수증입니다.'
                        : '알림핀·PUSH 등 유료 서비스 결제 시 자동 발행된 거래명세서·세금계산서·현금영수증입니다.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: AppColors.textSecondary.withValues(alpha: 0.95),
                    ),
                  ),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      _FilterChip(
                        label: '전체',
                        selected: _filter == null,
                        onTap: () => setState(() => _filter = null),
                      ),
                      ...TaxDocumentType.values.map(
                        (type) => _FilterChip(
                          label: type.label,
                          selected: _filter == type,
                          onTap: () => setState(() => _filter = type),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: _filtered.isEmpty
                      ? Center(
                          child: Text(
                            '발행된 증빙이 없습니다.\n결제 완료 후 자동으로 생성됩니다.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.textSecondary.withValues(
                                alpha: 0.9,
                              ),
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          itemCount: _filtered.length,
                          itemBuilder: (context, index) {
                            final doc = _filtered[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: CorporateSurfaceCard(
                                onTap: () => _openDetail(doc),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        _TypeBadge(type: doc.type),
                                        const Spacer(),
                                        Text(
                                          DateFormat('yyyy.MM.dd HH:mm')
                                              .format(doc.issuedAt),
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: AppColors.textSecondary
                                                .withValues(alpha: 0.9),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      doc.productName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${CorporateTaxDocumentService.formatKrw(doc.totalKrw)}원 · ${doc.categoryLabel}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textSecondary
                                            .withValues(alpha: 0.95),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      doc.statusLabel,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.primary
                                            .withValues(alpha: 0.95),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  void _openDetail(CorporateTaxDocument doc) {
    showAdaptiveSheet<void>(
      context: context,
      builder: (context) => _TaxDocumentDetailSheet(document: doc),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: AppColors.primaryLight.withValues(alpha: 0.35),
        checkmarkColor: AppColors.primary,
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.type});

  final TaxDocumentType type;

  @override
  Widget build(BuildContext context) {
    final color = switch (type) {
      TaxDocumentType.transactionStatement => const Color(0xFF1565C0),
      TaxDocumentType.taxInvoice => const Color(0xFF2E7D32),
      TaxDocumentType.cashReceipt => const Color(0xFFE65100),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        type.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _TaxDocumentDetailSheet extends StatelessWidget {
  const _TaxDocumentDetailSheet({required this.document});

  final CorporateTaxDocument document;

  @override
  Widget build(BuildContext context) {
    final text = CorporateTaxDocumentService.formatPlainText(document);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.searchBarBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              document.typeLabel,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            Text(
              document.issueNumber,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary.withValues(alpha: 0.9),
              ),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                child: Text(
                  text,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => Share.share(text, subject: document.typeLabel),
              icon: const Icon(Icons.share_outlined),
              label: const Text('공유·저장'),
            ),
          ],
        ),
      ),
    );
  }
}

void openCorporateTaxDocuments(
  BuildContext context, {
  TaxDocumentType? initialFilter,
}) {
  Navigator.of(context).pushNamed(
    AppRoutes.corporateTaxDocuments,
    arguments: initialFilter,
  );
}

Future<void> showTaxDocumentsIssuedSnackBar(
  BuildContext context, {
  required int count,
}) async {
  if (!context.mounted || count <= 0) return;
  showTransientSnackBar(
    context,
    '증빙 $count건이 발행되었습니다.',
    action: SnackBarAction(
      label: '보기',
      onPressed: () => openCorporateTaxDocuments(context),
    ),
  );
}
