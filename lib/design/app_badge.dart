import 'package:flutter/material.dart';
import 'package:modipay/utils/color.dart';
import 'app_tokens.dart';

enum AppBadgeTone { neutral, primary, success, warning, error }

/// shadcn/ui-style Badge: small pill with a tinted background and matching
/// text color, used for status labels (e.g. "Dibayar", "Tarif/Daya").
class AppBadge extends StatelessWidget {
  final String label;
  final AppBadgeTone tone;

  const AppBadge({super.key, required this.label, this.tone = AppBadgeTone.neutral});

  Color get _color {
    switch (tone) {
      case AppBadgeTone.primary:
        return primaryBlue500;
      case AppBadgeTone.success:
        return success500;
      case AppBadgeTone.warning:
        return warning600;
      case AppBadgeTone.error:
        return error500;
      case AppBadgeTone.neutral:
        return grey500;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontFamily: 'Gilroy Bold', fontSize: 11),
      ),
    );
  }
}
