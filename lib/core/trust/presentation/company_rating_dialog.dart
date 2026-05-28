import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/hiring/hiring_application.dart';
import 'package:map/core/trust/company_rating.dart';
import 'package:map/core/trust/local_company_rating_repository.dart';

const _companyRatingTags = [
  '급여 약속 준수',
  '업무 설명 명확',
  '시설·환경 좋음',
  '재채용 희망',
];

/// 근무 완료 후 구직자 → 고용주 평가
Future<void> showCompanyRatingDialog(
  BuildContext context,
  HiringApplication application,
) async {
  final companyKey = application.companyKey;
  if (companyKey == null || companyKey.isEmpty) return;

  final repo = await LocalCompanyRatingRepository.create();
  if (await repo.hasRated(application.id)) return;
  if (!context.mounted) return;

  await showDialog<void>(
    context: context,
    builder: (context) => _CompanyRatingDialog(
      application: application,
      companyKey: companyKey,
    ),
  );
}

class _CompanyRatingDialog extends StatefulWidget {
  const _CompanyRatingDialog({
    required this.application,
    required this.companyKey,
  });

  final HiringApplication application;
  final String companyKey;

  @override
  State<_CompanyRatingDialog> createState() => _CompanyRatingDialogState();
}

class _CompanyRatingDialogState extends State<_CompanyRatingDialog> {
  int _stars = 5;
  final _selectedTags = <String>{};
  final _commentController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _saving = true);
    final repo = await LocalCompanyRatingRepository.create();
    await repo.save(
      CompanyRating(
        id: 'cr_${DateTime.now().millisecondsSinceEpoch}',
        companyKey: widget.companyKey,
        applicationId: widget.application.id,
        seekerEmail: widget.application.seekerEmail,
        stars: _stars,
        createdAt: DateTime.now(),
        branchId: widget.application.branchId,
        tags: _selectedTags.toList(),
        comment: _commentController.text.trim().isEmpty
            ? null
            : _commentController.text.trim(),
      ),
    );
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.application;

    return AlertDialog(
      title: const Text('고용주 평가'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${app.companyName} 근무는 어떠셨나요?',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final star = index + 1;
                return IconButton(
                  onPressed: () => setState(() => _stars = star),
                  icon: Icon(
                    star <= _stars
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: AppColors.primary,
                    size: 32,
                  ),
                );
              }),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _companyRatingTags.map((tag) {
                final selected = _selectedTags.contains(tag);
                return FilterChip(
                  label: Text(tag, style: const TextStyle(fontSize: 12)),
                  selected: selected,
                  onSelected: (value) {
                    setState(() {
                      if (value) {
                        _selectedTags.add(tag);
                      } else {
                        _selectedTags.remove(tag);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _commentController,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: '한 줄 코멘트 (선택)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('건너뛰기'),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('평가 저장'),
        ),
      ],
    );
  }
}
