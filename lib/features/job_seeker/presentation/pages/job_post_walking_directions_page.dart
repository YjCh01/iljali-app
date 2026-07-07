import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/utils/external_maps_launcher.dart';
import 'package:map/core/widgets/app_back_button.dart';
import 'package:map/features/job_seeker/presentation/widgets/job_post_walking_directions_map.dart';

/// 공고 상세 → 내 주소에서 근무지까지 도보 길찾기
class JobPostWalkingDirectionsPage extends StatelessWidget {
  const JobPostWalkingDirectionsPage({
    super.key,
    required this.originLabel,
    required this.destinationLabel,
    required this.originLatitude,
    required this.originLongitude,
    required this.destinationLatitude,
    required this.destinationLongitude,
  });

  final String originLabel;
  final String destinationLabel;
  final double originLatitude;
  final double originLongitude;
  final double destinationLatitude;
  final double destinationLongitude;

  Future<void> _openNaverDirections(BuildContext context) async {
    final opened = await openNaverDirections(
      destinationLabel: destinationLabel,
      destinationLatitude: destinationLatitude,
      destinationLongitude: destinationLongitude,
      originLatitude: originLatitude,
      originLongitude: originLongitude,
      originLabel: originLabel,
      mode: NaverDirectionsMode.walk,
    );
    if (!context.mounted) return;
    if (!opened) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('네이버 지도를 열 수 없습니다.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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
          '도보 길찾기',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            color: AppColors.primaryLight.withValues(alpha: 0.14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _RouteEndpointRow(
                  icon: Icons.home_outlined,
                  label: '출발 · 내 주소지',
                  value: originLabel,
                ),
                const SizedBox(height: 8),
                _RouteEndpointRow(
                  icon: Icons.place_outlined,
                  label: '도착 · 근무지',
                  value: destinationLabel,
                ),
              ],
            ),
          ),
          Expanded(
            child: JobPostWalkingDirectionsMap(
              originLatitude: originLatitude,
              originLongitude: originLongitude,
              destinationLatitude: destinationLatitude,
              destinationLongitude: destinationLongitude,
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '상세 경로·소요시간은 네이버 지도에서 확인할 수 있습니다.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: AppColors.textSecondary.withValues(alpha: 0.95),
                    ),
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: () => _openNaverDirections(context),
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('네이버 지도에서 상세 경로 보기'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteEndpointRow extends StatelessWidget {
  const _RouteEndpointRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
