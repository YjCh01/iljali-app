import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/core/widgets/app_back_button.dart';
import 'package:map/features/job_seeker/domain/entities/seeker_resume_import_result.dart';
import 'package:map/features/job_seeker/domain/services/seeker_resume_import_service.dart';

/// 알바몬·잡코리아 등 외부 이력서 AI 불러오기
class SeekerResumeImportPage extends StatefulWidget {
  const SeekerResumeImportPage({super.key});

  @override
  State<SeekerResumeImportPage> createState() => _SeekerResumeImportPageState();
}

class _SeekerResumeImportPageState extends State<SeekerResumeImportPage>
    with SingleTickerProviderStateMixin {
  final _service = SeekerResumeImportService();
  final _urlController = TextEditingController();
  final _textController = TextEditingController();

  late final TabController _tabController;
  SeekerResumeImportResult? _preview;
  bool _loading = false;
  String? _error;
  String? _pickedFileName;
  SeekerResumeImportPlatform _platform = SeekerResumeImportPlatform.albamon;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _urlController.dispose();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _runImport(Future<SeekerResumeImportResult> future) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await future;
      if (!mounted) return;
      setState(() => _preview = result);
      if (!result.hasStructuredContent && result.message.isNotEmpty) {
        setState(() => _error = result.message);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('StateError: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _importFromUrl() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      setState(() => _error = '이력서 링크를 붙여넣어 주세요.');
      return;
    }
    setState(() => _platform = SeekerResumeImportPlatform.detectFromUrl(url));
    await _runImport(_service.importFromUrl(url));
  }

  Future<void> _importFromText() async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      setState(() => _error = '이력서 내용을 붙여넣어 주세요.');
      return;
    }
    await _runImport(
      _service.importFromText(text: text, platform: _platform),
    );
  }

  Future<void> _pickFile() async {
    final picked = await _service.pickResumeFile();
    if (picked == null) return;
    setState(() => _pickedFileName = picked.name);
    await _runImport(
      _service.importFromFile(
        bytes: picked.bytes,
        fileName: picked.name,
        platform: _platform,
      ),
    );
  }

  Future<void> _pickScreenshot() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2200,
      imageQuality: 88,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() => _pickedFileName = file.name);
    await _runImport(
      _service.importFromFile(
        bytes: bytes,
        fileName: file.name,
        platform: _platform,
      ),
    );
  }

  Future<void> _applyToResume() async {
    final preview = _preview;
    if (preview == null || !preview.hasStructuredContent) {
      setState(() => _error = '먼저 이력서를 불러온 뒤 적용해 주세요.');
      return;
    }
    final user = AuthSession.instance.currentUser;
    final profile = user?.seekerProfile;
    if (profile == null) {
      setState(() => _error = '로그인 후 이용할 수 있습니다.');
      return;
    }

    final mergedResume = _service.mergeIntoExisting(
      existing: profile.resume,
      imported: preview.resume,
      replaceSelfIntroduction: preview.resume.selfIntroduction.trim().isNotEmpty,
    );
    await AuthSession.instance.updateSeekerProfile(
      profile.copyWith(resume: mergedResume),
    );
    if (!mounted) return;

    final hasLicenseOrCertification =
        preview.resume.licenses.isNotEmpty ||
            preview.resume.certifications.isNotEmpty;
    if (hasLicenseOrCertification) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('면허·자격증은 직접 확인해 주세요'),
          content: const Text(
            '불러온 면허·자격증 정보는 자동으로 등록되지 않습니다.\n'
            '자격증 메뉴에서 목록을 다시 확인하고, 특히 자료(사진) 업로드까지 '
            '직접 완료해 주세요.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('확인했어요'),
            ),
          ],
        ),
      );
    }
    if (!mounted) return;
    Navigator.of(context).pop(true);
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
        title: const Text('내 이력서 AI로 불러오기'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          tabs: const [
            Tab(text: '링크'),
            Tab(text: '파일·캡처'),
            Tab(text: '붙여넣기'),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildUrlTab(),
                _buildFileTab(),
                _buildTextTab(),
              ],
            ),
          ),
          if (_preview != null) _buildPreview(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: FilledButton(
                onPressed: _loading || _preview == null ? null : _applyToResume,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size.fromHeight(48),
                ),
                child: Text(
                  _loading ? '분석 중…' : '이력서에 적용',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlatformPicker() {
    return DropdownButtonFormField<SeekerResumeImportPlatform>(
      initialValue: _platform,
      decoration: const InputDecoration(
        labelText: '출처 사이트 (선택)',
        border: OutlineInputBorder(),
      ),
      items: SeekerResumeImportPlatform.values
          .map(
            (platform) => DropdownMenuItem(
              value: platform,
              child: Text(platform.label),
            ),
          )
          .toList(),
      onChanged: _loading
          ? null
          : (value) {
              if (value != null) setState(() => _platform = value);
            },
    );
  }

  Widget _buildUrlTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          '알바몬·잡코리아 등에 등록한 이력서 링크를 붙여넣어 주세요.\n'
          '로그인이 필요한 페이지는 캡처·PDF 탭을 이용해 주세요.',
          style: TextStyle(fontSize: 13, height: 1.45),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _urlController,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: '이력서 URL',
            hintText: 'https://www.albamon.com/...',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        _buildPlatformPicker(),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _loading ? null : _importFromUrl,
          child: const Text('링크에서 불러오기'),
        ),
      ],
    );
  }

  Widget _buildFileTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          '이력서 PDF, 화면 캡처(PNG/JPG)를 올리면 AI가 학력·경력 등을 추출합니다.',
          style: TextStyle(fontSize: 13, height: 1.45),
        ),
        const SizedBox(height: 16),
        _buildPlatformPicker(),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _loading ? null : _pickFile,
          icon: const Icon(Icons.upload_file_outlined),
          label: const Text('PDF·이미지 파일 선택'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _loading ? null : _pickScreenshot,
          icon: const Icon(Icons.photo_library_outlined),
          label: const Text('갤러리 캡처 선택'),
        ),
        if (_pickedFileName != null) ...[
          const SizedBox(height: 12),
          Text(
            '선택: $_pickedFileName',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ],
    );
  }

  Widget _buildTextTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          '사이트에서 이력서 전체를 복사해 붙여넣어도 됩니다.',
          style: TextStyle(fontSize: 13, height: 1.45),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _textController,
          maxLines: 14,
          decoration: const InputDecoration(
            labelText: '이력서 내용',
            hintText: '학력\n...\n경력\n...',
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 12),
        _buildPlatformPicker(),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _loading ? null : _importFromText,
          child: const Text('텍스트 분석'),
        ),
      ],
    );
  }

  Widget _buildPreview() {
    final preview = _preview!;
    final resume = preview.resume;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '추출 미리보기 · 신뢰도 ${(preview.confidence * 100).round()}%',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 6),
          Text('학력 ${resume.educations.length} · 경력 ${resume.experiences.length} · '
              '면허 ${resume.licenses.length} · 자격증 ${resume.certifications.length}'),
          if (resume.selfIntroduction.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                resume.selfIntroduction.trim(),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, height: 1.35),
              ),
            ),
          if (preview.message.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                preview.message,
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary.withValues(alpha: 0.9),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
