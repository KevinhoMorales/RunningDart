import 'package:cloud_firestore/cloud_firestore.dart';

import 'alliance_status.dart';
import 'business_hours.dart';
import 'membership_modality.dart';
import '../utils/business_hours_helpers.dart';

class BusinessModel {
  const BusinessModel({
    required this.id,
    required this.name,
    required this.description,
    required this.address,
    required this.phone,
    required this.hours,
    this.operatingHours = BusinessOperatingHours.empty,
    required this.category,
    required this.benefits,
    required this.discount,
    this.imageUrl,
    this.latitude,
    this.longitude,
    this.whatsapp,
    this.instagram,
    this.meniuzMenuUrl,
    this.conditions,
    this.allianceStatus = AllianceStatus.active,
    this.validUntil,
    this.applicableModalities = const [],
  });

  final String id;
  final String name;
  final String description;
  final String address;
  final String phone;
  final String hours;
  final BusinessOperatingHours operatingHours;
  final String category;
  final List<String> benefits;
  final String discount;
  final String? imageUrl;
  final double? latitude;
  final double? longitude;
  final String? whatsapp;
  final String? instagram;
  final String? meniuzMenuUrl;
  final String? conditions;
  final AllianceStatus allianceStatus;
  final DateTime? validUntil;
  final List<MembershipModality> applicableModalities;

  bool get hasStructuredHours => operatingHours.isNotEmpty;
  bool get hasHoursDisplay => hasStructuredHours || hours.trim().isNotEmpty;
  bool get hasLocation => latitude != null && longitude != null;
  bool get isAllianceActive => allianceStatus == AllianceStatus.active;

  bool appliesToModality(MembershipModality modality) {
    if (applicableModalities.isEmpty) {
      return true;
    }
    return applicableModalities.contains(modality);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'address': address,
      'phone': phone,
      'hours': hours,
      if (operatingHours.isNotEmpty)
        'operatingHours': operatingHours.toJsonList(),
      'category': category,
      'benefits': benefits,
      'discount': discount,
      'imageUrl': imageUrl,
      'latitude': latitude,
      'longitude': longitude,
      'whatsapp': whatsapp,
      'instagram': instagram,
      'meniuzMenuUrl': meniuzMenuUrl,
      'conditions': conditions,
      'allianceStatus': allianceStatus.firestoreValue,
      'validUntil': validUntil?.toIso8601String(),
      'applicableModalities':
          applicableModalities.map((m) => m.firestoreValue).toList(),
    };
  }

  Map<String, dynamic> toFirestore() {
    final summaryHours = operatingHours.isNotEmpty
        ? BusinessHoursHelpers.toDisplaySummary(operatingHours.slots)
        : hours;

    return {
      'name': name,
      'description': description,
      'address': address,
      'phone': phone,
      'hours': summaryHours,
      if (operatingHours.isNotEmpty)
        'operatingHours': operatingHours.toJsonList(),
      'category': category,
      'benefits': benefits,
      'discount': discount,
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (whatsapp != null && whatsapp!.isNotEmpty) 'whatsapp': whatsapp,
      if (instagram != null && instagram!.isNotEmpty) 'instagram': instagram,
      if (meniuzMenuUrl != null && meniuzMenuUrl!.isNotEmpty)
        'meniuzMenuUrl': meniuzMenuUrl,
      if (conditions != null && conditions!.isNotEmpty)
        'conditions': conditions,
      'allianceStatus': allianceStatus.firestoreValue,
      // Explícito y no omitido: al editar, quitar la vigencia tiene que borrar
      // la fecha anterior en lugar de dejarla intacta.
      'validUntil': validUntil == null ? null : Timestamp.fromDate(validUntil!),
      if (applicableModalities.isNotEmpty)
        'applicableModalities':
            applicableModalities.map((m) => m.firestoreValue).toList(),
    };
  }

  factory BusinessModel.fromJson(Map<String, dynamic> json) {
    return BusinessModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      address: json['address'] as String,
      phone: json['phone'] as String,
      hours: json['hours'] as String? ?? '',
      operatingHours: BusinessOperatingHours.fromJsonList(
        json['operatingHours'] as List<dynamic>?,
      ),
      category: json['category'] as String,
      benefits: List<String>.from(json['benefits'] as List),
      discount: json['discount'] as String? ?? '',
      imageUrl: json['imageUrl'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      whatsapp: json['whatsapp'] as String?,
      instagram: json['instagram'] as String?,
      meniuzMenuUrl: json['meniuzMenuUrl'] as String?,
      conditions: json['conditions'] as String?,
      allianceStatus:
          AllianceStatus.fromFirestore(json['allianceStatus'] as String?),
      validUntil: json['validUntil'] != null
          ? DateTime.parse(json['validUntil'] as String)
          : null,
      applicableModalities: _readModalities(json['applicableModalities']),
    );
  }

  factory BusinessModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    return BusinessModel(
      id: doc.id,
      name: data['name'] as String,
      description: data['description'] as String,
      address: data['address'] as String,
      phone: data['phone'] as String,
      hours: data['hours'] as String? ?? '',
      operatingHours: BusinessOperatingHours.fromJsonList(
        data['operatingHours'] as List<dynamic>?,
      ),
      category: data['category'] as String,
      benefits: List<String>.from(data['benefits'] as List? ?? []),
      discount: data['discount'] as String? ?? '',
      imageUrl: data['imageUrl'] as String?,
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      whatsapp: data['whatsapp'] as String?,
      instagram: data['instagram'] as String?,
      meniuzMenuUrl: data['meniuzMenuUrl'] as String?,
      conditions: data['conditions'] as String?,
      allianceStatus:
          AllianceStatus.fromFirestore(data['allianceStatus'] as String?),
      validUntil: data['validUntil'] is Timestamp
          ? (data['validUntil'] as Timestamp).toDate()
          : null,
      applicableModalities: _readModalities(data['applicableModalities']),
    );
  }

  static List<MembershipModality> _readModalities(dynamic value) {
    if (value is! List) {
      return const [];
    }
    return value
        .map((item) => MembershipModality.fromFirestore(item as String?))
        .toList(growable: false);
  }

  BusinessModel copyWith({
    String? id,
    String? name,
    String? description,
    String? address,
    String? phone,
    String? hours,
    BusinessOperatingHours? operatingHours,
    String? category,
    List<String>? benefits,
    String? discount,
    String? imageUrl,
    double? latitude,
    double? longitude,
    String? whatsapp,
    String? instagram,
    String? meniuzMenuUrl,
    String? conditions,
    AllianceStatus? allianceStatus,
    DateTime? validUntil,
    List<MembershipModality>? applicableModalities,
  }) {
    return BusinessModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      hours: hours ?? this.hours,
      operatingHours: operatingHours ?? this.operatingHours,
      category: category ?? this.category,
      benefits: benefits ?? this.benefits,
      discount: discount ?? this.discount,
      imageUrl: imageUrl ?? this.imageUrl,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      whatsapp: whatsapp ?? this.whatsapp,
      instagram: instagram ?? this.instagram,
      meniuzMenuUrl: meniuzMenuUrl ?? this.meniuzMenuUrl,
      conditions: conditions ?? this.conditions,
      allianceStatus: allianceStatus ?? this.allianceStatus,
      validUntil: validUntil ?? this.validUntil,
      applicableModalities: applicableModalities ?? this.applicableModalities,
    );
  }
}
