import 'package:flutter/material.dart';

class DesktopTitleWrapper extends StatelessWidget {
  final Widget child;
  const DesktopTitleWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    // If the elevation in appBarTheme is our special flag (0.007),
    // it means we are inside the desktop popup!
    final isPopup = Theme.of(context).appBarTheme.elevation == 0.007;
    if (isPopup) {
      return const SizedBox.shrink();
    }
    return child;
  }
}

/// Sembunyikan tombol back AppBar hanya untuk layar pertama di dalam popup
/// desktop (popup sudah punya tombol close-X sendiri). Layar yang di-push
/// lebih dalam di Navigator bersarang milik popup tetap butuh tombol back
/// agar bisa kembali ke layar sebelumnya di dalam popup.
class DesktopLeadingWrapper extends StatelessWidget {
  final Widget child;
  const DesktopLeadingWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isPopup = Theme.of(context).appBarTheme.elevation == 0.007;
    final isFirstInPopup = isPopup && (ModalRoute.of(context)?.isFirst ?? false);
    if (isFirstInPopup) {
      return const SizedBox.shrink();
    }
    return child;
  }
}
