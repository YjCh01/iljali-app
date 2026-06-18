import 'package:flutter/material.dart';

import 'package:map/core/constants/app_colors.dart';

import 'package:map/core/job_board/job_board_refresh.dart';

import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';

import 'package:map/features/corporate/domain/entities/workplace_address.dart';

import 'package:map/features/corporate/presentation/navigation/corporate_job_post_flow_result.dart';

import 'package:map/features/corporate/presentation/widgets/corporate_job_post_optional_services_sheet.dart';



/// 공고 등록 직후 — 확인 및 선택 유료 서비스

class CorporateJobPostPublishedPage extends StatefulWidget {

  const CorporateJobPostPublishedPage({

    super.key,

    required this.post,

    required this.workplace,

  });



  final CorporateJobPost post;

  final WorkplaceAddress workplace;



  @override

  State<CorporateJobPostPublishedPage> createState() =>

      _CorporateJobPostPublishedPageState();

}



class _CorporateJobPostPublishedPageState

    extends State<CorporateJobPostPublishedPage> {

  late CorporateJobPost _post;



  @override

  void initState() {

    super.initState();

    _post = widget.post;

  }



  void _finish(BuildContext context) {

    JobBoardRefresh.markUpdated();

    Navigator.of(context).pop(

      const CorporateJobPostFlowResult(shellTabIndex: 1),

    );

  }



  void _openOptionalServicesSheet() {

    showCorporateJobPostOptionalServicesSheet(

      context,

      post: _post,

      workplace: widget.workplace,

      onPostUpdated: (updated) {

        setState(() => _post = updated);

        JobBoardRefresh.markUpdated();

      },

    );

  }



  @override

  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor: AppColors.background,

      appBar: AppBar(

        backgroundColor: AppColors.surface,

        foregroundColor: AppColors.textPrimary,

        elevation: 0,

        automaticallyImplyLeading: false,

        actions: [

          TextButton(

            onPressed: () => _finish(context),

            child: const Text('닫기'),

          ),

        ],

      ),

      body: SafeArea(

        child: ListView(

          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),

          children: [

            const Icon(

              Icons.check_circle_rounded,

              color: AppColors.primary,

              size: 64,

            ),

            const SizedBox(height: 16),

            const Text(

              '공고가 등록되었습니다',

              textAlign: TextAlign.center,

              style: TextStyle(

                fontSize: 24,

                fontWeight: FontWeight.w800,

                height: 1.3,

              ),

            ),

            const SizedBox(height: 10),

            Text(

              '「${_post.title}」',

              textAlign: TextAlign.center,

              style: TextStyle(

                fontSize: 16,

                fontWeight: FontWeight.w600,

                color: AppColors.textSecondary.withValues(alpha: 0.95),

              ),

            ),

            const SizedBox(height: 28),

            Row(

              children: [

                Expanded(

                  child: _ActionTile(

                    icon: Icons.list_alt_rounded,

                    label: '공고 목록 보기',

                    onTap: () => _finish(context),

                  ),

                ),

                const SizedBox(width: 12),

                Expanded(

                  child: _ActionTile(

                    icon: Icons.payments_outlined,

                    label: '유료 결제 추가 (선택)',

                    onTap: _openOptionalServicesSheet,

                    accent: AppColors.primary,

                  ),

                ),

              ],

            ),

          ],

        ),

      ),

    );

  }

}



class _ActionTile extends StatelessWidget {

  const _ActionTile({

    required this.icon,

    required this.label,

    required this.onTap,

    this.accent,

  });



  final IconData icon;

  final String label;

  final VoidCallback onTap;

  final Color? accent;



  @override

  Widget build(BuildContext context) {

    final color = accent ?? AppColors.textPrimary;



    return Material(

      color: AppColors.surface,

      borderRadius: BorderRadius.circular(14),

      clipBehavior: Clip.antiAlias,

      child: InkWell(

        onTap: onTap,

        child: Container(

          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),

          decoration: BoxDecoration(

            borderRadius: BorderRadius.circular(14),

            border: Border.all(

              color: (accent ?? AppColors.searchBarBorder)

                  .withValues(alpha: accent != null ? 0.35 : 1),

            ),

          ),

          child: Column(

            mainAxisSize: MainAxisSize.min,

            children: [

              Icon(icon, size: 28, color: color),

              const SizedBox(height: 10),

              Text(

                label,

                textAlign: TextAlign.center,

                style: TextStyle(

                  fontSize: 13,

                  fontWeight: FontWeight.w800,

                  height: 1.35,

                  color: color,

                ),

              ),

            ],

          ),

        ),

      ),

    );

  }

}

