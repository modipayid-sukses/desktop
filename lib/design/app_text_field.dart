import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:modipay/utils/color.dart';
import 'package:modipay/utils/colornotifire.dart';
import 'app_tokens.dart';

/// shadcn/ui-style form field: label above the input, subtle 1px border,
/// and an error message slot below — instead of the floating-label /
/// filled-box variants scattered across the app.
class AppTextField extends StatelessWidget {
  final String? label;
  final String? hint;
  final String? errorText;
  final TextEditingController? controller;
  final bool obscureText;
  final TextInputType? keyboardType;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final ValueChanged<String>? onChanged;
  final bool enabled;
  final int maxLines;
  final int? maxLength;

  const AppTextField({
    super.key,
    this.label,
    this.hint,
    this.errorText,
    this.controller,
    this.obscureText = false,
    this.keyboardType,
    this.prefixIcon,
    this.suffixIcon,
    this.onChanged,
    this.enabled = true,
    this.maxLines = 1,
    this.maxLength,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ColorNotifire>().getIsDark;
    final labelColor = isDark ? grey200 : grey700;
    final borderColor = errorText != null ? error500 : (isDark ? grey600 : grey200);
    final fillColor = isDark ? grey800 : Colors.white;
    final textColor = isDark ? Colors.white : grey900;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: TextStyle(fontFamily: 'Gilroy Bold', fontSize: 13, color: labelColor),
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
        TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          onChanged: onChanged,
          enabled: enabled,
          maxLines: maxLines,
          maxLength: maxLength,
          style: TextStyle(fontFamily: 'Gilroy Medium', fontSize: 14, color: textColor),
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: fillColor,
            prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 20, color: labelColor) : null,
            suffixIcon: suffixIcon,
            contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              borderSide: BorderSide(color: borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              borderSide: BorderSide(color: errorText != null ? error500 : primaryBlue500, width: 1.5),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              borderSide: BorderSide(color: borderColor),
            ),
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            errorText!,
            style: const TextStyle(fontFamily: 'Gilroy Medium', fontSize: 12, color: error500),
          ),
        ],
      ],
    );
  }
}
