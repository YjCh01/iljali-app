import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/core/widgets/app_back_button.dart';
import 'package:map/features/credential/domain/custom_credential_support.dart';
import 'package:map/features/credential/domain/entities/credential_catalog.dart';
import 'package:map/features/credential/domain/entities/credential_category.dart';
import 'package:map/features/credential/domain/entities/credential_definition.dart';
import 'package:map/features/credential/domain/services/credential_search_service.dart';
import 'package:map/features/credential/presentation/widgets/credential_guide_link.dart';
import 'package:map/features/job_seeker/domain/entities/seeker_credential_holding.dart';
import 'package:map/features/job_seeker/domain/entities/seeker_member_profile.dart';
import 'package:map/features/job_seeker/domain/utils/seeker_profile_credentials.dart';
import 'package:map/features/job_seeker/presentation/utils/seeker_document_storage.dart';
import 'package:map/features/job_seeker/presentation/widgets/seeker_document_image.dart';

/// 카테고리 표시 순서 — 식품·건설 보건 항목을 상단에
const _credentialCategoryOrder = <CredentialCategory>[
  CredentialCategory.foodService,
  CredentialCategory.constructionManufacturing,
  CredentialCategory.logisticsDriving,
  CredentialCategory.facilitySecurity,
  CredentialCategory.cleaningCare,
];
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

  Future<void> _addCustomCredential() async {
    final profile = _profile;
    if (profile == null) return;

    final nameController = TextEditingController();
    final label = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('그 외 자격증 추가'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '자격증·면허 이름',
            hintText: '예: 위험물운송기능사, 바리스타',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.length < 2) return;
              Navigator.pop(ctx, name);
            },
            child: const Text('다음'),
          ),
        ],
      ),
    );
    nameController.dispose();
    if (label == null || !mounted) return;

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

    final id = CustomCredentialSupport.newId();
    final storedPath = await persistSeekerDocumentImage(file, id);
    if (storedPath == null || !mounted) return;

    await _saveProfile(
      profile.upsertCredentialHolding(
        SeekerCredentialHolding(
          credentialId: id,
          customLabel: label,
          imagePath: storedPath,
          updatedAt: DateTime.now(),
        ),
      ),
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('「$label」 사진이 등록되었습니다.')),
    );
  }

  Future<void> _removeCustomCredential(String credentialId) async {
    final profile = _profile;
    if (profile == null) return;
    await _saveProfile(profile.removeCredentialHolding(credentialId));
  }

  Future<void> _replaceCustomCredentialPhoto(SeekerCredentialHolding holding) async {
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
      holding.credentialId,
    );
    if (storedPath == null || !mounted) return;

    await _saveProfile(
      profile.upsertCredentialHolding(
        holding.copyWith(
          imagePath: storedPath,
          updatedAt: DateTime.now(),
        ),
      ),
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '「${CustomCredentialSupport.displayLabel(holding)}」 사진이 변경되었습니다.',
        ),
      ),
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
    return ListenableBuilder(
      listenable: AuthSession.instance.seekerProfileRevision,
      builder: (context, _) {
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
                    _BoGeonQuickSection(
                      profile: profile,
                      onToggle: _toggleOwned,
                      onUpload: _uploadPhoto,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: '검색 (예: 보건증, 지게차, 경비)',
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
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(def.category.label),
                              CredentialGuideLink(definition: def, dense: true),
                            ],
                          ),
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
                    ..._credentialCategoryOrder.map(
                      (cat) => _CategorySection(
                        category: cat,
                        profile: profile,
                        onToggle: _toggleOwned,
                        onUpload: _uploadPhoto,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _CustomCredentialsSection(
                      profile: profile,
                      onAdd: _addCustomCredential,
                      onRemove: _removeCustomCredential,
                      onReplacePhoto: _replaceCustomCredentialPhoto,
                    ),
                  ],
                ),
        );
      },
    );
  }
}

/// 「보건」관련 — 식품 보건증 + 건설 안전보건교육 (항상 상단 고정)
class _BoGeonQuickSection extends StatelessWidget {
  const _BoGeonQuickSection({
    required this.profile,
    required this.onToggle,
    required this.onUpload,
  });

  final SeekerMemberProfile profile;
  final Future<void> Function(CredentialDefinition def, bool owned) onToggle;
  final Future<void> Function(CredentialDefinition def) onUpload;

  @override
  Widget build(BuildContext context) {
    final items = CredentialSearchService.pinnedBoGeon();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '보건 관련 (자주 찾는 항목)',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: AppColors.textSecondary.withValues(alpha: 0.95),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '식품·외식 = 보건증 · 건설 현장 = 기초안전보건교육 (다른 서류입니다)',
          style: TextStyle(
            fontSize: 11,
            height: 1.4,
            color: AppColors.textSecondary.withValues(alpha: 0.8),
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
            highlight: true,
          );
        }),
      ],
    );
  }
}

/// 표준 목록에 없는 자격증 — 이름 + 사진 직접 등록
class _CustomCredentialsSection extends StatelessWidget {
  const _CustomCredentialsSection({
    required this.profile,
    required this.onAdd,
    required this.onRemove,
    required this.onReplacePhoto,
  });

  final SeekerMemberProfile profile;
  final VoidCallback onAdd;
  final Future<void> Function(String credentialId) onRemove;
  final Future<void> Function(SeekerCredentialHolding holding) onReplacePhoto;

  @override
  Widget build(BuildContext context) {
    final items = profile.customCredentialHoldings;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '그 외 자격증 (항목에 없음)',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          '목록에 없는 면허·자격증은 이름을 적고 사진을 올려 주세요.',
          style: TextStyle(
            fontSize: 12,
            height: 1.45,
            color: AppColors.textSecondary.withValues(alpha: 0.9),
          ),
        ),
        const SizedBox(height: 10),
        ...items.map((holding) {
          final label = CustomCredentialSupport.displayLabel(holding);
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
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (holding.hasPhoto) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: seekerDocumentImage(holding.imagePath!, height: 120),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => onReplacePhoto(holding),
                        icon: const Icon(Icons.upload_rounded, size: 18),
                        label: Text(holding.hasPhoto ? '사진 변경' : '사진 업로드'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => onRemove(holding.credentialId),
                      icon: const Icon(Icons.delete_outline_rounded),
                      tooltip: '삭제',
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
        OutlinedButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add_rounded),
          label: const Text('그 외 자격증 사진 추가'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ],
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
    final items = CredentialCatalog.forCategory(category)
        .where((d) => !CredentialSearchService.boGeonPinnedIds.contains(d.id))
        .toList();
    if (items.isEmpty) return const SizedBox.shrink();
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
    this.highlight = false,
  });

  final CredentialDefinition definition;
  final bool owned;
  final String? imagePath;
  final ValueChanged<bool> onToggle;
  final VoidCallback onUpload;
  final VoidCallback onRemove;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final needsPhoto = definition.requiresPhoto;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: highlight
            ? AppColors.primaryLight.withValues(alpha: 0.12)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: highlight ? AppColors.primary.withValues(alpha: 0.35) : AppColors.searchBarBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (highlight)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                definition.category.label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary.withValues(alpha: 0.9),
                ),
              ),
            ),
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
                    CredentialGuideLink(definition: definition, dense: true),
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
