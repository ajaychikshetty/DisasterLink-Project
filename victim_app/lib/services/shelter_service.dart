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
}