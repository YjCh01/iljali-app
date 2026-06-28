import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/features/corporate/domain/entities/job_post_description_body.dart';

/// 공고 상세 본문 — 텍스트·이미지·HTML (구조화 필드와 분리된 영역)
class JobPostDescriptionBodyView extends StatelessWidget {
  const JobPostDescriptionBodyView({
    super.key,
    required this.body,
    this.compact = false,
  });

  final JobPostDescriptionBody body;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (!body.hasContent) {
      return Text(
        '업무 내용이 등록되지 않았습니다.',
        style: TextStyle(
          fontSize: 14,
          height: 1.45,
          color: AppColors.textSecondary.withValues(alpha: 0.9),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (body.text.trim().isNotEmpty) ...[
          Text(
            body.text.trim(),
            style: TextStyle(
              fontSize: compact ? 13 : 14,
              height: 1.45,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
          if (body.imageUrls.isNotEmpty || body.html.trim().isNotEmpty)
            SizedBox(height: compact ? 10 : 14),
        ],
        for (var i = 0; i < body.imageUrls.length; i++) ...[
          _BodyImage(url: body.imageUrls[i]),
          if (i < body.imageUrls.length - 1) const SizedBox(height: 10),
        ],
        if (body.html.trim().isNotEmpty) ...[
          if (body.text.trim().isNotEmpty || body.imageUrls.isNotEmpty)
            SizedBox(height: compact ? 10 : 14),
          HtmlWidget(
            body.html.trim(),
            textStyle: TextStyle(
              fontSize: compact ? 13 : 14,
              height: 1.45,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ],
    );
  }
}

class _BodyImage extends StatelessWidget {
  const _BodyImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Material(
        color: Colors.white,
        child: InkWell(
          onTap: () => _openFullscreen(context),
          child: Image.network(
            url,
            fit: BoxFit.contain,
            width: double.infinity,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return AspectRatio(
                aspectRatio: 4 / 3,
                child: Center(
                  child: CircularProgressIndicator(
                    value: progress.expectedTotalBytes != null
                        ? progress.cumulativeBytesLoaded /
                            progress.expectedTotalBytes!
                        : null,
                    strokeWidth: 2,
                  ),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return Container(
                padding: const EdgeInsets.all(24),
                color: AppColors.primaryLight.withValues(alpha: 0.08),
                child: Column(
                  children: [
                    Icon(
                      Icons.broken_image_outlined,
                      color: AppColors.textSecondary.withValues(alpha: 0.7),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '이미지를 불러올 수 없습니다',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _openFullscreen(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4,
                child: Image.network(url, fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: MediaQuery.paddingOf(ctx).top + 8,
              right: 8,
              child: IconButton(
                onPressed: () => Navigator.of(ctx).pop(),
                icon: const Icon(Icons.close_rounded, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
