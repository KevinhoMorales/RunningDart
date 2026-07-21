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
import '../../widgets/haptic_controls.dart';
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Horarios publicados.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudieron guardar los horarios.')),
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

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ubicación'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: locationController,
              decoration: const InputDecoration(
                labelText: 'Lugar',
                hintText: 'Ej. Jelen Tenka',
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: venueController,
              decoration: const InputDecoration(
                labelText: 'Ciudad / sede',
                hintText: 'Ej. Santo Domingo',
              ),
            ),
          ],
        ),
        actions: [
          HapticTextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          HapticFilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Listo'),
          ),
        ],
      ),
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
                child: ScheduleLocationBanner(
                  location: _locationController.text.trim().isEmpty
                      ? AppConstants.clubLocation
                      : _locationController.text.trim(),
                  venue: _venueController.text.trim().isEmpty
                      ? AppConstants.clubVenue
                      : _venueController.text.trim(),
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
            color: palette.cardBackground,
            border: Border(top: BorderSide(color: palette.cardBorder)),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isSaving ? null : AppHaptics.wrap(_save),
                icon: _isSaving
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: palette.accentPrimary,
                        ),
                      )
                    : const Icon(Icons.publish_rounded, size: 18),
                label: Text(_isSaving ? 'Publicando...' : 'Publicar cambios'),
              ),
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

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: palette.cardBackground,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: AppHaptics.wrap(onToggle),
          enableFeedback: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.sm,
                  AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    Icon(
                      ScheduleHelpers.iconFor(editor.iconName),
                      size: 18,
                      color: palette.accentPrimary,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        preview.title.isEmpty
                            ? 'Modalidad ${index + 1}'
                            : preview.title,
                        style: AppTypography.title(context),
                      ),
                    ),
                    Icon(
                      isExpanded
                          ? Icons.expand_less_rounded
                          : Icons.edit_outlined,
                      size: 20,
                      color: palette.textMuted,
                    ),
                  ],
                ),
              ),
              if (!isExpanded) ...[
                if (preview.subtitle.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      0,
                      AppSpacing.md,
                      AppSpacing.xs,
                    ),
                    child: Text(
                      preview.subtitle,
                      style: AppTypography.caption(context),
                    ),
                  ),
                if (preview.lines.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      0,
                      AppSpacing.md,
                      AppSpacing.md,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: preview.lines.take(2).map((line) {
                        final parsed = ScheduleHelpers.parseLine(line);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            parsed.secondary != null
                                ? '${parsed.primary} · ${parsed.secondary}'
                                : parsed.primary,
                            style: AppTypography.caption(
                              context,
                              color: palette.textMuted,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
              ],
              if (isExpanded) ...[
                Divider(height: 1, color: palette.cardBorder),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: editor.titleController,
                        decoration: const InputDecoration(
                          labelText: 'Título',
                          isDense: true,
                        ),
                        onChanged: (_) => onChanged(),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextField(
                        controller: editor.subtitleController,
                        decoration: const InputDecoration(
                          labelText: 'Descripción breve',
                          isDense: true,
                        ),
                        onChanged: (_) => onChanged(),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Horarios',
                        style: AppTypography.caption(
                          context,
                          color: palette.textMuted,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      ...editor.lineControllers.asMap().entries.map(
                        (entry) => Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: entry.value,
                                  decoration: InputDecoration(
                                    hintText: entry.key == 0
                                        ? 'Ej. Martes y jueves · 7:00 p.m.'
                                        : 'Ej. Jelen Tenka',
                                    isDense: true,
                                  ),
                                  onChanged: (_) => onChanged(),
                                ),
                              ),
                              HapticIconButton(
                                onPressed: editor.lineControllers.length > 1
                                    ? AppHaptics.wrap(() {
                                        editor.removeLine(entry.key);
                                        onChanged();
                                      })
                                    : null,
                                icon: Icon(
                                  Icons.close_rounded,
                                  size: 18,
                                  color: palette.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: HapticTextButtonIcon(
                          onPressed: () {
                            editor.addLine();
                            onChanged();
                          },
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('Agregar línea'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
