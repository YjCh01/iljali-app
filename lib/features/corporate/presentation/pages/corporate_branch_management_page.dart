import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/constants/app_routes.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/core/widgets/app_back_button.dart';
import 'package:map/features/corporate/data/repositories/local_branch_repository.dart';
import 'package:map/features/corporate/domain/entities/corporate_branch.dart';
import 'package:map/features/corporate/domain/entities/workplace_address.dart';
import 'package:map/features/corporate/domain/utils/branch_plan_limits.dart';
import 'package:map/features/corporate/presentation/widgets/corporate_surface_card.dart';

/// Multi-지점 등록·관리
class CorporateBranchManagementPage extends StatefulWidget {
  const CorporateBranchManagementPage({super.key});

  @override
  State<CorporateBranchManagementPage> createState() =>
      _CorporateBranchManagementPageState();
}

class _CorporateBranchManagementPageState
    extends State<CorporateBranchManagementPage> {
  List<CorporateBranch> _branches = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = AuthSession.instance.currentUser?.corporateProfile;
    if (profile == null) {
      setState(() {
        _loading = false;
        _error = '기업 로그인이 필요합니다.';
      });
      return;
    }
    final repo = await LocalBranchRepository.create();
    final branches = await repo.fetchForCompany(profile.companyKey);
    if (!mounted) return;
    setState(() {
      _branches = branches;
      _loading = false;
    });
  }

  Future<void> _addBranch() async {
    final profile = AuthSession.instance.currentUser?.corporateProfile;
    if (profile == null) return;

    final tier = profile.partnershipTier;
    final max = BranchPlanLimits.maxBranches(tier);
    if (_branches.length >= max) {
      if (!mounted) return;
      final upgrade = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('지점 한도 초과'),
          content: Text(
            '현재 지점 한도(${BranchPlanLimits.limitLabel(tier)})에 도달했습니다.\n'
            '지역 푸시권을 구매해 지점을 추가하시겠습니까?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('닫기'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('지역 푸시권 상점'),
            ),
          ],
        ),
      );
      if (upgrade == true && mounted) {
        await Navigator.of(context).pushNamed(AppRoutes.corporatePushPackageShop);
        await _load();
      }
      return;
    }

    final nameController = TextEditingController();
    final addressController = TextEditingController();
    final managerController = TextEditingController();
    var selectedLevel = BranchLevel.store;
    String? selectedParentId;

    final created = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('지점 추가'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<BranchLevel>(
                  value: selectedLevel,
                  decoration: const InputDecoration(
                    labelText: '계층',
                    border: OutlineInputBorder(),
                  ),
                  items: BranchLevel.values
                      .map(
                        (level) => DropdownMenuItem(
                          value: level,
                          child: Text(level.label),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setDialogState(() {
                      selectedLevel = value;
                      if (value == BranchLevel.hq) selectedParentId = null;
                    });
                  },
                ),
                if (selectedLevel != BranchLevel.hq &&
                    _branches.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String?>(
                    value: selectedParentId,
                    decoration: const InputDecoration(
                      labelText: '상위 지점',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('상위 없음 (독립)'),
                      ),
                      ..._branches
                          .where((b) =>
                              b.level == BranchLevel.hq ||
                              b.level == BranchLevel.regional)
                          .map(
                            (b) => DropdownMenuItem(
                              value: b.id,
                              child: Text('${b.level.label} · ${b.name}'),
                            ),
                          ),
                    ],
                    onChanged: (value) =>
                        setDialogState(() => selectedParentId = value),
                  ),
                ],
                const SizedBox(height: 10),
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: selectedLevel == BranchLevel.hq
                        ? '본사명'
                        : selectedLevel == BranchLevel.regional
                            ? '지역명'
                            : '매장·센터명',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                InkWell(
                  onTap: () async {
                    final picked = await Navigator.of(context, rootNavigator: true)
                        .pushNamed(AppRoutes.corporateWorkplaceSearch);
                    if (picked is WorkplaceAddress) {
                      setDialogState(() {
                        addressController.text = picked.displayLabel;
                      });
                    }
                  },
                  borderRadius: BorderRadius.circular(4),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: '도로명 주소',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.search_rounded),
                    ),
                    child: Text(
                      addressController.text.isEmpty
                          ? '탭하여 도로명 주소 검색'
                          : addressController.text,
                      style: TextStyle(
                        color: addressController.text.isEmpty
                            ? Colors.grey
                            : null,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: managerController,
                  decoration: const InputDecoration(
                    labelText: '담당자 (선택)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('등록'),
            ),
          ],
        ),
      ),
    );

    if (created != true) {
      nameController.dispose();
      addressController.dispose();
      managerController.dispose();
      return;
    }

    if (nameController.text.trim().isEmpty ||
        addressController.text.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('센터명과 주소를 입력해 주세요.')),
        );
      }
      nameController.dispose();
      addressController.dispose();
      managerController.dispose();
      return;
    }

    final repo = await LocalBranchRepository.create();
    try {
      await repo.createBranch(
        companyKey: profile.companyKey,
        name: nameController.text,
        roadAddress: addressController.text,
        level: selectedLevel,
        parentBranchId: selectedParentId,
        managerName: managerController.text.trim().isEmpty
            ? null
            : managerController.text.trim(),
      );
    } on BranchHierarchyException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
      nameController.dispose();
      addressController.dispose();
      managerController.dispose();
      return;
    }
    nameController.dispose();
    addressController.dispose();
    managerController.dispose();
    if (mounted) await _load();
  }

  Future<void> _deactivate(CorporateBranch branch) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('지점 비활성화'),
        content: Text('「${branch.displayLabel}」을(를) 비활성화할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('비활성화'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final repo = await LocalBranchRepository.create();
    await repo.deactivate(branch.id);
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final profile = AuthSession.instance.currentUser?.corporateProfile;
    final tier = profile?.partnershipTier;
    final limitLabel =
        tier != null ? BranchPlanLimits.limitLabel(tier) : '-';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        leading: const AppBackButton(),
        automaticallyImplyLeading: false,
        title: const Text('Multi-지점 관리'),
        actions: [
          IconButton(
            onPressed: _addBranch,
            icon: const Icon(Icons.add_business_outlined),
            tooltip: '지점 추가',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Text(
                      '본사 · 지역 · 매장 계층 · 등록 ${_branches.length} / $limitLabel',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary.withValues(alpha: 0.95),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_branches.isEmpty)
                      CorporateSurfaceCard(
                        child: Text(
                          '등록된 지점이 없습니다. 「+」로 센터·창고를 추가하세요.',
                          style: TextStyle(
                            color: AppColors.textSecondary.withValues(alpha: 0.95),
                          ),
                        ),
                      )
                    else
                      ..._branches.map(
                        (branch) {
                          final parent = branch.parentBranchId == null
                              ? null
                              : _branches.cast<CorporateBranch?>().firstWhere(
                                    (b) => b?.id == branch.parentBranchId,
                                    orElse: () => null,
                                  );
                          final parentName = parent?.name;
                          return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: CorporateSurfaceCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryLight
                                            .withValues(alpha: 0.22),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        branch.level.label,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        branch.name,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (parentName != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    '↳ $parentName 하위',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary
                                          .withValues(alpha: 0.9),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 6),
                                Text(
                                  branch.roadAddress,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary
                                        .withValues(alpha: 0.95),
                                  ),
                                ),
                                if (branch.managerName != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    '담당: ${branch.managerName}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ],
                                const SizedBox(height: 10),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: () => _deactivate(branch),
                                    child: const Text('비활성화'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                        },
                      ),
                  ],
                ),
    );
  }
}
