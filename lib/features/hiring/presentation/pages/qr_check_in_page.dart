import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/geo/device_location_service.dart';
import 'package:map/core/hiring/attendance_geofence_service.dart';
import 'package:map/core/hiring/hiring_application.dart';
import 'package:map/core/hiring/hiring_refresh.dart';
import 'package:map/core/hiring/local_hiring_repository.dart';
import 'package:map/core/widgets/app_back_button.dart';
import 'package:map/features/attendance/domain/services/daily_attendance_code_service.dart';

/// QR·코드 백업 출근
class QrCheckInPage extends StatefulWidget {
  const QrCheckInPage({
    super.key,
    required this.application,
  });

  final HiringApplication application;

  @override
  State<QrCheckInPage> createState() => _QrCheckInPageState();
}

class _QrCheckInPageState extends State<QrCheckInPage> {
  final _codeController = TextEditingController();
  bool _checkingIn = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      setState(() => _error = '6자리 코드를 입력해 주세요.');
      return;
    }

    final companyKey = widget.application.companyKey;
    if (companyKey == null || companyKey.isEmpty) {
      setState(() => _error = '기업 정보를 확인할 수 없습니다.');
      return;
    }

    setState(() {
      _checkingIn = true;
      _error = null;
    });

    try {
      final codeService = await DailyAttendanceCodeService.create();
      final valid = await codeService.verifyCode(
        companyKey: companyKey,
        code: code,
      );
      if (!valid) {
        if (!mounted) return;
        setState(() {
          _error = '코드가 올바르지 않습니다. 담당자에게 확인해 주세요.';
          _checkingIn = false;
        });
        return;
      }

      final geofence = await AttendanceGeofenceService.evaluateCurrent(
        workplace: widget.application.workplaceCoordinate,
      );
      final detailed = await DeviceLocationService.getCurrentPositionDetailed();

      await AttendanceGeofenceService.logVerificationAttempt(
        applicationId: widget.application.id,
        role: 'seeker_qr',
        result: geofence,
        latitude: detailed?.coordinate.latitude,
        longitude: detailed?.coordinate.longitude,
        companyKey: widget.application.companyKey,
      );

      if (!geofence.allowed) {
        if (!mounted) return;
        setState(() {
          _error = geofence.userMessage;
          _checkingIn = false;
        });
        return;
      }

      final repo = await LocalHiringRepository.create();
      await repo.checkInWithQr(
        widget.application.id,
        latitude: detailed?.coordinate.latitude,
        longitude: detailed?.coordinate.longitude,
        geofenceVerified: geofence.allowed,
        geofenceDistanceMeters: geofence.distanceMeters,
      );
      HiringRefresh.markUpdated();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('QR 출근이 기록되었습니다.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = '출근 기록에 실패했습니다.';
        _checkingIn = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.application;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        leading: const AppBackButton(),
        automaticallyImplyLeading: false,
        title: const Text(
          'QR 출근',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              app.postTitle,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(app.companyName, style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 24),
            const Icon(Icons.qr_code_scanner, size: 72, color: AppColors.primary),
            const SizedBox(height: 12),
            const Text(
              '현장에 안내된 6자리 코드를 입력하세요.\n(스캔 기능은 준비 중입니다)',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, height: 1.45),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _codeController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: 8,
              ),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                counterText: '',
                hintText: '000000',
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const Spacer(),
            FilledButton(
              onPressed: _checkingIn ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size.fromHeight(52),
              ),
              child: _checkingIn
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      '코드로 출근하기',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
