import 'package:flutter/material.dart';

abstract final class ResponsiveLayout {
  static const compactBreakpoint = 600.0;
  static const wideBreakpoint = 900.0;

  static bool isCompact(BuildContext context) =>
      MediaQuery.sizeOf(context).width < compactBreakpoint;

  static bool isWide(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= wideBreakpoint;

  static EdgeInsets pagePadding(BuildContext context) => EdgeInsets.symmetric(
        horizontal: isCompact(context) ? 16 : 24,
        vertical: isCompact(context) ? 16 : 24,
      );
}
