import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'activity_tracking_service.dart';

class DisasterDetectionService {
  static const String _disasterMessageKey = 'disaster_message_received';
  static const String _disasterMessageTimeKey = 'disaster_message_time';
  static const String _disasterNameKey = 'disaster_name';
  
  static Timer? _monitoringTimer;
  static Timer? _autoResetTimer;
  static final SmsQuery _smsQuery = SmsQuery();
  
  // Keywords that indicate disaster messages
  static const List<String> _disasterKeywords = [
    'disaster',
    'emergency',
    'flood',
    'earthquake',
    'cyclone',
    'tsunami',
    'fire',
    'storm',
    'warning',
    'alert',
    'evacuate',
  ];
  
  // Start monitoring for disaster SMS messages
  static Future<void> startMonitoring() async {
    await _checkExistingDisasterStatus();
    await _monitorForDisasterMessages();
    
    // Check every 5 minutes for new disaster messages
    _monitoringTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _monitorForDisasterMessages();
    });
    
    print('Disaster detection service started - monitoring SMS for disaster alerts');
  }
  
  // Stop monitoring
  static void stopMonitoring() {
    _monitoringTimer?.cancel();
    _autoResetTimer?.cancel();
    _monitoringTimer = null;
    _autoResetTimer = null;
    print('Disaster detection service stopped');
  }
  
  // Check if there's an existing disaster status that needs auto-reset
  static Future<void> _checkExistingDisasterStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final disasterMessageTime = prefs.getInt(_disasterMessageTimeKey);
      
      if (disasterMessageTime != null) {
        final messageTime = DateTime.fromMillisecondsSinceEpoch(disasterMessageTime);
        final timeSinceMessage = DateTime.now().difference(messageTime);
        
        if (timeSinceMessage.inHours >= 24) {
          // 24 hours have passed, reset disaster status
          await _resetDisasterStatus();
          print('Auto-reset: Disaster status cleared after 24 hours');
        } else {
          // Verify the disaster message still exists in SMS
          final now = DateTime.now();
          final last24Hours = now.subtract(const Duration(hours: 24));
          
          final messages = await _smsQuery.querySms(
            kinds: [SmsQueryKind.inbox],
            count: 100,
          );
          
          final recentMessages = messages.where((message) =>
              message.date != null && message.date!.isAfter(last24Hours)).toList();
          
          bool disasterMessageExists = false;
          for (final message in recentMessages) {
            if (_isDisasterMessage(message.body ?? '')) {
              disasterMessageExists = true;
              break;
            }
          }
          
          if (disasterMessageExists) {
            // Still within 24 hours and message exists, keep disaster status active
            await ActivityTrackingService.setDisasterAreaStatus(true);
            final remainingHours = 24 - timeSinceMessage.inHours;
            print('Disaster status active - ${remainingHours}h remaining');
            
            // Schedule auto-reset
            _scheduleAutoReset(remainingHours);
          } else {
            // Message no longer exists, reset disaster status
            await _resetDisasterStatus();
            print('Disaster message no longer exists - disaster status reset to FALSE');
          }
        }
      } else {
        // No stored disaster status, ensure it's false
        await _resetDisasterStatus();
        print('No stored disaster status - ensuring FALSE');
      }
    } catch (e) {
      print('Error checking existing disaster status: $e');
      // On error, reset to false to be safe
      await _resetDisasterStatus();
    }
  }
  
  // Monitor SMS messages for disaster alerts
  static Future<void> _monitorForDisasterMessages() async {
    try {
      final now = DateTime.now();
      final last24Hours = now.subtract(const Duration(hours: 24));
      
      // Query recent SMS messages
      final messages = await _smsQuery.querySms(
        kinds: [SmsQueryKind.inbox],
        count: 100,
      );
      
      // Filter messages from last 24 hours
      final recentMessages = messages.where((message) =>
          message.date != null && message.date!.isAfter(last24Hours)).toList();
      
      // Check if there are ANY disaster-related messages
      bool hasDisasterMessage = false;
      String latestDisasterName = '';
      DateTime? latestDisasterTime;
      
      for (final message in recentMessages) {
        if (_isDisasterMessage(message.body ?? '')) {
          hasDisasterMessage = true;
          latestDisasterName = _extractDisasterName(message.body ?? '');
          latestDisasterTime = message.date!;
        }
      }
      
      // If no disaster messages found, reset disaster status
      if (!hasDisasterMessage) {
        await _resetDisasterStatus();
        print('No disaster messages found - disaster status reset to FALSE');
      } else if (latestDisasterTime != null) {
        // Process the latest disaster message
        await _handleDisasterMessage(latestDisasterName, latestDisasterTime);
      }
    } catch (e) {
      print('Error monitoring disaster messages: $e');
    }
  }
  
  // Check if message contains disaster-related keywords
  static bool _isDisasterMessage(String messageBody) {
    final lowerBody = messageBody.toLowerCase();
    return _disasterKeywords.any((keyword) => lowerBody.contains(keyword));
  }
  
  // Extract disaster name from message (simple extraction)
  static String _extractDisasterName(String messageBody) {
    // Look for common disaster patterns
    final lowerBody = messageBody.toLowerCase();
    
    for (final keyword in _disasterKeywords) {
      if (lowerBody.contains(keyword)) {
        // Try to extract the disaster type
        if (lowerBody.contains('flood')) return 'Flood';
        if (lowerBody.contains('earthquake')) return 'Earthquake';
        if (lowerBody.contains('cyclone')) return 'Cyclone';
        if (lowerBody.contains('tsunami')) return 'Tsunami';
        if (lowerBody.contains('fire')) return 'Fire';
        if (lowerBody.contains('storm')) return 'Storm';
        if (lowerBody.contains('disaster')) return 'Disaster';
        if (lowerBody.contains('emergency')) return 'Emergency';
        return keyword.toUpperCase();
      }
    }
    
    return 'Unknown Disaster';
  }
  
  // Handle disaster message detection
  static Future<void> _handleDisasterMessage(String disasterName, DateTime messageTime) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastDisasterTime = prefs.getInt(_disasterMessageTimeKey);
      
      // Only process if this is a new disaster message (within last 5 minutes)
      if (lastDisasterTime != null) {
        final lastTime = DateTime.fromMillisecondsSinceEpoch(lastDisasterTime);
        if (messageTime.difference(lastTime).inMinutes < 5) {
          return; // Already processed this disaster
        }
      }
      
      // Store disaster information
      await prefs.setBool(_disasterMessageKey, true);
      await prefs.setInt(_disasterMessageTimeKey, messageTime.millisecondsSinceEpoch);
      await prefs.setString(_disasterNameKey, disasterName);
      
      // Set disaster area status to true
      await ActivityTrackingService.setDisasterAreaStatus(true);
      
      // Schedule auto-reset after 24 hours
      _scheduleAutoReset(24);
      
      print('🚨 DISASTER DETECTED: $disasterName 🚨');
      print('Disaster area status set to TRUE');
      print('Auto-reset scheduled in 24 hours');
      print('Message time: $messageTime');
      print('=====================================');
      
    } catch (e) {
      print('Error handling disaster message: $e');
    }
  }
  
  // Schedule automatic reset after specified hours
  static void _scheduleAutoReset(int hours) {
    _autoResetTimer?.cancel();
    _autoResetTimer = Timer(Duration(hours: hours), () async {
      await _resetDisasterStatus();
      print('Auto-reset: Disaster status cleared after $hours hours');
    });
  }
  
  // Reset disaster status
  static Future<void> _resetDisasterStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_disasterMessageKey);
      await prefs.remove(_disasterMessageTimeKey);
      await prefs.remove(_disasterNameKey);
      
      await ActivityTrackingService.setDisasterAreaStatus(false);
      
      print('Disaster status reset to FALSE');
    } catch (e) {
      print('Error resetting disaster status: $e');
    }
  }
  
  // Get current disaster information
  static Future<Map<String, dynamic>> getDisasterInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasDisaster = prefs.getBool(_disasterMessageKey) ?? false;
      final disasterTime = prefs.getInt(_disasterMessageTimeKey);
      final disasterName = prefs.getString(_disasterNameKey) ?? '';
      
      if (hasDisaster && disasterTime != null) {
        final messageTime = DateTime.fromMillisecondsSinceEpoch(disasterTime);
        final timeSinceMessage = DateTime.now().difference(messageTime);
        final remainingHours = 24 - timeSinceMessage.inHours;
        
        return {
          'hasDisaster': true,
          'disasterName': disasterName,
          'messageTime': messageTime,
          'remainingHours': remainingHours.clamp(0, 24),
        };
      }
      
      return {'hasDisaster': false};
    } catch (e) {
      print('Error getting disaster info: $e');
      return {'hasDisaster': false};
    }
  }
  
  // Manually reset disaster status (for testing or admin use)
  static Future<void> manualReset() async {
    await _resetDisasterStatus();
    _autoResetTimer?.cancel();
    print('Disaster status manually reset');
  }
}