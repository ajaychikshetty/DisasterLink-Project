import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:victim_app/providers/auth_provider.dart' show authProvider;

class AuthUtils {
  // Store auth credentials
  static Future<void> storeAuthCredentials(String phoneNumber, String authId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('phone_number', phoneNumber);
      await prefs.setString('auth_id', authId);
    } catch (e) {
      print('Error storing auth credentials: $e');
    }
  }

  // Get stored auth credentials
  static Future<Map<String, String?>> getStoredAuthCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return {
        'phoneNumber': prefs.getString('phone_number'),
        'authId': prefs.getString('auth_id'),
      };
    } catch (e) {
      print('Error getting auth credentials: $e');
      return {'phoneNumber': null, 'authId': null};
    }
  }

  // Clear stored auth credentials
  static Future<void> clearAuthCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('phone_number');
      await prefs.remove('auth_id');
    } catch (e) {
      print('Error clearing auth credentials: $e');
    }
  }

  // Check if user is logged in
  static Future<bool> isLoggedIn() async {
    final credentials = await getStoredAuthCredentials();
    return credentials['phoneNumber'] != null && credentials['authId'] != null;
  }

  // Logout function
  static Future<void> logout(WidgetRef ref) async {
    try {
      // Clear stored credentials
      await clearAuthCredentials();
      
      // Clear auth provider state
      ref.read(authProvider.notifier).signOut();
      
      // Clear auth ID provider if using it
      // ref.read(authIdProvider.notifier).state = null;
      
    } catch (e) {
      print('Error during logout: $e');
    }
  }
}

// Usage example in your home screen or settings:
/*
// In your home screen or wherever you want logout button
ElevatedButton(
  onPressed: () async {
    await AuthUtils.logout(ref);
    if (mounted) {
      context.go('/phone'); // Navigate back to phone input
    }
  },
  child: Text('Logout'),
),
*/