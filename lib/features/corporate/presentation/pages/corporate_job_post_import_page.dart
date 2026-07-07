import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/widgets/app_back_button.dart';
import 'package:map/features/corporate/domain/entities/external_job_post_import_result.dart';
import 'package:map/features/corporate/domain/entities/external_job_post_platform.dart';
import 'package:map/features/corporate/domain/entities/job_post_write_draft.dart';
import 'package:map/features/corporate/domain/services/external_job_post_import_service.dart';
import 'package:map/features/corporate/presentation/navigation/corporate_job_post_flow_result.dart';
import 'package:map/features/corporate/presentation/widgets/create_job_post/wizard_widgets.dart';
import 'package:map/features/corporate/presentation/widgets/corporate_job_post_write_form_host.dart';
import 'package:map/features/corporate/presentation/widgets/job_post_import_labels.dart';

/// 외부 사이트 공고 가져오기 → 직접 작성 폼에 자동 채움
class CorporateJobPostImportPage extends StatefulWidget {
  const CorporateJobPostImportPage({super.key});

  @override
  State<CorporateJobPostImportPage> createState() =>
      _CorporateJobPostImportPageState();
}

class _CorporateJobPostImportPageState extends State<CorporateJobPostImportPage>
    with SingleTickerProviderStateMixin {
  final _importService = ExternalJobPostImportService();
  final _formKey = GlobalKey<CorporateJobPostWriteFormHostState>();
  final _urlController = TextEditingController();
  final _textController = TextEditingController();

  late final TabController _tabController;
  ExternalJobPostPlatform _platform = ExternalJobPostPlatform.albamon;
  ExternalJobPostImportResult? _preview;
  JobPostWriteDraft? _draft;
  bool _loading = false;
  String? _error;
  String? _pickedImageName;

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

  Future<void> _applyImportToForm(ExternalJobPostImportResult result) async {
    final draft = _importService.buildDraftFromImport(result);
    setState(() {
      _preview = result;
      _draft = draft;
    });
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;
    await _formKey.currentState?.applyDraftAsync(draft);
  }

  Future<void> _runImport(Future<ExternalJobPostImportResult> future) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await future;
      if (!mounted) return;
      await _applyImportToForm(result);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _importFromUrl() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      setState(() => _error = '공고 링크를 붙여넣어 주세요.');
      return;
    }
    final detected = ExternalJobPostPlatform.detectFromUrl(url);
    setState(() => _platform = detected);
    await _runImport(_importService.importFromUrl(url));
  }

  Future<void> _importFromText() async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      setState(() => _error = '공고 내용을 붙여넣어 주세요.');
      return;
    }
    await _runImport(
      _importService.importFromText(text: text, platform: _platform),
    );
  }

  Future<void> _pickScreenshot() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2000,
      imageQuality: 85,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() => _pickedImageName = file.name);
    await _runImport(
      _importService.importFromScreenshot(
        imageBytes: bytes,
        fileName: file.name,
        platform: _platform,
      ),
    );
  }

  void _onFlowComplete(CorporateJobPostFlowResult result) {
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
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AiSparkleMark(size: 16, badge: true),
            const SizedBox(width: 8),
            const Text(
              JobPostImportCopy.pageTitle,
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          const WizardInfoBanner(
            message:
                '알바몬·알바천국·인크루트·동네알바·당근알바 등에 올린 공고를\n'
                '링크·캡처·텍스트로 가져오면 아래 작성 폼에 자동으로 채워집니다.\n\n'
                '항목을 확인·수정한 뒤 등록해 주세요.',
            icon: Icons.auto_awesome_outlined,
          ),
          const SizedBox(height: 12),
          _buildPlatformChips(),
          const SizedBox(height: 12),
          TabBar(
            controller: _tabController,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            tabs: const [
              Tab(text: '링크'),
              Tab(text: '캡처'),
              Tab(text: '텍스트'),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 220,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildUrlTab(),
                _buildCaptureTab(),
                _buildTextTab(),
              ],
            ),
          ),
          if (_loading) ...[
            const SizedBox(height: 16),
            const Center(child: CircularProgressIndicator()),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: const TextStyle(color: Color(0xFFC62828), fontSize: 13),
            ),
          ],
          if (_preview != null) ...[
            const SizedBox(height: 12),
            _buildImportNotes(_preview!),
          ],
          if (_draft != null) ...[
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 8),
            const Text(
              '가져온 공고 확인·수정',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            CorporateJobPostWriteFormHost(
              key: _formKey,
              initialDraft: _draft!,
              onFlowComplete: _onFlowComplete,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPlatformChips() {
    final platforms = [
      ExternalJobPostPlatform.albamon,
      ExternalJobPostPlatform.albacheon,
      ExternalJobPostPlatform.incruit,
      ExternalJobPostPlatform.dongnealba,
      ExternalJobPostPlatform.karrot,
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: platforms.map((p) {
        final selected = _platform == p;
        return FilterChip(
          label: Text(p.label),
          selected: selected,
          onSelected: (_) => setState(() => _platform = p),
          selectedColor: AppColors.primaryLight.withValues(alpha: 0.25),
          checkmarkColor: AppColors.primary,
        );
      }).toList(),
    );
  }

  Widget _buildUrlTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _urlController,
          decoration: const InputDecoration(
            hintText: 'https://www.albamon.com/...',
            labelText: '다른 사이트 공고 링크',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.url,
          maxLines: 2,
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: _loading ? null : _importFromUrl,
          icon: const Icon(Icons.link_rounded),
          label: const Text('링크 불러오기'),
        ),
      ],
    );
  }

  Widget _buildCaptureTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '공고 화면을 캡처한 이미지를 선택하세요.\n'
          '인식이 어려우면 「텍스트」 탭에 복사·붙여넣기를 이용해 주세요.',
          style: TextStyle(fontSize: 12, height: 1.4),
        ),
        const SizedBox(height: 10),
        if (_pickedImageName != null)
          Text(
            '선택: $_pickedImageName',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary.withValues(alpha: 0.95),
            ),
          ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _loading ? null : _pickScreenshot,
          icon: const Icon(Icons.photo_library_outlined),
          label: const Text('캡처 이미지 선택'),
        ),
      ],
    );
  }

  Widget _buildTextTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: TextField(
            controller: _textController,
            decoration: const InputDecoration(
              hintText: '다른 사이트 공고 제목·급여·시간·주소·업무 내용을 붙여넣기',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            maxLines: 6,
          ),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _loading ? null : _importFromText,
          icon: const Icon(Icons.content_paste_go_rounded),
          label: const Text('텍스트 분석'),
        ),
      ],
    );
  }

  Widget _buildImportNotes(ExternalJobPostImportResult result) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final w in result.warnings)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '· $w',
              style: TextStyle(
                fontSize: 12,
                height: 1.35,
                color: AppColors.textSecondary.withValues(alpha: 0.95),
              ),
            ),
          ),
      ],
    );
  }
}
