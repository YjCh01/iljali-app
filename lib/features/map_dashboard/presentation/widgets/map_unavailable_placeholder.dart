import 'package:flutter/material.dart';

import 'package:map/core/constants/app_colors.dart';

import 'package:map/core/constants/map_constants.dart';



/// Naver Map 미설정 시 대체 UI

class MapUnavailablePlaceholder extends StatelessWidget {

  const MapUnavailablePlaceholder({super.key});



  @override

  Widget build(BuildContext context) {

    return ColoredBox(

      color: AppColors.background,

      child: Stack(

        fit: StackFit.expand,

        children: [

          Positioned.fill(

            child: CustomPaint(

              painter: _GridPainter(),

            ),

          ),

          Center(

            child: Padding(

              padding: const EdgeInsets.all(32),

              child: Column(

                mainAxisSize: MainAxisSize.min,

                children: [

                  Icon(

                    Icons.map_outlined,

                    size: 56,

                    color: AppColors.primary.withValues(alpha: 0.7),

                  ),

                  const SizedBox(height: 16),

                  const Text(

                    '지도 미리보기 모드',

                    style: TextStyle(

                      fontSize: 18,

                      fontWeight: FontWeight.w700,

                      color: AppColors.textPrimary,

                    ),

                  ),

                  const SizedBox(height: 8),

                  Text(

                    'Naver Map Client ID 설정 전에도\n검색·지원하기 UI는 테스트할 수 있습니다.',

                    textAlign: TextAlign.center,

                    style: TextStyle(

                      fontSize: 14,

                      height: 1.45,

                      color: AppColors.textSecondary.withValues(alpha: 0.95),

                    ),

                  ),

                  const SizedBox(height: 12),

                  Text(

                    '강남·역삼·선릉 인근 (${MapConstants.warehouseAreaCenter.latitude.toStringAsFixed(2)}, '

                    '${MapConstants.warehouseAreaCenter.longitude.toStringAsFixed(2)})',

                    style: TextStyle(

                      fontSize: 12,

                      color: AppColors.textSecondary.withValues(alpha: 0.85),

                    ),

                  ),

                ],

              ),

            ),

          ),

        ],

      ),

    );

  }

}



class _GridPainter extends CustomPainter {

  @override

  void paint(Canvas canvas, Size size) {

    final paint = Paint()

      ..color = AppColors.primaryLight.withValues(alpha: 0.15)

      ..strokeWidth = 1;



    const step = 48.0;

    for (var x = 0.0; x < size.width; x += step) {

      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);

    }

    for (var y = 0.0; y < size.height; y += step) {

      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);

    }

  }



  @override

  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;

}

