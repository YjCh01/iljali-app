import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/hiring/hiring_application.dart';
import 'package:map/core/trust/employer_rating.dart';
import 'package:map/core/trust/local_employer_rating_repository.dart';

const _ratingTags = [
  '시간 약속 준수',
  '업무 태도 좋음',
  '재고의',
  '커뮤니케이션 원활',
];

/// 출근·수수료 결제 후 구직자 평가
Future<void> showEmployerRatingDialog(
  BuildContext context,
  HiringApplication application, {
  String? companyKey,
  String? branchId,
}) async {
  final repo = await LocalEmployerRatingRepository.create();
  if (await repo.hasRated(application.id)) return;
  if (!context.mounted) return;

  await showDialog<void>(
    context: context,
    builder: (context) => _EmployerRatingDialog(
      application: application,
      companyKey: companyKey ?? application.companyKey ?? '',
      branchId: branchId,
    ),
  );
}

class _EmployerRatingDialog extends StatefulWidget {
  const _EmployerRatingDialog({
    required this.application,
    required this.companyKey,
    this.branchId,
  });

  final HiringApplication application;
  final String companyKey;
  final String? branchId;

  @override
  State<_EmployerRatingDialog> createState() => _EmployerRatingDialogState();
}

class _EmployerRatingDialogState extends State<_EmployerRatingDialog> {
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
    final repo = await LocalEmployerRatingRepository.create();
    await repo.save(
      EmployerRating(
        id: 'rating_${DateTime.now().millisecondsSinceEpoch}',
        companyKey: widget.companyKey,
        applicationId: widget.application.id,
        seekerEmail: widget.application.seekerEmail,
        stars: _stars,
        createdAt: DateTime.now(),
        branchId: widget.branchId,
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
      title: const Text('구직자 평가'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${app.seekerName}님과의 근무는 어떠셨나요?',
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
                    star <= _stars ? Icons.star_rounded : Icons.star_outline_rounded,
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
              children: _ratingTags.map((tag) {
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
