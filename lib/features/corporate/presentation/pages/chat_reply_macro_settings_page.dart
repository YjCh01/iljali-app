import 'package:flutter/material.dart';
import 'package:map/core/widgets/adaptive_sheet.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/core/widgets/app_back_button.dart';
import 'package:map/features/corporate/data/repositories/chat_reply_macro_repository.dart';
import 'package:map/features/corporate/domain/entities/chat_reply_macro.dart';

import 'package:map/features/corporate/presentation/widgets/chat/chat_reply_macro_editor_sheet.dart';

/// 담당자 채팅 매크로 등록·수정
class ChatReplyMacroSettingsPage extends StatefulWidget {
  const ChatReplyMacroSettingsPage({super.key});

  @override
  State<ChatReplyMacroSettingsPage> createState() =>
      _ChatReplyMacroSettingsPageState();
}

class _ChatReplyMacroSettingsPageState extends State<ChatReplyMacroSettingsPage> {
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

  Future<void> _resetDefaults() async {
    final companyKey =
        AuthSession.instance.currentUser?.corporateProfile?.companyKey;
    if (companyKey == null) return;
    final repo = await ChatReplyMacroRepository.create();
    await repo.resetToDefaults(companyKey);
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('기본 매크로로 되돌렸습니다.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
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
  }

  Future<void> _deleteMacro(ChatReplyMacro macro) async {
    setState(() => _macros.removeWhere((m) => m.id == macro.id));
    await _save();
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
        title: const Text('채팅 매크로'),
        actions: [
          TextButton(onPressed: _resetDefaults, child: const Text('기본값')),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                Text(
                  '지원자가 자주 묻는 질문에 바로 답할 수 있도록 '
                  '미리 등록해 두세요.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: AppColors.textSecondary.withValues(alpha: 0.95),
                  ),
                ),
                const SizedBox(height: 16),
                ..._macros.map(
                  (macro) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Material(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        onTap: () => _editMacro(existing: macro),
                        borderRadius: BorderRadius.circular(14),
                        child: Ink(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.searchBarBorder),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      macro.title,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: '삭제',
                                    onPressed: () => _deleteMacro(macro),
                                    icon: const Icon(Icons.delete_outline),
                                    color: AppColors.textSecondary,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                macro.body,
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.45,
                                  color: AppColors.textSecondary
                                      .withValues(alpha: 0.95),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (_macros.length < ChatReplyMacroRepository.maxMacros)
                  OutlinedButton.icon(
                    onPressed: () => _editMacro(),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('매크로 추가'),
                  ),
              ],
            ),
    );
  }
}
