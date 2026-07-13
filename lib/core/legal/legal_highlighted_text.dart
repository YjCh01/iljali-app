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

    return RichText(
      text: TextSpan(
        children: LegalDocumentParser.parseToSpans(
          LegalDocumentParser.stripMarkers(raw),
          baseStyle: baseStyle,
        ),
      ),
    );
  }
}
