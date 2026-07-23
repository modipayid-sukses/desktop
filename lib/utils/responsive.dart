import 'package:flutter/material.dart';

/// Responsive breakpoints untuk berbagai ukuran layar
class ResponsiveBreakpoints {
  static const double mobileMax = 480;
  static const double tabletMin = 480;
  static const double tabletMax = 768;
  static const double desktopMin = 768;
  static const double desktopMax = 1024;
  static const double largeDesktopMin = 1024;
  static const double largeDesktopMax = 1440;
  static const double xlargeDesktopMin = 1440;
}

/// Helper class untuk responsive design
class ResponsiveHelper {
  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < ResponsiveBreakpoints.tabletMin;

  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= ResponsiveBreakpoints.tabletMin &&
      MediaQuery.of(context).size.width < ResponsiveBreakpoints.desktopMin;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= ResponsiveBreakpoints.desktopMin &&
      MediaQuery.of(context).size.width < ResponsiveBreakpoints.largeDesktopMin;

  static bool isLargeDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= ResponsiveBreakpoints.largeDesktopMin;

  static bool isXlargeDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= ResponsiveBreakpoints.xlargeDesktopMin;

  static double getMaxWidth(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (isXlargeDesktop(context)) return 1400;
    if (isLargeDesktop(context)) return 1000;
    if (isDesktop(context)) return 900;
    if (isTablet(context)) return 700;
    return width - 32;
  }

  static int getGridColumns(BuildContext context) {
    if (isXlargeDesktop(context)) return 5;
    if (isLargeDesktop(context)) return 4;
    if (isDesktop(context)) return 3;
    if (isTablet(context)) return 2;
    return 1;
  }

  static EdgeInsets getPadding(BuildContext context) {
    if (isXlargeDesktop(context)) return EdgeInsets.all(48);
    if (isLargeDesktop(context)) return EdgeInsets.all(32);
    if (isDesktop(context)) return EdgeInsets.all(24);
    if (isTablet(context)) return EdgeInsets.all(20);
    return EdgeInsets.all(16);
  }

  static double getIconSize(BuildContext context) {
    if (isLargeDesktop(context)) return 36;
    if (isDesktop(context)) return 32;
    if (isTablet(context)) return 28;
    return 24;
  }

  static Orientation getOrientation(BuildContext context) =>
      MediaQuery.of(context).orientation;

  static bool isPortrait(BuildContext context) =>
      getOrientation(context) == Orientation.portrait;

  static bool isLandscape(BuildContext context) =>
      getOrientation(context) == Orientation.landscape;

  static Size getScreenSize(BuildContext context) {
    return MediaQuery.of(context).size;
  }
}

/// Extension methods untuk convenience
extension ResponsiveExt on BuildContext {
  bool get isMobile => ResponsiveHelper.isMobile(this);
  bool get isTablet => ResponsiveHelper.isTablet(this);
  bool get isDesktop => ResponsiveHelper.isDesktop(this);
  bool get isLargeDesktop => ResponsiveHelper.isLargeDesktop(this);
  bool get isXlargeDesktop => ResponsiveHelper.isXlargeDesktop(this);

  double get maxWidth => ResponsiveHelper.getMaxWidth(this);
  int get gridColumns => ResponsiveHelper.getGridColumns(this);
  EdgeInsets get padding => ResponsiveHelper.getPadding(this);
  double get iconSize => ResponsiveHelper.getIconSize(this);

  bool get isPortrait => ResponsiveHelper.isPortrait(this);
  bool get isLandscape => ResponsiveHelper.isLandscape(this);

  Size get screenSize => ResponsiveHelper.getScreenSize(this);
}

/// Responsive widget builder untuk conditional UI
class ResponsiveWidget extends StatelessWidget {
  final WidgetBuilder mobile;
  final WidgetBuilder? tablet;
  final WidgetBuilder? desktop;
  final WidgetBuilder? largeDesktop;

  const ResponsiveWidget({
    required this.mobile,
    this.tablet,
    this.desktop,
    this.largeDesktop,
  });

  @override
  Widget build(BuildContext context) {
    if (context.isXlargeDesktop && largeDesktop != null) {
      return largeDesktop!(context);
    }
    if (context.isLargeDesktop && desktop != null) {
      return desktop!(context);
    }
    if (context.isDesktop && desktop != null) {
      return desktop!(context);
    }
    if (context.isTablet && tablet != null) {
      return tablet!(context);
    }
    return mobile(context);
  }
}

/// Legacy compatibility
const double kDesktopBreakpoint = 900;

bool isDesktop(BuildContext context) =>
    MediaQuery.of(context).size.width >= kDesktopBreakpoint;

bool isDesktopPopup(BuildContext context) {
  try {
    return Theme.of(context).appBarTheme.shadowColor == const Color(0xFF000007);
  } catch (_) {
    return false;
  }
}
