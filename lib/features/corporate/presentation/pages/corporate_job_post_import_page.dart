import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:map/core/config/product_feature_flags.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/constants/app_routes.dart';
import 'package:map/core/widgets/app_back_button.dart';
import 'package:map/features/corporate/domain/entities/external_job_post_import_result.dart';
import 'package:map/features/corporate/domain/entities/external_job_post_platform.dart';
import 'package:map/features/corporate/domain/entities/job_post_write_draft.dart';
import 'package:map/features/corporate/domain/services/external_job_post_import_service.dart';
import 'package:map/features/corporate/domain/services/job_post_import_demo_samples.dart';
import 'package:map/features/corporate/presentation/widgets/create_job_post/wizard_widgets.dart';
import 'package:map/features/corporate/presentation/widgets/corporate_surface_card.dart';
import 'package:map/features/corporate/presentation/widgets/job_post_import_labels.dart';

/// 외부 사이트 공고 가져오기 → 자동 초안 등록
class CorporateJobPostImportPage extends StatefulWidget {
  const CorporateJobPostImportPage({super.key});

  @override
  State<CorporateJobPostImportPage> createState() =>
      _CorporateJobPostImportPageState();
}

class _CorporateJobPostImportPageState extends State<CorporateJobPostImportPage>
    with SingleTickerProviderStateMixin {
  final _importService = ExternalJobPostImportService();
  final _urlController = TextEditingController();
  final _textController = TextEditingController();

  late final TabController _tabController;
  ExternalJobPostPlatform _platform = ExternalJobPostPlatform.albamon;
  ExternalJobPostImportResult? _preview;
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

  Future<void> _runImport(Future<ExternalJobPostImportResult> future) async {
    setState(() {
      _loading = true;
      _error = null;
      _preview = null;
    });
    try {
      final result = await future;
      if (!mounted) return;
      setState(() => _preview = result);
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

  void _fillDemoUrl() {
    _urlController.text = JobPostImportDemoSamples.demoUrl;
    setState(() {
      _platform = ExternalJobPostPlatform.albamon;
      _error = null;
    });
    _tabController.animateTo(0);
  }

  void _fillDemoText({bool runAnalysis = false}) {
    _textController.text = JobPostImportDemoSamples.albamonText.trim();
    setState(() {
      _platform = ExternalJobPostPlatform.albamon;
      _error = null;
    });
    _tabController.animateTo(2);
    if (runAnalysis) {
      _importFromText();
    }
  }

  Future<void> _openWriteWithAi() async {
    final preview = _preview;
    if (preview == null || !preview.hasUsableTitle) {
      setState(() => _error = '먼저 공고를 가져오거나 제목을 확인해 주세요.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final draft = await _importService.buildDraftWithAiSummary(
        imported: preview,
        workerCategory: ProductFeatureFlags.defaultWorkerCategory,
        paymentDate: DateTime.now().add(const Duration(days: 7)),
      );
      if (!mounted) return;
      final created = await Navigator.of(context).pushNamed<bool>(
        AppRoutes.corporateJobPostWrite,
        arguments: draft,
      );
      if (created == true && mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              children: [
                const WizardInfoBanner(
                  message:
                      '알바몬·알바천국·인크루트·동네알바·당근알바 등에 올린 공고를\n'
                      '링크·캡처·텍스트로 가져오면 자동으로 일자리 공고 초안을 만들어 드립니다.\n\n'
                      '등록은 무료 — 가입 후 버튼 한 번이면 끝!',
                  icon: Icons.auto_awesome_outlined,
                ),
                const SizedBox(height: 12),
                _buildMvpDemoBanner(),
                const SizedBox(height: 16),
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
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: const TextStyle(color: Color(0xFFC62828), fontSize: 13),
                  ),
                ],
                if (_preview != null) ...[
                  const SizedBox(height: 16),
                  _buildPreview(_preview!),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton.icon(
                  onPressed: _loading || _preview == null
                      ? null
                      : _openWriteWithAi,
                  icon: _loading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.auto_awesome_rounded, size: 20),
                  label: Text(
                    _loading ? '초안 작성 중…' : JobPostImportCopy.registerFromImport,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryLight,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.of(context).pushNamed(
                    AppRoutes.corporateJobPostWrite,
                    arguments: JobPostWriteDraft(
                      workerCategory: ProductFeatureFlags.defaultWorkerCategory,
                    ),
                  ),
                  child: const Text('직접 입력으로 등록'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMvpDemoBanner() {
    return CorporateSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.play_circle_outline,
                size: 20,
                color: AppColors.primary.withValues(alpha: 0.9),
              ),
              const SizedBox(width: 8),
              const Text(
                'MVP 데모 안내',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            JobPostImportDemoSamples.mvpHintSteps.trim(),
            style: TextStyle(
              fontSize: 12,
              height: 1.45,
              color: AppColors.textSecondary.withValues(alpha: 0.95),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _loading ? null : () => _fillDemoText(runAnalysis: true),
                icon: const Icon(Icons.content_paste, size: 18),
                label: const Text('데모 채우기 (텍스트)'),
              ),
              OutlinedButton.icon(
                onPressed: _loading ? null : _fillDemoUrl,
                icon: const Icon(Icons.link, size: 18),
                label: const Text('데모 URL'),
              ),
            ],
          ),
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
        const SizedBox(height: 6),
        Text(
          '서버 없이도 알바몬 URL은 샘플 공고로 미리보기됩니다.',
          style: TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary.withValues(alpha: 0.9),
          ),
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
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _loading ? null : _importFromText,
                icon: const Icon(Icons.content_paste_go_rounded),
                label: const Text('텍스트 분석'),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: _loading ? null : () => _fillDemoText(),
              child: const Text('데모'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPreview(ExternalJobPostImportResult result) {
    return CorporateSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.check_circle_outline,
                color: AppColors.primary.withValues(alpha: 0.9),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                '${result.platform.label} · 인식 ${(result.confidence * 100).round()}%',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _previewRow('제목', result.title),
          _previewRow('근무지', result.workplaceAddress ?? '(확인 필요)'),
          _previewRow('급여', result.hourlyWage ?? '(확인 필요)'),
          _previewRow('일정', result.workSchedule.isEmpty ? '(확인 필요)' : result.workSchedule),
          if (result.jobDescription.isNotEmpty)
            _previewRow('업무', result.jobDescription.split('\n').first),
          for (final w in result.warnings)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '· $w',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary.withValues(alpha: 0.95),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _previewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: RichText(
        text: TextSpan(
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textPrimary.withValues(alpha: 0.95),
            height: 1.35,
          ),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}
