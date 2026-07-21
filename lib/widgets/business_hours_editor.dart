import 'package:flutter/material.dart';

import '../models/business_hours.dart';
import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/app_haptics.dart';
import '../utils/business_hours_helpers.dart';
import 'category_chip.dart';

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

  void _addSlot() {
    onChanged([
      ...slots,
      const BusinessHoursSlot(
        weekdays: [1, 2, 3, 4, 5],
        period: BusinessDayPeriod.morning,
        start: TimeOfDay(hour: 9, minute: 0),
        end: TimeOfDay(hour: 12, minute: 0),
      ),
    ]);
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
          'Crea slots por días, franja y rango horario.',
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
                      'Define slots estructurados y guarda para migrarlo.',
                      style: AppTypography.caption(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
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
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          onPressed: enabled ? AppHaptics.wrap(_addSlot) : null,
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Agregar horario'),
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

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: palette.cardBackground,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Horario ${index + 1}',
                  style: AppTypography.title(context),
                ),
              ),
              if (onRemove != null)
                IconButton(
                  onPressed: enabled ? AppHaptics.wrap(onRemove) : null,
                  icon: Icon(Icons.delete_outline_rounded, color: palette.textMuted),
                  tooltip: 'Eliminar horario',
                  enableFeedback: false,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Días',
            style: AppTypography.caption(context, color: palette.textMuted),
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: BusinessHoursHelpers.weekdayShortLabels.entries.map((entry) {
              final isSelected = slot.weekdays.contains(entry.key);
              return CategoryChip(
                label: entry.value,
                isSelected: isSelected,
                onSelected: enabled ? () => _toggleDay(entry.key) : () {},
              );
            }).toList(),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Franja',
            style: AppTypography.caption(context, color: palette.textMuted),
          ),
          const SizedBox(height: AppSpacing.xs),
          SegmentedButton<BusinessDayPeriod>(
            segments: const [
              ButtonSegment(
                value: BusinessDayPeriod.morning,
                label: Text('Mañana'),
                icon: Icon(Icons.wb_sunny_outlined, size: 16),
              ),
              ButtonSegment(
                value: BusinessDayPeriod.afternoon,
                label: Text('Tarde'),
                icon: Icon(Icons.wb_twilight_rounded, size: 16),
              ),
            ],
            selected: {slot.period},
            onSelectionChanged: enabled
                ? AppHaptics.wrapValue((selection) {
                    if (selection.isNotEmpty) {
                      onChanged(slot.copyWith(period: selection.first));
                    }
                  })
                : null,
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _TimeField(
                  label: 'Inicio',
                  time: slot.start,
                  enabled: enabled,
                  onTap: () => onPickTime(
                    slot.start,
                    (time) => onChanged(slot.copyWith(start: time)),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _TimeField(
                  label: 'Fin',
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
        ],
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

    return InkWell(
      onTap: enabled ? AppHaptics.wrap(onTap) : null,
      enableFeedback: false,
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: palette.chipBackground,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            borderSide: BorderSide(color: palette.inputBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            borderSide: BorderSide(color: palette.inputBorder),
          ),
        ),
        child: Text(
          BusinessHoursHelpers.formatTime(time),
          style: AppTypography.body(context),
        ),
      ),
    );
  }
}
