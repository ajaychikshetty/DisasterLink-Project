import 'dart:async';
import 'accelerometer_service.dart';
import 'activity_tracking_service.dart';

class UnconsciousDetectionService {
  static StreamSubscription<MovementData>? _movementSubscription;
  static StreamSubscription<ActivityStatus>? _activitySubscription;
  static Timer? _detectionTimer;
  
  static bool _isMonitoring = false;
  static DateTime? _lastSignificantMovement;
  static final Duration _movementTimeout = Duration(minutes: 1); // No movement for 10 minutes /////////////// change for testing ////////////
  static Timer? _backgroundTimer;
  static bool _isAppInForeground = true;
  static bool _incidentSmsSent = false; // prevent duplicate SMS per incident
  
  // Stream controller for unconscious alerts
  static final StreamController<UnconsciousAlert> _alertController = 
      StreamController<UnconsciousAlert>.broadcast();
  
  static Stream<UnconsciousAlert> get alertStream => _alertController.stream;

  // Start unconscious detection monitoring
  static Future<void> startMonitoring() async {
    if (_isMonitoring) return;
    
    _isMonitoring = true;
    print('Starting unconscious detection monitoring...');
    
    // Initialize services
    await ActivityTrackingService.initialize();
    await AccelerometerService.startMonitoring();
    
    // Listen to movement data
    _movementSubscription = AccelerometerService.movementStream.listen((movementData) {
      _handleMovementData(movementData);
    });
    
    // Listen to activity status
    _activitySubscription = ActivityTrackingService.activityStream.listen((activityStatus) {
      _handleActivityStatus(activityStatus);
    });
    
    // Start periodic detection check
    _detectionTimer = Timer.periodic(Duration(seconds: 30), (timer) {
      _performUnconsciousCheck();
    });
    
    // Start background monitoring timer (runs every 5 minutes when app is in background)
    _backgroundTimer = Timer.periodic(Duration(minutes: 5), (timer) {
      if (!_isAppInForeground) {
        _performUnconsciousCheck();
      }
    });
  }

  // Stop unconscious detection monitoring
  static Future<void> stopMonitoring() async {
    if (!_isMonitoring) return;
    
    _isMonitoring = false;
    
    await _movementSubscription?.cancel();
    await _activitySubscription?.cancel();
    _detectionTimer?.cancel();
    _backgroundTimer?.cancel();
    
    await AccelerometerService.stopMonitoring();
    
    _movementSubscription = null;
    _activitySubscription = null;
    _detectionTimer = null;
    _backgroundTimer = null;
    
    print('Stopped unconscious detection monitoring');
  }

  // Handle movement data
  static void _handleMovementData(MovementData movementData) {
    if (movementData.isMoving && movementData.movementIntensity > 0.3) {
      _lastSignificantMovement = DateTime.now();
    }
  }

  // Handle activity status
  static void _handleActivityStatus(ActivityStatus activityStatus) {
    // This will be called when activity status changes
    // We can use this to trigger additional checks
  }

  // Perform unconscious check
  static void _performUnconsciousCheck() {
    final activityStatus = ActivityTrackingService.getCurrentStatus();
    
    // Only check if unconscious detection is enabled
    if (!activityStatus.isUnconsciousCheckEnabled) return;
    
    // Check if user is in disaster area
    if (!activityStatus.isInDisasterArea) {
      print('User not in disaster area, skipping unconscious check');
      return;
    }
    
    // Check for prolonged inactivity
    final isInactive = activityStatus.isInactive;
    final timeSinceLastActivity = activityStatus.timeSinceLastActivity;
    
    // Check for lack of movement
    final hasRecentMovement = _lastSignificantMovement != null && 
        DateTime.now().difference(_lastSignificantMovement!) < _movementTimeout;
    
    // Determine if user might be unconscious
    final isUnconscious = isInactive && !hasRecentMovement;
    
    if (isUnconscious) {
      _triggerUnconsciousAlert(activityStatus);
    } else {
      print('Unconscious check: User appears active');
      print('  - Time since last activity: ${timeSinceLastActivity.inMinutes} minutes');
      print('  - Has recent movement: $hasRecentMovement');
      print('  - Last significant movement: $_lastSignificantMovement');
      // User is active again; allow future incident SMS
      _incidentSmsSent = false;
    }
  }

  // Trigger unconscious alert
  static void _triggerUnconsciousAlert(ActivityStatus activityStatus) {
    final alert = UnconsciousAlert(
      timestamp: DateTime.now(),
      lastActivityTime: activityStatus.lastActivityTime,
      timeSinceLastActivity: activityStatus.timeSinceLastActivity,
      lastMovementTime: _lastSignificantMovement,
      isInDisasterArea: activityStatus.isInDisasterArea,
      confidence: _calculateConfidence(activityStatus),
    );
    
    // Emit alert
    _alertController.add(alert);
    
    // Print to console as requested
    print('UNCONSCIOUS ALERT');  //////////////////////////////////////////////// api call unconsious //////////
    print('Timestamp: ${alert.timestamp}');
    print('Last Activity: ${alert.lastActivityTime}');
    print('Time Since Activity: ${alert.timeSinceLastActivity.inMinutes} minutes');
    print('Last Movement: ${alert.lastMovementTime}');
    print('In Disaster Area: ${alert.isInDisasterArea}');
    print('Confidence Level: ${alert.confidence}%');
    print('=====================================');
    
    // Do NOT send SMS here anymore; SOS flow will handle sending exactly once
    // Keep flag behavior for potential future use
    if (!_incidentSmsSent) {
      _incidentSmsSent = true;
      print('Incident flagged as SMS-sent; actual SMS will be sent by SOS flow');
    }
  }

  // Reset per-incident flags (call on user-confirmed SAFE)
  static void resetIncident() {
    _incidentSmsSent = false;
  }

  // Calculate confidence level for unconscious detection
  static double _calculateConfidence(ActivityStatus activityStatus) {
    double confidence = 0.0;
    
    // Base confidence on time since last activity
    final minutesSinceActivity = activityStatus.timeSinceLastActivity.inMinutes;
    if (minutesSinceActivity >= 30) confidence += 30.0;
    if (minutesSinceActivity >= 60) confidence += 30.0;
    if (minutesSinceActivity >= 120) confidence += 20.0;
    
    // Add confidence if no recent movement
    if (_lastSignificantMovement == null || 
        DateTime.now().difference(_lastSignificantMovement!) > _movementTimeout) {
      confidence += 20.0;
    }
    
    return confidence.clamp(0.0, 100.0);
  }

  // Record user activity (call this when user interacts with app)
  static Future<void> recordUserActivity() async {
    await ActivityTrackingService.recordActivity();
  }

  // Set disaster area status
  static Future<void> setDisasterAreaStatus(bool isInDisasterArea) async {
    await ActivityTrackingService.setDisasterAreaStatus(isInDisasterArea);
  }

  // Enable/disable unconscious detection
  static Future<void> setUnconsciousDetectionEnabled(bool enabled) async {
    await ActivityTrackingService.setUnconsciousCheckEnabled(enabled);
  }

  // Handle app lifecycle changes
  static void onAppResumed() {
    _isAppInForeground = true;
    print('App resumed - Unconscious detection active');
    // Record activity when app comes to foreground
    recordUserActivity();
  }

  static void onAppPaused() {
    _isAppInForeground = false;
    print('App paused - Background monitoring active');
  }

  // Get current monitoring status
  static bool get isMonitoring => _isMonitoring;

  // Get app foreground status
  static bool get isAppInForeground => _isAppInForeground;

  // Dispose resources
  static void dispose() {
    stopMonitoring();
    _alertController.close();
  }
}

// Unconscious alert model
class UnconsciousAlert {
  final DateTime timestamp;
  final DateTime? lastActivityTime;
  final Duration timeSinceLastActivity;
  final DateTime? lastMovementTime;
  final bool isInDisasterArea;
  final double confidence;

  UnconsciousAlert({
    required this.timestamp,
    required this.lastActivityTime,
    required this.timeSinceLastActivity,
    required this.lastMovementTime,
    required this.isInDisasterArea,
    required this.confidence,
  });

  @override
  String toString() {
    return 'UnconsciousAlert(timestamp: $timestamp, confidence: ${confidence.toStringAsFixed(1)}%, timeSinceActivity: ${timeSinceLastActivity.inMinutes}m)';
  }
}