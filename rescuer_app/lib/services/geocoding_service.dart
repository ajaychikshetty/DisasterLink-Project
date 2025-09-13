// TODO Implement this library.
import 'package:geocoding/geocoding.dart';

class GeocodingService {
  // Get city name from coordinates
  static Future<String> getCityFromCoordinates({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        return placemark.locality ?? 
               placemark.administrativeArea ?? 
               placemark.country ?? 
               'Unknown Location';
      }
      return 'Unknown Location';
    } catch (e) {
      print('Error getting city from coordinates: $e');
      return 'Unknown Location';
    }
  }

  // Get full address from coordinates
  static Future<String> getFullAddressFromCoordinates({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        final address = [
          placemark.street,
          placemark.locality,
          placemark.administrativeArea,
          placemark.country,
        ].where((part) => part != null && part.isNotEmpty).join(', ');
        
        return address.isNotEmpty ? address : 'Unknown Location';
      }
      return 'Unknown Location';
    } catch (e) {
      print('Error getting address from coordinates: $e');
      return 'Unknown Location';
    }
  }

  // Get coordinates from address
  static Future<Map<String, double>?> getCoordinatesFromAddress(String address) async {
    try {
      final locations = await locationFromAddress(address);
      if (locations.isNotEmpty) {
        final location = locations.first;
        return {
          'latitude': location.latitude,
          'longitude': location.longitude,
        };
      }
      return null;
    } catch (e) {
      print('Error getting coordinates from address: $e');
      return null;
    }
  }
  static Future<String> getAddressFromCoordinates({
  required double latitude,
  required double longitude,
}) async {
  try {
    List<Placemark> placemarks = await placemarkFromCoordinates(
      latitude,
      longitude,
    );

    if (placemarks.isNotEmpty) {
      Placemark place = placemarks[0];
      List<String> addressParts = [];
      
      if (place.street != null && place.street!.isNotEmpty) addressParts.add(place.street!);
      if (place.locality != null && place.locality!.isNotEmpty) addressParts.add(place.locality!);
      if (place.administrativeArea != null && place.administrativeArea!.isNotEmpty) addressParts.add(place.administrativeArea!);
      if (place.country != null && place.country!.isNotEmpty) addressParts.add(place.country!);
      
      return addressParts.join(', ');
    }
    return 'Address not found';
  } catch (e) {
    print('Reverse geocoding error: $e');
    return 'Error fetching address';
  }
}
}