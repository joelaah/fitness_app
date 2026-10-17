import 'package:flutter/material.dart';

/// Centralized responsive breakpoint tokens and layout queries for PulseFit AI.
class AppBreakpoints {
  AppBreakpoints._();

  static const double mobileMax = 899.0;
  static const double desktopMin = 900.0;
  static const double wideDesktopMin = 1200.0;

  static const double contentMaxWidth = 1200.0;
  static const double splitViewMaxWidth = 1440.0;
  static const double marketplaceMaxWidth = 1280.0;
  static const double chatSplitMaxWidth = 1400.0;

  /// Returns true when viewport width < 900 logical pixels.
  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < desktopMin;

  /// Returns true when viewport width >= 900 logical pixels.
  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= desktopMin;

  /// Returns true when viewport width >= 1200 logical pixels.
  static bool isWideDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= wideDesktopMin;
}
