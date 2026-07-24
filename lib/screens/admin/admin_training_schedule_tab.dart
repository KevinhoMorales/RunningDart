import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/training_schedule_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/training_schedule_service.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/app_haptics.dart';
import '../../utils/constants.dart';
import '../../utils/schedule_helpers.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/haptic_controls.dart';
import '../../widgets/modern_text_field.dart';
import '../../widgets/schedule_card.dart';

class AdminTrainingScheduleTab extends StatefulWidget {
  const AdminTrainingScheduleTab({super.key});

  @override
  State<AdminTrainingScheduleTab> createState() =>
      _AdminTrainingScheduleTabState();
}

class _AdminTrainingScheduleTabState extends State<AdminTrainingScheduleTab>
    with AutomaticKeepAliveClientMixin {
  final _service = TrainingScheduleService();
  final _locationController = TextEditingController();
  final _venueController = TextEditingController();
  final List<_SectionEditor> _sections = [];
  bool _isLoading = true;
  bool _isSaving = false;
  bool _usedFallback = false;
  int? _expandedIndex;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _locationController.dispose();
    _venueController.dispose();
    for (final section in _sections) {
      section.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = true;
      _usedFallback = false;
    });

    TrainingScheduleModel schedule;
    var usedFallback = false;

    try {
      schedule = await _service.getSchedule();
    } catch (_) {
      schedule = TrainingScheduleService.defaultSchedule;
      usedFallback = true;
    }

    if (!mounted) {
      return;
    }

    _applySchedule(schedule);

    setState(() {
      _isLoading = false;
      _usedFallback = usedFallback;
      _expandedIndex = null;
    });
  }

  void _applySchedule(TrainingScheduleModel schedule) {
    for (final section in _sections) {
      section.dispose();
    }
    _sections.clear();
    _locationController.text = schedule.location ?? AppConstants.clubLocation;
    _venueController.text = schedule.venue ?? AppConstants.clubVenue;
    for (final section in schedule.sections) {
      _sections.add(_SectionEditor.fromSection(section));
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      await _service.saveSchedule(
        TrainingScheduleModel(
          location: _locationController.text.trim(),
          venue: _venueController.text.trim(),
          sections: _sections.map((s) => s.toSection()).toList(),
        ),
      );
      if (mounted) {
        AppSnackBar.show(context, 'Horarios publicados correctamente.');
      }
    } catch (_) {
      if (mounted) {
        AppSnackBar.show(
          context,
          'No se pudieron guardar los horarios.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _editVenue() async {
    final locationController = TextEditingController(
      text: _locationController.text,
    );
    final venueController = TextEditingController(text: _venueController.text);

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final palette = sheetContext.palette;

        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: palette.bottomSheetBackground,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppSpacing.radiusLg),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: palette.inputBorder,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Ubicación del club',
                  style: AppTypography.sectionTitle(sheetContext),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Así se verá en la vista pública de horarios.',
                  style: AppTypography.muted(sheetContext),
                ),
                const SizedBox(height: AppSpacing.md),
                ModernTextField(
                  controller: locationController,
                  labelText: 'Ciudad / región',
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: AppSpacing.sm),
                ModernTextField(
                  controller: venueController,
                  labelText: 'Sede / lugar',
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: AppSpacing.lg),
                PrimaryButton(
                  label: 'Guardar ubicación',
                  onPressed: () => Navigator.pop(sheetContext, true),
                ),
                const SizedBox(height: AppSpacing.sm),
                HapticTextButton(
                  onPressed: () => Navigator.pop(sheetContext, false),
                  child: Text(
                    'Cancelar',
                    style: TextStyle(color: palette.textMuted),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (saved == true && mounted) {
      setState(() {
        _locationController.text = locationController.text.trim();
        _venueController.text = venueController.text.trim();
      });
    }

    locationController.dispose();
    venueController.dispose();
  }

  void _toggleSection(int index) {
    setState(() {
      _expandedIndex = _expandedIndex == index ? null : index;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final palette = context.palette;
    final auth = context.watch<AuthProvider>();

    if (!auth.canManageSchedules) {
      return Center(
        child: Text(
          'Sin permiso para editar horarios.',
          style: AppTypography.muted(context),
        ),
      );
    }

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                if (_usedFallback)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Material(
                      color: palette.accentPrimary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              size: 18,
                              color: palette.accentPrimary,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                'Mostrando horarios por defecto. Revisa tu conexión o publica cambios.',
                                style: AppTypography.caption(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                Text(
                  'Vista previa pública',
                  style: AppTypography.caption(context, color: palette.textMuted),
                ),
              const SizedBox(height: AppSpacing.sm),
              InkWell(
                onTap: _isSaving ? null : AppHaptics.wrap(_editVenue),
                enableFeedback: false,
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                child: Stack(
                  children: [
                    ScheduleLocationBanner(
                      location: _locationController.text.trim().isEmpty
                          ? AppConstants.clubLocation
                          : _locationController.text.trim(),
                      venue: _venueController.text.trim().isEmpty
                          ? AppConstants.clubVenue
                          : _venueController.text.trim(),
                    ),
                    Positioned(
                      top: AppSpacing.sm,
                      right: AppSpacing.sm,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: palette.cardBackground.withValues(alpha: 0.92),
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusSm),
                          border: Border.all(color: palette.cardBorder),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.edit_location_alt_outlined,
                              size: 14,
                              color: palette.accentPrimary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Editar',
                              style: AppTypography.micro(
                                context,
                                color: palette.accentPrimary,
                              ).copyWith(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              ..._sections.asMap().entries.map(
                (entry) => _AdminSectionPanel(
                  editor: entry.value,
                  index: entry.key,
                  isExpanded: _expandedIndex == entry.key,
                  onToggle: () => _toggleSection(entry.key),
                  onChanged: () => setState(() {}),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Toca una modalidad para editar sus líneas. '
                'Usa el formato "Días · Hora" para mejor presentación.',
                style: AppTypography.caption(context, color: palette.textMuted)
                    .copyWith(height: 1.35),
              ),
            ],
          ),
        ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: palette.scaffoldBackground,
            border: Border(top: BorderSide(color: palette.cardBorder)),
            boxShadow: [
              BoxShadow(
                color: palette.navBarShadow,
                blurRadius: 12,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: PrimaryButton(
              label: _isSaving ? 'Publicando...' : 'Publicar cambios',
              isLoading: _isSaving,
              onPressed: _isSaving ? null : _save,
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionEditor {
  _SectionEditor({
    required this.titleController,
    required this.subtitleController,
    required this.lineControllers,
    this.iconName,
  });

  factory _SectionEditor.fromSection(TrainingScheduleSection section) {
    return _SectionEditor(
      titleController: TextEditingController(text: section.title),
      subtitleController: TextEditingController(text: section.subtitle),
      lineControllers: section.lines
          .map((line) => TextEditingController(text: line))
          .toList(),
      iconName: section.iconName,
    );
  }

  final TextEditingController titleController;
  final TextEditingController subtitleController;
  final List<TextEditingController> lineControllers;
  String? iconName;

  TrainingScheduleSection toSection() {
    final lines = lineControllers
        .map((controller) => controller.text.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    return TrainingScheduleSection(
      title: titleController.text.trim(),
      subtitle: subtitleController.text.trim(),
      lines: lines,
      iconName: iconName,
    );
  }

  void addLine() {
    lineControllers.add(TextEditingController());
  }

  void removeLine(int index) {
    lineControllers.removeAt(index).dispose();
  }

  void dispose() {
    titleController.dispose();
    subtitleController.dispose();
    for (final controller in lineControllers) {
      controller.dispose();
    }
  }
}

class _AdminSectionPanel extends StatelessWidget {
  const _AdminSectionPanel({
    required this.editor,
    required this.index,
    required this.isExpanded,
    required this.onToggle,
    required this.onChanged,
  });

  final _SectionEditor editor;
  final int index;
  final bool isExpanded;
  final VoidCallback onToggle;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final preview = editor.toSection();
    final title = preview.title.isEmpty ? 'Modalidad ${index + 1}' : preview.title;
    final icon = ScheduleHelpers.iconFor(editor.iconName);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: palette.cardBackground,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(
            color: isExpanded ? palette.accentPrimary : palette.cardBorder,
            width: isExpanded ? 1.5 : 1,
          ),
          boxShadow: isExpanded
              ? [
                  BoxShadow(
                    color: palette.accentPrimary.withValues(alpha: 0.12),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : palette.softShadow,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 3,
                decoration: BoxDecoration(
                  color: palette.accentPrimary,
                ),
              ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: AppHaptics.wrap(onToggle),
                  enableFeedback: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.md,
                      AppSpacing.md,
                      AppSpacing.sm,
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: palette.accentPrimary.withValues(alpha: 0.1),
                            borderRadius:
                                BorderRadius.circular(AppSpacing.radiusSm),
                          ),
                          child: Icon(
                            icon,
                            size: 20,
                            color: palette.accentPrimary,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(title, style: AppTypography.title(context)),
                              if (preview.subtitle.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  preview.subtitle,
                                  style: AppTypography.muted(context),
                                  maxLines: isExpanded ? 2 : 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.xs,
                          ),
                          decoration: BoxDecoration(
                            color: isExpanded
                                ? palette.accentPrimary.withValues(alpha: 0.12)
                                : palette.inputFill,
                            borderRadius:
                                BorderRadius.circular(AppSpacing.radiusSm),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isExpanded
                                    ? Icons.expand_less_rounded
                                    : Icons.edit_outlined,
                                size: 16,
                                color: isExpanded
                                    ? palette.accentPrimary
                                    : palette.textMuted,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isExpanded ? 'Cerrar' : 'Editar',
                                style: AppTypography.micro(
                                  context,
                                  color: isExpanded
                                      ? palette.accentPrimary
                                      : palette.textMuted,
                                ).copyWith(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 220),
                crossFadeState: isExpanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                firstCurve: Curves.easeOutCubic,
                secondCurve: Curves.easeOutCubic,
                sizeCurve: Curves.easeOutCubic,
                firstChild: _CollapsedSchedulePreview(lines: preview.lines),
                secondChild: _ExpandedScheduleEditor(
                  editor: editor,
                  onChanged: onChanged,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CollapsedSchedulePreview extends StatelessWidget {
  const _CollapsedSchedulePreview({required this.lines});

  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    if (lines.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: Text(
          'Sin líneas de horario. Toca Editar para agregar.',
          style: AppTypography.caption(context),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: lines.take(3).map((line) {
          final parsed = ScheduleHelpers.parseLine(line);
          final icon = parsed.isTimeSlot
              ? Icons.calendar_today_rounded
              : parsed.isLocation
                  ? Icons.place_outlined
                  : Icons.notes_rounded;

          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 14, color: palette.accentPrimary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    parsed.secondary != null
                        ? '${parsed.primary} · ${parsed.secondary}'
                        : parsed.primary,
                    style: AppTypography.caption(context),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ExpandedScheduleEditor extends StatelessWidget {
  const _ExpandedScheduleEditor({
    required this.editor,
    required this.onChanged,
  });

  final _SectionEditor editor;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Divider(height: 1, color: palette.cardBorder),
          const SizedBox(height: AppSpacing.md),
          ModernTextField(
            controller: editor.titleController,
            labelText: 'Título',
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => onChanged(),
          ),
          const SizedBox(height: AppSpacing.sm),
          ModernTextField(
            controller: editor.subtitleController,
            labelText: 'Descripción breve',
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => onChanged(),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Horarios',
            style: AppTypography.title(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Usa el formato "Días · Hora" en la primera línea cuando aplique.',
            style: AppTypography.caption(context, color: palette.textMuted),
          ),
          const SizedBox(height: AppSpacing.sm),
          ...editor.lineControllers.asMap().entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _ScheduleLineEditorRow(
                controller: entry.value,
                index: entry.key,
                canRemove: editor.lineControllers.length > 1,
                onChanged: onChanged,
                onRemove: () {
                  editor.removeLine(entry.key);
                  onChanged();
                },
              ),
            ),
          ),
          OutlinedButton.icon(
            onPressed: AppHaptics.wrap(() {
              editor.addLine();
              onChanged();
            }),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Agregar línea'),
          ),
        ],
      ),
    );
  }
}

class _ScheduleLineEditorRow extends StatelessWidget {
  const _ScheduleLineEditorRow({
    required this.controller,
    required this.index,
    required this.canRemove,
    required this.onChanged,
    required this.onRemove,
  });

  final TextEditingController controller;
  final int index;
  final bool canRemove;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final parsed = ScheduleHelpers.parseLine(controller.text);

    IconData lineIcon;
    if (parsed.isTimeSlot) {
      lineIcon = Icons.calendar_today_rounded;
    } else if (parsed.isLocation) {
      lineIcon = Icons.place_outlined;
    } else {
      lineIcon = Icons.notes_rounded;
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.xs,
        AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: palette.inputFill,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: palette.inputBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: palette.accentPrimary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(lineIcon, size: 16, color: palette.accentPrimary),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: ModernTextField(
              controller: controller,
              labelText: index == 0 ? 'Horario principal' : 'Línea ${index + 1}',
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => onChanged(),
            ),
          ),
          HapticIconButton(
            onPressed: canRemove ? AppHaptics.wrap(onRemove) : null,
            icon: Icon(
              Icons.close_rounded,
              size: 18,
              color: canRemove ? palette.textMuted : palette.inputBorder,
            ),
          ),
        ],
      ),
    );
  }
}
