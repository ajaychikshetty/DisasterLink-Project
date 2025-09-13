import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/shelter_model.dart';

class ShelterService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'shelters';

  // Fetch shelters within 10km radius
  static Future<List<ShelterModel>> getSheltersWithinRadius({
    required double userLat,
    required double userLon,
    double radiusKm = 10.0,
  }) async {
    try {
      final allShelters = await getAllShelters();
      
      final nearbyShelters = allShelters
          .where((shelter) {
            final distance = shelter.calculateDistance(userLat, userLon);
            return distance <= radiusKm;
          })
          .toList();

      // Sort by distance (closest first)
      nearbyShelters.sort((a, b) {
        final distanceA = a.calculateDistance(userLat, userLon);
        final distanceB = b.calculateDistance(userLat, userLon);
        return distanceA.compareTo(distanceB);
      });

      return nearbyShelters;
    } catch (e) {
      print('Error fetching nearby shelters: $e');
      return [];
    }
  }

  // Get shelter by ID
  static Future<ShelterModel?> getShelterById(String id) async {
    try {
      final doc = await _firestore.collection(_collection).doc(id).get();
      if (doc.exists) {
        return ShelterModel.fromMap({
          'id': doc.id,
          ...doc.data() as Map<String, dynamic>,
        });
      }
      return null;
    } catch (e) {
      print('Error fetching shelter by ID: $e');
      return null;
    }
  }// Add this debug method to your ShelterService class
static Future<void> debugShelters() async {
  try {
    // Check total documents in collection
    final allDocs = await _firestore.collection(_collection).get();
    print('Total shelter documents: ${allDocs.docs.length}');
    
    // Check active shelters
    final activeDocs = await _firestore
        .collection(_collection)
        .where('isActive', isEqualTo: true)
        .get();
    print('Active shelters: ${activeDocs.docs.length}');
    
    // Check shelters with lastUpdated field
    final withLastUpdated = await _firestore
        .collection(_collection)
        .where('isActive', isEqualTo: true)
        .where('lastUpdated', isGreaterThan: 0)
        .get();
    print('Active shelters with lastUpdated: ${withLastUpdated.docs.length}');
    
    // Print details of each document
    for (var doc in allDocs.docs) {
      final data = doc.data();
      print('Shelter ${doc.id}: ${data['name']} - Active: ${data['isActive']} - LastUpdated: ${data['lastUpdated']}');
    }
  } catch (e) {
    print('Debug error: $e');
  }
}

// Modified getAllShelters with better error handling
static Future<List<ShelterModel>> getAllShelters() async {
  try {
    print('Fetching shelters from Firestore...');
    
    final QuerySnapshot snapshot = await _firestore
        .collection(_collection)
        .where('isActive', isEqualTo: true)
        .get(); // Remove orderBy temporarily to test
        
    print('Found ${snapshot.docs.length} active shelter documents');

    final shelters = snapshot.docs
        .map((doc) {
          try {
            final data = {
              'id': doc.id,
              ...doc.data() as Map<String, dynamic>,
            };
            print('Processing shelter: ${data['name']}');
            return ShelterModel.fromMap(data);
          } catch (e) {
            print('Error creating ShelterModel from doc ${doc.id}: $e');
            return null;
          }
        })
        .where((shelter) => shelter != null)
        .cast<ShelterModel>()
        .toList();
    
    print('Successfully created ${shelters.length} ShelterModel objects');
    return shelters;
  } catch (e) {
    print('Error fetching shelters: $e');
    return [];
  }
}

  // Add sample data for testing
  static Future<void> addSampleShelters() async {
    try {
      final sampleShelters = [
        {
          'name': 'Emergency Shelter Alpha',
          'address': '123 Main Street, Downtown',
          'latitude': 19.0760,
          'longitude': 72.8777,
          'capacity': 100,
          'currentOccupancy': 45,
          'status': 'Open',
          'contactNumber': '+91-9876543210',
          'description': 'Large emergency shelter with medical facilities',
          'amenities': ['Medical', 'Food', 'Water', 'Electricity'],
          'lastUpdated': DateTime.now().millisecondsSinceEpoch,
          'isActive': true,
        },
        {
          'name': 'Community Center Beta',
          'address': '456 Park Avenue, Suburb',
          'latitude': 19.0860,
          'longitude': 72.8877,
          'capacity': 50,
          'currentOccupancy': 40,
          'status': 'Limited',
          'contactNumber': '+91-9876543211',
          'description': 'Community center with basic facilities',
          'amenities': ['Food', 'Water', 'Basic Medical'],
          'lastUpdated': DateTime.now().millisecondsSinceEpoch,
          'isActive': true,
        },
        {
          'name': 'School Shelter Gamma',
          'address': '789 Education Road, School District',
          'latitude': 19.0960,
          'longitude': 72.8977,
          'capacity': 200,
          'currentOccupancy': 200,
          'status': 'Full',
          'contactNumber': '+91-9876543212',
          'description': 'School converted to emergency shelter',
          'amenities': ['Food', 'Water', 'Electricity', 'Sanitation'],
          'lastUpdated': DateTime.now().millisecondsSinceEpoch,
          'isActive': true,
        },
        {
          'name': 'Hospital Refuge Delta',
          'address': '321 Health Street, Medical District',
          'latitude': 19.1060,
          'longitude': 72.9077,
          'capacity': 75,
          'currentOccupancy': 0,
          'status': 'Closed',
          'contactNumber': '+91-9876543213',
          'description': 'Hospital emergency shelter with full medical support',
          'amenities': ['Medical', 'Food', 'Water', 'Electricity', 'Sanitation'],
          'lastUpdated': DateTime.now().millisecondsSinceEpoch,
          'isActive': true,
        },
      ];

      for (final shelter in sampleShelters) {
        await _firestore.collection(_collection).add(shelter);
      }
      
      print('Sample shelters added successfully');
    } catch (e) {
      print('Error adding sample shelters: $e');
    }
  }
}