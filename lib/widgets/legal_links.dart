import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/app_haptics.dart';
import '../utils/constants.dart';
import 'haptic_controls.dart';

Future<void> openLegalUrl(BuildContext context, String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) {
    return;
  }

  final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!launched && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No se pudo abrir el enlace. Intenta de nuevo.'),
      ),
    );
  }
}

class LegalLinksNotice extends StatelessWidget {
  const LegalLinksNotice({
    super.key,
    this.prefix = 'Al continuar, aceptas nuestros ',
    this.textAlign = TextAlign.center,
  });

  final String prefix;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    return LegalLinksRichText(
      prefix: prefix,
      textAlign: textAlign,
      style: AppTypography.caption(context, color: context.palette.textMuted),
    );
  }
}

class LegalLinksRichText extends StatefulWidget {
  const LegalLinksRichText({
    super.key,
    required this.prefix,
    this.textAlign = TextAlign.start,
    this.style,
  });

  final String prefix;
  final TextAlign textAlign;
  final TextStyle? style;

  @override
  State<LegalLinksRichText> createState() => _LegalLinksRichTextState();
}

class _LegalLinksRichTextState extends State<LegalLinksRichText> {
  late final TapGestureRecognizer _termsRecognizer;
  late final TapGestureRecognizer _privacyRecognizer;

  @override
  void initState() {
    super.initState();
    _termsRecognizer = TapGestureRecognizer()
      ..onTap = AppHaptics.wrap(
        () => openLegalUrl(context, AppConstants.termsOfServiceUrl),
      );
    _privacyRecognizer = TapGestureRecognizer()
      ..onTap = AppHaptics.wrap(
        () => openLegalUrl(context, AppConstants.privacyPolicyUrl),
      );
  }

  @override
  void dispose() {
    _termsRecognizer.dispose();
    _privacyRecognizer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final baseStyle = widget.style ?? AppTypography.caption(context);
    final linkStyle = baseStyle.copyWith(
      color: palette.accentPrimary,
      decoration: TextDecoration.underline,
      fontWeight: FontWeight.w600,
    );

    return RichText(
      textAlign: widget.textAlign,
      text: TextSpan(
        style: baseStyle,
        children: [
          TextSpan(text: widget.prefix),
          TextSpan(
            text: 'Términos y condiciones',
            style: linkStyle,
            recognizer: _termsRecognizer,
          ),
          const TextSpan(text: ' y '),
          TextSpan(
            text: 'Política de privacidad',
            style: linkStyle,
            recognizer: _privacyRecognizer,
          ),
          const TextSpan(text: '.'),
        ],
      ),
    );
  }
}

class LegalAcceptanceField extends StatelessWidget {
  const LegalAcceptanceField({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? AppHaptics.wrap(() => onChanged(!value)) : null,
      enableFeedback: false,
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: value,
            onChanged: enabled
                ? AppHaptics.wrapValue((checked) => onChanged(checked ?? false))
                : null,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: LegalLinksRichText(
                prefix: 'Acepto los ',
                style: AppTypography.caption(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LegalLinkTile extends StatelessWidget {
  const LegalLinkTile({
    super.key,
    required this.icon,
    required this.label,
    required this.url,
  });

  final IconData icon;
  final String label;
  final String url;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Material(
      color: palette.cardBackground,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      clipBehavior: Clip.antiAlias,
      child: HapticListTile(
        leading: Icon(icon, color: palette.accentPrimary),
        title: Text(label, style: AppTypography.body(context)),
        trailing: Icon(Icons.open_in_new_rounded, color: palette.textMuted),
        onTap: () => openLegalUrl(context, url),
      ),
    );
  }
}
