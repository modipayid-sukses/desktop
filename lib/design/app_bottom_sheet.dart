import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:modipay/utils/color.dart';
import 'package:modipay/utils/colornotifire.dart';
import 'app_tokens.dart';

/// shadcn/ui-style Sheet: rounded top corners, a drag handle, an optional
/// title row with a close button, and consistent content padding —
/// replacing the one-off bottom sheet containers scattered across screens.
class AppBottomSheet extends StatelessWidget {
  final String? title;
  final Widget child;
  final bool showCloseButton;

  const AppBottomSheet({
    super.key,
    this.title,
    required this.child,
    this.showCloseButton = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ColorNotifire>().getIsDark;
    final surface = isDark ? grey800 : Colors.white;
    final titleColor = isDark ? Colors.white : grey900;
    final handleColor = isDark ? grey600 : grey200;

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.sheetTop)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: handleColor,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                ),
              ),
              if (title != null) ...[
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title!,
                        style: TextStyle(
                          fontFamily: 'Gilroy Bold',
                          fontSize: 16,
                          color: titleColor,
                        ),
                      ),
                    ),
                    if (showCloseButton)
                      InkWell(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        onTap: () => Navigator.of(context).pop(),
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.xs),
                          child: Icon(Icons.close_rounded, size: 20, color: titleColor),
                        ),
                      ),
                  ],
                ),
              ] else
                const SizedBox(height: AppSpacing.lg),
              child,
            ],
          ),
        ),
      ),
    );
  }

  static Future<T?> show<T>({
    required BuildContext context,
    String? title,
    required WidgetBuilder builder,
    bool showCloseButton = true,
    bool isScrollControlled = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AppBottomSheet(
        title: title,
        showCloseButton: showCloseButton,
        child: builder(ctx),
      ),
    );
  }
}
