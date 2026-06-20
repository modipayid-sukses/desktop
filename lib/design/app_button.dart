import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:modipay/utils/color.dart';
import 'package:modipay/utils/colornotifire.dart';
import 'app_tokens.dart';

enum AppButtonVariant { primary, secondary, destructive, ghost, success, neutral }

/// Minimal button set matching shadcn/ui's Button component: filled
/// primary, outlined secondary, filled destructive, and a borderless
/// ghost variant. Heights are fixed so action rows line up consistently.
class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool expand;
  final bool loading;
  final IconData? icon;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.expand = false,
    this.loading = false,
    this.icon,
  });

  const AppButton.primary({
    super.key,
    required this.label,
    required this.onPressed,
    this.expand = false,
    this.loading = false,
    this.icon,
  }) : variant = AppButtonVariant.primary;

  const AppButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.expand = false,
    this.loading = false,
    this.icon,
  }) : variant = AppButtonVariant.secondary;

  const AppButton.destructive({
    super.key,
    required this.label,
    required this.onPressed,
    this.expand = false,
    this.loading = false,
    this.icon,
  }) : variant = AppButtonVariant.destructive;

  const AppButton.ghost({
    super.key,
    required this.label,
    required this.onPressed,
    this.expand = false,
    this.loading = false,
    this.icon,
  }) : variant = AppButtonVariant.ghost;

  const AppButton.success({
    super.key,
    required this.label,
    required this.onPressed,
    this.expand = false,
    this.loading = false,
    this.icon,
  }) : variant = AppButtonVariant.success;

  /// Dark, brand-neutral fill (no blue) — used where a filled primary
  /// action is needed but the blue brand accent should be avoided, e.g.
  /// inside AppDialog.
  const AppButton.neutral({
    super.key,
    required this.label,
    required this.onPressed,
    this.expand = false,
    this.loading = false,
    this.icon,
  }) : variant = AppButtonVariant.neutral;

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ColorNotifire>().getIsDark;

    late final Color background;
    late final Color foreground;
    late final BorderSide border;

    switch (variant) {
      case AppButtonVariant.primary:
        background = primaryBlue500;
        foreground = Colors.white;
        border = BorderSide.none;
        break;
      case AppButtonVariant.secondary:
        background = Colors.transparent;
        foreground = isDark ? Colors.white : grey900;
        border = BorderSide(color: isDark ? grey600 : grey200);
        break;
      case AppButtonVariant.destructive:
        background = error500;
        foreground = Colors.white;
        border = BorderSide.none;
        break;
      case AppButtonVariant.ghost:
        background = Colors.transparent;
        foreground = isDark ? grey200 : grey600;
        border = BorderSide.none;
        break;
      case AppButtonVariant.success:
        background = success500;
        foreground = Colors.white;
        border = BorderSide.none;
        break;
      case AppButtonVariant.neutral:
        background = isDark ? Colors.white : grey900;
        foreground = isDark ? grey900 : Colors.white;
        border = BorderSide.none;
        break;
    }

    final child = loading
        ? SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: foreground),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: foreground),
                const SizedBox(width: AppSpacing.sm),
              ],
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Gilroy Bold',
                  fontSize: 14,
                  color: foreground,
                ),
              ),
            ],
          );

    final button = OutlinedButton(
      onPressed: loading ? null : onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: background,
        side: border,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        disabledBackgroundColor: background.withOpacity(0.6),
      ),
      child: child,
    );

    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}
