import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/widgets/mvp_feedback.dart';
import 'package:map/features/corporate/presentation/widgets/corporate_surface_card.dart';

class _ChatPreview {
  const _ChatPreview({
    required this.company,
    required this.preview,
    required this.time,
  });

  final String company;
  final String preview;
  final String time;
}

/// 구직자 5번 탭 — 기업 채팅 (↔ 기업 채팅)
class IndividualChatTab extends StatelessWidget {
  const IndividualChatTab({super.key});

  static const _rooms = [
    _ChatPreview(
      company: '강남 지점',
      preview: '내일 9시 출근 가능하신가요?',
      time: '14:20',
    ),
    _ChatPreview(
      company: '역삼 지점',
      preview: '서류 검토 완료되었습니다.',
      time: '어제',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.background,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        itemCount: _rooms.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final room = _rooms[index];
          return CorporateSurfaceCard(
            onTap: () => showMvpInfoSnackBar(context, '채팅방'),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.primaryLight.withValues(alpha: 0.35),
                  child: const Icon(Icons.business, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        room.company,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        room.preview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary.withValues(alpha: 0.95),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  room.time,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
