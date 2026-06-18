import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/core/widgets/app_back_button.dart';
import 'package:map/features/corporate/presentation/widgets/corporate_surface_card.dart';
import 'package:map/features/job_seeker/data/repositories/seeker_document_repository.dart';

/// 구직자 — 신분증·통장사본 등록 (내정보)
class SeekerMyDocumentsPage extends StatefulWidget {
  const SeekerMyDocumentsPage({super.key});

  @override
  State<SeekerMyDocumentsPage> createState() => _SeekerMyDocumentsPageState();
}

class _SeekerMyDocumentsPageState extends State<SeekerMyDocumentsPage> {
  SeekerDocuments _docs = const SeekerDocuments();
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final email = AuthSession.instance.currentUser?.email;
    if (email == null) {
      setState(() => _loading = false);
      return;
    }
    final repo = await SeekerDocumentRepository.create();
    final docs = await repo.load(email);
    if (!mounted) return;
    setState(() {
      _docs = docs;
      _loading = false;
    });
  }

  Future<void> _pickAndSave({
    required bool isIdCard,
    required ImageSource source,
  }) async {
    final email = AuthSession.instance.currentUser?.email;
    if (email == null) return;

    final file = await ImagePicker().pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (file == null || !mounted) return;

    setState(() => _saving = true);
    final updated = _docs.copyWith(
      idCardImagePath: isIdCard ? file.path : _docs.idCardImagePath,
      bankAccountImagePath: isIdCard ? _docs.bankAccountImagePath : file.path,
      updatedAt: DateTime.now(),
    );
    final repo = await SeekerDocumentRepository.create();
    await repo.save(email, updated);
    if (!mounted) return;
    setState(() {
      _docs = updated;
      _saving = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isIdCard ? '신분증이 등록되었습니다.' : '통장사본이 등록되었습니다.',
        ),
      ),
    );
  }

  Future<void> _showPickSource(bool isIdCard) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('카메라로 촬영'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('앨범에서 선택'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    await _pickAndSave(isIdCard: isIdCard, source: source);
  }

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
        title: const Text('신분증·통장 등록'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                Text(
                  '채팅에서 바로 보낼 수 있도록 미리 등록해 두세요.',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color: AppColors.textSecondary.withValues(alpha: 0.95),
                  ),
                ),
                const SizedBox(height: 16),
                _DocumentCard(
                  title: '신분증',
                  icon: Icons.badge_outlined,
                  imagePath: _docs.idCardImagePath,
                  onRegister: _saving ? null : () => _showPickSource(true),
                ),
                const SizedBox(height: 12),
                _DocumentCard(
                  title: '통장사본',
                  icon: Icons.account_balance_outlined,
                  imagePath: _docs.bankAccountImagePath,
                  onRegister: _saving ? null : () => _showPickSource(false),
                ),
                const SizedBox(height: 16),
                Text(
                  '등록된 서류는 채팅 + 메뉴에서 「신분증 전송」「통장사본 전송」으로 '
                  '구인자에게 보낼 수 있습니다.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.45,
                    color: AppColors.textSecondary.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
    );
  }
}

class _DocumentCard extends StatelessWidget {
  const _DocumentCard({
    required this.title,
    required this.icon,
    required this.imagePath,
    this.onRegister,
  });

  final String title;
  final IconData icon;
  final String? imagePath;
  final VoidCallback? onRegister;

  @override
  Widget build(BuildContext context) {
    final hasImage = imagePath != null && File(imagePath!).existsSync();

    return CorporateSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              if (hasImage)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '등록됨',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2E7D32),
                    ),
                  ),
                ),
            ],
          ),
          if (hasImage) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                File(imagePath!),
                height: 140,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRegister,
            icon: Icon(hasImage ? Icons.refresh_rounded : Icons.add_a_photo),
            label: Text(hasImage ? '다시 등록' : '등록하기'),
          ),
        ],
      ),
    );
  }
}