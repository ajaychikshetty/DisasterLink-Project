// TODO Implement this library.
import 'dart:math' as math;
import 'package:flutter/material.dart';

class ShelterModel {
  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final int capacity;
  final int currentOccupancy;
  final String status; // 'Open', 'Limited', 'Full', 'Closed'
  final String contactNumber;
  final String description;
  final List<String> amenities;
  final DateTime lastUpdated;
  final bool isActive;

  ShelterModel({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.capacity,
    required this.currentOccupancy,
    required this.status,
    required this.contactNumber,
    required this.description,
    required this.amenities,
    required this.lastUpdated,
    required this.isActive,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'capacity': capacity,
      'currentOccupancy': currentOccupancy,
      'status': status,
      'contactNumber': contactNumber,
      'description': description,
      'amenities': amenities,
      'lastUpdated': lastUpdated.millisecondsSinceEpoch,
      'isActive': isActive,
    };
  }

  factory ShelterModel.fromMap(Map<String, dynamic> map) {
    return ShelterModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      address: map['address'] ?? '',
      latitude: map['latitude']?.toDouble() ?? 0.0,
      longitude: map['longitude']?.toDouble() ?? 0.0,
      capacity: map['capacity'] ?? 0,
      currentOccupancy: map['currentOccupancy'] ?? 0,
      status: map['status'] ?? 'Closed',
      contactNumber: map['contactNumber'] ?? '',
      description: map['description'] ?? '',
      amenities: List<String>.from(map['amenities'] ?? []),
      lastUpdated: DateTime.fromMillisecondsSinceEpoch(map['lastUpdated'] ?? 0),
      isActive: map['isActive'] ?? false,
    );
  }

  // Calculate distance from user location
  double calculateDistance(double userLat, double userLon) {
    const double earthRadius = 6371; // Earth's radius in kilometers
    
    double lat1Rad = userLat * (3.14159265359 / 180);
    double lat2Rad = latitude * (3.14159265359 / 180);
    double deltaLat = (latitude - userLat) * (3.14159265359 / 180);
    double deltaLon = (longitude - userLon) * (3.14159265359 / 180);

    double a = (deltaLat / 2).sin() * (deltaLat / 2).sin() +
        lat1Rad.cos() * lat2Rad.cos() *
        (deltaLon / 2).sin() * (deltaLon / 2).sin();
    double c = 2 * (a.sqrt()).asin();

    return earthRadius * c;
  }

  // Get availability percentage
  double get availabilityPercentage {
    if (capacity == 0) return 0.0;
    return ((capacity - currentOccupancy) / capacity) * 100;
  }

  // Get status color
  Color get statusColor {
    switch (status.toLowerCase()) {
      case 'open':
        return const Color(0xFF66BB6A);
      case 'limited':
        return const Color(0xFFFFB74D);
      case 'full':
        return const Color(0xFFE57373);
      case 'closed':
        return const Color(0xFF9E9E9E);
      default:
        return const Color(0xFF9E9E9E);
    }
  }

  // Get status icon
  IconData get statusIcon {
    switch (status.toLowerCase()) {
      case 'open':
        return Icons.home;
      case 'limited':
        return Icons.business;
      case 'full':
        return Icons.local_hospital;
      case 'closed':
        return Icons.home_work;
      default:
        return Icons.home;
    }
  }
}

// Extension for math functions
extension MathExtensions on double {
  double sin() => math.sin(this);
  double cos() => math.cos(this);
  double asin() => math.asin(this);
  double sqrt() => math.sqrt(this);
}