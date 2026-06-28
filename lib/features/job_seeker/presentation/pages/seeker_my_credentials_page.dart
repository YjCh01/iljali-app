import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/core/widgets/app_back_button.dart';
import 'package:map/features/credential/domain/entities/credential_catalog.dart';
import 'package:map/features/credential/domain/entities/credential_category.dart';
import 'package:map/features/credential/domain/entities/credential_definition.dart';
import 'package:map/features/credential/domain/services/credential_search_service.dart';
import 'package:map/features/job_seeker/domain/entities/seeker_credential_holding.dart';
import 'package:map/features/job_seeker/domain/entities/seeker_member_profile.dart';
import 'package:map/features/job_seeker/domain/utils/seeker_profile_credentials.dart';
import 'package:map/features/job_seeker/presentation/utils/seeker_document_storage.dart';
import 'package:map/features/job_seeker/presentation/widgets/seeker_document_image.dart';

/// 구직자 — 표준 자격·면허 보유 등록 (사진 필수)
class SeekerMyCredentialsPage extends StatefulWidget {
  const SeekerMyCredentialsPage({super.key});

  @override
  State<SeekerMyCredentialsPage> createState() =>
      _SeekerMyCredentialsPageState();
}

class _SeekerMyCredentialsPageState extends State<SeekerMyCredentialsPage> {
  final _searchController = TextEditingController();
  List<CredentialDefinition> _suggestions = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _suggestions = CredentialSearchService.suggest(_searchController.text);
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  SeekerMemberProfile? get _profile =>
      AuthSession.instance.currentUser?.seekerProfile;

  Future<void> _saveProfile(SeekerMemberProfile profile) async {
    setState(() => _saving = true);
    await AuthSession.instance.updateSeekerProfile(profile);
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _toggleOwned(CredentialDefinition def, bool owned) async {
    final profile = _profile;
    if (profile == null) return;

    if (!owned) {
      await _saveProfile(profile.removeCredentialHolding(def.id));
      return;
    }

    if (def.requiresPhoto) {
      await _uploadPhoto(def);
      return;
    }

    await _saveProfile(
      profile.upsertCredentialHolding(
        SeekerCredentialHolding(
          credentialId: def.id,
          updatedAt: DateTime.now(),
        ),
      ),
    );
  }

  Future<void> _uploadPhoto(CredentialDefinition def) async {
    final profile = _profile;
    if (profile == null) return;

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('카메라'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('앨범'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    final file = await ImagePicker().pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (file == null || !mounted) return;

    final storedPath = await persistSeekerDocumentImage(
      file,
      'credential_${def.id}',
    );
    if (storedPath == null || !mounted) return;

    await _saveProfile(
      profile.upsertCredentialHolding(
        SeekerCredentialHolding(
          credentialId: def.id,
          imagePath: storedPath,
          updatedAt: DateTime.now(),
        ),
      ),
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('「${def.label}」 사진이 등록되었습니다.')),
    );
  }

  Future<void> _addFromSearch(CredentialDefinition def) async {
    _searchController.clear();
    final existing = _profile?.holdingFor(def.id);
    if (existing?.isComplete ?? false) return;
    if (def.requiresPhoto) {
      await _uploadPhoto(def);
    } else {
      await _toggleOwned(def, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        leading: const AppBackButton(),
        automaticallyImplyLeading: false,
        title: const Text('자격·면허 등록'),
      ),
      body: profile == null
          ? const Center(child: Text('로그인 후 등록할 수 있습니다.'))
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                const Text(
                  '보유 자격·면허',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Text(
                  '표준 목록에서 선택하세요. 사진 등록이 완료되어야 보유로 표시됩니다.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: AppColors.textSecondary.withValues(alpha: 0.95),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: '검색 (예: 지게차, 경비, 요양)',
                    prefixIcon: const Icon(Icons.search_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                if (_suggestions.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    '추천 검색어',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary.withValues(alpha: 0.9),
                    ),
                  ),
                  ..._suggestions.map(
                    (def) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(def.label),
                      subtitle: Text(def.category.label),
                      trailing: const Icon(Icons.add_circle_outline),
                      onTap: () => _addFromSearch(def),
                    ),
                  ),
                  const Divider(height: 24),
                ],
                if (_saving)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: LinearProgressIndicator(),
                  ),
                ...CredentialCategory.values.map(
                  (cat) => _CategorySection(
                    category: cat,
                    profile: profile,
                    onToggle: _toggleOwned,
                    onUpload: _uploadPhoto,
                  ),
                ),
              ],
            ),
    );
  }
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({
    required this.category,
    required this.profile,
    required this.onToggle,
    required this.onUpload,
  });

  final CredentialCategory category;
  final SeekerMemberProfile profile;
  final Future<void> Function(CredentialDefinition def, bool owned) onToggle;
  final Future<void> Function(CredentialDefinition def) onUpload;

  @override
  Widget build(BuildContext context) {
    final items = CredentialCatalog.forCategory(category);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            category.label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          ...items.map((def) {
            final holding = profile.holdingFor(def.id);
            final owned = holding != null &&
                (def.requiresPhoto ? holding.hasPhoto : true);
            return _CredentialRow(
              definition: def,
              owned: owned,
              imagePath: holding?.imagePath,
              onToggle: (v) => onToggle(def, v),
              onUpload: () => onUpload(def),
              onRemove: () => onToggle(def, false),
            );
          }),
        ],
      ),
    );
  }
}

class _CredentialRow extends StatelessWidget {
  const _CredentialRow({
    required this.definition,
    required this.owned,
    required this.onToggle,
    required this.onUpload,
    required this.onRemove,
    this.imagePath,
  });

  final CredentialDefinition definition;
  final bool owned;
  final String? imagePath;
  final ValueChanged<bool> onToggle;
  final VoidCallback onUpload;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final needsPhoto = definition.requiresPhoto;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.searchBarBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!needsPhoto)
                Checkbox(
                  value: owned,
                  onChanged: (v) => onToggle(v ?? false),
                  activeColor: AppColors.primary,
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      definition.label,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (needsPhoto)
                      Text(
                        owned ? '사진 등록 완료' : '사진을 업로드하면 보유로 등록됩니다',
                        style: TextStyle(
                          fontSize: 11,
                          color: owned
                              ? AppColors.primary
                              : AppColors.textSecondary.withValues(alpha: 0.85),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (needsPhoto) ...[
            const SizedBox(height: 8),
            if (imagePath != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: seekerDocumentImage(imagePath!, height: 120),
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onUpload,
              icon: const Icon(Icons.upload_rounded, size: 18),
              label: Text(imagePath == null ? '자격증 사진 업로드' : '사진 변경'),
            ),
            if (owned) ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: onRemove,
                  child: const Text('등록 삭제'),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
