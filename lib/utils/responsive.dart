import 'package:flutter/widgets.dart';

/// Lebar minimum (logical px) sebelum UI beralih dari layout mobile
/// (single column, bottom nav) ke layout desktop (sidebar + topbar),
/// mengikuti referensi desain `login.jpeg` / `dashboard.jpeg`.
const double kDesktopBreakpoint = 900;

bool isDesktop(BuildContext context) =>
    MediaQuery.of(context).size.width >= kDesktopBreakpoint;
