import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/legal/legal_document_parser.dart';

class LegalHighlightedText extends StatelessWidget {
  const LegalHighlightedText({super.key, required this.raw});

  final String raw;

  @override
  Widget build(BuildContext context) {
    final baseStyle = TextStyle(
      fontSize: 13,
      height: 1.55,
      color: AppColors.textPrimary.withValues(alpha: 0.92),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF9C4),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFF9A825)),
          ),
          child: const Text(
            '노란 형광펜 구간은 법무 검토 전 반드시 수정·확인해야 하는 항목입니다. '
            '그대로 사용할 수 없습니다.',
            style: TextStyle(fontSize: 12, height: 1.4, fontWeight: FontWeight.w600),
          ),
        ),
        RichText(
          text: TextSpan(
            children: LegalDocumentParser.parseToSpans(
              raw,
              baseStyle: baseStyle,
            ),
          ),
        ),
      ],
    );
  }
}
