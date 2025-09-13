import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

class ActivityTrackingService {
  static const String _lastActivityKey = 'last_user_activity';
  static const String _isInDisasterAreaKey = 'is_in_disaster_area';
  static const String _unconsciousCheckEnabledKey = 'unconscious_check_enabled';
  
  static Timer? _activityTimer;
  static DateTime? _lastActivityTime;
  static bool _isInDisasterArea = false;
  static bool _unconsciousCheckEnabled = true;
  
  // Activity timeout duration (30 minutes)
  static const Duration _activityTimeout = Duration(minutes: 1);  /////////////// change for testing ////////////
  
  // Stream controller for activity updates
  static final StreamController<ActivityStatus> _activityController = 
      StreamController<ActivityStatus>.broadcast();
  
  static Stream<ActivityStatus> get activityStream => _activityController.stream;

  // Initialize the service
  static Future<void> initialize() async {
    await _loadSettings();
    _startActivityTracking();
    print('Activity tracking service initialized');
  }

  // Load settings from SharedPreferences
  static Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _unconsciousCheckEnabled = prefs.getBool(_unconsciousCheckEnabledKey) ?? true;
    _isInDisasterArea = prefs.getBool(_isInDisasterAreaKey) ?? false;
    
    final lastActivityMillis = prefs.getInt(_lastActivityKey);
    if (lastActivityMillis != null) {
      _lastActivityTime = DateTime.fromMillisecondsSinceEpoch(lastActivityMillis);
    } else {
      _lastActivityTime = DateTime.now();
    }
  }

  // Save settings to SharedPreferences
  static Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_unconsciousCheckEnabledKey, _unconsciousCheckEnabled);
    await prefs.setBool(_isInDisasterAreaKey, _isInDisasterArea);
    
    if (_lastActivityTime != null) {
      await prefs.setInt(_lastActivityKey, _lastActivityTime!.millisecondsSinceEpoch);
    }
  }

  // Start activity tracking
  static void _startActivityTracking() {
    _activityTimer?.cancel();
    _activityTimer = Timer.periodic(Duration(seconds: 30), (timer) {
      _checkActivityStatus();
    });
  }

  // Record user activity
  static Future<void> recordActivity() async {
    _lastActivityTime = DateTime.now();
    await _saveSettings();
    
    // Emit activity status
    _emitActivityStatus();
    
    print('User activity recorded at ${_lastActivityTime}');
  }

  // Set disaster area status
  static Future<void> setDisasterAreaStatus(bool isInDisasterArea) async {
    _isInDisasterArea = isInDisasterArea;
    await _saveSettings();
    _emitActivityStatus();
    
    print('Disaster area status updated: $isInDisasterArea');
  }

  // Enable/disable unconscious check
  static Future<void> setUnconsciousCheckEnabled(bool enabled) async {
    _unconsciousCheckEnabled = enabled;
    await _saveSettings();
    _emitActivityStatus();
    
    print('Unconscious check ${enabled ? 'enabled' : 'disabled'}');
  }

  // Check activity status
  static void _checkActivityStatus() {
    if (!_unconsciousCheckEnabled || _lastActivityTime == null) return;
    
    final timeSinceLastActivity = DateTime.now().difference(_lastActivityTime!);
    final isInactive = timeSinceLastActivity > _activityTimeout;
    
    _emitActivityStatus();
    
    // Check for unconscious state
    if (isInactive && _isInDisasterArea) {
      _handleUnconsciousDetection();
    }
  }

  // Emit current activity status
  static void _emitActivityStatus() {
    final timeSinceLastActivity = _lastActivityTime != null 
        ? DateTime.now().difference(_lastActivityTime!)
        : Duration.zero;
    
    final status = ActivityStatus(
      lastActivityTime: _lastActivityTime,
      timeSinceLastActivity: timeSinceLastActivity,
      isInDisasterArea: _isInDisasterArea,
      isUnconsciousCheckEnabled: _unconsciousCheckEnabled,
      isInactive: timeSinceLastActivity > _activityTimeout,
    );
    
    _activityController.add(status);
  }

  // Handle unconscious detection
  static void _handleUnconsciousDetection() {
    final timeSinceLastActivity = DateTime.now().difference(_lastActivityTime!);
    
    print('🚨 UNCONSCIOUS DETECTED! 🚨');
    print('Time since last activity: ${timeSinceLastActivity.inMinutes} minutes');
    print('User is in disaster area: $_isInDisasterArea');
    print('Detection time: ${DateTime.now()}');
    print('Last activity: $_lastActivityTime');
    print('=====================================');
    
    // TODO: Here you can integrate with your API
    // Example: await _sendUnconsciousAlert();
  }

  // Get current activity status
  static ActivityStatus getCurrentStatus() {
    final timeSinceLastActivity = _lastActivityTime != null 
        ? DateTime.now().difference(_lastActivityTime!)
        : Duration.zero;
    
    return ActivityStatus(
      lastActivityTime: _lastActivityTime,
      timeSinceLastActivity: timeSinceLastActivity,
      isInDisasterArea: _isInDisasterArea,
      isUnconsciousCheckEnabled: _unconsciousCheckEnabled,
      isInactive: timeSinceLastActivity > _activityTimeout,
    );
  }

  // Dispose resources
  static void dispose() {
    _activityTimer?.cancel();
    _activityController.close();
  }
}

// Activity status model
class ActivityStatus {
  final DateTime? lastActivityTime;
  final Duration timeSinceLastActivity;
  final bool isInDisasterArea;
  final bool isUnconsciousCheckEnabled;
  final bool isInactive;

  ActivityStatus({
    required this.lastActivityTime,
    required this.timeSinceLastActivity,
    required this.isInDisasterArea,
    required this.isUnconsciousCheckEnabled,
    required this.isInactive,
  });

  @override
  String toString() {
    return 'ActivityStatus(lastActivity: $lastActivityTime, timeSince: ${timeSinceLastActivity.inMinutes}m, inDisasterArea: $isInDisasterArea, enabled: $isUnconsciousCheckEnabled, inactive: $isInactive)';
  }
}