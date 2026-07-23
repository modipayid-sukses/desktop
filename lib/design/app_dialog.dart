import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:modipay/utils/color.dart';
import 'package:modipay/utils/colornotifire.dart';
import 'app_button.dart';
import 'app_tokens.dart';

enum AppDialogTone { neutral, success, error, warning }

/// shadcn/ui-style alert dialog: centered card, subtle 1px border instead
/// of heavy elevation, tone icon, and a right-aligned action row
/// (secondary action first, primary action last).
class AppDialog extends StatelessWidget {
  final String title;
  final String? description;
  final Widget? body;
  final AppDialogTone tone;
  final String? primaryActionText;
  final String? secondaryActionText;
  final bool primaryIsDestructive;

  const AppDialog({
    super.key,
    required this.title,
    this.description,
    this.body,
    this.tone = AppDialogTone.neutral,
    this.primaryActionText,
    this.secondaryActionText,
    this.primaryIsDestructive = false,
  });

  IconData get _icon {
    switch (tone) {
      case AppDialogTone.success:
        return Icons.check_circle_rounded;
      case AppDialogTone.error:
        return Icons.error_rounded;
      case AppDialogTone.warning:
        return Icons.warning_rounded;
      case AppDialogTone.neutral:
        return Icons.info_rounded;
    }
  }

  Color _iconColor(bool isDark) {
    switch (tone) {
      case AppDialogTone.success:
        return success500;
      case AppDialogTone.error:
        return error500;
      case AppDialogTone.warning:
        return warning500;
      case AppDialogTone.neutral:
        return isDark ? grey200 : grey700;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ColorNotifire>().getIsDark;
    final surface = isDark ? grey800 : Colors.white;
    final borderColor = isDark ? grey600 : grey200;
    final titleColor = isDark ? Colors.white : grey900;
    final descColor = isDark ? grey200 : grey500;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 360),
        padding: const EdgeInsets.all(AppSpacing.xxl),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(AppRadius.dialog),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _iconColor(isDark).withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(_icon, color: _iconColor(isDark), size: 24),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title,
              style: TextStyle(
                fontFamily: 'Gilroy Bold',
                fontSize: 17,
                color: titleColor,
              ),
            ),
            if (description != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                description!,
                style: TextStyle(
                  fontFamily: 'Gilroy Medium',
                  fontSize: 14,
                  height: 1.4,
                  color: descColor,
                ),
              ),
            ],
            if (body != null) ...[
              const SizedBox(height: AppSpacing.lg),
              body!,
            ],
            if (primaryActionText != null || secondaryActionText != null) ...[
              const SizedBox(height: AppSpacing.xxl),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (secondaryActionText != null)
                    AppButton.secondary(
                      label: secondaryActionText!,
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                  if (secondaryActionText != null && primaryActionText != null)
                    const SizedBox(width: AppSpacing.sm),
                  if (primaryActionText != null)
                    primaryIsDestructive
                        ? AppButton.destructive(
                            label: primaryActionText!,
                            onPressed: () => Navigator.of(context).pop(true),
                          )
                        : AppButton.neutral(
                            label: primaryActionText!,
                            onPressed: () => Navigator.of(context).pop(true),
                          ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Shows the dialog and resolves to `true` when the primary action is
  /// tapped, `false` for the secondary action, and `null` if dismissed.
  static Future<bool?> show({
    required BuildContext context,
    required String title,
    String? description,
    Widget? body,
    AppDialogTone tone = AppDialogTone.neutral,
    String? primaryActionText,
    String? secondaryActionText,
    bool primaryIsDestructive = false,
    bool barrierDismissible = true,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierColor: Colors.black.withOpacity(0.45),
      builder: (_) => AppDialog(
        title: title,
        description: description,
        body: body,
        tone: tone,
        primaryActionText: primaryActionText,
        secondaryActionText: secondaryActionText,
        primaryIsDestructive: primaryIsDestructive,
      ),
    );
  }

  /// Convenience for a yes/no confirmation. Returns `true` only when the
  /// user taps the confirm action.
  static Future<bool> confirm({
    required BuildContext context,
    required String title,
    String? description,
    String confirmText = 'Ya',
    String cancelText = 'Batal',
    bool isDestructive = false,
  }) async {
    final result = await show(
      context: context,
      title: title,
      description: description,
      tone: isDestructive ? AppDialogTone.warning : AppDialogTone.neutral,
      primaryActionText: confirmText,
      secondaryActionText: cancelText,
      primaryIsDestructive: isDestructive,
    );
    return result == true;
  }

  static Future<void> success({
    required BuildContext context,
    required String title,
    String? description,
    String actionText = 'Selesai',
    bool barrierDismissible = false,
  }) {
    return show(
      context: context,
      title: title,
      description: description,
      tone: AppDialogTone.success,
      primaryActionText: actionText,
      barrierDismissible: barrierDismissible,
    );
  }

  static Future<void> error({
    required BuildContext context,
    required String title,
    String? description,
    String actionText = 'Tutup',
  }) {
    return show(
      context: context,
      title: title,
      description: description,
      tone: AppDialogTone.error,
      primaryActionText: actionText,
    );
  }
}
