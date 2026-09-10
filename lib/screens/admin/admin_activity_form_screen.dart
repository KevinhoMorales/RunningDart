import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/activity_model.dart';
import '../../models/activity_type.dart';
import '../../providers/auth_provider.dart';
import '../../services/activity_service.dart';
import '../../theme/app_spacing.dart';
import '../../utils/activity_helpers.dart';
import '../../utils/app_haptics.dart';
import '../../utils/constants.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/modern_text_field.dart';

class AdminActivityFormScreen extends StatefulWidget {
  const AdminActivityFormScreen({super.key, this.activityId});

  final String? activityId;

  bool get isEditing => activityId != null;

  @override
  State<AdminActivityFormScreen> createState() =>
      _AdminActivityFormScreenState();
}

class _AdminActivityFormScreenState extends State<AdminActivityFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController(text: 'Social Run');
  final _descriptionController = TextEditingController();
  final _venueController = TextEditingController(text: AppConstants.clubVenue);
  final _locationController =
      TextEditingController(text: AppConstants.clubLocation);

  ActivityType _type = ActivityType.socialRun;
  DateTime _startsAt = ActivityHelpers.socialRunStartAt(
    year: DateTime.now().year,
    month: DateTime.now().month,
    day: DateTime.now().day,
  );
  bool _isPublished = true;
  bool _loading = false;
  ActivityModel? _existing;

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) {
      _load();
    } else {
      final upcoming = ActivityHelpers.upcomingSocialRunDays(weeksAhead: 1);
      if (upcoming.isNotEmpty) {
        final day = upcoming.first;
        _startsAt = ActivityHelpers.socialRunStartAt(
          year: day.year,
          month: day.month,
          day: day.day,
        );
      }
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final activity =
        await context.read<ActivityService>().getActivity(widget.activityId!);
    if (!mounted) return;
    if (activity != null) {
      _existing = activity;
      _titleController.text = activity.title;
      _descriptionController.text = activity.description ?? '';
      _venueController.text = activity.venue ?? AppConstants.clubVenue;
      _locationController.text =
          activity.location ?? AppConstants.clubLocation;
      _type = activity.type;
      _startsAt = activity.startsAt;
      _isPublished = activity.isPublished;
    }
    setState(() => _loading = false);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _venueController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final ecuador = _startsAt.toUtc().add(ActivityHelpers.ecuadorOffset);
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime(ecuador.year, ecuador.month, ecuador.day),
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: ecuador.hour, minute: ecuador.minute),
    );
    if (time == null || !mounted) return;
    setState(() {
      _startsAt = ActivityHelpers.socialRunStartAt(
        year: date.year,
        month: date.month,
        day: date.day,
      );
      // Ajustar a la hora elegida (no forzar 19:00 si el admin cambia).
      final local = DateTime(date.year, date.month, date.day, time.hour, time.minute);
      _startsAt = local.subtract(ActivityHelpers.ecuadorOffset).toUtc();
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _loading = true);
    try {
      final service = context.read<ActivityService>();
      final auth = context.read<AuthProvider>();
      if (widget.isEditing && _existing != null) {
        await service.updateActivity(
          _existing!.copyWith(
            title: _titleController.text.trim(),
            type: _type,
            startsAt: _startsAt,
            endsAt: ActivityHelpers.defaultEndsAt(_startsAt),
            venue: _venueController.text.trim(),
            location: _locationController.text.trim(),
            description: _descriptionController.text.trim(),
            isPublished: _isPublished,
          ),
        );
      } else {
        final created = await service.createManualActivity(
          title: _titleController.text.trim(),
          type: _type,
          startsAt: _startsAt,
          description: _descriptionController.text.trim(),
          venue: _venueController.text.trim(),
          location: _locationController.text.trim(),
          createdBy: auth.user?.id,
          isPublished: _isPublished,
        );
        if (!mounted) return;
        context.pop();
        context.push('/admin/activities/${created.id}');
        AppSnackBar.show(context, 'Actividad creada.');
        return;
      }
      if (!mounted) return;
      AppSnackBar.show(context, 'Actividad guardada.');
      context.pop();
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.showError(context, e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: widget.isEditing ? 'Editar actividad' : 'Nueva actividad',
      ),
      body: _loading && widget.isEditing && _existing == null
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                  ModernTextField(
                    controller: _titleController,
                    labelText: 'Título',
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  DropdownButtonFormField<ActivityType>(
                    value: _type,
                    decoration: const InputDecoration(labelText: 'Tipo'),
                    items: ActivityType.values
                        .map(
                          (t) => DropdownMenuItem(
                            value: t,
                            child: Text(t.displayName),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _type = value;
                        if (_titleController.text.trim().isEmpty ||
                            ActivityType.values.any(
                              (t) => t.displayName == _titleController.text.trim(),
                            )) {
                          _titleController.text = value.displayName;
                        }
                      });
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Fecha y hora'),
                    subtitle: Text(
                      ActivityHelpers.formatActivityWhen(_startsAt),
                    ),
                    trailing: const Icon(Icons.calendar_today_outlined),
                    onTap: AppHaptics.wrap(_pickDateTime),
                  ),
                  ModernTextField(
                    controller: _venueController,
                    labelText: 'Lugar',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ModernTextField(
                    controller: _locationController,
                    labelText: 'Ciudad / ubicación',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ModernTextField(
                    controller: _descriptionController,
                    labelText: 'Descripción',
                    maxLines: 3,
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Publicada'),
                    value: _isPublished,
                    onChanged: (v) => setState(() => _isPublished = v),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  FilledButton(
                    onPressed: _loading ? null : AppHaptics.wrap(_save),
                    child: Text(widget.isEditing ? 'Guardar' : 'Crear'),
                  ),
                ],
              ),
            ),
    );
  }
}
