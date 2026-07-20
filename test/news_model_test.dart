import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:running_dart/models/news_model.dart';

void main() {
  group('NewsModel', () {
    test('toFirestore includes required fields', () {
      final eventDate = DateTime(2026, 8, 1, 18);
      final createdAt = DateTime(2026, 7, 1, 10);
      final news = NewsModel(
        id: 'news-1',
        title: 'Encuentro SAINTS',
        summary: 'Resumen',
        body: 'Cuerpo',
        eventDate: eventDate,
        createdAt: createdAt,
        updatedAt: createdAt,
        isPublished: true,
      );

      final payload = news.toFirestore();

      expect(payload['title'], 'Encuentro SAINTS');
      expect(payload['summary'], 'Resumen');
      expect(payload['body'], 'Cuerpo');
      expect(payload['isPublished'], isTrue);
      expect(payload['eventDate'], isA<Timestamp>());
    });
  });

  group('NewsModel.fromFirestore', () {
    test('skips invalid documents when parsed manually', () {
      final validDoc = _FakeDocumentSnapshot(
        id: 'valid',
        data: {
          'title': 'Evento',
          'summary': 'Resumen',
          'body': 'Cuerpo',
          'eventDate': Timestamp.fromDate(DateTime(2026, 8, 1)),
          'createdAt': Timestamp.fromDate(DateTime(2026, 7, 1)),
          'updatedAt': Timestamp.fromDate(DateTime(2026, 7, 1)),
          'isPublished': true,
        },
      );
      final invalidDoc = _FakeDocumentSnapshot(
        id: 'invalid',
        data: {
          'title': 'Sin campos requeridos',
        },
      );

      final items = <NewsModel>[];
      for (final doc in [validDoc, invalidDoc]) {
        try {
          items.add(NewsModel.fromFirestore(doc));
        } catch (_) {}
      }

      expect(items, hasLength(1));
      expect(items.first.id, 'valid');
    });
  });
}

class _FakeDocumentSnapshot
    extends Fake
    implements DocumentSnapshot<Map<String, dynamic>> {
  _FakeDocumentSnapshot({
    required this.id,
    required Map<String, dynamic> data,
  }) : _data = data;

  @override
  final String id;

  final Map<String, dynamic> _data;

  @override
  Map<String, dynamic>? data() => _data;

  @override
  bool get exists => true;
}
