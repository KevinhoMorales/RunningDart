import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:running_dart/models/business_hours.dart';
import 'package:running_dart/models/business_model.dart';
import 'package:running_dart/utils/business_hours_helpers.dart';

void main() {
  group('BusinessModel location', () {
    test('hasLocation is true when latitude and longitude are set', () {
      const business = BusinessModel(
        id: 'biz-1',
        name: 'Test',
        description: 'Desc',
        address: 'Address',
        phone: '123',
        hours: '9-5',
        category: 'café',
        benefits: [],
        discount: '10%',
        latitude: -0.18,
        longitude: -78.46,
      );

      expect(business.hasLocation, isTrue);
    });

    test('serializes latitude and longitude to Firestore', () {
      const business = BusinessModel(
        id: 'biz-1',
        name: 'Test',
        description: 'Desc',
        address: 'Address',
        phone: '123',
        hours: '9-5',
        category: 'café',
        benefits: [],
        discount: '10%',
        latitude: -0.18,
        longitude: -78.46,
      );

      expect(business.toFirestore(), {
        'name': 'Test',
        'description': 'Desc',
        'address': 'Address',
        'phone': '123',
        'hours': '9-5',
        'category': 'café',
        'benefits': [],
        'discount': '10%',
        'latitude': -0.18,
        'longitude': -78.46,
        'allianceStatus': 'active',
      });
    });

    test('round-trips location through json', () {
      const business = BusinessModel(
        id: 'biz-1',
        name: 'Test',
        description: 'Desc',
        address: 'Address',
        phone: '123',
        hours: '9-5',
        category: 'café',
        benefits: ['A'],
        discount: '10%',
        latitude: -0.18,
        longitude: -78.46,
      );

      final restored = BusinessModel.fromJson(business.toJson());

      expect(restored.latitude, business.latitude);
      expect(restored.longitude, business.longitude);
      expect(restored.hasLocation, isTrue);
    });
  });
}
