import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/training_schedule_model.dart';
import '../utils/constants.dart';

class TrainingScheduleService {
  TrainingScheduleService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const _docPath = 'club_settings/training_schedule';
  static const _loadTimeout = Duration(seconds: 12);

  static TrainingScheduleModel get defaultSchedule {
    return TrainingScheduleModel(
      location: AppConstants.clubLocation,
      venue: AppConstants.clubVenue,
      sections: const [
        TrainingScheduleSection(
          title: 'Comunidad SAINTS',
          subtitle: 'Modalidad libre y recreativa',
          lines: [
            'Martes y jueves · 7:00 p.m.',
            'Jelen Tenka',
            'Fines de semana coordinados en el grupo del club',
          ],
        ),
        TrainingScheduleSection(
          title: 'Miembro Oficial 2026',
          subtitle: 'Incluye entrenamientos de comunidad',
          iconName: 'groups',
          lines: [
            'Martes y jueves · 7:00 p.m.',
            'Jelen Tenka',
            'Acceso a beneficios con marcas aliadas',
          ],
        ),
        TrainingScheduleSection(
          title: 'SAINTS Pro Team',
          subtitle: 'Entrenamiento guiado con coach',
          iconName: 'fitness',
          lines: [
            'Lunes, miércoles y viernes · 7:00 p.m.',
            'Jelen Tenka',
            'Gym y fondos según cronograma interno del coach',
          ],
        ),
      ],
    );
  }

  Stream<TrainingScheduleModel> watchSchedule() {
    return _firestore.doc(_docPath).snapshots().map(_resolveSchedule);
  }

  Future<TrainingScheduleModel> getSchedule() async {
    try {
      final snapshot = await _firestore
          .doc(_docPath)
          .get(const GetOptions(source: Source.serverAndCache))
          .timeout(_loadTimeout);
      return _resolveSchedule(snapshot);
    } catch (_) {
      return defaultSchedule;
    }
  }

  Future<void> saveSchedule(TrainingScheduleModel schedule) async {
    await _firestore.doc(_docPath).set(schedule.toFirestore());
  }

  TrainingScheduleModel _resolveSchedule(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    if (!snapshot.exists) {
      return defaultSchedule;
    }

    final parsed = TrainingScheduleModel.fromFirestore(snapshot);
    if (parsed.sections.isEmpty) {
      return TrainingScheduleModel(
        location: parsed.location ?? defaultSchedule.location,
        venue: parsed.venue ?? defaultSchedule.venue,
        sections: defaultSchedule.sections,
        updatedAt: parsed.updatedAt,
      );
    }

    return parsed;
  }
}
