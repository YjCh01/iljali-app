import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/features/listings/data/repositories/listing_repository_impl.dart';
import 'package:map/features/listings/domain/usecases/create_listing_usecase.dart';
import 'package:map/features/map_dashboard/data/repositories/map_repository_impl.dart';

/// 채용 공고 등록 (글쓰기)
class CreateListingPage extends StatefulWidget {
  const CreateListingPage({super.key});

  @override
  State<CreateListingPage> createState() => _CreateListingPageState();
}

class _CreateListingPageState extends State<CreateListingPage> {
  final _createListing = CreateListingUseCase(ListingRepositoryImpl());
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _wageController = TextEditingController();

  List<String> _warehouseNames = [];
  String? _selectedWarehouse;
  bool _loadingWarehouses = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadWarehouses();
  }

  Future<void> _loadWarehouses() async {
    final warehouses = await MapRepositoryImpl().getWarehouses();
    if (!mounted) return;
    setState(() {
      _warehouseNames = warehouses.map((w) => w.name).toList();
      _selectedWarehouse =
          _warehouseNames.isNotEmpty ? _warehouseNames.first : null;
      _loadingWarehouses = false;
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _wageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;

    setState(() => _submitting = true);
    final result = await _createListing(
      title: _titleController.text,
      description: _descriptionController.text,
      warehouseName: _selectedWarehouse ?? '',
      hourlyWage: _wageController.text,
    );
    if (!mounted) return;
    setState(() => _submitting = false);

    if (!result.isSuccess) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(result.message ?? '등록에 실패했습니다.')),
        );
      return;
    }

    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        title: const Text('채용 공고 등록'),
      ),
      body: _loadingWarehouses
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _FieldLabel('제목'),
                  TextField(
                    controller: _titleController,
                    textInputAction: TextInputAction.next,
                    decoration: _inputDecoration('예: 당일배송 분류 알바 모집'),
                  ),
                  const SizedBox(height: 16),
                  _FieldLabel('근무지'),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.searchBarBorder),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: _selectedWarehouse,
                        hint: const Text('센터 선택'),
                        items: _warehouseNames
                            .map(
                              (name) => DropdownMenuItem(
                                value: name,
                                child: Text(name),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setState(() => _selectedWarehouse = value);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _FieldLabel('시급'),
                  TextField(
                    controller: _wageController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    textInputAction: TextInputAction.next,
                    decoration: _inputDecoration('예: 12500'),
                  ),
                  const SizedBox(height: 16),
                  _FieldLabel('상세 설명'),
                  TextField(
                    controller: _descriptionController,
                    minLines: 4,
                    maxLines: 6,
                    textInputAction: TextInputAction.done,
                    decoration: _inputDecoration('근무 내용, 우대 사항 등을 입력하세요'),
                  ),
                  const SizedBox(height: 28),
                  FilledButton(
                    onPressed: _submitting ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryLight,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _submitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            '등록하기',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
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
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}
