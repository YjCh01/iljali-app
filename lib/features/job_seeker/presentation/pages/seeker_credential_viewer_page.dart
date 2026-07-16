import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/widgets/app_back_button.dart';
import 'package:map/features/job_seeker/presentation/widgets/seeker_document_image.dart';
import 'package:share_plus/share_plus.dart';

Future<void> openSeekerCredentialViewer(
  BuildContext context, {
  required String label,
  required String imagePath,
}) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => SeekerCredentialViewerPage(
        title: label,
        imagePath: imagePath,
      ),
    ),
  );
}

/// 채용 확정 후 기업회원 — 자격증 원본 열람·다운로드
class SeekerCredentialViewerPage extends StatelessWidget {
  const SeekerCredentialViewerPage({
    super.key,
    required this.title,
    required this.imagePath,
  });

  final String title;
  final String imagePath;

  Future<void> _download(BuildContext context) async {
    final ref = imagePath.trim();
    if (ref.isEmpty) return;

    try {
      if (ref.startsWith('data:image/')) {
        if (!context.mounted) return;
        await Share.share(ref, subject: title);
        return;
      }

      if (kIsWeb || ref.startsWith('http://') || ref.startsWith('https://')) {
        if (!context.mounted) return;
        await Share.share('자격증: $title\n$ref');
        return;
      }

      final file = File(ref);
      if (!await file.exists()) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('파일을 찾을 수 없습니다.')),
        );
        return;
      }

      await Share.shareXFiles(
        [XFile(file.path, name: '$title.jpg')],
        subject: title,
        text: title,
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('다운로드에 실패했습니다. ($error)')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        leading: const AppBackButton(),
        automaticallyImplyLeading: false,
        title: Text(title),
        actions: [
          IconButton(
            tooltip: '다운로드',
            onPressed: () => _download(context),
            icon: const Icon(Icons.download_outlined),
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          child: seekerDocumentImage(imagePath, height: double.infinity),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: FilledButton.icon(
            onPressed: () => _download(context),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              minimumSize: const Size.fromHeight(48),
            ),
            icon: const Icon(Icons.download_outlined),
            label: const Text('다운로드'),
          ),
        ),
      ),
    );
  }
}
