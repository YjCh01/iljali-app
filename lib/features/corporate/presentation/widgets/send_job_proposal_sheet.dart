import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/core/widgets/adaptive_sheet.dart';
import 'package:map/features/corporate/data/datasources/corporate_job_post_local_data_source.dart';
import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';
import 'package:map/features/corporate/domain/entities/talent_search_entry.dart';
import 'package:map/features/hiring/data/repositories/job_proposal_repository.dart';
import 'package:map/features/hiring/domain/entities/job_proposal.dart';

Future<bool?> showSendJobProposalSheet(
  BuildContext context, {
  required TalentSearchEntry entry,
  required String companyKey,
  required String companyName,
}) {
  return showAdaptiveSheet<bool>(
    context: context,
    builder: (ctx) => _SendJobProposalBody(
      entry: entry,
      companyKey: companyKey,
      companyName: companyName,
    ),
  );
}

class _SendJobProposalBody extends StatefulWidget {
  const _SendJobProposalBody({
    required this.entry,
    required this.companyKey,
    required this.companyName,
  });

  final TalentSearchEntry entry;
  final String companyKey;
  final String companyName;

  @override
  State<_SendJobProposalBody> createState() => _SendJobProposalBodyState();
}

class _SendJobProposalBodyState extends State<_SendJobProposalBody> {
  List<CorporateJobPost> _activePosts = [];
  CorporateJobPost? _selectedPost;
  final _messageController = TextEditingController();
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadPosts() async {
    final posts = await const CorporateJobPostLocalDataSourceImpl()
        .fetchJobPosts();
    final active = posts
        .where(
          (p) =>
              p.registeredBy?.companyKey == widget.companyKey &&
              p.isActiveForSeekers,
        )
        .toList();
    if (!mounted) return;
    setState(() {
      _activePosts = active;
      _selectedPost = active.isNotEmpty ? active.first : null;
      _loading = false;
    });
  }

  Future<void> _send() async {
    final post = _selectedPost;
    if (post == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('활성 공고를 선택해 주세요.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _sending = true);
    final repo = await JobProposalRepository.create();
    final hasPending = await repo.hasPending(
      postId: post.id,
      seekerEmail: widget.entry.seekerEmail,
    );
    if (hasPending) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('이미 같은 공고로 제안을 보냈습니다.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final recruiter = AuthSession.instance.currentUser?.email;
    final proposal = JobProposal(
      id: 'prop_${DateTime.now().millisecondsSinceEpoch}',
      postId: post.id,
      postTitle: post.title,
      companyKey: widget.companyKey,
      companyName: widget.companyName,
      seekerEmail: widget.entry.seekerEmail,
      seekerDisplayNameMasked: widget.entry.displayNameMasked,
      recruiterEmail: recruiter,
      message: _messageController.text.trim().isEmpty
          ? null
          : _messageController.text.trim(),
      status: JobProposalStatus.pending,
      createdAt: DateTime.now(),
    );
    await repo.save(proposal);
    if (!mounted) return;
    Navigator.of(context).pop(true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${widget.entry.displayNameMasked}님에게 제안을 보냈습니다.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${widget.entry.displayNameMasked}님에게 제안',
                    style: const TextStyle(
                      fontSize: 18,
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
            const SizedBox(height: 8),
            Text(
              '연결할 활성 공고를 선택해 주세요. 수락 시 일반 지원과 동일한 절차로 진행됩니다.',
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: AppColors.textSecondary.withValues(alpha: 0.95),
              ),
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_activePosts.isEmpty)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  '활성 공고가 없습니다. 공고 탭에서 채용 공고를 등록·게시한 뒤 제안해 주세요.',
                  style: TextStyle(fontSize: 13, height: 1.45),
                ),
              )
            else ...[
              DropdownButtonFormField<CorporateJobPost>(
                value: _selectedPost,
                decoration: const InputDecoration(
                  labelText: '활성 공고',
                  border: OutlineInputBorder(),
                ),
                items: _activePosts
                    .map(
                      (p) => DropdownMenuItem(
                        value: p,
                        child: Text(
                          p.title,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _selectedPost = value),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _messageController,
                maxLines: 3,
                maxLength: 200,
                decoration: const InputDecoration(
                  labelText: '제안 메시지 (선택)',
                  hintText: '근무 일정·우대 사항 등을 간단히 적어 주세요.',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _sending || _activePosts.isEmpty ? null : _send,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _sending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('제안 보내기'),
            ),
          ],
        ),
      ),
    );
  }
}
