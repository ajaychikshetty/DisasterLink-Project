import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'unconscious_detection_service.dart';
import 'disaster_detection_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/emergency_sos_screen.dart';

class GlobalUnconsciousService {
  static bool _isInitialized = false;
  static bool _emergencyTriggered = false;
  static StreamSubscription<UnconsciousAlert>? _alertSubscription;
  static BuildContext? _currentContext;
  static const String _kEmergencyFlagKey = 'emergency_active';

  // Initialize global unconscious detection
  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    _isInitialized = true;
    
    print('Initializing Global Unconscious Detection Service...');
    
    // Start unconscious detection monitoring
    await UnconsciousDetectionService.startMonitoring();
    
    // Listen to unconscious alerts globally
    _alertSubscription = UnconsciousDetectionService.alertStream.listen((alert) {
      print('Global unconscious alert received: $alert');
      _handleGlobalUnconsciousAlert(alert);
    });
    
    // Start disaster detection service (monitors SMS for disaster alerts)
    await DisasterDetectionService.startMonitoring();
    
    // Restore persistent emergency state
    try {
      final prefs = await SharedPreferences.getInstance();
      final persisted = prefs.getBool(_kEmergencyFlagKey) ?? false;
      _emergencyTriggered = persisted;
      if (persisted) {
        print('Emergency persisted across restart - forcing SOS screen');
      }
    } catch (_) {}

    print('Global Unconscious Detection Service initialized and monitoring globally');
  }

  // Handle unconscious alert globally
  static void _handleGlobalUnconsciousAlert(UnconsciousAlert alert) {
    try {
      // Check if emergency has already been triggered
      if (_emergencyTriggered) {
        print('Emergency already triggered - ignoring unconscious alert');
        return;
      }

      // Check if app is in background
      if (UnconsciousDetectionService.isAppInForeground) {
        // App is in foreground, show SOS screen directly
        _showEmergencySosScreen(alert);
      } else {
        // App is in background, bring to foreground and show SOS screen
        _bringAppToForegroundAndShowSOS(alert);
      }
    } catch (e) {
      print('Error handling global unconscious alert: $e');
    }
  }

  // Show Emergency SOS screen
  static void _showEmergencySosScreen(UnconsciousAlert alert) {
    try {
      final context = _currentContext;
      if (context != null && context.mounted) {
        // Mark emergency as triggered
        _emergencyTriggered = true;
        _persistEmergency(true);
        
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => EmergencySosScreen(alert: alert),
        );
      } else {
        print('No valid context available to show SOS screen');
      }
    } catch (e) {
      print('Error showing SOS screen: $e');
    }
  }

  // Bring app to foreground and show SOS screen
  static void _bringAppToForegroundAndShowSOS(UnconsciousAlert alert) {
    try {
      // Bring app to foreground
      SystemChannels.platform.invokeMethod('SystemNavigator.pop');
      
      // Wait a bit for app to come to foreground, then show SOS
      Timer(Duration(milliseconds: 500), () {
        _showEmergencySosScreen(alert);
      });
    } catch (e) {
      print('Error bringing app to foreground: $e');
      // Fallback: just show SOS screen
      _showEmergencySosScreen(alert);
    }
  }

  // Update current context (call this when navigating)
  static void updateContext(BuildContext context) {
    _currentContext = context;
    // If an emergency was persisted across restarts, ensure the SOS screen is shown
    if (_emergencyTriggered) {
      // Use a synthetic alert to render SOS immediately
      final alert = _buildSyntheticAlert();
      _showEmergencySosScreen(alert);
    }
  }

  // Record user activity globally
  static Future<void> recordUserActivity() async {
    await UnconsciousDetectionService.recordUserActivity();
  }

  // Set disaster area status globally
  static Future<void> setDisasterAreaStatus(bool isInDisasterArea) async {
    await UnconsciousDetectionService.setDisasterAreaStatus(isInDisasterArea);
  }

  // Enable/disable unconscious detection globally
  static Future<void> setUnconsciousDetectionEnabled(bool enabled) async {
    await UnconsciousDetectionService.setUnconsciousDetectionEnabled(enabled);
  }

  // Handle app lifecycle changes globally
  static void onAppResumed() {
    UnconsciousDetectionService.onAppResumed();
  }

  static void onAppPaused() {
    UnconsciousDetectionService.onAppPaused();
  }

  // Reset emergency flag (call this when app is restarted)
  static void resetEmergencyFlag() {
    _emergencyTriggered = false;
    _persistEmergency(false);
    print('Emergency flag reset - unconscious detection re-enabled');
  }

  // Build a synthetic alert for restoring SOS UI after app restart
  static UnconsciousAlert _buildSyntheticAlert() {
    return UnconsciousAlert(
      timestamp: DateTime.now(),
      lastActivityTime: DateTime.now(),
      timeSinceLastActivity: const Duration(minutes: 0),
      lastMovementTime: DateTime.now(),
      isInDisasterArea: true,
      confidence: 100.0,
    );
  }

  static Future<void> _persistEmergency(bool active) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kEmergencyFlagKey, active);
    } catch (_) {}
  }

  // Dispose global service
  static void dispose() {
    _alertSubscription?.cancel();
    _alertSubscription = null;
    _currentContext = null;
    _isInitialized = false;
    _emergencyTriggered = false;
    DisasterDetectionService.stopMonitoring();
    UnconsciousDetectionService.dispose();
  }
}