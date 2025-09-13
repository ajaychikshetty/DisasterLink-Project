import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String authId; // Custom auth ID from your service
  final String phoneNumber;
  final String name;
  final DateTime dateOfBirth;
  final String gender;
  final String city;
  final String bloodGroup;
  final double latitude;
  final double longitude;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserModel({
    required this.authId,
    required this.phoneNumber,
    required this.name,
    required this.dateOfBirth,
    required this.gender,
    required this.city,
    required this.bloodGroup,
    required this.latitude,
    required this.longitude,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'authId': authId,
      'phoneNumber': phoneNumber,
      'name': name,
      'dateOfBirth': Timestamp.fromDate(dateOfBirth),
      'gender': gender,
      'city': city,
      'bloodGroup': bloodGroup,
      'latitude': latitude,
      'longitude': longitude,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  // Create from Firestore document
  factory UserModel.fromDocument(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    return UserModel(
      authId: data['authId'] ?? '',
      phoneNumber: data['phoneNumber'] ?? '',
      name: data['name'] ?? '',
      dateOfBirth: (data['dateOfBirth'] as Timestamp).toDate(),
      gender: data['gender'] ?? '',
      city: data['city'] ?? '',
      bloodGroup: data['bloodGroup'] ?? '',
      latitude: data['latitude']?.toDouble() ?? 0.0,
      longitude: data['longitude']?.toDouble() ?? 0.0,
      isActive: data['isActive'] ?? true,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  // Create from Map
  factory UserModel.fromMap(Map<String, dynamic> data) {
    return UserModel(
      authId: data['authId'] ?? '',
      phoneNumber: data['phoneNumber'] ?? '',
      name: data['name'] ?? '',
      dateOfBirth: data['dateOfBirth'] is Timestamp 
          ? (data['dateOfBirth'] as Timestamp).toDate()
          : data['dateOfBirth'],
      gender: data['gender'] ?? '',
      city: data['city'] ?? '',
      bloodGroup: data['bloodGroup'] ?? '',
      latitude: data['latitude']?.toDouble() ?? 0.0,
      longitude: data['longitude']?.toDouble() ?? 0.0,
      isActive: data['isActive'] ?? true,
      createdAt: data['createdAt'] is Timestamp 
          ? (data['createdAt'] as Timestamp).toDate()
          : data['createdAt'],
      updatedAt: data['updatedAt'] is Timestamp 
          ? (data['updatedAt'] as Timestamp).toDate()
          : data['updatedAt'],
    );
  }

  // Copy with method for updates
  UserModel copyWith({
    String? authId,
    String? phoneNumber,
    String? name,
    DateTime? dateOfBirth,
    String? gender,
    String? city,
    String? bloodGroup,
    double? latitude,
    double? longitude,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      authId: authId ?? this.authId,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      name: name ?? this.name,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      gender: gender ?? this.gender,
      city: city ?? this.city,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}