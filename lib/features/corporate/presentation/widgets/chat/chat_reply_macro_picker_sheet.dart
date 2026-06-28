import 'package:flutter/material.dart';
import 'package:map/core/widgets/adaptive_sheet.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/features/corporate/data/repositories/chat_reply_macro_repository.dart';
import 'package:map/features/corporate/domain/entities/chat_reply_macro.dart';
import 'package:map/core/hiring/hiring_application.dart';
import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';
import 'package:map/features/corporate/domain/services/chat_reply_macro_renderer.dart';

import 'package:map/features/corporate/presentation/widgets/chat/chat_reply_macro_editor_sheet.dart';

/// 매크로 선택 결과
class ChatReplyMacroPickResult {
  const ChatReplyMacroPickResult({
    required this.text,
    this.sendImmediately = false,
  });

  final String text;
  final bool sendImmediately;
}

/// 채팅 입력 — 자주 쓰는 답변 시트 (선택·추가·수정·삭제)
Future<ChatReplyMacroPickResult?> showChatReplyMacroPickerSheet(
  BuildContext context, {
  required HiringApplication application,
  CorporateJobPost? jobPost,
}) {
  return showAdaptiveSheet<ChatReplyMacroPickResult>(
    context: context,
    builder: (context) => ChatReplyMacroPickerSheet(
      application: application,
      jobPost: jobPost,
    ),
  );
}

class ChatReplyMacroPickerSheet extends StatefulWidget {
  const ChatReplyMacroPickerSheet({
    super.key,
    required this.application,
    this.jobPost,
  });

  final HiringApplication application;
  final CorporateJobPost? jobPost;

  @override
  State<ChatReplyMacroPickerSheet> createState() =>
      _ChatReplyMacroPickerSheetState();
}

class _ChatReplyMacroPickerSheetState extends State<ChatReplyMacroPickerSheet> {
  static const _renderer = ChatReplyMacroRenderer();

  List<ChatReplyMacro> _macros = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final companyKey =
        AuthSession.instance.currentUser?.corporateProfile?.companyKey;
    if (companyKey == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final repo = await ChatReplyMacroRepository.create();
    final macros = await repo.load(companyKey);
    if (!mounted) return;
    setState(() {
      _macros = macros;
      _loading = false;
    });
  }

  Future<void> _save() async {
    final companyKey =
        AuthSession.instance.currentUser?.corporateProfile?.companyKey;
    if (companyKey == null) return;
    final repo = await ChatReplyMacroRepository.create();
    await repo.save(companyKey, _macros);
  }

  Future<void> _editMacro({ChatReplyMacro? existing}) async {
    final result = await showAdaptiveSheet<ChatReplyMacro>(
      context: context,
      builder: (context) => ChatReplyMacroEditorSheet(initial: existing),
    );
    if (result == null) return;
    setState(() {
      final index = _macros.indexWhere((m) => m.id == result.id);
      if (index >= 0) {
        _macros[index] = result;
      } else {
        _macros = [..._macros, result];
      }
    });
    await _save();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('매크로를 저장했습니다.'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _deleteMacro(ChatReplyMacro macro) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('매크로 삭제'),
        content: Text('「${macro.title}」을(를) 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _macros.removeWhere((m) => m.id == macro.id));
    await _save();
  }

  void _pick(String renderedBody, {bool sendImmediately = false}) {
    Navigator.of(context).pop(
      ChatReplyMacroPickResult(
        text: renderedBody,
        sendImmediately: sendImmediately,
      ),
    );
  }

  String _renderedBody(ChatReplyMacro macro) {
    final profile = AuthSession.instance.currentUser?.corporateProfile;
    return _renderer.renderBody(
      macro: macro,
      application: widget.application,
      jobPost: widget.jobPost,
      profile: profile,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.72;

    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(maxHeight: maxHeight),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 12, 8),
                child: Row(
                  children: [
                    const ChatReplyMacroIcon(size: 22),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        '자주 쓰는 답변',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  '탭하면 입력창에 넣고, 전송 아이콘으로 바로 보낼 수 있습니다.',
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.45,
                    color: AppColors.textSecondary.withValues(alpha: 0.9),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: EdgeInsets.fromLTRB(20, 0, 20, 12 + bottomInset),
                    itemCount: _macros.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final macro = _macros[index];
                      final preview = _renderedBody(macro);
                      return Material(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          onTap: () => _pick(preview),
                          borderRadius: BorderRadius.circular(14),
                          child: Ink(
                            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border:
                                  Border.all(color: AppColors.searchBarBorder),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        macro.title,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        preview,
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12,
                                          height: 1.4,
                                          color: AppColors.textSecondary
                                              .withValues(alpha: 0.95),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  tooltip: '바로 전송',
                                  onPressed: () => _pick(
                                    preview,
                                    sendImmediately: true,
                                  ),
                                  icon: const Icon(Icons.send_rounded, size: 20),
                                  color: AppColors.primary,
                                ),
                                IconButton(
                                  tooltip: '수정',
                                  onPressed: () =>
                                      _editMacro(existing: macro),
                                  icon: const Icon(Icons.edit_outlined, size: 20),
                                  color: AppColors.textSecondary,
                                ),
                                IconButton(
                                  tooltip: '삭제',
                                  onPressed: () => _deleteMacro(macro),
                                  icon: const Icon(Icons.delete_outline, size: 20),
                                  color: AppColors.textSecondary,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              if (!_loading &&
                  _macros.length < ChatReplyMacroRepository.maxMacros)
                Padding(
                  padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + bottomInset),
                  child: OutlinedButton.icon(
                    onPressed: () => _editMacro(),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('매크로 추가'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A4 + 체크 형태 매크로 아이콘
class ChatReplyMacroIcon extends StatelessWidget {
  const ChatReplyMacroIcon({
    super.key,
    this.size = 24,
    this.color,
  });

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? AppColors.primary;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            Icons.description_outlined,
            size: size,
            color: tint,
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: size * 0.42,
              height: size * 0.42,
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: tint, width: 1.2),
              ),
              child: Icon(
                Icons.check_rounded,
                size: size * 0.28,
                color: tint,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
