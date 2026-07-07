import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/features/credential/domain/entities/credential_catalog.dart';
import 'package:map/features/credential/domain/entities/credential_category.dart';
import 'package:map/features/credential/domain/entities/credential_definition.dart';
import 'package:map/features/credential/domain/services/credential_search_service.dart';
import 'package:map/features/credential/presentation/widgets/credential_guide_link.dart';

/// 자격증 검색 + 연관검색어 추천 + 다중 선택
class CredentialSearchPickerSheet extends StatefulWidget {
  const CredentialSearchPickerSheet({
    super.key,
    required this.selectedIds,
    this.onChanged,
    this.title = '필수 자격·면허 선택',
    this.confirmLabel = '선택 완료',
  });

  final Set<String> selectedIds;
  final ValueChanged<Set<String>>? onChanged;
  final String title;
  final String confirmLabel;

  static Future<Set<String>?> show(
    BuildContext context, {
    required Set<String> selectedIds,
    String title = '필수 자격·면허 선택',
  }) {
    return showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CredentialSearchPickerSheet(
        selectedIds: selectedIds,
        title: title,
        onChanged: (_) {},
      ),
    );
  }

  @override
  State<CredentialSearchPickerSheet> createState() =>
      _CredentialSearchPickerSheetState();
}

class _CredentialSearchPickerSheetState extends State<CredentialSearchPickerSheet> {
  late Set<String> _selected;
  final _queryController = TextEditingController();
  List<CredentialDefinition> _suggestions = [];

  @override
  void initState() {
    super.initState();
    _selected = Set<String>.from(widget.selectedIds);
    _queryController.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    setState(() {
      _suggestions = CredentialSearchService.suggest(
        _queryController.text,
        excludeIds: _selected,
      );
    });
  }

  void _toggle(CredentialDefinition def) {
    setState(() {
      if (_selected.contains(def.id)) {
        _selected.remove(def.id);
      } else {
        _selected.add(def.id);
      }
      _suggestions = CredentialSearchService.suggest(
        _queryController.text,
        excludeIds: _selected,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Container(
      margin: EdgeInsets.only(top: MediaQuery.sizeOf(context).height * 0.08),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _queryController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: '자격증명·별칭 검색 (예: 지게차)',
                  prefixIcon: const Icon(Icons.search_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              if (_suggestions.isNotEmpty) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '추천 검색어',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary.withValues(alpha: 0.9),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                ..._suggestions.map(
                  (def) => _CredentialCheckTile(
                    definition: def,
                    checked: _selected.contains(def.id),
                    onChanged: (_) => _toggle(def),
                  ),
                ),
              ],
              if (_selected.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  '선택됨',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _selected.map((id) {
                    final def = CredentialCatalog.findById(id);
                    final label = def?.label ?? id;
                    return InputChip(
                      label: Text(
                        label,
                        style: const TextStyle(fontSize: 12),
                      ),
                      onDeleted: () {
                        setState(() => _selected.remove(id));
                        _onQueryChanged();
                      },
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(_selected),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(widget.confirmLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CredentialCheckTile extends StatelessWidget {
  const _CredentialCheckTile({
    required this.definition,
    required this.checked,
    required this.onChanged,
  });

  final CredentialDefinition definition;
  final bool checked;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      value: checked,
      onChanged: onChanged,
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      title: Text(
        definition.label,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            definition.category.label,
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary.withValues(alpha: 0.85),
            ),
          ),
          if (definition.summary != null && definition.summary!.isNotEmpty)
            Text(
              definition.summary!,
              style: TextStyle(
                fontSize: 10,
                height: 1.35,
                color: AppColors.textSecondary.withValues(alpha: 0.75),
              ),
            ),
          CredentialGuideLink(definition: definition, dense: true),
        ],
      ),
    );
  }
}

/// 공고 작성 — 필수 자격 선택 필드
class RequiredCredentialsField extends StatelessWidget {
  const RequiredCredentialsField({
    super.key,
    required this.selectedIds,
    required this.onChanged,
  });

  final List<String> selectedIds;
  final ValueChanged<List<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '필수 자격·면허',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '현장·법정 요건에 맞는 자격증을 검색해 선택하세요.',
          style: TextStyle(
            fontSize: 12,
            height: 1.4,
            color: AppColors.textSecondary.withValues(alpha: 0.9),
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () async {
            final result = await showModalBottomSheet<Set<String>>(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (ctx) => CredentialSearchPickerSheet(
                selectedIds: selectedIds.toSet(),
                title: '필수 자격·면허 선택',
              ),
            );
            if (result != null) onChanged(result.toList());
          },
          icon: const Icon(Icons.search_rounded),
          label: const Text('자격·면허 검색하여 추가'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
        if (selectedIds.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: selectedIds.map((id) {
              final def = CredentialCatalog.findById(id);
              return Chip(
                label: Text(def?.label ?? id),
                onDeleted: () {
                  onChanged(selectedIds.where((x) => x != id).toList());
                },
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}
