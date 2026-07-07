import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';

/// 공고 본문 이미지 — https URL · data URL(base64) 모두 표시
class JobPostDescriptionImage extends StatelessWidget {
  const JobPostDescriptionImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius = BorderRadius.zero,
  });

  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius borderRadius;

  static Uint8List? decodeDataUrl(String url) {
    if (!url.startsWith('data:')) return null;
    final comma = url.indexOf(',');
    if (comma < 0) return null;
    try {
      return base64Decode(url.substring(comma + 1));
    } on Object {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bytes = decodeDataUrl(url);
    final child = bytes != null
        ? Image.memory(
            bytes,
            width: width,
            height: height,
            fit: fit,
            errorBuilder: (_, __, ___) => _errorPlaceholder(),
          )
        : Image.network(
            url,
            width: width,
            height: height,
            fit: fit,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return _loadingPlaceholder(progress);
            },
            errorBuilder: (_, __, ___) => _errorPlaceholder(),
          );

    if (borderRadius == BorderRadius.zero) return child;
    return ClipRRect(borderRadius: borderRadius, child: child);
  }

  Widget _loadingPlaceholder(ImageChunkEvent progress) {
    return SizedBox(
      width: width,
      height: height,
      child: Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          value: progress.expectedTotalBytes != null
              ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
              : null,
        ),
      ),
    );
  }

  Widget _errorPlaceholder() {
    return Container(
      width: width,
      height: height,
      color: AppColors.primaryLight.withValues(alpha: 0.15),
      alignment: Alignment.center,
      child: Icon(
        Icons.broken_image_outlined,
        color: AppColors.textSecondary.withValues(alpha: 0.75),
      ),
    );
  }
}
