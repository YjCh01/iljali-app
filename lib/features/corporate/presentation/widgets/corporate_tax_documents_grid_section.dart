import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/constants/app_routes.dart';
import 'package:map/features/corporate/domain/entities/tax_document_type.dart';
import 'package:map/features/corporate/presentation/widgets/corporate_surface_card.dart';

/// 더보기 탭 — 결제 증빙 3분할 그리드
class CorporateTaxDocumentsGridSection extends StatelessWidget {
  const CorporateTaxDocumentsGridSection({
    super.key,
    required this.counts,
    this.onRefresh,
  });

  final Map<TaxDocumentType, int> counts;
  final VoidCallback? onRefresh;

  int get _total =>
      counts.values.fold<int>(0, (sum, value) => sum + value);

  void _open(BuildContext context, TaxDocumentType? filter) {
    Navigator.of(context)
        .pushNamed(AppRoutes.corporateTaxDocuments, arguments: filter)
        .then((_) => onRefresh?.call());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              '결제 증빙',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
            const Spacer(),
            if (_total > 0)
              TextButton(
                onPressed: () => _open(context, null),
                child: Text('전체 $_total건'),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '결제할 때마다 자동 발행됩니다. 현금영수증은 결제 직후 확인하고, '
          '거래명세서·세금계산서는 여기서 언제든 조회하세요.',
          style: TextStyle(
            fontSize: 12,
            height: 1.45,
            color: AppColors.textSecondary.withValues(alpha: 0.92),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _GridTile(
                icon: Icons.description_outlined,
                label: '거래명세서',
                count: counts[TaxDocumentType.transactionStatement] ?? 0,
                color: const Color(0xFF1565C0),
                onTap: () =>
                    _open(context, TaxDocumentType.transactionStatement),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _GridTile(
                icon: Icons.receipt_long_outlined,
                label: '세금계산서',
                count: counts[TaxDocumentType.taxInvoice] ?? 0,
                color: const Color(0xFF2E7D32),
                onTap: () => _open(context, TaxDocumentType.taxInvoice),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _GridTile(
                icon: Icons.payments_outlined,
                label: '현금영수증',
                count: counts[TaxDocumentType.cashReceipt] ?? 0,
                color: const Color(0xFFE65100),
                onTap: () => _open(context, TaxDocumentType.cashReceipt),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _GridTile extends StatelessWidget {
  const _GridTile({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final int count;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CorporateSurfaceCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              const Spacer(),
              if (count > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            count > 0 ? '발행 $count건' : '내역 없음',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }
}
