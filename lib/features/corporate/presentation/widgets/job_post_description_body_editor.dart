import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/features/corporate/domain/entities/job_post_description_body.dart';
import 'package:map/features/corporate/domain/services/job_post_media_upload_service.dart';

enum _BodyEditorMode { text, images, html }

/// 공고 작성 — 업무 내용 본문 (텍스트 · 이미지 · HTML)
class JobPostDescriptionBodyEditor extends StatefulWidget {
  const JobPostDescriptionBodyEditor({
    super.key,
    required this.body,
    required this.onChanged,
  });

  final JobPostDescriptionBody body;
  final ValueChanged<JobPostDescriptionBody> onChanged;

  @override
  State<JobPostDescriptionBodyEditor> createState() =>
      _JobPostDescriptionBodyEditorState();
}

class _JobPostDescriptionBodyEditorState
    extends State<JobPostDescriptionBodyEditor> {
  late final TextEditingController _textController =
      TextEditingController(text: widget.body.text);
  late final TextEditingController _htmlController =
      TextEditingController(text: widget.body.html);
  late _BodyEditorMode _mode = _initialMode(widget.body);
  final _uploadService = JobPostMediaUploadService();
  bool _uploading = false;

  static _BodyEditorMode _initialMode(JobPostDescriptionBody body) {
    if (body.imageUrls.isNotEmpty) return _BodyEditorMode.images;
    if (body.html.trim().isNotEmpty) return _BodyEditorMode.html;
    return _BodyEditorMode.text;
  }

  @override
  void dispose() {
    _textController.dispose();
    _htmlController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(JobPostDescriptionBodyEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.body != widget.body) {
      if (_textController.text != widget.body.text) {
        _textController.text = widget.body.text;
      }
      if (_htmlController.text != widget.body.html) {
        _htmlController.text = widget.body.html;
      }
    }
  }

  void _emit(JobPostDescriptionBody next) => widget.onChanged(next);

  Future<void> _pickImages() async {
    if (_uploading) return;
    final picker = ImagePicker();
    final files = await picker.pickMultiImage(
      imageQuality: 85,
      maxWidth: 2400,
    );
    if (files.isEmpty || !mounted) return;

    setState(() => _uploading = true);
    final urls = List<String>.from(widget.body.imageUrls);
    try {
      for (final file in files) {
        final bytes = await file.readAsBytes();
        final url = await _uploadService.uploadBytes(
          bytes: bytes,
          filename: file.name,
          mimeType: jobPostMediaMimeType(file.name),
        );
        urls.add(url);
      }
      if (!mounted) return;
      _emit(widget.body.copyWith(imageUrls: urls));
      setState(() => _mode = _BodyEditorMode.images);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _removeImage(int index) {
    final urls = List<String>.from(widget.body.imageUrls)..removeAt(index);
    _emit(widget.body.copyWith(imageUrls: urls));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<_BodyEditorMode>(
          segments: const [
            ButtonSegment(
              value: _BodyEditorMode.text,
              label: Text('글'),
              icon: Icon(Icons.notes_outlined, size: 18),
            ),
            ButtonSegment(
              value: _BodyEditorMode.images,
              label: Text('이미지'),
              icon: Icon(Icons.image_outlined, size: 18),
            ),
            ButtonSegment(
              value: _BodyEditorMode.html,
              label: Text('HTML'),
              icon: Icon(Icons.code_outlined, size: 18),
            ),
          ],
          selected: {_mode},
          onSelectionChanged: (selection) {
            setState(() => _mode = selection.first);
          },
          style: ButtonStyle(
            visualDensity: VisualDensity.compact,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        const SizedBox(height: 10),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: switch (_mode) {
            _BodyEditorMode.text => _buildTextPanel(),
            _BodyEditorMode.images => _buildImagesPanel(),
            _BodyEditorMode.html => _buildHtmlPanel(),
          },
        ),
        const SizedBox(height: 6),
        Text(
          '제목·급여·근무 일정은 위 항목에 입력합니다. '
          '여기는 상세 본문(업무 안내·현장 사진 등)만 작성하세요.',
          style: TextStyle(
            fontSize: 11,
            height: 1.35,
            color: AppColors.textSecondary.withValues(alpha: 0.9),
          ),
        ),
      ],
    );
  }

  Widget _buildTextPanel() {
    return TextField(
      key: const ValueKey('body-text'),
      controller: _textController,
      minLines: 4,
      maxLines: 8,
      onChanged: (value) => _emit(widget.body.copyWith(text: value)),
      decoration: InputDecoration(
        hintText: '담당 업무, 근무 조건, 유의사항 등',
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        contentPadding: const EdgeInsets.all(14),
      ),
    );
  }

  Widget _buildImagesPanel() {
    final urls = widget.body.imageUrls;
    return Column(
      key: const ValueKey('body-images'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: _uploading ? null : _pickImages,
          icon: _uploading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.add_photo_alternate_outlined),
          label: Text(_uploading ? '업로드 중…' : '이미지 추가'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        if (urls.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              '공고 전체를 이미지로 올리거나, 현장·업무 사진을 추가할 수 있습니다.',
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: AppColors.textSecondary.withValues(alpha: 0.9),
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < urls.length; i++)
                  _ImageThumb(
                    url: urls[i],
                    onRemove: () => _removeImage(i),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildHtmlPanel() {
    return TextField(
      key: const ValueKey('body-html'),
      controller: _htmlController,
      minLines: 6,
      maxLines: 12,
      onChanged: (value) => _emit(widget.body.copyWith(html: value)),
      style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
      decoration: InputDecoration(
        hintText: '<p>업무 안내…</p>\n<ul><li>항목</li></ul>',
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        contentPadding: const EdgeInsets.all(14),
      ),
    );
  }
}

class _ImageThumb extends StatelessWidget {
  const _ImageThumb({
    required this.url,
    required this.onRemove,
  });

  final String url;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.network(
            url,
            width: 96,
            height: 96,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              width: 96,
              height: 96,
              color: AppColors.primaryLight.withValues(alpha: 0.15),
              child: const Icon(Icons.image_outlined),
            ),
          ),
        ),
        Positioned(
          top: -6,
          right: -6,
          child: Material(
            color: Colors.black87,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: onRemove,
              customBorder: const CircleBorder(),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.close_rounded, size: 16, color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
