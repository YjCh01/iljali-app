import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/widgets/app_back_button.dart';
import 'package:map/features/job_seeker/domain/entities/seeker_resume_snapshot.dart';
import 'package:map/features/job_seeker/presentation/widgets/seeker_resume_detail_body.dart';

Future<void> openSeekerResumeDetail(
  BuildContext context, {
  required SeekerResumeSnapshot snapshot,
  String title = '이력서 상세',
}) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => SeekerResumeDetailPage(
        snapshot: snapshot,
        title: title,
      ),
    ),
  );
}

/// 이력서 전체 상세 화면
class SeekerResumeDetailPage extends StatelessWidget {
  const SeekerResumeDetailPage({
    super.key,
    required this.snapshot,
    this.title = '이력서 상세',
    this.showContact = true,
  });

  final SeekerResumeSnapshot snapshot;
  final String title;
  final bool showContact;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        leading: const AppBackButton(),
        automaticallyImplyLeading: false,
        title: Text(title),
      ),
      body: SeekerResumeDetailBody(
        snapshot: snapshot,
        showContact: showContact,
      ),
    );
  }
}
