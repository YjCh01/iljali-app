import 'package:flutter/material.dart';
import 'package:map/features/corporate/domain/entities/chat_reply_macro.dart';

/// 매크로 추가·수정 바텀시트
class ChatReplyMacroEditorSheet extends StatefulWidget {
  const ChatReplyMacroEditorSheet({super.key, this.initial});

  final ChatReplyMacro? initial;

  @override
  State<ChatReplyMacroEditorSheet> createState() =>
      _ChatReplyMacroEditorSheetState();
}

class _ChatReplyMacroEditorSheetState extends State<ChatReplyMacroEditorSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initial?.title ?? '');
    _bodyController = TextEditingController(text: widget.initial?.body ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();
    if (title.isEmpty || body.isEmpty) return;
    Navigator.of(context).pop(
      ChatReplyMacro(
        id: widget.initial?.id ??
            'macro_${DateTime.now().millisecondsSinceEpoch}',
        title: title,
        body: body,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.initial == null ? '매크로 추가' : '매크로 수정',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: '제목 (예: 채용 여부)',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _bodyController,
            minLines: 4,
            maxLines: 8,
            decoration: const InputDecoration(
              labelText: '답변 내용',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: _submit,
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }
}
