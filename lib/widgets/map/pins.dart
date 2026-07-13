import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class PinTail extends StatelessWidget {
  final Color color;
  final double width;
  final double height;
  const PinTail({super.key, required this.color, this.width = 14, this.height = 9});

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: _TailClipper(),
      child: Container(width: width, height: height, color: color),
    );
  }
}

class _TailClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width / 2, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class WorkplacePin extends StatelessWidget {
  final bool isPaid;
  final Color brandColor;
  const WorkplacePin({super.key, required this.isPaid, this.brandColor = AppColors.purple});

  @override
  Widget build(BuildContext context) {
    final fill = isPaid ? brandColor : AppColors.freeGray;
    final head = Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isPaid)
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.purpleRing, width: 2),
            ),
            child: head,
          )
        else
          head,
        Transform.translate(offset: const Offset(0, -2), child: PinTail(color: fill)),
      ],
    );
  }
}

class JobAlertPin extends StatelessWidget {
  final Color brandColor;
  const JobAlertPin({super.key, this.brandColor = AppColors.purple});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 34,
          height: 30,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 4,
                top: 4,
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(color: brandColor, shape: BoxShape.circle),
                ),
              ),
              Positioned(
                right: 0,
                top: 0,
                child: ClipPath(
                  clipper: _FlagClipper(),
                  child: Container(width: 12, height: 10, color: brandColor),
                ),
              ),
            ],
          ),
        ),
        Transform.translate(offset: const Offset(0, -2), child: PinTail(color: brandColor)),
      ],
    );
  }
}

class _FlagClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width, size.height / 2);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class StopPin extends StatelessWidget {
  final Color brandColor;
  const StopPin({super.key, this.brandColor = AppColors.purple});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(color: brandColor, borderRadius: BorderRadius.circular(8)),
          child: const Icon(Icons.directions_bus_rounded, color: Colors.white, size: 15),
        ),
        Transform.translate(offset: const Offset(0, -2), child: PinTail(color: brandColor)),
      ],
    );
  }
}

class ClusterBadge extends StatelessWidget {
  final int count;
  const ClusterBadge({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: const BoxDecoration(color: Color(0xFF1A1A1A), shape: BoxShape.circle),
      child: Text(
        '+$count',
        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}
