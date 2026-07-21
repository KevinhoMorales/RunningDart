import 'package:cloud_firestore/cloud_firestore.dart';

class TrainingScheduleSection {
  const TrainingScheduleSection({
    required this.title,
    required this.subtitle,
    required this.lines,
    this.iconName,
  });

  final String title;
  final String subtitle;
  final List<String> lines;
  final String? iconName;

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'subtitle': subtitle,
      'lines': lines,
      if (iconName != null) 'iconName': iconName,
    };
  }

  factory TrainingScheduleSection.fromJson(Map<String, dynamic> json) {
    return TrainingScheduleSection(
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      lines: (json['lines'] as List<dynamic>? ?? [])
          .map((line) => line.toString().trim())
          .where((line) => line.isNotEmpty)
          .toList(),
      iconName: json['iconName'] as String?,
    );
  }
}

class TrainingScheduleModel {
  const TrainingScheduleModel({
    required this.sections,
    this.location,
    this.venue,
    this.updatedAt,
  });

  final List<TrainingScheduleSection> sections;
  final String? location;
  final String? venue;
  final DateTime? updatedAt;

  Map<String, dynamic> toFirestore() {
    return {
      'sections': sections.map((s) => s.toJson()).toList(),
      if (location != null) 'location': location,
      if (venue != null) 'venue': venue,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory TrainingScheduleModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    if (data == null) {
      return const TrainingScheduleModel(sections: []);
    }

    final sectionsRaw = data['sections'] as List<dynamic>? ?? [];
    final sections = sectionsRaw
        .whereType<Map>()
        .map(
          (item) => TrainingScheduleSection.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .where((section) => section.title.isNotEmpty || section.lines.isNotEmpty)
        .toList();

    return TrainingScheduleModel(
      sections: sections,
      location: data['location'] as String?,
      venue: data['venue'] as String?,
      updatedAt: data['updatedAt'] is Timestamp
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }
}
