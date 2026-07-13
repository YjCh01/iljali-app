import 'package:flutter/material.dart';

/// 지도 영역 재검색 — 현재 위치 버튼 아래 새로고침 아이콘
class MapSearchAreaButton extends StatelessWidget {
  const MapSearchAreaButton({
    super.key,
    required this.onPressed,
    this.loading = false,
  });

  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 3,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(10),
      color: Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: loading ? null : onPressed,
        child: SizedBox(
          width: 44,
          height: 44,
          child: loading
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: Color(0xFF757575),
                  ),
                )
              : const Icon(
                  Icons.refresh_rounded,
                  size: 22,
                  color: Color(0xFF757575),
                ),
        ),
      ),
    );
  }
}
