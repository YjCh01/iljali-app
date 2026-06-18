import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';
import 'package:map/features/corporate/domain/entities/push_dispatch_target.dart';
import 'package:map/features/corporate/domain/entities/push_ticket_catalog.dart';
import 'package:map/features/corporate/domain/services/push_dispatch_service.dart';
import 'package:map/features/corporate/domain/utils/exposure_slot_policy.dart';
import 'package:map/features/corporate/presentation/widgets/select_all_toggle_bar.dart';

class PushTargetSelectResult {
  const PushTargetSelectResult({
    required this.targets,
    required this.paymentMode,
  });

  final List<PushDispatchTarget> targets;
  final PushTargetPaymentMode paymentMode;
}

/// PUSH 발송 — 대상 복수 선택 + PUSH권 결제/소진
Future<PushTargetSelectResult?> showPushTargetSelectSheet(
  BuildContext context, {
  required List<PushDispatchTarget> targets,
  required int pushTicketCredits,
  required CorporateJobPost post,
}) {
  return showModalBottomSheet<PushTargetSelectResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _PushTargetSelectSheet(
      targets: targets,
      pushTicketCredits: pushTicketCredits,
      post: post,
    ),
  );
}

class _PushTargetSelectSheet extends StatefulWidget {
  const _PushTargetSelectSheet({
    required this.targets,
    required this.pushTicketCredits,
    required this.post,
  });

  final List<PushDispatchTarget> targets;
  final int pushTicketCredits;
  final CorporateJobPost post;

  @override
  State<_PushTargetSelectSheet> createState() => _PushTargetSelectSheetState();
}

class _PushTargetSelectSheetState extends State<_PushTargetSelectSheet> {
  final Set<String> _selectedIds = {};

  List<PushDispatchTarget> get _selectedTargets {
    return [
      for (final target in widget.targets)
        if (_selectedIds.contains(target.id)) target,
    ];
  }

  bool get _useWallet => widget.pushTicketCredits > 0;

  bool get _canConfirm {
    if (_selectedIds.isEmpty) return false;
    if (_useWallet) {
      return _selectedIds.length <= widget.pushTicketCredits;
    }
    return true;
  }

  void _toggleTarget(String id) {
    final target = widget.targets.firstWhere((t) => t.id == id);
    if (_isTargetDisabled(target)) return;
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  List<PushDispatchTarget> _selectableTargets(
    Iterable<PushDispatchTarget> targets,
  ) =>
      targets.where((target) => !_isTargetDisabled(target)).toList();

  void _toggleSelectAll({PushDispatchTargetKind? kind}) {
    final pool = kind == null
        ? widget.targets
        : widget.targets.where((target) => target.kind == kind);
    final selectable = _selectableTargets(pool);
    if (selectable.isEmpty) return;
    final ids = selectable.map((target) => target.id).toSet();
    final allSelected = ids.every(_selectedIds.contains);
    setState(() {
      if (allSelected) {
        _selectedIds.removeAll(ids);
      } else {
        _selectedIds.addAll(ids);
      }
    });
  }

  bool _isAllSelected(Iterable<PushDispatchTarget> targets) {
    final selectable = _selectableTargets(targets);
    if (selectable.isEmpty) return false;
    return selectable.every((target) => _selectedIds.contains(target.id));
  }

  int _selectedCountIn(Iterable<PushDispatchTarget> targets) {
    return targets
        .where((target) => _selectedIds.contains(target.id))
        .length;
  }

  String? _blockReason(PushDispatchTarget target) =>
      ExposureSlotPolicy.pushTicketBlockReason(
        post: widget.post,
        target: target,
      );

  bool _isTargetDisabled(PushDispatchTarget target) =>
      _blockReason(target) != null;

  void _confirm() {
    if (!_canConfirm) return;
    final selected = _selectedTargets;
    if (selected.isEmpty) return;
    Navigator.of(context).pop(
      PushTargetSelectResult(
        targets: selected,
        paymentMode: _useWallet
            ? PushTargetPaymentMode.walletCredit
            : PushTargetPaymentMode.pgPayment,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final grouped = <PushDispatchTargetKind, List<PushDispatchTarget>>{};
    for (final target in widget.targets) {
      grouped.putIfAbsent(target.kind, () => []).add(target);
    }
    final selectedCount = _selectedIds.length;
    final overCredit =
        _useWallet && selectedCount > widget.pushTicketCredits;
    final allSelectable = _selectableTargets(widget.targets);

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.82,
        ),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.searchBarBorder,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'PUSH 보내기',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    PushTicketCatalog.priceLine,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: AppColors.textSecondary.withValues(alpha: 0.95),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '근무지 · 알림핀 · 셔틀 정류장 중 발송할 곳을 선택하세요. '
                    '여러 곳을 동시에 선택할 수 있습니다.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: AppColors.textSecondary.withValues(alpha: 0.88),
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                shrinkWrap: true,
                children: [
                  if (allSelectable.isNotEmpty)
                    SelectAllToggleBar(
                      allSelected: _isAllSelected(widget.targets),
                      selectableCount: allSelectable.length,
                      selectedCount: _selectedCountIn(widget.targets),
                      onToggle: () => _toggleSelectAll(),
                      padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
                    ),
                  for (final kind in PushDispatchTargetKind.values)
                    if (grouped[kind]?.isNotEmpty == true) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
                        child: Text(
                          kind.sectionTitle,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      SelectAllToggleBar(
                        allSelected: _isAllSelected(grouped[kind]!),
                        selectableCount:
                            _selectableTargets(grouped[kind]!).length,
                        selectedCount: _selectedCountIn(grouped[kind]!),
                        onToggle: () => _toggleSelectAll(kind: kind),
                        padding: const EdgeInsets.only(bottom: 6),
                      ),
                      ...grouped[kind]!.map(_buildTargetTile),
                    ],
                ],
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              decoration: BoxDecoration(
                color: AppColors.background,
                border: Border(
                  top: BorderSide(
                    color: AppColors.searchBarBorder.withValues(alpha: 0.8),
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _useWallet
                        ? '보유 PUSH 알림권 총 ${widget.pushTicketCredits}회'
                        : 'PUSH 알림권 없음 · ${PushTicketCatalog.unitPriceLabel} 결제',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary.withValues(alpha: 0.95),
                    ),
                  ),
                  if (overCredit) ...[
                    const SizedBox(height: 6),
                    Text(
                      '선택 ${selectedCount}곳 — 보유 알림권이 부족합니다.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  FilledButton(
                    onPressed: _canConfirm ? _confirm : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      _useWallet
                          ? selectedCount > 0
                              ? 'PUSH 알림권 사용 · ${selectedCount}곳 발송'
                              : 'PUSH 알림권 사용 · 발송'
                          : selectedCount > 0
                              ? '${PushTicketCatalog.unitPriceLabel} 결제 · ${selectedCount}곳 발송'
                              : '${PushTicketCatalog.unitPriceLabel} 결제 후 발송',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTargetTile(PushDispatchTarget target) {
    final selected = _selectedIds.contains(target.id);
    final disabled = _isTargetDisabled(target);
    final blockReason = _blockReason(target);
    final icon = switch (target.kind) {
      PushDispatchTargetKind.workplace => Icons.storefront_outlined,
      PushDispatchTargetKind.notificationPin => Icons.push_pin_outlined,
      PushDispatchTargetKind.shuttleStop => Icons.directions_bus_filled_outlined,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected
            ? AppColors.primaryLight.withValues(alpha: 0.18)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: disabled ? null : () => _toggleTarget(target.id),
          borderRadius: BorderRadius.circular(12),
          child: Opacity(
            opacity: disabled ? 0.45 : 1,
            child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected
                    ? AppColors.primary.withValues(alpha: 0.45)
                    : AppColors.searchBarBorder,
              ),
            ),
            child: Row(
              children: [
                Icon(icon, size: 20, color: AppColors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        target.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        blockReason ??
                            '${target.subtitle} · 반경 ${target.radiusLabel}',
                        style: TextStyle(
                          fontSize: 11,
                          color: blockReason != null
                              ? Colors.red.shade700
                              : AppColors.textSecondary.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                Checkbox(
                  value: selected,
                  onChanged: disabled ? null : (_) => _toggleTarget(target.id),
                  activeColor: AppColors.primary,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          ),
        ),
      ),
    );
  }
}
