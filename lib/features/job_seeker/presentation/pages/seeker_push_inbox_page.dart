import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/widgets/app_back_button.dart';
import 'package:map/features/corporate/presentation/widgets/corporate_surface_card.dart';
import 'package:map/features/job_seeker/data/repositories/seeker_push_inbox_repository.dart';
import 'package:map/features/job_seeker/domain/entities/seeker_push_notification.dart';
import 'package:map/features/job_seeker/domain/utils/seeker_push_retention_policy.dart';

/// 구직자 — 수신 푸시 받은함 (30일 보관 · 보관함 · 삭제)
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
        title: const Text('푸시 삭제'),
        content: const Text('이 푸시 알림을 삭제할까요?'),
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
        title: const Text('푸시 알림'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          tabs: const [
            Tab(text: '받은 푸시'),
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
                  emptyMessage: '받은 푸시가 없습니다.',
                  onArchive: _archiveItem,
                  onDelete: _deleteItem,
                ),
                _PushList(
                  items: _archive,
                  emptyMessage: '보관함이 비어 있습니다.',
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
    this.onArchive,
    this.onRestore,
    required this.onDelete,
  });

  final List<SeekerPushNotification> items;
  final String emptyMessage;
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
