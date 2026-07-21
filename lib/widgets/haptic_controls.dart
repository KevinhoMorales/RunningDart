import 'package:flutter/material.dart';

import '../utils/app_haptics.dart';

class HapticIconButton extends StatelessWidget {
  const HapticIconButton({
    super.key,
    required this.onPressed,
    required this.icon,
    this.tooltip,
    this.color,
    this.style,
    this.isSelected,
    this.selectedIcon,
  });

  final VoidCallback? onPressed;
  final Widget icon;
  final String? tooltip;
  final Color? color;
  final ButtonStyle? style;
  final bool? isSelected;
  final Widget? selectedIcon;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: AppHaptics.wrap(onPressed),
      icon: icon,
      tooltip: tooltip,
      color: color,
      style: style,
      isSelected: isSelected,
      selectedIcon: selectedIcon,
      enableFeedback: false,
    );
  }
}

class HapticTextButton extends StatelessWidget {
  const HapticTextButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.style,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final ButtonStyle? style;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: AppHaptics.wrap(onPressed),
      style: style,
      child: child,
    );
  }
}

class HapticTextButtonIcon extends StatelessWidget {
  const HapticTextButtonIcon({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.label,
    this.style,
  });

  final VoidCallback? onPressed;
  final Widget icon;
  final Widget label;
  final ButtonStyle? style;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: AppHaptics.wrap(onPressed),
      icon: icon,
      label: label,
      style: style,
    );
  }
}

class HapticFilledButton extends StatelessWidget {
  const HapticFilledButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.style,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final ButtonStyle? style;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: AppHaptics.wrap(onPressed),
      style: style,
      child: child,
    );
  }
}

class HapticFloatingActionButton extends StatelessWidget {
  const HapticFloatingActionButton({
    super.key,
    required this.onPressed,
    required this.icon,
    this.label,
    this.tooltip,
    this.backgroundColor,
    this.foregroundColor,
  });

  final VoidCallback? onPressed;
  final Widget icon;
  final Widget? label;
  final String? tooltip;
  final Color? backgroundColor;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    if (label != null) {
      return FloatingActionButton.extended(
        onPressed: AppHaptics.wrap(onPressed),
        icon: icon,
        label: label!,
        tooltip: tooltip,
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        enableFeedback: false,
      );
    }

    return FloatingActionButton(
      onPressed: AppHaptics.wrap(onPressed),
      tooltip: tooltip,
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      enableFeedback: false,
      child: icon,
    );
  }
}

class HapticListTile extends StatelessWidget {
  const HapticListTile({
    super.key,
    this.leading,
    this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.shape,
    this.contentPadding,
  });

  final Widget? leading;
  final Widget? title;
  final Widget? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final ShapeBorder? shape;
  final EdgeInsetsGeometry? contentPadding;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: leading,
      title: title,
      subtitle: subtitle,
      trailing: trailing,
      onTap: AppHaptics.wrap(onTap),
      shape: shape,
      contentPadding: contentPadding,
      enableFeedback: false,
    );
  }
}
