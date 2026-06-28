import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/core/widgets/app_back_button.dart';
import 'package:map/features/corporate/domain/entities/talent_search_entry.dart';
import 'package:map/features/corporate/domain/services/talent_search_service.dart';
import 'package:map/features/corporate/presentation/widgets/corporate_surface_card.dart';
import 'package:map/features/corporate/presentation/widgets/send_job_proposal_sheet.dart';
import 'package:map/features/corporate/presentation/widgets/talent_search_card.dart';
import 'package:map/features/credential/domain/entities/credential_catalog.dart';
import 'package:map/features/job_seeker/domain/data/seeker_work_region_catalog.dart';
import 'package:map/features/job_seeker/domain/entities/seeker_work_availability.dart';

/// 기업 — 인재 검색 (자격·지역·요일 필터)
class CorporateTalentSearchPage extends StatefulWidget {
  const CorporateTalentSearchPage({super.key});

  @override
  State<CorporateTalentSearchPage> createState() =>
      _CorporateTalentSearchPageState();
}

class _CorporateTalentSearchPageState extends State<CorporateTalentSearchPage> {
  final Set<String> _credentialIds = {};
  final Set<String> _regions = {};
  final Set<int> _weekdays = {};
  final _regionSearchController = TextEditingController();
  String? _regionSidoFilter;

  List<TalentSearchEntry> _results = [];
  bool _loading = true;

  String? get _companyKey =>
      AuthSession.instance.currentUser?.corporateProfile?.companyKey;

  String get _companyName =>
      AuthSession.instance.currentUser?.corporateProfile?.companyName ??
      AuthSession.instance.currentUser?.name ??
      '기업';

  @override
  void dispose() {
    _regionSearchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _search();
  }

  Future<void> _search() async {
    setState(() => _loading = true);
    final results = await TalentSearchService.search(
      TalentSearchFilter(
        credentialIds: _credentialIds.toList(),
        regions: _regions.toList(),
        weekdays: _weekdays.toList(),
      ),
    );
    if (!mounted) return;
    setState(() {
      _results = results;
      _loading = false;
    });
  }

  Future<void> _propose(TalentSearchEntry entry) async {
    final companyKey = _companyKey;
    if (companyKey == null || companyKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('기업 프로필을 먼저 완료해 주세요.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    await showSendJobProposalSheet(
      context,
      entry: entry,
      companyKey: companyKey,
      companyName: _companyName,
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
        title: const Text(
          '인재 검색',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _search,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            CorporateSurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '필터',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '이름·연락처는 제안 수락 전까지 비공개입니다.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary.withValues(alpha: 0.95),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '자격·면허',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: CredentialCatalog.all.take(8).map((cred) {
                      final selected = _credentialIds.contains(cred.id);
                      return FilterChip(
                        label: Text(
                          cred.label,
                          style: const TextStyle(fontSize: 11),
                        ),
                        selected: selected,
                        onSelected: (value) {
                          setState(() {
                            if (value) {
                              _credentialIds.add(cred.id);
                            } else {
                              _credentialIds.remove(cred.id);
                            }
                          });
                          _search();
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '희망 지역',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _regionSearchController,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      isDense: true,
                      hintText: '시·군·구 검색',
                      prefixIcon: Icon(Icons.search, size: 20),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: SeekerWorkRegionCatalog.sidos.take(8).map((sido) {
                      final selected = _regionSidoFilter == sido;
                      return FilterChip(
                        label: Text(sido, style: const TextStyle(fontSize: 11)),
                        selected: selected,
                        onSelected: (value) {
                          setState(() {
                            _regionSidoFilter = value ? sido : null;
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: SeekerWorkRegionCatalog.search(
                      query: _regionSearchController.text.trim(),
                      sido: _regionSidoFilter,
                      limit: 16,
                    ).map((region) {
                      final selected = _regions.contains(region);
                      return FilterChip(
                        label: Text(
                          region,
                          style: const TextStyle(fontSize: 11),
                        ),
                        selected: selected,
                        onSelected: (value) {
                          setState(() {
                            if (value) {
                              _regions.add(region);
                            } else {
                              _regions.remove(region);
                            }
                          });
                          _search();
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '출근 가능 요일',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: List.generate(7, (weekday) {
                      final label = SeekerAvailabilitySlot.weekdayLabels[weekday];
                      final selected = _weekdays.contains(weekday);
                      return FilterChip(
                        label: Text(label),
                        selected: selected,
                        onSelected: (value) {
                          setState(() {
                            if (value) {
                              _weekdays.add(weekday);
                            } else {
                              _weekdays.remove(weekday);
                            }
                          });
                          _search();
                        },
                      );
                    }),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '검색 결과 ${_results.length}명',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_results.isEmpty)
              CorporateSurfaceCard(
                child: Text(
                  '조건에 맞는 인재가 없습니다. 필터를 조정하거나 구직자가 제안 수신에 동의했는지 확인해 주세요.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: AppColors.textSecondary.withValues(alpha: 0.95),
                  ),
                ),
              )
            else
              ..._results.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TalentSearchCard(
                    entry: entry,
                    onPropose: () => _propose(entry),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
