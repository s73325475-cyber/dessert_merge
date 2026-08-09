import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// PC 브라우저에서는 세로 모바일 프레임(430px)으로 표시, 실제 모바일은 전체 화면.
class WebMobileShell extends StatelessWidget {
  const WebMobileShell({super.key, required this.child});

  final Widget? child;

  static const double phoneWidth = 430;
  static const double phoneHeight = 932;

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb || child == null) return child ?? const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth > phoneWidth + 32;
        if (!wide) return child!;

        final height = constraints.maxHeight.clamp(0, phoneHeight).toDouble();
        final width = phoneWidth.clamp(0, constraints.maxWidth).toDouble();

        return ColoredBox(
          color: const Color(0xff120a1c),
          child: Center(
            child: Container(
              width: width,
              height: height > 0 ? height : phoneHeight,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x99000000),
                    blurRadius: 32,
                    offset: Offset(0, 16),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: child,
            ),
          ),
        );
      },
    );
  }
}
