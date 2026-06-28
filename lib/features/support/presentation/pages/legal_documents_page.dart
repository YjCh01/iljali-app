import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/legal/legal_document_catalog.dart';
import 'package:map/core/legal/legal_highlighted_text.dart';
import 'package:map/core/widgets/app_back_button.dart';

/// 약관·정책 전문 (`store/legal` 초안 — 노란 형광펜 = 법무 검토 전 수정 필수)
class LegalDocumentsPage extends StatefulWidget {
  const LegalDocumentsPage({super.key, this.initialDocumentId});

  final String? initialDocumentId;

  @override
  State<LegalDocumentsPage> createState() => _LegalDocumentsPageState();
}

class _LegalDocumentsPageState extends State<LegalDocumentsPage>
    with SingleTickerProviderStateMixin {
  late final Future<Map<String, String>> _documentsFuture;
  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    _documentsFuture = LegalDocumentCatalog.loadAll();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  int _initialTabIndex() {
    if (widget.initialDocumentId == null) return 0;
    final index = LegalDocumentCatalog.entries
        .indexWhere((e) => e.id == widget.initialDocumentId);
    return index < 0 ? 0 : index;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, String>>(
      future: _documentsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(
              backgroundColor: AppColors.surface,
              foregroundColor: AppColors.textPrimary,
              elevation: 0,
              leading: const AppBackButton(),
              title: const Text('약관 및 정책'),
            ),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(
              backgroundColor: AppColors.surface,
              foregroundColor: AppColors.textPrimary,
              elevation: 0,
              leading: const AppBackButton(),
              title: const Text('약관 및 정책'),
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  '약관을 불러오지 못했습니다.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ),
          );
        }

        final documents = snapshot.data!;
        _tabController ??= TabController(
          length: LegalDocumentCatalog.entries.length,
          vsync: this,
          initialIndex: _initialTabIndex(),
        );

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.surface,
            foregroundColor: AppColors.textPrimary,
            elevation: 0,
            leading: const AppBackButton(),
            title: const Text('약관 및 정책'),
            bottom: TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.primary,
              tabAlignment: TabAlignment.start,
              tabs: [
                for (final entry in LegalDocumentCatalog.entries)
                  Tab(text: entry.shortTabLabel ?? entry.title),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              for (final entry in LegalDocumentCatalog.entries)
                _LegalScroll(raw: documents[entry.id] ?? ''),
            ],
          ),
        );
      },
    );
  }
}

class _LegalScroll extends StatelessWidget {
  const _LegalScroll({required this.raw});

  final String raw;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: LegalHighlightedText(raw: raw),
    );
  }
}
