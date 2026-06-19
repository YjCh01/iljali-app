import 'package:flutter/material.dart';

import 'package:map/core/constants/app_colors.dart';

import 'package:map/features/job_seeker/domain/entities/job_map_pin.dart';

import 'package:map/features/job_seeker/domain/entities/job_map_pin_display_tier.dart';



/// 구직자 지도 — 유료 공고 배너 목록 (탭 2)

class JobMapHotJobsPanel extends StatelessWidget {

  const JobMapHotJobsPanel({

    super.key,

    required this.pins,

    required this.onBannerTap,

  });



  final List<JobMapPin> pins;

  final ValueChanged<JobMapPin> onBannerTap;



  static bool isHotPin(JobMapPin pin) =>

      pin.displayTier == JobMapPinDisplayTier.packageActive;



  @override

  Widget build(BuildContext context) {

    final hotPins = pins.where(isHotPin).toList()

      ..sort((a, b) => b.displayTier.sortOrder.compareTo(a.displayTier.sortOrder));



    if (hotPins.isEmpty) {

      return Center(

        child: Padding(

          padding: const EdgeInsets.all(32),

          child: Text(

            '지금 뜨는 유료 공고가 없습니다.\n지도 탭에서 주변 공고를 찾아보세요.',

            textAlign: TextAlign.center,

            style: TextStyle(

              color: AppColors.textSecondary.withValues(alpha: 0.9),

              height: 1.45,

            ),

          ),

        ),

      );

    }



    return ListView.separated(

      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),

      itemCount: hotPins.length,

      separatorBuilder: (_, __) => const SizedBox(height: 10),

      itemBuilder: (context, index) {

        final pin = hotPins[index];

        final tier = pin.displayTier;

        return Material(

          color: AppColors.surface,

          borderRadius: BorderRadius.circular(16),

          elevation: 1,

          shadowColor: Colors.black26,

          child: InkWell(

            onTap: () => onBannerTap(pin),

            borderRadius: BorderRadius.circular(16),

            child: Padding(

              padding: const EdgeInsets.all(16),

              child: Row(

                children: [

                  Container(

                    width: 48,

                    height: 48,

                    decoration: BoxDecoration(

                      color: tier.pinLightColor,

                      borderRadius: BorderRadius.circular(12),

                    ),

                    alignment: Alignment.center,

                    child: Icon(

                      Icons.push_pin_rounded,

                      color: tier.pinColor,

                    ),

                  ),

                  const SizedBox(width: 12),

                  Expanded(

                    child: Column(

                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [

                        Row(

                          children: [

                            Container(

                              padding: const EdgeInsets.symmetric(

                                horizontal: 8,

                                vertical: 2,

                              ),

                              decoration: BoxDecoration(

                                color: tier.pinColor.withValues(alpha: 0.15),

                                borderRadius: BorderRadius.circular(8),

                              ),

                              child: Text(

                                '인기',

                                style: TextStyle(

                                  fontSize: 10,

                                  fontWeight: FontWeight.w800,

                                  color: tier.pinColor,

                                ),

                              ),

                            ),

                            const SizedBox(width: 6),

                            Text(

                              tier.label,

                              style: TextStyle(

                                fontSize: 11,

                                color: AppColors.textSecondary,

                              ),

                            ),

                          ],

                        ),

                        const SizedBox(height: 4),

                        Text(

                          pin.post.title,

                          maxLines: 2,

                          overflow: TextOverflow.ellipsis,

                          style: const TextStyle(

                            fontWeight: FontWeight.w800,

                            fontSize: 15,

                          ),

                        ),

                        Text(

                          '${pin.companyName} · ${pin.post.hourlyWage}',

                          style: TextStyle(

                            fontSize: 12,

                            color: AppColors.textSecondary.withValues(alpha: 0.9),

                          ),

                        ),

                      ],

                    ),

                  ),

                  const Icon(Icons.chevron_right_rounded),

                ],

              ),

            ),

          ),

        );

      },

    );

  }

}

