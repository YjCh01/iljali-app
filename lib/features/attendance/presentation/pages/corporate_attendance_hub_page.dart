import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/core/widgets/app_back_button.dart';
import 'package:map/features/attendance/domain/services/daily_attendance_code_service.dart';
import 'package:map/features/corporate/presentation/widgets/corporate_surface_card.dart';

/// 기업 — 일일 출근 QR 코드 생성·표시
class CorporateAttendanceHubPage extends StatefulWidget {
  const CorporateAttendanceHubPage({super.key});

  @override
  State<CorporateAttendanceHubPage> createState() =>
      _CorporateAttendanceHubPageState();
}

class _CorporateAttendanceHubPageState
    extends State<CorporateAttendanceHubPage> {
  String? _code;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final profile = AuthSession.instance.currentUser?.corporateProfile;
    if (profile == null) {
      setState(() => _loading = false);
      return;
    }
    final service = await DailyAttendanceCodeService.create();
    final code = await service.getOrCreateCode(companyKey: profile.companyKey);
    if (!mounted) return;
    setState(() {
      _code = code;
      _loading = false;
    });
  }

  void _copyCode() {
    final code = _code;
    if (code == null) return;
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('코드를 복사했습니다.')),
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
        title: const Text(
          '출근 QR 코드',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
            tooltip: '새로고침',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CorporateSurfaceCard(
                    child: Column(
                      children: [
                        const Text(
                          '오늘의 출근 코드',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _code ?? '------',
                          style: const TextStyle(
                            fontSize: 42,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 12,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          '구직자가 QR 출근 화면에서 이 코드를 입력합니다.\n매일 자동으로 갱신됩니다.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, height: 1.45),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _code == null ? null : _copyCode,
                    icon: const Icon(Icons.copy),
                    label: const Text(
                      '코드 복사',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
