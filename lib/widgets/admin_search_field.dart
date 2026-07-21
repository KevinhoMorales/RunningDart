import 'package:flutter/material.dart';

import '../utils/app_haptics.dart';
import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';

class AdminSearchField extends StatelessWidget {
  const AdminSearchField({
    super.key,
    required this.controller,
    required this.hintText,
    this.onChanged,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: TextStyle(color: palette.textPrimary),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(color: palette.textMuted),
          prefixIcon: Icon(Icons.search_rounded, color: palette.textMuted),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  tooltip: 'Limpiar',
                  onPressed: AppHaptics.wrap(() {
                    controller.clear();
                    onChanged?.call('');
                  }),
                  icon: Icon(Icons.close_rounded, color: palette.textMuted),
                  enableFeedback: false,
                )
              : null,
          filled: true,
          fillColor: palette.cardBackground,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            borderSide: BorderSide(color: palette.cardBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            borderSide: BorderSide(color: palette.cardBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            borderSide: BorderSide(color: palette.accentPrimary),
          ),
        ),
      ),
    );
  }
}

class AdminSearchFieldStateful extends StatefulWidget {
  const AdminSearchFieldStateful({
    super.key,
    required this.controller,
    required this.hintText,
    this.onChanged,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;

  @override
  State<AdminSearchFieldStateful> createState() =>
      _AdminSearchFieldStatefulState();
}

class _AdminSearchFieldStatefulState extends State<AdminSearchFieldStateful> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return AdminSearchField(
      controller: widget.controller,
      hintText: widget.hintText,
      onChanged: widget.onChanged,
    );
  }
}
