import 'dart:convert';
import 'package:telephony/telephony.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';

class AdminAlertService {
  static const String _adminNumber = '917400358566';
  static final Telephony _telephony = Telephony.instance;
  static final Battery _battery = Battery();

  /// Sends unconscious alert SMS using telephony package
  static Future<void> sendUnconsciousSms({
    double? latitude,
    double? longitude,
    int? batteryPercent,
  }) async {
    try {
      print("Starting unconscious SMS alert...");

      // Request permissions first
      final bool? isGranted = await _telephony.requestPhoneAndSmsPermissions;
      
      if (!(isGranted ?? false)) {
        print("SMS permissions denied");
        return;
      }

      print("SMS permissions granted");

      // Get current location if not provided
      double? currentLat = latitude;
      double? currentLon = longitude;
      
      if (currentLat == null || currentLon == null) {
        try {
          final Position position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 10),
          );
          currentLat = position.latitude;
          currentLon = position.longitude;
          print("Location fetched: $currentLat, $currentLon");
        } catch (e) {
          print("Failed to get current location: $e");
          // Use null values if location can't be fetched
        }
      }

      // Get battery level if not provided
      int currentBatteryLevel = batteryPercent ?? 0;
      if (batteryPercent == null) {
        try {
          currentBatteryLevel = await _battery.batteryLevel;
          print("Battery level fetched: $currentBatteryLevel%");
        } catch (e) {
          print("Failed to get battery level: $e");
          currentBatteryLevel = 0; // Default to 0 if can't fetch
        }
      }

      // Create timestamp
      String timestamp = DateFormat("yyyy-MM-dd HH:mm:ss").format(DateTime.now());
      print("Timestamp: $timestamp");

      // Create compact JSON payload
      Map<String, dynamic> messageJson = {
        "lat": currentLat,
        "lon": currentLon,
        "msg": "victim is unconscious", // Changed message as requested
        "bat": currentBatteryLevel,
        "sos": "103",
        "time": timestamp,
      };

      String jsonPart = jsonEncode(messageJson);
      String message = "DISASTERLINKx9040\n$jsonPart";
      
      print("=== UNCONSCIOUS ALERT DEBUG INFO ===");
      print("Message with header: $message");
      print("Message length: ${message.length} characters");
      print("Phone number: $_adminNumber");
      
      // Check message length warnings
      if (message.length > 160) {
        print("WARNING: Message exceeds standard SMS length (160 chars)");
      }
      if (message.length > 1600) {
        print("ERROR: Message exceeds extended SMS length (1600 chars)");
      }

      // Send SMS
      await _telephony.sendSms(
        to: _adminNumber,
        message: message,
      );

      print("✅ Unconscious alert SMS sent successfully");

    } catch (e) {
      print("=== UNCONSCIOUS SMS SEND ERROR ===");
      print("Error: $e");
      print("Error type: ${e.runtimeType}");
      // Non-fatal; keep app flow - don't throw exception
    }
  }

  /// Alternative method with callback support for UI feedback
  static Future<void> sendUnconsciousSmsWithCallback({
    double? latitude,
    double? longitude,
    int? batteryPercent,
    Function()? onSuccess,
    Function(String error)? onError,
  }) async {
    try {
      print("Starting unconscious SMS alert with callbacks...");

      // Request permissions first
      final bool? isGranted = await _telephony.requestPhoneAndSmsPermissions;
      
      if (!(isGranted ?? false)) {
        final errorMsg = "SMS permissions denied";
        print(errorMsg);
        onError?.call(errorMsg);
        return;
      }

      print("SMS permissions granted");

      // Get current location if not provided
      double? currentLat = latitude;
      double? currentLon = longitude;
      
      if (currentLat == null || currentLon == null) {
        try {
          final Position position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 10),
          );
          currentLat = position.latitude;
          currentLon = position.longitude;
          print("Location fetched: $currentLat, $currentLon");
        } catch (e) {
          print("Failed to get current location: $e");
          // Continue with null values
        }
      }

      // Get battery level if not provided
      int currentBatteryLevel = batteryPercent ?? 0;
      if (batteryPercent == null) {
        try {
          currentBatteryLevel = await _battery.batteryLevel;
          print("Battery level fetched: $currentBatteryLevel%");
        } catch (e) {
          print("Failed to get battery level: $e");
          currentBatteryLevel = 0;
        }
      }

      // Create timestamp
      String timestamp = DateFormat("yyyy-MM-dd HH:mm:ss").format(DateTime.now());
      print("Timestamp: $timestamp");

      // Create compact JSON payload
      Map<String, dynamic> messageJson = {
        "lat": currentLat,
        "lon": currentLon,
        "msg": "user is unconscious",
        "bat": currentBatteryLevel,
        "sos": "103",
        "time": timestamp,
      };

      String jsonPart = jsonEncode(messageJson);
      String message = "DISASTERLINKx9040\n$jsonPart";
      
      print("=== UNCONSCIOUS ALERT DEBUG INFO ===");
      print("Message with header: $message");
      print("Message length: ${message.length} characters");
      print("Phone number: $_adminNumber");

      // Send SMS
      await _telephony.sendSms(
        to: _adminNumber,
        message: message,
      );

      print("✅ Unconscious alert SMS sent successfully");
      onSuccess?.call();

    } catch (e) {
      final errorMsg = "Failed to send unconscious SMS: $e";
      print("=== UNCONSCIOUS SMS SEND ERROR ===");
      print("Error: $e");
      print("Error type: ${e.runtimeType}");
      onError?.call(errorMsg);
    }
  }

  /// Send an SMS notifying admin that user is safe now
  static Future<void> sendUserSafeSms({
    double? latitude,
    double? longitude,
    int? batteryPercent,
  }) async {
    try {
      final bool? isGranted = await _telephony.requestPhoneAndSmsPermissions;
      if (!(isGranted ?? false)) return;

      double? currentLat = latitude;
      double? currentLon = longitude;
      if (currentLat == null || currentLon == null) {
        try {
          final Position position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 10),
          );
          currentLat = position.latitude;
          currentLon = position.longitude;
        } catch (_) {}
      }

      int currentBatteryLevel = batteryPercent ?? 0;
      if (batteryPercent == null) {
        try {
          currentBatteryLevel = await _battery.batteryLevel;
        } catch (_) {}
      }

      final timestamp = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
      final payload = <String, dynamic>{
        'lat': currentLat,
        'lon': currentLon,
        'msg': 'user is safe now',
        'bat': currentBatteryLevel,
        'sos': '101',
        'time': timestamp,
      };

      final message = 'DISASTERLINKx9040\n${jsonEncode(payload)}';
      await _telephony.sendSms(to: _adminNumber, message: message);
    } catch (e) {
      // ignore: avoid_print
      print('Failed to send SAFE SMS: $e');
    }
  }

  /// Check if SMS permissions are granted
  static Future<bool> checkSmsPermissions() async {
    try {
      final bool? isGranted = await _telephony.requestPhoneAndSmsPermissions;
      return isGranted ?? false;
    } catch (e) {
      print("Error checking SMS permissions: $e");
      return false;
    }
  }
}