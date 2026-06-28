import 'package:flutter/material.dart';
import 'package:map/core/widgets/adaptive_sheet.dart';
import 'package:map/core/constants/app_colors.dart';

class ChatAttachmentOption {
  const ChatAttachmentOption({
    required this.id,
    required this.icon,
    required this.label,
    required this.subtitle,
    this.enabled = true,
  });

  final String id;
  final IconData icon;
  final String label;
  final String subtitle;
  final bool enabled;
}

Future<String?> showChatAttachmentPickerSheet(
  BuildContext context, {
  required List<ChatAttachmentOption> options,
}) {
  return showAdaptiveSheet<String>(
    context: context,
    builder: (context) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.searchBarBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '첨부 보내기',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                '현장에서 자주 쓰는 서류·사진을 바로 보낼 수 있습니다.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: AppColors.textSecondary.withValues(alpha: 0.95),
                ),
              ),
              const SizedBox(height: 16),
              ...options.map(
                (option) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    enabled: option.enabled,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: AppColors.searchBarBorder),
                    ),
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primaryLight.withValues(
                        alpha: 0.2,
                      ),
                      child: Icon(option.icon, color: AppColors.primary),
                    ),
                    title: Text(
                      option.label,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      option.subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary.withValues(alpha: 0.9),
                      ),
                    ),
                    onTap: option.enabled
                        ? () => Navigator.of(context).pop(option.id)
                        : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
