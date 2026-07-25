import 'package:flutter/material.dart';

import '../data/phone_countries.dart';
import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/app_haptics.dart';
import '../utils/constants.dart';
import '../utils/membership_helpers.dart';

class InternationalPhoneField extends StatefulWidget {
  const InternationalPhoneField({
    super.key,
    required this.controller,
    required this.labelText,
    this.initialCountry,
    this.initialStoredNumber,
    this.enabled = true,
    this.validator,
    this.onCountryChanged,
  });

  final TextEditingController controller;
  final String labelText;
  final PhoneCountry? initialCountry;
  final String? initialStoredNumber;
  final bool enabled;
  final String? Function(String?)? validator;
  final ValueChanged<PhoneCountry>? onCountryChanged;

  @override
  State<InternationalPhoneField> createState() => InternationalPhoneFieldState();
}

class InternationalPhoneFieldState extends State<InternationalPhoneField> {
  late PhoneCountry _selectedCountry;

  @override
  void initState() {
    super.initState();
    _selectedCountry = widget.initialCountry ?? PhoneCountries.defaultCountry;

    final stored = widget.initialStoredNumber?.trim();
    if (stored != null && stored.isNotEmpty && widget.controller.text.isEmpty) {
      final parsed = PhoneCountries.parseStoredNumber(stored);
      _selectedCountry = parsed.country;
      widget.controller.text = parsed.nationalNumber;
    }
  }

  Future<void> _pickCountry() async {
    if (!widget.enabled) {
      return;
    }

    final selected = await showModalBottomSheet<PhoneCountry>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _CountryPickerSheet(
        selectedCountry: _selectedCountry,
      ),
    );

    if (selected == null || !mounted) {
      return;
    }

    setState(() => _selectedCountry = selected);
    widget.onCountryChanged?.call(selected);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: palette.inputFill,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          child: InkWell(
            onTap: widget.enabled ? AppHaptics.wrap(_pickCountry) : null,
            enableFeedback: false,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            child: Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(color: palette.inputBorder),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _selectedCountry.displayLabel,
                    style: AppTypography.body(context).copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Icon(
                    Icons.expand_more_rounded,
                    size: 20,
                    color: palette.textMuted,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: TextFormField(
            controller: widget.controller,
            enabled: widget.enabled,
            keyboardType: TextInputType.phone,
            inputFormatters: MembershipHelpers.internationalPhoneInputFormatters,
            validator: (value) {
              if (widget.validator != null) {
                return widget.validator!(value);
              }
              if (value == null ||
                  !MembershipHelpers.isValidNationalPhoneNumber(
                    value,
                    countryCode: _selectedCountry.dialCode,
                  )) {
                return 'Ingresa un número válido';
              }
              return null;
            },
            style: TextStyle(color: palette.textPrimary),
            decoration: InputDecoration(
              labelText: widget.labelText,
              filled: true,
              fillColor: palette.inputFill,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                borderSide: BorderSide(color: palette.inputBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                borderSide: BorderSide(color: palette.inputBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                borderSide: BorderSide(color: palette.accentPrimary),
              ),
            ),
          ),
        ),
      ],
    );
  }

  PhoneCountry get selectedCountry => _selectedCountry;

  String formatForStorage() {
    return MembershipHelpers.formatWhatsappForStorage(
      widget.controller.text.trim(),
      countryCode: _selectedCountry.dialCode,
    );
  }
}

class _CountryPickerSheet extends StatefulWidget {
  const _CountryPickerSheet({required this.selectedCountry});

  final PhoneCountry selectedCountry;

  @override
  State<_CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends State<_CountryPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<PhoneCountry> get _filteredCountries {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) {
      return PhoneCountries.all;
    }
    return PhoneCountries.all
        .where((country) => country.searchLabel.contains(query))
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final countries = _filteredCountries;

    return Container(
      height: MediaQuery.of(context).size.height * 0.72,
      decoration: BoxDecoration(
        color: palette.bottomSheetBackground,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusLg),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.sm),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: palette.inputBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(
              'Selecciona tu país',
              style: AppTypography.sectionTitle(context),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                hintText: 'Buscar país o código',
                prefixIcon: Icon(Icons.search_rounded, color: palette.textMuted),
                filled: true,
                fillColor: palette.inputFill,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  borderSide: BorderSide(color: palette.inputBorder),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: ListView.separated(
              itemCount: countries.length,
              separatorBuilder: (_, _) => Divider(
                height: 1,
                color: palette.cardBorder,
              ),
              itemBuilder: (context, index) {
                final country = countries[index];
                final isSelected = country.isoCode == widget.selectedCountry.isoCode &&
                    country.dialCode == widget.selectedCountry.dialCode;

                return ListTile(
                  leading: Text(country.flag, style: const TextStyle(fontSize: 24)),
                  title: Text(country.name),
                  subtitle: Text('+${country.dialCode}'),
                  trailing: isSelected
                      ? Icon(Icons.check_circle_rounded, color: AppConstants.primaryColor)
                      : null,
                  onTap: AppHaptics.wrap(() => Navigator.pop(context, country)),
                  enableFeedback: false,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
