import 'package:flutter/material.dart';

import 'package:map/core/map/pins/teardrop_map_pin_art.dart';
import 'package:map/features/job_seeker/domain/entities/job_map_pin_display_tier.dart';

/// 패키지 상점 · 지도 핀 등급 미리보기 (일반 · 알림핀)
class MapPinTierPreviewRow extends StatelessWidget {
  const MapPinTierPreviewRow({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _PinChip(tier: JobMapPinDisplayTier.standard, caption: '일반'),
        const SizedBox(width: 24),
        _PinChip(tier: JobMapPinDisplayTier.packageActive, caption: '알림핀'),
      ],
    );
  }
}

class _PinChip extends StatelessWidget {
  const _PinChip({required this.tier, required this.caption});

  final JobMapPinDisplayTier tier;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        JobTeardropPinWidget(
          bodyColor: tier.pinColor,
          style: tier == JobMapPinDisplayTier.packageActive
              ? MapPinStyle.notification
              : MapPinStyle.workplace,
          scale: 0.72,
        ),
        const SizedBox(height: 4),
        Text(
          caption,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
