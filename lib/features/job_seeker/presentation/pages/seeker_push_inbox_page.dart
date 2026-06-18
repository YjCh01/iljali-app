import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/constants/app_routes.dart';
import 'package:map/core/widgets/app_back_button.dart';
import 'package:map/features/corporate/data/datasources/corporate_job_post_local_data_source.dart';
import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';
import 'package:map/features/corporate/presentation/widgets/corporate_surface_card.dart';
import 'package:map/features/job_seeker/data/repositories/seeker_push_inbox_repository.dart';
import 'package:map/features/job_seeker/domain/entities/job_map_pin.dart';
import 'package:map/features/job_seeker/domain/entities/seeker_push_notification.dart';
import 'package:map/features/job_seeker/domain/services/collusion_report_service.dart';
import 'package:map/features/job_seeker/domain/utils/seeker_push_retention_policy.dart';
import 'package:map/features/job_seeker/presentation/widgets/job_post_detail_sheet.dart';

/// 구직자 — 수신 PUSH 받은함 (30일 보관 · 보관함 · 삭제)
class SeekerPushInboxPage extends StatefulWidget {
  const SeekerPushInboxPage({super.key});

  @override
  State<SeekerPushInboxPage> createState() => _SeekerPushInboxPageState();
}

class _SeekerPushInboxPageState extends State<SeekerPushInboxPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  SeekerPushInboxRepository? _repo;
  List<SeekerPushNotification> _inbox = [];
  List<SeekerPushNotification> _archive = [];
  bool _loading = true;
  final _postDataSource = const CorporateJobPostLocalDataSourceImpl();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _init();
  }

  Future<void> _init() async {
    _repo = await SeekerPushInboxRepository.create();
    await _reload();
  }

  Future<void> _reload() async {
    final repo = _repo;
    if (repo == null) return;
    final inbox = await repo.loadFolder(SeekerPushInboxFolder.inbox);
    final archive = await repo.loadFolder(SeekerPushInboxFolder.archive);
    if (!mounted) return;
    setState(() {
      _inbox = inbox;
      _archive = archive;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _archiveItem(SeekerPushNotification item) async {
    await _repo?.moveToArchive(item.id);
    await _reload();
  }

  Future<void> _restoreItem(SeekerPushNotification item) async {
    await _repo?.moveToInbox(item.id);
    await _reload();
  }

  Future<void> _deleteItem(SeekerPushNotification item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('PUSH 삭제'),
        content: const Text('이 PUSH 알림을 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _repo?.delete(item.id);
    await _reload();
  }

  Future<void> _openItem(SeekerPushNotification item) async {
    await _repo?.markRead(item.id);
    await _reload();
    if (!mounted) return;
    final postId = item.jobPostId;
    if (postId == null || postId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('연결된 공고 정보가 없습니다.')),
      );
      return;
    }
    final post = await _postDataSource.findById(postId);
    if (!mounted) return;
    if (post == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('공고를 찾을 수 없습니다.')),
      );
      return;
    }
    await _openJobDetail(item, post);
  }

  Future<void> _openJobDetail(
    SeekerPushNotification item,
    CorporateJobPost post,
  ) async {
    final apply = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(item.title),
        content: Text(post.fullDescriptionText),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('닫기'),
          ),
          TextButton(
            onPressed: () async {
              await _reportCollusion(item);
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop(false);
              }
            },
            child: const Text('담합 신고'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('지원하기'),
          ),
        ],
      ),
    );
    if (apply != true || !mounted) return;
    await _applyAndOpenChat(post);
  }

  Future<void> _applyAndOpenChat(CorporateJobPost post) async {
    final applied = await showJobApplyDialog(
      context,
      JobMapPin(
        post: post,
        latitude: 0,
        longitude: 0,
        companyName: post.registeredBy?.companyName ?? '기업',
        displayTier: post.effectiveMapPinTier,
      ),
      onApplied: null,
    );
    if (!applied || !mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.home,
      (_) => false,
      arguments: const {'seekerTabIndex': 3},
    );
  }

  Future<void> _reportCollusion(SeekerPushNotification item) async {
    await CollusionReportService().submit(
      CollusionReportSubmission(
        applicationId: item.id,
        companyKey: item.companyName,
        reason: 'PUSH 알림 기반 담합/오프플랫폼 유도 의심 신고',
        detail: item.body,
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('신고가 접수되었습니다. 보상 크레딧은 추후 지급됩니다.')),
    );
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
        title: const Text('PUSH 알림'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          tabs: const [
            Tab(text: '받은 PUSH'),
            Tab(text: '보관함'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _PushList(
                  items: _inbox,
                  emptyMessage: '받은 PUSH가 없습니다.',
                  onTapItem: _openItem,
                  onArchive: _archiveItem,
                  onDelete: _deleteItem,
                ),
                _PushList(
                  items: _archive,
                  emptyMessage: '보관함이 비어 있습니다.',
                  onTapItem: _openItem,
                  onRestore: _restoreItem,
                  onDelete: _deleteItem,
                ),
              ],
            ),
    );
  }
}

class _PushList extends StatelessWidget {
  const _PushList({
    required this.items,
    required this.emptyMessage,
    required this.onTapItem,
    this.onArchive,
    this.onRestore,
    required this.onDelete,
  });

  final List<SeekerPushNotification> items;
  final String emptyMessage;
  final Future<void> Function(SeekerPushNotification) onTapItem;
  final Future<void> Function(SeekerPushNotification)? onArchive;
  final Future<void> Function(SeekerPushNotification)? onRestore;
  final Future<void> Function(SeekerPushNotification) onDelete;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Text(
          emptyMessage,
          style: TextStyle(
            color: AppColors.textSecondary.withValues(alpha: 0.9),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = items[index];
        return Dismissible(
          key: ValueKey(item.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            decoration: BoxDecoration(
              color: Colors.red.shade400,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.delete_outline, color: Colors.white),
          ),
          confirmDismiss: (_) async {
            await onDelete(item);
            return false;
          },
          child: CorporateSurfaceCard(
            onTap: () => onTapItem(item),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight:
                              item.read ? FontWeight.w600 : FontWeight.w800,
                        ),
                      ),
                    ),
                    if (!item.read)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  item.companyName,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary.withValues(alpha: 0.95),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  item.body,
                  style: const TextStyle(fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 8),
                Text(
                  SeekerPushRetentionPolicy.expiryLabel(item.receivedAt),
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (onArchive != null)
                      TextButton(
                        onPressed: () => onArchive!(item),
                        child: const Text('보관함'),
                      ),
                    if (onRestore != null)
                      TextButton(
                        onPressed: () => onRestore!(item),
                        child: const Text('받은함으로'),
                      ),
                    TextButton(
                      onPressed: () => onDelete(item),
                      child: const Text('삭제'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
