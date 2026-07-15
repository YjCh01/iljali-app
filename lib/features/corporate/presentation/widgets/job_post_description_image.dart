import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:map/core/config/env_config.dart';
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

  static const _externalCdnHosts = [
    'albamon.com',
    'albamon.kr',
    'saraminimage.co.kr',
    'saramin.co.kr',
    'alba.co.kr',
    'incruit.com',
  ];

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

  /// 외부 채용 CDN은 핫링크 403 → API 프록시 URL로 변환
  static String resolveDisplayUrl(String raw) {
    final url = raw.trim();
    if (url.isEmpty || url.startsWith('data:')) return url;
    if (url.contains('/media/job-posts/')) return url;
    if (url.contains('/v1/job-media/proxy')) return url;

    final uri = Uri.tryParse(url);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      return url;
    }
    final host = uri.host.toLowerCase();
    final isExternal = _externalCdnHosts.any(
      (suffix) => host == suffix || host.endsWith('.$suffix'),
    );
    if (!isExternal) return url;

    final base = EnvConfig.complianceApiBaseUrl.replaceAll(RegExp(r'/$'), '');
    if (base.isEmpty) return url;
    return Uri.parse('$base/v1/job-media/proxy').replace(
      queryParameters: {'url': url},
    ).toString();
  }

  @override
  Widget build(BuildContext context) {
    final displayUrl = resolveDisplayUrl(url);
    final bytes = decodeDataUrl(displayUrl);
    final child = bytes != null
        ? Image.memory(
            bytes,
            width: width,
            height: height,
            fit: fit,
            errorBuilder: (_, __, ___) => _errorPlaceholder(),
          )
        : Image.network(
            displayUrl,
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
