import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/app_haptics.dart';
import '../utils/constants.dart';

class ModernTextField extends StatelessWidget {
  const ModernTextField({
    super.key,
    required this.controller,
    required this.labelText,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.textCapitalization = TextCapitalization.none,
    this.prefixIcon,
    this.suffixIcon,
    this.validator,
    this.onFieldSubmitted,
    this.onChanged,
    this.enabled = true,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String labelText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final TextCapitalization textCapitalization;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  final void Function(String)? onFieldSubmitted;
  final void Function(String)? onChanged;
  final bool enabled;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      obscureText: obscureText,
      textCapitalization: textCapitalization,
      maxLines: maxLines,
      enabled: enabled,
      onChanged: onChanged,
      onFieldSubmitted: onFieldSubmitted,
      validator: validator,
      style: TextStyle(color: palette.textPrimary),
      decoration: InputDecoration(
        labelText: labelText,
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, color: palette.textMuted, size: 22)
            : null,
        suffixIcon: suffixIcon,
      ),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: AppConstants.brandGradientAccentColors,
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        boxShadow: [
          BoxShadow(
            color: AppConstants.primaryColor.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : AppHaptics.wrap(onPressed),
          enableFeedback: false,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            alignment: Alignment.center,
            child: isLoading
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    label,
                    style: AppTypography.title(
                      context,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
