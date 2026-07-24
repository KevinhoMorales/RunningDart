import 'package:flutter/material.dart';

import '../models/business_hours.dart';
import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/app_haptics.dart';
import '../utils/business_hours_helpers.dart';
import '../utils/constants.dart';

class BusinessHoursEditor extends StatelessWidget {
  const BusinessHoursEditor({
    super.key,
    required this.slots,
    required this.onChanged,
    this.legacyHours,
    this.enabled = true,
  });

  final List<BusinessHoursSlot> slots;
  final ValueChanged<List<BusinessHoursSlot>> onChanged;
  final String? legacyHours;
  final bool enabled;

  void _updateSlot(int index, BusinessHoursSlot slot) {
    final updated = List<BusinessHoursSlot>.from(slots);
    updated[index] = slot;
    onChanged(updated);
  }

  void _removeSlot(int index) {
    final updated = List<BusinessHoursSlot>.from(slots)..removeAt(index);
    onChanged(updated);
  }

  void _addSlotForPeriod(BusinessDayPeriod period) {
    final weekdays = slots.isNotEmpty
        ? List<int>.from(slots.first.weekdays)
        : BusinessHoursHelpers.weekdaysPresetWeekdays;
    onChanged([
      ...slots,
      BusinessHoursHelpers.defaultSlotForPeriod(period, weekdays: weekdays),
    ]);
  }

  void _addSlot() {
    _addSlotForPeriod(BusinessDayPeriod.morning);
  }

  Future<void> _pickTime(
    BuildContext context, {
    required TimeOfDay initial,
    required ValueChanged<TimeOfDay> onSelected,
  }) async {
    if (!enabled) {
      return;
    }

    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (picked != null) {
      onSelected(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final hasLegacyOnly = slots.isEmpty &&
        legacyHours != null &&
        legacyHours!.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Horarios de atención',
          style: AppTypography.title(context),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Elige los días, la franja y el rango horario de cada bloque. '
          'Puedes definir mañana, tarde y noche para los mismos días.',
          style: AppTypography.muted(context),
        ),
        if (hasLegacyOnly) ...[
          const SizedBox(height: AppSpacing.sm),
          Material(
            color: palette.accentPrimary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 18,
                    color: palette.accentPrimary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Horario anterior en texto: "${legacyHours!.trim()}". '
                      'Define bloques estructurados y guarda para migrarlo.',
                      style: AppTypography.caption(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        ...slots.asMap().entries.map(
          (entry) => _BusinessHoursSlotCard(
            index: entry.key,
            slot: entry.value,
            enabled: enabled,
            onChanged: (slot) => _updateSlot(entry.key, slot),
            onRemove: slots.length > 1 ? () => _removeSlot(entry.key) : null,
            onPickTime: (initial, onSelected) => _pickTime(
              context,
              initial: initial,
              onSelected: onSelected,
            ),
          ),
        ),
        Material(
          color: palette.chipBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            side: BorderSide(
              color: palette.cardBorder,
              style: BorderStyle.solid,
            ),
          ),
          child: InkWell(
            onTap: enabled ? AppHaptics.wrap(_addSlot) : null,
            enableFeedback: false,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.md,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_circle_outline_rounded,
                    size: 20,
                    color: enabled
                        ? AppConstants.primaryColor
                        : palette.textMuted,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Agregar otro horario',
                    style: AppTypography.title(
                      context,
                      color: enabled
                          ? AppConstants.primaryColor
                          : palette.textMuted,
                    ).copyWith(fontSize: 15),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: BusinessDayPeriod.values.map((period) {
            return ActionChip(
              avatar: Icon(
                BusinessHoursHelpers.iconForPeriod(period),
                size: 16,
                color: enabled
                    ? AppConstants.primaryColor
                    : palette.textMuted,
              ),
              label: Text(period.displayName),
              onPressed: enabled
                  ? AppHaptics.wrap(() => _addSlotForPeriod(period))
                  : null,
              visualDensity: VisualDensity.compact,
              labelStyle: AppTypography.caption(context).copyWith(
                fontWeight: FontWeight.w600,
              ),
              side: BorderSide(color: palette.inputBorder),
              backgroundColor: palette.chipBackground,
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _BusinessHoursSlotCard extends StatelessWidget {
  const _BusinessHoursSlotCard({
    required this.index,
    required this.slot,
    required this.enabled,
    required this.onChanged,
    required this.onPickTime,
    this.onRemove,
  });

  final int index;
  final BusinessHoursSlot slot;
  final bool enabled;
  final ValueChanged<BusinessHoursSlot> onChanged;
  final VoidCallback? onRemove;
  final Future<void> Function(
    TimeOfDay initial,
    ValueChanged<TimeOfDay> onSelected,
  ) onPickTime;

  void _setWeekdays(List<int> weekdays) {
    final sorted = weekdays.toList()..sort();
    onChanged(slot.copyWith(weekdays: sorted));
  }

  void _toggleDay(int day) {
    final days = List<int>.from(slot.weekdays);
    if (days.contains(day)) {
      days.remove(day);
    } else {
      days.add(day);
    }
    days.sort();
    onChanged(slot.copyWith(weekdays: days));
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final hasDays = slot.weekdays.isNotEmpty;
    final hasValidRange =
        BusinessHoursHelpers.isValidTimeRange(slot.start, slot.end);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: palette.cardBackground,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: palette.cardBorder),
        boxShadow: palette.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: palette.accentPrimary,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: Text(
                  '${index + 1}',
                  style: AppTypography.caption(context, color: Colors.white)
                      .copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bloque ${index + 1}',
                      style: AppTypography.title(context),
                    ),
                    if (hasDays && hasValidRange)
                      Text(
                        BusinessHoursHelpers.formatSlot(slot),
                        style: AppTypography.caption(context),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              if (onRemove != null)
                IconButton(
                  onPressed: enabled ? AppHaptics.wrap(onRemove) : null,
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    color: palette.textMuted,
                  ),
                  tooltip: 'Eliminar bloque',
                  enableFeedback: false,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Días',
            style: AppTypography.caption(context, color: palette.textMuted),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: BusinessHoursHelpers.weekdayLetters.entries.map((entry) {
              final isLast = entry.key == 7;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: isLast ? 0 : AppSpacing.xs),
                  child: _DayToggle(
                    label: entry.value,
                    tooltip: BusinessHoursHelpers.weekdayShortLabels[entry.key]!,
                    isSelected: slot.weekdays.contains(entry.key),
                    enabled: enabled,
                    onTap: () => _toggleDay(entry.key),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              _PresetChip(
                label: 'Lun - Vie',
                enabled: enabled,
                onTap: () => _setWeekdays(
                  BusinessHoursHelpers.weekdaysPresetWeekdays,
                ),
              ),
              _PresetChip(
                label: 'Fin de semana',
                enabled: enabled,
                onTap: () => _setWeekdays(
                  BusinessHoursHelpers.weekdaysPresetWeekend,
                ),
              ),
              _PresetChip(
                label: 'Todos',
                enabled: enabled,
                onTap: () => _setWeekdays(
                  BusinessHoursHelpers.weekdaysPresetAll,
                ),
              ),
            ],
          ),
          if (!hasDays) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Selecciona al menos un día.',
              style: AppTypography.caption(
                context,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Text(
            'Franja',
            style: AppTypography.caption(context, color: palette.textMuted),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: BusinessDayPeriod.values.asMap().entries.map((entry) {
              final period = entry.value;
              final isLast = entry.key == BusinessDayPeriod.values.length - 1;
              final isSelected = slot.period == period;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: isLast ? 0 : AppSpacing.xs,
                  ),
                  child: _PeriodChip(
                    period: period,
                    isSelected: isSelected,
                    enabled: enabled,
                    onTap: () {
                      final defaults = BusinessHoursHelpers.defaultSlotForPeriod(
                        period,
                        weekdays: slot.weekdays,
                      );
                      onChanged(
                        slot.copyWith(
                          period: period,
                          start: defaults.start,
                          end: defaults.end,
                        ),
                      );
                    },
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Horario',
            style: AppTypography.caption(context, color: palette.textMuted),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _TimeField(
                  label: 'Desde',
                  time: slot.start,
                  enabled: enabled,
                  onTap: () => onPickTime(
                    slot.start,
                    (time) => onChanged(slot.copyWith(start: time)),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  size: 18,
                  color: palette.textMuted,
                ),
              ),
              Expanded(
                child: _TimeField(
                  label: 'Hasta',
                  time: slot.end,
                  enabled: enabled,
                  onTap: () => onPickTime(
                    slot.end,
                    (time) => onChanged(slot.copyWith(end: time)),
                  ),
                ),
              ),
            ],
          ),
          if (!hasValidRange) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'La hora de fin debe ser posterior al inicio.',
              style: AppTypography.caption(
                context,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DayToggle extends StatelessWidget {
  const _DayToggle({
    required this.label,
    required this.tooltip,
    required this.isSelected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final String tooltip;
  final bool isSelected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? AppHaptics.wrap(onTap) : null,
          enableFeedback: false,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSelected ? palette.accentPrimary : palette.chipBackground,
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              border: Border.all(
                color: isSelected
                    ? Colors.transparent
                    : palette.inputBorder,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: AppConstants.primaryColor.withValues(alpha: 0.2),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              label,
              style: AppTypography.title(context).copyWith(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: isSelected ? Colors.white : palette.textMuted,
                height: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return ActionChip(
      label: Text(label),
      onPressed: enabled ? AppHaptics.wrap(onTap) : null,
      visualDensity: VisualDensity.compact,
      labelStyle: AppTypography.caption(context).copyWith(
        fontWeight: FontWeight.w600,
      ),
      side: BorderSide(color: palette.inputBorder),
      backgroundColor: palette.chipBackground,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
    );
  }
}

class _PeriodChip extends StatelessWidget {
  const _PeriodChip({
    required this.period,
    required this.isSelected,
    required this.enabled,
    required this.onTap,
  });

  final BusinessDayPeriod period;
  final bool isSelected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? AppHaptics.wrap(onTap) : null,
        enableFeedback: false,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? palette.accentPrimary.withValues(alpha: 0.12)
                : palette.chipBackground,
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            border: Border.all(
              color: isSelected
                  ? palette.accentPrimary
                  : palette.inputBorder,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                BusinessHoursHelpers.iconForPeriod(period),
                size: 18,
                color: isSelected ? palette.accentPrimary : palette.textMuted,
              ),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  period.displayName,
                  style: AppTypography.caption(context).copyWith(
                    fontWeight: FontWeight.w700,
                    color: isSelected
                        ? palette.accentPrimary
                        : palette.textMuted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isSelected) ...[
                const SizedBox(width: AppSpacing.xs),
                Icon(
                  Icons.check_circle_rounded,
                  size: 16,
                  color: palette.accentPrimary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TimeField extends StatelessWidget {
  const _TimeField({
    required this.label,
    required this.time,
    required this.onTap,
    required this.enabled,
  });

  final String label;
  final TimeOfDay time;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Material(
      color: palette.chipBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        side: BorderSide(color: palette.inputBorder),
      ),
      child: InkWell(
        onTap: enabled ? AppHaptics.wrap(onTap) : null,
        enableFeedback: false,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTypography.caption(
                  context,
                  color: palette.textMuted,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    size: 16,
                    color: AppConstants.primaryColor,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      BusinessHoursHelpers.formatTime(time),
                      style: AppTypography.title(context).copyWith(
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
