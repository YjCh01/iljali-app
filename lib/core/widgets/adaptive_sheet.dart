import 'package:flutter/material.dart';
import 'package:map/core/widgets/web_right_navigation_rail.dart';

/// 모바일: bottom sheet · 넓은 웹: 우측 패널(dialog)
Future<T?> showAdaptiveSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
  bool useSafeArea = true,
}) {
  final wide = WebLayoutBreakpoints.isWideWeb(context);
  if (wide) {
    return showDialog<T>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Align(
        alignment: Alignment.centerRight,
        child: Material(
          elevation: 12,
          borderRadius: const BorderRadius.horizontal(
            left: Radius.circular(16),
          ),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            width: 480,
            height: MediaQuery.sizeOf(ctx).height,
            child: builder(ctx),
          ),
        ),
      ),
    );
  }

  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    useSafeArea: useSafeArea,
    showDragHandle: true,
    builder: builder,
  );
}
