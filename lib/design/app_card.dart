import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:modipay/utils/color.dart';
import 'package:modipay/utils/colornotifire.dart';
import 'app_tokens.dart';

/// shadcn/ui-style Card: flat surface with a subtle 1px border instead of
/// elevation/shadow.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ColorNotifire>().getIsDark;
    final surface = isDark ? grey800 : Colors.white;
    final borderColor = isDark ? grey600 : grey200;

    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: borderColor),
      ),
      child: child,
    );

    if (onTap == null) return card;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: card,
      ),
    );
  }
}
