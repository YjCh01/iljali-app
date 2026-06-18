import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/features/commute/domain/utils/shuttle_route_color_utils.dart';
import 'package:map/features/commute/presentation/widgets/shuttle_route_color_dialogs.dart';

enum _ShuttleColorPickerMode { circle, block, rgb }

/// 노선 색상 — 원형 색상환·블록 팔레트 팝업 + RGB 직접 입력
class ShuttleRouteColorPicker extends StatefulWidget {
  const ShuttleRouteColorPicker({
    super.key,
    required this.colorHex,
    required this.onChanged,
  });

  final String colorHex;
  final ValueChanged<String> onChanged;

  @override
  State<ShuttleRouteColorPicker> createState() => _ShuttleRouteColorPickerState();
}

class _ShuttleRouteColorPickerState extends State<ShuttleRouteColorPicker> {
  _ShuttleColorPickerMode _mode = _ShuttleColorPickerMode.circle;
  late TextEditingController _rController;
  late TextEditingController _gController;
  late TextEditingController _bController;
  late TextEditingController _hexController;

  @override
  void initState() {
    super.initState();
    final rgb = ShuttleRouteColorUtils.rgbFromHex(widget.colorHex);
    _rController = TextEditingController(text: '${rgb.r}');
    _gController = TextEditingController(text: '${rgb.g}');
    _bController = TextEditingController(text: '${rgb.b}');
    _hexController = TextEditingController(text: widget.colorHex.toUpperCase());
  }

  @override
  void didUpdateWidget(covariant ShuttleRouteColorPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.colorHex != widget.colorHex) {
      _syncControllerTexts(widget.colorHex);
    }
  }

  @override
  void dispose() {
    _rController.dispose();
    _gController.dispose();
    _bController.dispose();
    _hexController.dispose();
    super.dispose();
  }

  Color get _selectedColor => ShuttleRouteColorUtils.parseHex(widget.colorHex);

  void _syncControllerTexts(String hex) {
    final rgb = ShuttleRouteColorUtils.rgbFromHex(hex);
    _rController.text = '${rgb.r}';
    _gController.text = '${rgb.g}';
    _bController.text = '${rgb.b}';
    _hexController.text = hex.toUpperCase();
  }

  void _selectHex(String hex) {
    widget.onChanged(hex.toUpperCase());
    _syncControllerTexts(hex);
  }

  void _applyRgbFromFields() {
    final r = int.tryParse(_rController.text.trim()) ?? 0;
    final g = int.tryParse(_gController.text.trim()) ?? 0;
    final b = int.tryParse(_bController.text.trim()) ?? 0;
    _selectHex(ShuttleRouteColorUtils.hexFromRgb(r, g, b));
  }

  void _applyHexField() {
    var raw = _hexController.text.trim();
    if (!raw.startsWith('#')) raw = '#$raw';
    if (!ShuttleRouteColorUtils.isValidHex(raw)) return;
    _selectHex(raw.toUpperCase());
  }

  Future<void> _openPalette() async {
    final hex = switch (_mode) {
      _ShuttleColorPickerMode.circle => await showShuttleCircleColorPickerDialog(
          context,
          initialHex: widget.colorHex,
        ),
      _ShuttleColorPickerMode.block => await showShuttleBlockColorPickerDialog(
          context,
          initialHex: widget.colorHex,
        ),
      _ShuttleColorPickerMode.rgb => null,
    };
    if (hex != null && mounted) _selectHex(hex);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<_ShuttleColorPickerMode>(
          segments: const [
            ButtonSegment(
              value: _ShuttleColorPickerMode.circle,
              label: Text('원형'),
              icon: Icon(Icons.lens_outlined, size: 16),
            ),
            ButtonSegment(
              value: _ShuttleColorPickerMode.block,
              label: Text('블록'),
              icon: Icon(Icons.crop_square_outlined, size: 16),
            ),
            ButtonSegment(
              value: _ShuttleColorPickerMode.rgb,
              label: Text('RGB'),
              icon: Icon(Icons.tune, size: 16),
            ),
          ],
          selected: {_mode},
          onSelectionChanged: (next) async {
            final picked = next.first;
            setState(() => _mode = picked);
            if (picked != _ShuttleColorPickerMode.rgb) {
              await _openPalette();
            }
          },
        ),
        const SizedBox(height: 12),
        if (_mode == _ShuttleColorPickerMode.rgb)
          _RgbInputs(
            rController: _rController,
            gController: _gController,
            bController: _bController,
            hexController: _hexController,
            previewColor: _selectedColor,
            onApplyRgb: _applyRgbFromFields,
            onApplyHex: _applyHexField,
          )
        else
          Material(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: _openPalette,
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _selectedColor,
                        shape: _mode == _ShuttleColorPickerMode.circle
                            ? BoxShape.circle
                            : BoxShape.rectangle,
                        borderRadius: _mode == _ShuttleColorPickerMode.block
                            ? BorderRadius.circular(8)
                            : null,
                        border: Border.all(
                          color: AppColors.textSecondary.withValues(alpha: 0.35),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.colorHex.toUpperCase(),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _mode == _ShuttleColorPickerMode.circle
                                ? '탭하면 원형 색상환 팝업'
                                : '탭하면 블록형 팔레트 팝업',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary.withValues(alpha: 0.95),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.palette_outlined,
                      color: AppColors.primary.withValues(alpha: 0.85),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _RgbInputs extends StatelessWidget {
  const _RgbInputs({
    required this.rController,
    required this.gController,
    required this.bController,
    required this.hexController,
    required this.previewColor,
    required this.onApplyRgb,
    required this.onApplyHex,
  });

  final TextEditingController rController;
  final TextEditingController gController;
  final TextEditingController bController;
  final TextEditingController hexController;
  final Color previewColor;
  final VoidCallback onApplyRgb;
  final VoidCallback onApplyHex;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: _channelField('R', rController, onApplyRgb)),
            const SizedBox(width: 8),
            Expanded(child: _channelField('G', gController, onApplyRgb)),
            const SizedBox(width: 8),
            Expanded(child: _channelField('B', bController, onApplyRgb)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: previewColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.textSecondary.withValues(alpha: 0.3),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: hexController,
                decoration: const InputDecoration(
                  labelText: 'HEX',
                  hintText: '#E53935',
                  isDense: true,
                ),
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[#0-9A-Fa-f]')),
                ],
                onSubmitted: (_) => onApplyHex(),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonal(
              onPressed: onApplyHex,
              child: const Text('적용'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _channelField(
    String label,
    TextEditingController controller,
    VoidCallback onSubmitted,
  ) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
      ),
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(3),
      ],
      onSubmitted: (_) => onSubmitted(),
      onEditingComplete: onSubmitted,
    );
  }
}
