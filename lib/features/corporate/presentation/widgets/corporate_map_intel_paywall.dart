import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/constants/app_routes.dart';

Future<void> showCorporateMapIntelPaywall(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('주변 채용 정보'),
      content: const Text(
        '무료 플랜에서는 지도에 핀·노선 밀도만 확인할 수 있습니다.\n'
        '다른 기업 공고 내용을 보려면 일자리 알림핀을 구매해 주세요.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('닫기'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop();
            Navigator.of(context).pushNamed(AppRoutes.corporatePushPackageShop);
          },
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          child: const Text('일자리 알림핀 구매'),
        ),
      ],
    ),
  );
}
