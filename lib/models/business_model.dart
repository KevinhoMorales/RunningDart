import 'package:cloud_firestore/cloud_firestore.dart';

class BusinessModel {
  const BusinessModel({
    required this.id,
    required this.name,
    required this.description,
    required this.address,
    required this.phone,
    required this.hours,
    required this.category,
    required this.benefits,
    required this.discount,
    this.imageUrl,
    this.latitude,
    this.longitude,
  });

  final String id;
  final String name;
  final String description;
  final String address;
  final String phone;
  final String hours;
  final String category;
  final List<String> benefits;
  final String discount;
  final String? imageUrl;
  final double? latitude;
  final double? longitude;

  bool get hasLocation => latitude != null && longitude != null;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'address': address,
      'phone': phone,
      'hours': hours,
      'category': category,
      'benefits': benefits,
      'discount': discount,
      'imageUrl': imageUrl,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'address': address,
      'phone': phone,
      'hours': hours,
      'category': category,
      'benefits': benefits,
      'discount': discount,
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
    };
  }

  factory BusinessModel.fromJson(Map<String, dynamic> json) {
    return BusinessModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      address: json['address'] as String,
      phone: json['phone'] as String,
      hours: json['hours'] as String,
      category: json['category'] as String,
      benefits: List<String>.from(json['benefits'] as List),
      discount: json['discount'] as String? ?? '',
      imageUrl: json['imageUrl'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
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
      hours: data['hours'] as String,
      category: data['category'] as String,
      benefits: List<String>.from(data['benefits'] as List? ?? []),
      discount: data['discount'] as String? ?? '',
      imageUrl: data['imageUrl'] as String?,
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
    );
  }

  BusinessModel copyWith({
    String? id,
    String? name,
    String? description,
    String? address,
    String? phone,
    String? hours,
    String? category,
    List<String>? benefits,
    String? discount,
    String? imageUrl,
    double? latitude,
    double? longitude,
  }) {
    return BusinessModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      hours: hours ?? this.hours,
      category: category ?? this.category,
      benefits: benefits ?? this.benefits,
      discount: discount ?? this.discount,
      imageUrl: imageUrl ?? this.imageUrl,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }
}
