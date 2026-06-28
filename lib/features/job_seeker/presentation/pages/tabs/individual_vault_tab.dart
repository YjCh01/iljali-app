import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/core/widgets/empty_state_card.dart';
import 'package:map/features/corporate/data/datasources/corporate_job_post_local_data_source.dart';
import 'package:map/features/corporate/presentation/widgets/corporate_surface_card.dart';
import 'package:map/features/job_seeker/data/repositories/job_bookmark_vault_repository.dart';
import 'package:map/features/job_seeker/domain/entities/job_bookmark.dart';
import 'package:map/features/job_seeker/domain/entities/job_bookmark_folder.dart';
import 'package:map/features/job_seeker/domain/entities/viewed_job_entry.dart';
import 'package:map/features/job_seeker/domain/utils/job_bookmark_retention_policy.dart';
import 'package:map/core/widgets/korean_calendar.dart';
import 'package:map/core/widgets/adaptive_sheet.dart';
import 'package:map/features/job_seeker/domain/utils/job_bookmark_sort.dart';
import 'package:map/features/job_seeker/domain/utils/job_map_pin_factory.dart';
import 'package:map/core/hiring/local_hiring_repository.dart';
import 'package:map/features/job_seeker/domain/services/seeker_application_withdraw_service.dart';
import 'package:map/features/job_seeker/presentation/widgets/job_post_detail_sheet.dart';

/// 구직자 — 나의 보관함 (폴더·메모·오늘 본 공고)
class IndividualVaultTab extends StatefulWidget {
  const IndividualVaultTab({
    super.key,
    this.onApplied,
    this.reloadToken = 0,
  });

  final VoidCallback? onApplied;
  final int reloadToken;

  @override
  State<IndividualVaultTab> createState() => _IndividualVaultTabState();
}

class _IndividualVaultTabState extends State<IndividualVaultTab>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  JobBookmarkVaultRepository? _repo;
  final _postDataSource = const CorporateJobPostLocalDataSourceImpl();

  List<JobBookmarkFolder> _folders = [];
  List<JobBookmark> _bookmarks = [];
  List<ViewedJobEntry> _viewedToday = [];
  List<JobBookmark> _expiringSoon = [];
  String? _selectedFolderId;
  JobBookmarkSortMode _sortMode = JobBookmarkSortMode.savedNewest;
  bool _loading = true;
  bool _compareMode = false;
  final Set<String> _selectedForCompare = {};
  final Map<String, bool> _canWithdrawByPostId = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this)
      ..addListener(() {
        if (!_tabController.indexIsChanging) setState(() {});
      });
    _init();
  }

  @override
  void didUpdateWidget(covariant IndividualVaultTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reloadToken != widget.reloadToken) {
      _reload();
    }
  }

  Future<void> _init() async {
    final user = AuthSession.instance.currentUser;
    _repo = await JobBookmarkVaultRepository.create(user?.email);
    await _reload();
  }

  Future<void> _reload() async {
    final repo = _repo;
    if (repo == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final folders = await repo.loadFolders();
    final bookmarks = await repo.loadBookmarks(
      folderId: _selectedFolderId,
    );
    final viewed = await repo.loadViewedToday();
    final expiring = await repo.loadExpiringSoon();
    final email = AuthSession.instance.currentUser?.email;
    final withdrawable = <String, bool>{};
    if (email != null && email.isNotEmpty) {
      final hiringRepo = await LocalHiringRepository.create();
      for (final bookmark in bookmarks) {
        final active = await hiringRepo.findActiveForPost(
          postId: bookmark.postId,
          seekerEmail: email,
        );
        withdrawable[bookmark.postId] = active != null &&
            LocalHiringRepository.canSeekerWithdraw(active);
      }
    }
    if (!mounted) return;
    setState(() {
      _folders = folders;
      _bookmarks = bookmarks;
      _viewedToday = viewed;
      _expiringSoon = expiring;
      _canWithdrawByPostId
        ..clear()
        ..addAll(withdrawable);
      _loading = false;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _createFolder() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('폴더 만들기'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '예: 이번 주, 물류센터, 주말알바',
          ),
          onSubmitted: (value) => Navigator.of(ctx).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('만들기'),
          ),
        ],
      ),
    );
    if (name == null || name.trim().isEmpty) return;
    try {
      await _repo?.createFolder(name);
      await _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('「$name」 폴더를 만들었습니다.')),
      );
    } on ArgumentError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? '폴더를 만들 수 없습니다.')),
      );
    }
  }

  Future<void> _editMemo(JobBookmark bookmark) async {
    final controller = TextEditingController(text: bookmark.memo);
    final memo = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('메모'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: '지원 일정, 조건 메모 등',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('저장'),
          ),
        ],
      ),
    );
    if (memo == null) return;
    await _repo?.updateMemo(bookmark.postId, memo);
    await _reload();
  }

  Future<void> _removeBookmark(JobBookmark bookmark) async {
    await _repo?.removeBookmark(bookmark.postId);
    await _reload();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('보관함에서 삭제했습니다.')),
    );
  }

  Future<void> _withdrawBookmark(JobBookmark bookmark) async {
    final ok = await SeekerApplicationWithdrawService.confirmAndWithdraw(
      context,
      postId: bookmark.postId,
      postTitle: bookmark.title,
    );
    if (ok) await _reload();
  }

  Future<void> _openBookmark(JobBookmark bookmark) async {
    final post = await _postDataSource.findById(bookmark.postId);
    if (!mounted) return;
    if (post == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('공고를 찾을 수 없습니다.')),
      );
      return;
    }
    final pin = jobMapPinFromPost(post);
    await showAdaptiveSheet<void>(
      context: context,
      builder: (context) => JobPostDetailSheet(
        pin: pin,
        vaultRepo: _repo,
        onClose: () => Navigator.of(context).pop(),
        onApply: () async {
          final applied = await showJobApplyDialog(
            context,
            pin,
            onApplied: widget.onApplied,
          );
          if (applied && context.mounted) Navigator.of(context).pop();
        },
        onVaultChanged: _reload,
        onApplicationStateChanged: _reload,
      ),
    );
    await _reload();
  }

  Future<void> _openViewed(ViewedJobEntry entry) async {
    final post = await _postDataSource.findById(entry.postId);
    if (!mounted) return;
    if (post == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('공고를 찾을 수 없습니다.')),
      );
      return;
    }
    final pin = jobMapPinFromPost(post);
    await showAdaptiveSheet<void>(
      context: context,
      builder: (context) => JobPostDetailSheet(
        pin: pin,
        vaultRepo: _repo,
        onClose: () => Navigator.of(context).pop(),
        onApply: () async {
          final applied = await showJobApplyDialog(
            context,
            pin,
            onApplied: widget.onApplied,
          );
          if (applied && context.mounted) Navigator.of(context).pop();
        },
        onVaultChanged: _reload,
        onApplicationStateChanged: _reload,
      ),
    );
    await _reload();
  }

  int _parseWageKrw(String wage) {
    final digits = wage.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(digits) ?? 0;
  }

  void _toggleCompareSelection(JobBookmark bookmark) {
    setState(() {
      if (_selectedForCompare.contains(bookmark.postId)) {
        _selectedForCompare.remove(bookmark.postId);
      } else if (_selectedForCompare.length < 2) {
        _selectedForCompare.add(bookmark.postId);
      }
    });
  }

  Future<void> _showWageCompareDialog() async {
    if (_selectedForCompare.length < 2) return;
    final selected = _bookmarks
        .where((b) => _selectedForCompare.contains(b.postId))
        .toList();
    if (selected.length < 2) return;
    selected.sort(
      (a, b) => _parseWageKrw(b.hourlyWage).compareTo(_parseWageKrw(a.hourlyWage)),
    );
    final higher = selected.first;
    final lower = selected.last;
    final diff = _parseWageKrw(higher.hourlyWage) - _parseWageKrw(lower.hourlyWage);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('시급 비교'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CompareRow(
              label: '높음',
              title: higher.title,
              wage: higher.hourlyWage,
              company: higher.companyName,
            ),
            const SizedBox(height: 12),
            _CompareRow(
              label: '낮음',
              title: lower.title,
              wage: lower.hourlyWage,
              company: lower.companyName,
            ),
            if (diff > 0) ...[
              const SizedBox(height: 12),
              Text(
                '시급 차이: ${diff.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}원',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary.withValues(alpha: 0.95),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  Future<void> _renameFolder(JobBookmarkFolder folder) async {
    final controller = TextEditingController(text: folder.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('폴더 이름 변경'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '새 폴더 이름'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('저장'),
          ),
        ],
      ),
    );
    if (name == null || name.trim().isEmpty) return;
    try {
      await _repo?.renameFolder(folder.id, name);
      await _reload();
    } on ArgumentError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? '이름을 변경할 수 없습니다.')),
      );
    }
  }

  Future<void> _deleteFolder(JobBookmarkFolder folder) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('폴더 삭제'),
        content: Text(
          '「${folder.name}」 폴더를 삭제할까요?\n'
          '보관한 공고는 기본 폴더로 이동합니다.',
        ),
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
    if (confirmed != true) return;
    try {
      await _repo?.deleteFolder(folder.id);
      if (_selectedFolderId == folder.id) {
        _selectedFolderId = null;
      }
      await _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('폴더를 삭제했습니다.')),
      );
    } on ArgumentError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? '폴더를 삭제할 수 없습니다.')),
      );
    }
  }

  Future<void> _showFolderMenu(JobBookmarkFolder folder) async {
    if (folder.id == JobBookmarkFolder.defaultFolderId) return;
    final action = await showAdaptiveSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.drive_file_rename_outline),
              title: Text('「${folder.name}」 이름 변경'),
              onTap: () => Navigator.of(ctx).pop('rename'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('폴더 삭제'),
              onTap: () => Navigator.of(ctx).pop('delete'),
            ),
          ],
        ),
      ),
    );
    if (action == 'rename') {
      await _renameFolder(folder);
    } else if (action == 'delete') {
      await _deleteFolder(folder);
    }
  }

  Future<void> _showCalendarStub(String title) async {
    final now = DateTime.now();
    final picked = await showKoreanDatePickerSheet(
      context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      title: '「$title」일정 기록',
    );
    if (!mounted || picked == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '「$title」${picked.year}.${picked.month}.${picked.day} 일정을 기록했습니다.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const ColoredBox(
        color: AppColors.background,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_repo == null) {
      return const ColoredBox(
        color: AppColors.background,
        child: Center(child: Text('로그인 후 보관함을 사용할 수 있습니다.')),
      );
    }

    final sortedBookmarks = JobBookmarkSort.sortBookmarks(_bookmarks, _sortMode);
    final sortedViewed = JobBookmarkSort.sortViewed(_viewedToday, _sortMode);

    return ColoredBox(
      color: AppColors.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    '나의 보관함',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (_bookmarks.length >= 2)
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _compareMode = !_compareMode;
                        if (!_compareMode) _selectedForCompare.clear();
                      });
                    },
                    icon: Icon(
                      _compareMode
                          ? Icons.close_rounded
                          : Icons.compare_arrows,
                      size: 18,
                    ),
                    label: Text(_compareMode ? '취소' : '비교'),
                  ),
                IconButton(
                  tooltip: '폴더 만들기',
                  onPressed: _createFolder,
                  icon: const Icon(Icons.create_new_folder_outlined),
                ),
                PopupMenuButton<JobBookmarkSortMode>(
                  tooltip: '정렬',
                  initialValue: _sortMode,
                  onSelected: (mode) => setState(() => _sortMode = mode),
                  itemBuilder: (context) => JobBookmarkSortMode.values
                      .map(
                        (mode) => PopupMenuItem(
                          value: mode,
                          child: Text(mode.label),
                        ),
                      )
                      .toList(),
                  icon: const Icon(Icons.sort_rounded),
                ),
              ],
            ),
          ),
          if (_expiringSoon.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: CorporateSurfaceCard(
                child: Row(
                  children: [
                    Icon(
                      Icons.schedule_outlined,
                      color: AppColors.primary.withValues(alpha: 0.9),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${_expiringSoon.length}개 항목이 곧 30일 보관 기한이 끝납니다. '
                        '삭제하거나 다시 저장해 주세요.',
                        style: const TextStyle(fontSize: 12, height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          TabBar(
            controller: _tabController,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            tabs: const [
              Tab(text: '보관한 공고'),
              Tab(text: '오늘 본 공고'),
            ],
          ),
          if (_tabController.index == 0) _buildFolderFilter(),
          if (_compareMode && _selectedForCompare.length == 2)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: FilledButton.icon(
                onPressed: _showWageCompareDialog,
                icon: const Icon(Icons.compare, size: 18),
                label: const Text('시급 비교하기'),
              ),
            ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildBookmarkList(sortedBookmarks),
                _buildViewedList(sortedViewed),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFolderFilter() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: const Text('전체'),
              selected: _selectedFolderId == null,
              onSelected: (_) async {
                setState(() => _selectedFolderId = null);
                await _reload();
              },
            ),
          ),
          ..._folders.map(
            (folder) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onLongPress: folder.id == JobBookmarkFolder.defaultFolderId
                    ? null
                    : () => _showFolderMenu(folder),
                child: FilterChip(
                  label: Text(folder.name),
                  selected: _selectedFolderId == folder.id,
                  onSelected: (_) async {
                    setState(() => _selectedFolderId = folder.id);
                    await _reload();
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookmarkList(List<JobBookmark> items) {
    if (items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _reload,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 120),
            EmptyStateCard(
              icon: Icons.bookmark_border_rounded,
              title: '보관한 공고가 없습니다',
              message: '지도에서 공고를 열고\n「보관함에 저장」을 눌러 보세요.',
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          final folderName = _folderName(item.folderId);
          final isSelected = _selectedForCompare.contains(item.postId);
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: CorporateSurfaceCard(
              onTap: _compareMode
                  ? () => _toggleCompareSelection(item)
                  : () => _openBookmark(item),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (_compareMode)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Icon(
                            isSelected
                                ? Icons.check_circle
                                : Icons.circle_outlined,
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.textSecondary,
                            size: 22,
                          ),
                        ),
                      Expanded(
                        child: Text(
                          item.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        JobBookmarkRetentionPolicy.expiryLabel(item.savedAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${item.companyName} · $folderName',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary.withValues(alpha: 0.95),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${item.warehouseName} · ${item.hourlyWage}',
                    style: const TextStyle(fontSize: 13),
                  ),
                  if (item.memo.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      item.memo,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.primary.withValues(alpha: 0.95),
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      TextButton.icon(
                        onPressed: () => _openBookmark(item),
                        icon: const Icon(Icons.open_in_new, size: 16),
                        label: const Text('상세'),
                      ),
                      TextButton.icon(
                        onPressed: () => _editMemo(item),
                        icon: const Icon(Icons.edit_note_outlined, size: 16),
                        label: const Text('메모'),
                      ),
                      if (_canWithdrawByPostId[item.postId] == true)
                        TextButton.icon(
                          onPressed: () => _withdrawBookmark(item),
                          icon: Icon(
                            Icons.cancel_outlined,
                            size: 16,
                            color: Colors.red.shade700,
                          ),
                          label: Text(
                            '지원취소',
                            style: TextStyle(color: Colors.red.shade700),
                          ),
                        ),
                      if (!_compareMode && _bookmarks.length >= 2)
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _compareMode = true;
                              _selectedForCompare
                                ..clear()
                                ..add(item.postId);
                            });
                          },
                          icon: const Icon(Icons.compare_arrows, size: 16),
                          label: const Text('비교'),
                        ),
                      TextButton.icon(
                        onPressed: () => _showCalendarStub(item.title),
                        icon: const Icon(Icons.event_outlined, size: 16),
                        label: const Text('캘린더'),
                      ),
                      TextButton.icon(
                        onPressed: () => _removeBookmark(item),
                        icon: const Icon(Icons.delete_outline, size: 16),
                        label: const Text('삭제'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildViewedList(List<ViewedJobEntry> items) {
    if (items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _reload,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 120),
            EmptyStateCard(
              icon: Icons.visibility_outlined,
              title: '오늘 본 공고가 없습니다',
              message: '지도나 공고 목록에서\n공고를 열어보면 여기에 표시됩니다.',
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: CorporateSurfaceCard(
              onTap: () => _openViewed(item),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.companyName,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary.withValues(alpha: 0.95),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${item.warehouseName} · ${item.hourlyWage}',
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '조회 ${_formatTime(item.viewedAt)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _folderName(String folderId) {
    for (final folder in _folders) {
      if (folder.id == folderId) return folder.name;
    }
    return '기본';
  }

  String _formatTime(DateTime time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _CompareRow extends StatelessWidget {
  const _CompareRow({
    required this.label,
    required this.title,
    required this.wage,
    required this.company,
  });

  final String label;
  final String title;
  final String wage;
  final String company;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary.withValues(alpha: 0.9),
          ),
        ),
        const SizedBox(height: 4),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        Text('$company · $wage', style: const TextStyle(fontSize: 13)),
      ],
    );
  }
}
