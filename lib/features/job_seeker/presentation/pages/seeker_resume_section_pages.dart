import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/constants/app_routes.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/core/widgets/app_back_button.dart';
import 'package:map/features/job_seeker/domain/entities/resume_item_kind.dart';
import 'package:map/features/job_seeker/domain/entities/seeker_resume_content.dart';
import 'package:map/features/job_seeker/domain/utils/seeker_profile_credentials.dart';
import 'package:map/features/job_seeker/presentation/widgets/resume_form_widgets.dart';

/// 이력서 작성 허브 — 5개 섹션 목록
class SeekerResumeEditHubPage extends StatefulWidget {
  const SeekerResumeEditHubPage({super.key});

  @override
  State<SeekerResumeEditHubPage> createState() => _SeekerResumeEditHubPageState();
}

class _SeekerResumeEditHubPageState extends State<SeekerResumeEditHubPage> {
  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final profile = AuthSession.instance.currentUser?.seekerProfile;
    final resume = profile?.resume ?? const SeekerResumeContent();

    return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.surface,
            foregroundColor: AppColors.textPrimary,
            elevation: 0,
            leading: const AppBackButton(),
            automaticallyImplyLeading: false,
            title: const Text('이력서 작성'),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
            children: [
              const Text(
                '학력·경력 등을 입력해 주세요',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  final applied = await Navigator.of(context).pushNamed<bool>(
                    AppRoutes.seekerResumeImport,
                  );
                  if (applied == true) _refresh();
                },
                icon: const Icon(Icons.auto_awesome_outlined, size: 18),
                label: const Text('내 이력서 AI로 불러오기'),
                style: OutlinedButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '알바몬·잡코리아 링크, PDF, 캡처로 학력·경력을 채울 수 있어요.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: AppColors.textSecondary.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(height: 16),
              ...ResumeItemKind.values.map(
                (kind) => _SectionTile(
                  kind: kind,
                  count: profile?.countForResumeKind(kind) ??
                      resume.countFor(kind),
                  onTap: () => _openSection(context, kind),
                ),
              ),
            ],
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  '완료',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
        );
  }

  Future<void> _openSection(BuildContext context, ResumeItemKind kind) async {
    if (kind == ResumeItemKind.license ||
        kind == ResumeItemKind.certification) {
      await Navigator.of(context).pushNamed(AppRoutes.seekerMyCredentials);
      _refresh();
      return;
    }
    if (kind == ResumeItemKind.selfIntroduction) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => const SeekerSelfIntroductionPage(),
        ),
      );
      _refresh();
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => SeekerResumeSectionListPage(
          kind: kind,
          onChanged: _refresh,
        ),
      ),
    );
    _refresh();
  }
}

class _SectionTile extends StatelessWidget {
  const _SectionTile({
    required this.kind,
    required this.count,
    required this.onTap,
  });

  final ResumeItemKind kind;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.searchBarBorder),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    kind.label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (count > 0)
                  Text(
                    '$count개',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary.withValues(alpha: 0.95),
                    ),
                  ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textSecondary.withValues(alpha: 0.6),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 섹션별 항목 목록 (학력·경력·면허·자격증)
class SeekerResumeSectionListPage extends StatefulWidget {
  const SeekerResumeSectionListPage({
    super.key,
    required this.kind,
    this.onChanged,
  });

  final ResumeItemKind kind;
  final VoidCallback? onChanged;

  @override
  State<SeekerResumeSectionListPage> createState() =>
      _SeekerResumeSectionListPageState();
}

class _SeekerResumeSectionListPageState extends State<SeekerResumeSectionListPage> {
  void _refresh() {
    setState(() {});
    widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final profile = AuthSession.instance.currentUser?.seekerProfile;
    final resume = profile?.resume ?? const SeekerResumeContent();
    final lines = _linesFor(resume);

    return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.surface,
            foregroundColor: AppColors.textPrimary,
            elevation: 0,
            leading: const AppBackButton(),
            automaticallyImplyLeading: false,
            title: Text(widget.kind.label),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
            children: [
              if (lines.isEmpty)
                Text(
                  '등록된 ${widget.kind.label}이(가) 없습니다.',
                  style: TextStyle(
                    color: AppColors.textSecondary.withValues(alpha: 0.9),
                  ),
                )
              else
                ...lines.map(
                  (line) => _EntryTile(
                    title: line.title,
                    subtitle: line.subtitle,
                    onTap: () => _openForm(context, entryId: line.id),
                  ),
                ),
            ],
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: OutlinedButton.icon(
                onPressed: () => _openForm(context),
                icon: const Icon(Icons.add_rounded),
                label: Text('${widget.kind.label} 추가'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
        );
  }

  List<_EntryLine> _linesFor(SeekerResumeContent resume) {
    return switch (widget.kind) {
      ResumeItemKind.education => resume.educations
          .map(
            (e) => _EntryLine(
              id: e.id,
              title: '${e.level} ${e.graduationStatus}',
              subtitle: e.schoolName ?? '',
            ),
          )
          .toList(),
      ResumeItemKind.experience => resume.experiences
          .map(
            (e) => _EntryLine(
              id: e.id,
              title: e.summaryLine,
              subtitle: e.periodLabel ?? e.employmentType,
            ),
          )
          .toList(),
      ResumeItemKind.license => resume.licenses
          .map(
            (e) => _EntryLine(
              id: e.id,
              title: e.name,
              subtitle: e.issuer ?? '',
            ),
          )
          .toList(),
      ResumeItemKind.certification => resume.certifications
          .map(
            (e) => _EntryLine(
              id: e.id,
              title: e.name,
              subtitle: e.issuer ?? '',
            ),
          )
          .toList(),
      ResumeItemKind.selfIntroduction => const [],
    };
  }

  Future<void> _openForm(BuildContext context, {String? entryId}) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => SeekerResumeItemFormPage(
          kind: widget.kind,
          entryId: entryId,
          onSaved: _refresh,
        ),
      ),
    );
    _refresh();
  }
}

class _EntryLine {
  const _EntryLine({
    required this.id,
    required this.title,
    required this.subtitle,
  });

  final String id;
  final String title;
  final String subtitle;
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.searchBarBorder),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textSecondary.withValues(alpha: 0.6),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 항목 추가·수정 폼
class SeekerResumeItemFormPage extends StatefulWidget {
  const SeekerResumeItemFormPage({
    super.key,
    required this.kind,
    this.entryId,
    this.onSaved,
  });

  final ResumeItemKind kind;
  final String? entryId;
  final VoidCallback? onSaved;

  @override
  State<SeekerResumeItemFormPage> createState() =>
      _SeekerResumeItemFormPageState();
}

class _SeekerResumeItemFormPageState extends State<SeekerResumeItemFormPage> {
  late String _level;
  late String _graduationStatus;
  late String _employmentType;
  final _schoolController = TextEditingController();
  final _majorController = TextEditingController();
  final _companyController = TextEditingController();
  final _jobRoleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _nameController = TextEditingController();
  final _issuerController = TextEditingController();
  final _acquiredController = TextEditingController();
  int? _startYear;
  int? _endYear;
  int? _startMonth;
  int? _endMonth;
  bool _saving = false;

  bool get _isEdit => widget.entryId != null;

  @override
  void initState() {
    super.initState();
    _level = SeekerResumeOptions.educationLevels.first;
    _graduationStatus = SeekerResumeOptions.graduationStatuses.first;
    _employmentType = SeekerResumeOptions.employmentTypes.first;
    _loadExisting();
  }

  void _loadExisting() {
    final id = widget.entryId;
    if (id == null) return;
    final resume =
        AuthSession.instance.currentUser?.seekerProfile?.resume ??
            const SeekerResumeContent();

    switch (widget.kind) {
      case ResumeItemKind.education:
        final entry = resume.educations.where((e) => e.id == id).firstOrNull;
        if (entry == null) return;
        _level = entry.level;
        _graduationStatus = entry.graduationStatus;
        _schoolController.text = entry.schoolName ?? '';
        _majorController.text = entry.major ?? '';
        _startYear = entry.startYear;
        _endYear = entry.endYear;
      case ResumeItemKind.experience:
        final entry = resume.experiences.where((e) => e.id == id).firstOrNull;
        if (entry == null) return;
        _employmentType = entry.employmentType;
        _companyController.text = entry.companyName;
        _jobRoleController.text = entry.jobRole;
        _descriptionController.text = entry.description ?? '';
        _startYear = entry.startYear;
        _endYear = entry.endYear;
        _startMonth = entry.startMonth;
        _endMonth = entry.endMonth;
      case ResumeItemKind.license:
        final entry = resume.licenses.where((e) => e.id == id).firstOrNull;
        if (entry == null) return;
        _nameController.text = entry.name;
        _issuerController.text = entry.issuer ?? '';
        _acquiredController.text = entry.acquiredLabel ?? '';
      case ResumeItemKind.certification:
        final entry =
            resume.certifications.where((e) => e.id == id).firstOrNull;
        if (entry == null) return;
        _nameController.text = entry.name;
        _issuerController.text = entry.issuer ?? '';
        _acquiredController.text = entry.acquiredLabel ?? '';
      case ResumeItemKind.selfIntroduction:
        break;
    }
  }

  @override
  void dispose() {
    _schoolController.dispose();
    _majorController.dispose();
    _companyController.dispose();
    _jobRoleController.dispose();
    _descriptionController.dispose();
    _nameController.dispose();
    _issuerController.dispose();
    _acquiredController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final profile = AuthSession.instance.currentUser?.seekerProfile;
    if (profile == null) return;

    if (!_validate()) return;

    setState(() => _saving = true);
    final resume = _buildUpdatedResume(profile.resume);
    await AuthSession.instance.updateSeekerProfile(
      profile.copyWith(resume: resume),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    widget.onSaved?.call();
    Navigator.of(context).pop();
  }

  bool _validate() {
    switch (widget.kind) {
      case ResumeItemKind.education:
        return true;
      case ResumeItemKind.experience:
        if (_companyController.text.trim().isEmpty ||
            _jobRoleController.text.trim().isEmpty) {
          _showError('업체명과 업무를 입력해 주세요.');
          return false;
        }
        return true;
      case ResumeItemKind.license:
      case ResumeItemKind.certification:
        if (_nameController.text.trim().isEmpty) {
          _showError('이름을 입력해 주세요.');
          return false;
        }
        return true;
      case ResumeItemKind.selfIntroduction:
        return true;
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  SeekerResumeContent _buildUpdatedResume(SeekerResumeContent resume) {
    final id = widget.entryId ?? 'item_${DateTime.now().millisecondsSinceEpoch}';
    return switch (widget.kind) {
      ResumeItemKind.education => _saveEducation(resume, id),
      ResumeItemKind.experience => _saveExperience(resume, id),
      ResumeItemKind.license => _saveLicense(resume, id),
      ResumeItemKind.certification => _saveCertification(resume, id),
      ResumeItemKind.selfIntroduction => resume,
    };
  }

  SeekerResumeContent _saveEducation(SeekerResumeContent resume, String id) {
    final entry = SeekerEducationEntry(
      id: id,
      level: _level,
      graduationStatus: _graduationStatus,
      schoolName: _schoolController.text.trim().isEmpty
          ? null
          : _schoolController.text.trim(),
      major: _majorController.text.trim().isEmpty
          ? null
          : _majorController.text.trim(),
      startYear: _startYear,
      endYear: _endYear,
    );
    final list = List<SeekerEducationEntry>.from(resume.educations);
    final index = list.indexWhere((e) => e.id == id);
    if (index >= 0) {
      list[index] = entry;
    } else {
      list.add(entry);
    }
    return resume.copyWith(educations: list);
  }

  SeekerResumeContent _saveExperience(SeekerResumeContent resume, String id) {
    final entry = SeekerExperienceEntry(
      id: id,
      employmentType: _employmentType,
      companyName: _companyController.text.trim(),
      jobRole: _jobRoleController.text.trim(),
      startYear: _startYear,
      endYear: _endYear,
      startMonth: _startMonth,
      endMonth: _endMonth,
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
    );
    final list = List<SeekerExperienceEntry>.from(resume.experiences);
    final index = list.indexWhere((e) => e.id == id);
    if (index >= 0) {
      list[index] = entry;
    } else {
      list.add(entry);
    }
    return resume.copyWith(experiences: list);
  }

  SeekerResumeContent _saveLicense(SeekerResumeContent resume, String id) {
    final entry = SeekerLicenseEntry(
      id: id,
      name: _nameController.text.trim(),
      issuer: _issuerController.text.trim().isEmpty
          ? null
          : _issuerController.text.trim(),
      acquiredLabel: _acquiredController.text.trim().isEmpty
          ? null
          : _acquiredController.text.trim(),
    );
    final list = List<SeekerLicenseEntry>.from(resume.licenses);
    final index = list.indexWhere((e) => e.id == id);
    if (index >= 0) {
      list[index] = entry;
    } else {
      list.add(entry);
    }
    return resume.copyWith(licenses: list);
  }

  SeekerResumeContent _saveCertification(
    SeekerResumeContent resume,
    String id,
  ) {
    final entry = SeekerCertificationEntry(
      id: id,
      name: _nameController.text.trim(),
      issuer: _issuerController.text.trim().isEmpty
          ? null
          : _issuerController.text.trim(),
      acquiredLabel: _acquiredController.text.trim().isEmpty
          ? null
          : _acquiredController.text.trim(),
    );
    final list = List<SeekerCertificationEntry>.from(resume.certifications);
    final index = list.indexWhere((e) => e.id == id);
    if (index >= 0) {
      list[index] = entry;
    } else {
      list.add(entry);
    }
    return resume.copyWith(certifications: list);
  }

  Future<void> _delete() async {
    final profile = AuthSession.instance.currentUser?.seekerProfile;
    final id = widget.entryId;
    if (profile == null || id == null) return;

    final resume = switch (widget.kind) {
      ResumeItemKind.education => profile.resume.copyWith(
          educations:
              profile.resume.educations.where((e) => e.id != id).toList(),
        ),
      ResumeItemKind.experience => profile.resume.copyWith(
          experiences:
              profile.resume.experiences.where((e) => e.id != id).toList(),
        ),
      ResumeItemKind.license => profile.resume.copyWith(
          licenses: profile.resume.licenses.where((e) => e.id != id).toList(),
        ),
      ResumeItemKind.certification => profile.resume.copyWith(
          certifications:
              profile.resume.certifications.where((e) => e.id != id).toList(),
        ),
      ResumeItemKind.selfIntroduction => profile.resume,
    };

    await AuthSession.instance.updateSeekerProfile(
      profile.copyWith(resume: resume),
    );
    if (!mounted) return;
    Navigator.of(context).pop();
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
        title: Text(_isEdit ? '${widget.kind.label} 수정' : '${widget.kind.label} 추가'),
        actions: [
          if (_isEdit)
            IconButton(
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        children: [
          Text(
            '${widget.kind.label}을 입력해 주세요',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 20),
          ..._buildFields(),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    '저장',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildFields() {
    return switch (widget.kind) {
      ResumeItemKind.education => [
          const ResumeFieldLabel('학력', required: true),
          ResumeDropdownField<String>(
            value: _level,
            items: SeekerResumeOptions.educationLevels,
            onChanged: (v) => setState(() => _level = v ?? _level),
          ),
          const SizedBox(height: 16),
          const ResumeFieldLabel('졸업 여부', required: true),
          ResumeDropdownField<String>(
            value: _graduationStatus,
            items: SeekerResumeOptions.graduationStatuses,
            onChanged: (v) =>
                setState(() => _graduationStatus = v ?? _graduationStatus),
          ),
          const SizedBox(height: 16),
          const ResumeFieldLabel('학교'),
          ResumeTextField(
            controller: _schoolController,
            hint: '학교명을 입력하세요',
          ),
          const SizedBox(height: 16),
          const ResumeFieldLabel('학과(전공)'),
          ResumeTextField(
            controller: _majorController,
            hint: '학과를 입력하세요',
          ),
          const SizedBox(height: 16),
          const ResumeFieldLabel('재학 기간'),
          ResumeYearRangeField(
            startYear: _startYear,
            endYear: _endYear,
            startHint: '입학',
            endHint: '종료',
            onStartChanged: (v) => setState(() => _startYear = v),
            onEndChanged: (v) => setState(() => _endYear = v),
          ),
        ],
      ResumeItemKind.experience => [
          const ResumeFieldLabel('근무 형태', required: true),
          ResumeDropdownField<String>(
            value: _employmentType,
            items: SeekerResumeOptions.employmentTypes,
            onChanged: (v) =>
                setState(() => _employmentType = v ?? _employmentType),
          ),
          const SizedBox(height: 16),
          const ResumeFieldLabel('업체명', required: true),
          ResumeTextField(
            controller: _companyController,
            hint: '업체명을 입력하세요',
          ),
          const SizedBox(height: 16),
          const ResumeFieldLabel('업무', required: true),
          ResumeTextField(
            controller: _jobRoleController,
            hint: '업무를 입력하세요',
          ),
          const SizedBox(height: 16),
          const ResumeFieldLabel('근무 기간'),
          ResumeYearMonthRangeField(
            startYear: _startYear,
            startMonth: _startMonth,
            endYear: _endYear,
            endMonth: _endMonth,
            onStartYearChanged: (v) => setState(() => _startYear = v),
            onStartMonthChanged: (v) => setState(() => _startMonth = v),
            onEndYearChanged: (v) => setState(() => _endYear = v),
            onEndMonthChanged: (v) => setState(() => _endMonth = v),
          ),
          const SizedBox(height: 16),
          const ResumeFieldLabel('업무 설명'),
          ResumeTextField(
            controller: _descriptionController,
            hint: '자신만의 업무 경험을 알려주세요',
            maxLines: 5,
            maxLength: 300,
          ),
        ],
      ResumeItemKind.license || ResumeItemKind.certification => [
          ResumeFieldLabel(widget.kind.label, required: true),
          ResumeTextField(
            controller: _nameController,
            hint: '${widget.kind.label}명을 입력하세요',
          ),
          const SizedBox(height: 16),
          const ResumeFieldLabel('발급처'),
          ResumeTextField(
            controller: _issuerController,
            hint: '발급처를 입력하세요',
          ),
          const SizedBox(height: 16),
          const ResumeFieldLabel('취득일'),
          ResumeTextField(
            controller: _acquiredController,
            hint: '예: 2020.05',
          ),
        ],
      ResumeItemKind.selfIntroduction => const [],
    };
  }
}

/// 자기소개 단일 입력
class SeekerSelfIntroductionPage extends StatefulWidget {
  const SeekerSelfIntroductionPage({super.key});

  @override
  State<SeekerSelfIntroductionPage> createState() =>
      _SeekerSelfIntroductionPageState();
}

class _SeekerSelfIntroductionPageState extends State<SeekerSelfIntroductionPage> {
  late final TextEditingController _controller;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final text = AuthSession.instance.currentUser?.seekerProfile?.resume
            .selfIntroduction ??
        '';
    _controller = TextEditingController(text: text);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final profile = AuthSession.instance.currentUser?.seekerProfile;
    if (profile == null) return;
    setState(() => _saving = true);
    await AuthSession.instance.updateSeekerProfile(
      profile.copyWith(
        resume: profile.resume.copyWith(
          selfIntroduction: _controller.text.trim(),
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.of(context).pop();
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
        title: const Text('자기소개'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        children: [
          const Text(
            '자기소개를 입력해 주세요',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 20),
          ResumeTextField(
            controller: _controller,
            hint: '나의 강점과 경험을 소개해 주세요',
            maxLines: 8,
            maxLength: 500,
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              '저장',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ),
    );
  }
}
