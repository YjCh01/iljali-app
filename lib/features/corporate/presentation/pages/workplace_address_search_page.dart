import 'package:flutter/material.dart';

import 'package:map/core/address/address_geocoder.dart';
import 'package:map/core/address/daum_postcode_picker_page.dart';
import 'package:map/core/address/workplace_address_mapper.dart';
import 'package:map/core/address/workplace_address_platform.dart';
import 'package:map/core/address/workplace_address_qc.dart';
import 'package:map/core/config/dev_experience_flags.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/widgets/app_back_button.dart';
import 'package:map/features/corporate/domain/entities/workplace_address.dart';

/// 근무지 — 앱·웹 동일: 탭 → 전체화면 도로명주소 검색 · 데스크톱 수동 입력
class WorkplaceAddressSearchPage extends StatefulWidget {
  const WorkplaceAddressSearchPage({
    super.key,
    this.initialQuery,
  });

  final String? initialQuery;

  @override
  State<WorkplaceAddressSearchPage> createState() =>
      _WorkplaceAddressSearchPageState();
}

class _WorkplaceAddressSearchPageState extends State<WorkplaceAddressSearchPage> {
  final _queryController = TextEditingController();
  final _detailController = TextEditingController();
  final _searchFocusNode = FocusNode();

  WorkplaceAddress? _selected;
  bool _resolvingCoordinates = false;
  String? _statusMessage;
  bool _showQcManual = false;

  bool get _qcPrimaryMode => WorkplaceAddressPlatform.isQcManualPrimaryMode;

  @override
  void initState() {
    super.initState();
    if (_qcPrimaryMode) {
      _showQcManual = true;
      _applyQcSample(prefillFields: widget.initialQuery == null);
      if (widget.initialQuery != null) {
        _queryController.text = widget.initialQuery!;
      }
    } else if (widget.initialQuery != null) {
      _queryController.text = widget.initialQuery!;
    }
  }

  @override
  void dispose() {
    _queryController.dispose();
    _detailController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _applyQcSample({bool prefillFields = true}) {
    final sample = WorkplaceAddressQc.sample();
    setState(() {
      _selected = sample;
      _statusMessage = DevExperienceFlags.enabled
          ? 'QC 샘플 좌표(강남)로 저장됩니다.'
          : '주소는 저장되며, 좌표는 서버 지오코딩으로 보완됩니다.';
      if (prefillFields) {
        _queryController.text = sample.roadAddress;
        _detailController.clear();
      }
    });
  }

  Future<void> _openPostcodePicker() async {
    _searchFocusNode.unfocus();
    FocusScope.of(context).unfocus();

    final result = await DaumPostcodePickerPage.show(context);
    if (!mounted || result == null) return;

    setState(() {
      _resolvingCoordinates = true;
      _statusMessage = null;
      _showQcManual = false;
    });

    final road = result.roadAddress.trim().isNotEmpty
        ? result.roadAddress.trim()
        : result.address.trim();
    final coordinate = await AddressGeocoder.geocode(road);

    if (!mounted) return;
    setState(() {
      _selected = WorkplaceAddressMapper.fromDaumPostcode(
        result,
        coordinate: coordinate,
      );
      _queryController.text = road;
      _detailController.clear();
      _resolvingCoordinates = false;
      if (coordinate == null) {
        _statusMessage =
            '주소는 선택되었습니다. 좌표는 서버 API 키 설정 시 자동 보완됩니다.';
      }
    });
  }

  void _applyManualQcInput() {
    final road = _queryController.text.trim();
    if (road.length < 4) {
      setState(() {
        _statusMessage = '도로명·동 이름을 4자 이상 입력해 주세요.';
      });
      return;
    }
    setState(() {
      _selected = WorkplaceAddressQc.fromManualInput(
        roadAddress: road,
        detailAddress: _detailController.text,
      );
      _statusMessage = DevExperienceFlags.enabled
          ? 'QC 샘플 좌표(강남)로 저장됩니다.'
          : '주소는 저장되며, 좌표는 서버 지오코딩으로 보완됩니다.';
    });
  }

  void _confirm() {
    final selected = _selected;
    if (selected == null) return;
    Navigator.of(context).pop(
      selected.copyWith(
        detailAddress: _detailController.text.trim().isEmpty
            ? null
            : _detailController.text.trim(),
      ),
    );
  }

  InputDecoration _searchDecoration({String? hintText}) {
    return InputDecoration(
      hintText: hintText ?? '동·도로명 검색...',
      prefixIcon: const Icon(Icons.search_rounded),
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.searchBarBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.searchBarBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: AppColors.primary,
          width: 1.5,
        ),
      ),
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
        title: const Text('근무지 검색'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_qcPrimaryMode) _buildQcBanner(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _queryController,
              focusNode: _searchFocusNode,
              readOnly: !_showQcManual && !_qcPrimaryMode,
              showCursor: _showQcManual || _qcPrimaryMode,
              textInputAction: TextInputAction.next,
              onTap: _showQcManual || _qcPrimaryMode ? null : _openPostcodePicker,
              onSubmitted: (_) {
                if (_showQcManual || _qcPrimaryMode) _applyManualQcInput();
              },
              decoration: _searchDecoration(
                hintText: _showQcManual || _qcPrimaryMode
                    ? '도로명·동 직접 입력'
                    : '탭하여 동·도로명 검색',
              ),
            ),
          ),
          if (_statusMessage != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                _statusMessage!,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.35,
                  color: AppColors.textSecondary.withValues(alpha: 0.9),
                ),
              ),
            ),
          if (_showQcManual || _qcPrimaryMode) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                controller: _detailController,
                textInputAction: TextInputAction.done,
                decoration: _searchDecoration(
                  hintText: '상세 주소 (선택, 예: B동 2층)',
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  if (DevExperienceFlags.enabled) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _applyQcSample(),
                        child: const Text('샘플 주소 (QC)'),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: FilledButton.tonal(
                      onPressed: _applyManualQcInput,
                      child: const Text('입력 적용'),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (_selected != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                controller: _detailController,
                textInputAction: TextInputAction.done,
                decoration: _searchDecoration(
                  hintText: '상세 주소 (선택, 예: B동 2층)',
                ),
              ),
            ),
          Expanded(
            child: _resolvingCoordinates
                ? const Center(child: CircularProgressIndicator())
                : _selected == null
                    ? _buildEmptyState()
                    : _buildSelectedPreview(),
          ),
          if (_selected != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton(
                onPressed: _confirm,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  _qcPrimaryMode || _showQcManual
                      ? '이 주소로 계속'
                      : '이 주소 선택',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQcBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primaryLight.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Windows 등 데스크톱 앱에서는 도로명주소 검색을 사용할 수 없습니다. '
              'Chrome 웹 또는 모바일 앱에서 주소 검색을 이용하거나, 직접 입력으로 공고 등록을 이어갈 수 있습니다.',
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: AppColors.textSecondary.withValues(alpha: 0.95),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    if (_showQcManual || _qcPrimaryMode) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            '주소를 입력한 뒤 「입력 적용」을 눌러 주세요.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary.withValues(alpha: 0.95),
            ),
          ),
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '검색창을 탭하거나 아래 버튼으로\n동·도로명을 검색해 주세요',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary.withValues(alpha: 0.95),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _openPostcodePicker,
              icon: const Icon(Icons.search_rounded),
              label: const Text('주소 검색 열기'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => setState(() => _showQcManual = true),
              child: const Text('주소 검색이 안 될 때 직접 입력'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedPreview() {
    final selected = _selected!;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primaryLight.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.35),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '선택한 근무지',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  selected.roadAddress,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (selected.jibunAddress != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    '지번 ${selected.jibunAddress}',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary.withValues(alpha: 0.9),
                    ),
                  ),
                ],
                if (selected.coordinate != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    '좌표 ${selected.coordinate!.latitude.toStringAsFixed(5)}, '
                    '${selected.coordinate!.longitude.toStringAsFixed(5)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (!_qcPrimaryMode)
            TextButton(
              onPressed: _openPostcodePicker,
              child: const Text('다시 검색'),
            ),
        ],
      ),
    );
  }
}
