import 'package:flutter/material.dart';

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

    final size = tier.markerSize * 0.55;

    return Column(

      children: [

        Container(

          width: size,

          height: size,

          alignment: Alignment.center,

          decoration: BoxDecoration(

            color: tier.pinColor,

            shape: BoxShape.circle,

            border: Border.all(color: tier.pinBorderColor, width: 2),

            boxShadow: [

              BoxShadow(

                color: tier.pinColor.withValues(alpha: 0.35),

                blurRadius: 6,

                offset: const Offset(0, 2),

              ),

            ],

          ),

          child: Text(

            tier.shapeGlyph,

            style: TextStyle(

              color: Colors.white,

              fontSize: size * 0.42,

              fontWeight: FontWeight.w900,

              height: 1,

            ),

          ),

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

