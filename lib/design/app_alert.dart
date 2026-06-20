import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:modipay/utils/color.dart';
import 'package:modipay/utils/colornotifire.dart';
import 'app_tokens.dart';

enum AppAlertTone { neutral, info, success, warning, error }

/// shadcn/ui-style inline Alert banner: tinted background, matching border
/// and icon, title + optional description. Used for inline error/info
/// messages instead of ad-hoc colored containers scattered per screen.
class AppAlert extends StatelessWidget {
  final String title;
  final String? description;
  final AppAlertTone tone;

  const AppAlert({super.key, required this.title, this.description, this.tone = AppAlertTone.info});

  Color _color(bool isDark) {
    switch (tone) {
      case AppAlertTone.success:
        return success500;
      case AppAlertTone.warning:
        return warning600;
      case AppAlertTone.error:
        return error500;
      case AppAlertTone.info:
        return primaryBlue500;
      case AppAlertTone.neutral:
        return isDark ? grey200 : grey600;
    }
  }

  IconData get _icon {
    switch (tone) {
      case AppAlertTone.success:
        return Icons.check_circle_rounded;
      case AppAlertTone.warning:
        return Icons.warning_rounded;
      case AppAlertTone.error:
        return Icons.error_rounded;
      case AppAlertTone.info:
      case AppAlertTone.neutral:
        return Icons.info_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ColorNotifire>().getIsDark;
    final color = _color(isDark);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        border: Border.all(color: color.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_icon, color: color, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: color, fontFamily: 'Gilroy Bold', fontSize: 13),
                ),
                if (description != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    description!,
                    style: TextStyle(
                      color: isDark ? grey200 : grey600,
                      fontFamily: 'Gilroy Medium',
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
