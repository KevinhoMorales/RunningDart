import 'package:cloud_firestore/cloud_firestore.dart';

class NewsModel {
  const NewsModel({
    required this.id,
    required this.title,
    required this.summary,
    required this.body,
    required this.eventDate,
    required this.createdAt,
    required this.updatedAt,
    this.location,
    this.link,
    this.whatsapp,
    this.moreInfo,
    this.imageUrl,
    this.isPublished = false,
  });

  final String id;
  final String title;
  final String summary;
  final String body;
  final DateTime eventDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? location;
  final String? link;
  final String? whatsapp;
  final String? moreInfo;
  final String? imageUrl;
  final bool isPublished;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'summary': summary,
      'body': body,
      'eventDate': eventDate.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String,
      'location': location,
      'link': link,
      'whatsapp': whatsapp,
      'moreInfo': moreInfo,
      'imageUrl': imageUrl,
      'isPublished': isPublished,
    };
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'summary': summary,
      'body': body,
      'eventDate': Timestamp.fromDate(eventDate),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      if (location != null && location!.isNotEmpty) 'location': location,
      if (link != null && link!.isNotEmpty) 'link': link,
      if (whatsapp != null && whatsapp!.isNotEmpty) 'whatsapp': whatsapp,
      if (moreInfo != null && moreInfo!.isNotEmpty) 'moreInfo': moreInfo,
      if (imageUrl != null) 'imageUrl': imageUrl,
      'isPublished': isPublished,
    };
  }

  factory NewsModel.fromJson(Map<String, dynamic> json) {
    return NewsModel(
      id: json['id'] as String,
      title: json['title'] as String,
      summary: json['summary'] as String,
      body: json['body'] as String,
      eventDate: DateTime.parse(json['eventDate'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      location: json['location'] as String?,
      link: json['link'] as String?,
      whatsapp: json['whatsapp'] as String?,
      moreInfo: json['moreInfo'] as String?,
      imageUrl: json['imageUrl'] as String?,
      isPublished: json['isPublished'] as bool? ?? false,
    );
  }

  factory NewsModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;

    DateTime readDate(dynamic value) {
      if (value is Timestamp) {
        return value.toDate();
      }
      return DateTime.parse(value as String);
    }

    return NewsModel(
      id: doc.id,
      title: data['title'] as String,
      summary: data['summary'] as String,
      body: data['body'] as String,
      eventDate: readDate(data['eventDate']),
      createdAt: readDate(data['createdAt']),
      updatedAt: readDate(data['updatedAt']),
      location: data['location'] as String?,
      link: data['link'] as String?,
      whatsapp: data['whatsapp'] as String?,
      moreInfo: data['moreInfo'] as String?,
      imageUrl: data['imageUrl'] as String?,
      isPublished: data['isPublished'] as bool? ?? false,
    );
  }

  NewsModel copyWith({
    String? id,
    String? title,
    String? summary,
    String? body,
    DateTime? eventDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? location,
    String? link,
    String? whatsapp,
    String? moreInfo,
    String? imageUrl,
    bool? isPublished,
  }) {
    return NewsModel(
      id: id ?? this.id,
      title: title ?? this.title,
      summary: summary ?? this.summary,
      body: body ?? this.body,
      eventDate: eventDate ?? this.eventDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      location: location ?? this.location,
      link: link ?? this.link,
      whatsapp: whatsapp ?? this.whatsapp,
      moreInfo: moreInfo ?? this.moreInfo,
      imageUrl: imageUrl ?? this.imageUrl,
      isPublished: isPublished ?? this.isPublished,
    );
  }
}
