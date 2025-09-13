import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

// State for current user
class AuthState {
  final bool isAuthenticated;
  final UserModel? user;
  final String? authId;
  final bool isLoading;

  const AuthState({
    this.isAuthenticated = false,
    this.user,
    this.authId,
    this.isLoading = false,
  });

  AuthState copyWith({
    bool? isAuthenticated,
    UserModel? user,
    String? authId,
    bool? isLoading,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      user: user,
      authId: authId ?? this.authId,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

// Auth provider notifier
class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState());

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Set auth ID after OTP verification
  void setAuthId(String authId) {
    state = state.copyWith(authId: authId);
  }

  // Check if user is registered in Firestore
  Future<bool> isUserRegistered(String phoneNumber) async {
    try {
      // Clean phone number for document ID
      final cleanPhoneNumber = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
      
      final doc = await _firestore
          .collection('victims')
          .doc(cleanPhoneNumber)
          .get();
      
      return doc.exists;
    } catch (e) {
      print('Error checking user registration: $e');
      return false;
    }
  }

  // Save user details to Firestore
  Future<void> saveUserDetails(UserModel user) async {
    try {
      state = state.copyWith(isLoading: true);

      // Clean phone number for document ID
      final cleanPhoneNumber = user.phoneNumber.replaceAll(RegExp(r'[^\d]'), '');

      await _firestore
          .collection('victims')
          .doc(cleanPhoneNumber)
          .set(user.toMap());

      state = state.copyWith(
        isAuthenticated: true,
        user: user,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false);
      throw Exception('Failed to save user details: $e');
    }
  }

  // Get user details by phone number
  Future<UserModel?> getUserByPhone(String phoneNumber) async {
    try {
      state = state.copyWith(isLoading: true);

      // Clean phone number for document ID
      final cleanPhoneNumber = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');

      final doc = await _firestore
          .collection('victims')
          .doc(cleanPhoneNumber)
          .get();

      if (doc.exists) {
        final user = UserModel.fromDocument(doc);
        state = state.copyWith(
          isAuthenticated: true,
          user: user,
          isLoading: false,
        );
        return user;
      } else {
        state = state.copyWith(isLoading: false);
        return null;
      }
    } catch (e) {
      state = state.copyWith(isLoading: false);
      throw Exception('Failed to get user details: $e');
    }
  }

  // Update user details
  Future<void> updateUserDetails(UserModel updatedUser) async {
    try {
      state = state.copyWith(isLoading: true);

      // Clean phone number for document ID
      final cleanPhoneNumber = updatedUser.phoneNumber.replaceAll(RegExp(r'[^\d]'), '');

      // Update the updatedAt timestamp
      final userWithTimestamp = updatedUser.copyWith(
        updatedAt: DateTime.now(),
      );

      await _firestore
          .collection('victims')
          .doc(cleanPhoneNumber)
          .update(userWithTimestamp.toMap());

      state = state.copyWith(
        user: userWithTimestamp,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false);
      throw Exception('Failed to update user details: $e');
    }
  }

  // Update user location
  Future<void> updateUserLocation(double latitude, double longitude) async {
    if (state.user == null) return;

    try {
      state = state.copyWith(isLoading: true);

      final cleanPhoneNumber = state.user!.phoneNumber.replaceAll(RegExp(r'[^\d]'), '');

      await _firestore
          .collection('victims')
          .doc(cleanPhoneNumber)
          .update({
        'latitude': latitude,
        'longitude': longitude,
        'updatedAt': Timestamp.now(),
      });

      final updatedUser = state.user!.copyWith(
        latitude: latitude,
        longitude: longitude,
        updatedAt: DateTime.now(),
      );

      state = state.copyWith(
        user: updatedUser,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false);
      throw Exception('Failed to update location: $e');
    }
  }

  // Set user as active/inactive
  Future<void> setUserStatus(bool isActive) async {
    if (state.user == null) return;

    try {
      state = state.copyWith(isLoading: true);

      final cleanPhoneNumber = state.user!.phoneNumber.replaceAll(RegExp(r'[^\d]'), '');

      await _firestore
          .collection('victims')
          .doc(cleanPhoneNumber)
          .update({
        'isActive': isActive,
        'updatedAt': Timestamp.now(),
      });

      final updatedUser = state.user!.copyWith(
        isActive: isActive,
        updatedAt: DateTime.now(),
      );

      state = state.copyWith(
        user: updatedUser,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false);
      throw Exception('Failed to update user status: $e');
    }
  }

  // Sign out
  void signOut() {
    state = const AuthState();
  }

  // Load user on app start (if you have stored auth info)
  Future<void> loadUser(String phoneNumber, String authId) async {
    try {
      state = state.copyWith(isLoading: true);

      final user = await getUserByPhone(phoneNumber);
      
      if (user != null && user.authId == authId) {
        state = state.copyWith(
          isAuthenticated: true,
          user: user,
          authId: authId,
          isLoading: false,
        );
      } else {
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }
}

// Provider instance
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(),
);