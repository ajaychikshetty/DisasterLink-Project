import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';

class AccelerometerService {
  static StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  static final StreamController<MovementData> _movementController = 
      StreamController<MovementData>.broadcast();
  
  static Stream<MovementData> get movementStream => _movementController.stream;
  
  // Movement detection parameters
  static const double _movementThreshold = 0.5; // Minimum acceleration to consider as movement
  static const int _sampleWindow = 10; // Number of samples to analyze
  // ignore: unused_field
  static const Duration _sampleInterval = Duration(milliseconds: 100); // Sample every 100ms
  
  static List<AccelerometerEvent> _recentSamples = [];
  static DateTime? _lastMovementTime;
  static bool _isMonitoring = false;

  // Start monitoring accelerometer
  static Future<void> startMonitoring() async {
    if (_isMonitoring) return;
    
    _isMonitoring = true;
    _lastMovementTime = DateTime.now();
    
    print('Starting accelerometer monitoring...');
    
    _accelerometerSubscription = accelerometerEvents.listen((AccelerometerEvent event) {
      _processAccelerometerData(event);
    });
  }

  // Stop monitoring accelerometer
  static Future<void> stopMonitoring() async {
    if (!_isMonitoring) return;
    
    _isMonitoring = false;
    await _accelerometerSubscription?.cancel();
    _accelerometerSubscription = null;
    _recentSamples.clear();
    
    print('Stopped accelerometer monitoring');
  }

  // Process accelerometer data
  static void _processAccelerometerData(AccelerometerEvent event) {
    _recentSamples.add(event);
    
    // Keep only recent samples
    if (_recentSamples.length > _sampleWindow) {
      _recentSamples.removeAt(0);
    }
    
    // Analyze movement if we have enough samples
    if (_recentSamples.length >= _sampleWindow) {
      _analyzeMovement();
    }
  }

  // Analyze movement patterns
  static void _analyzeMovement() {
    if (_recentSamples.length < _sampleWindow) return;
    
    // Calculate movement intensity
    double totalMovement = 0.0;
    for (int i = 1; i < _recentSamples.length; i++) {
      final prev = _recentSamples[i - 1];
      final curr = _recentSamples[i];
      
      final deltaX = curr.x - prev.x;
      final deltaY = curr.y - prev.y;
      final deltaZ = curr.z - prev.z;
      
      final movement = sqrt(deltaX * deltaX + deltaY * deltaY + deltaZ * deltaZ);
      totalMovement += movement;
    }
    
    final averageMovement = totalMovement / (_recentSamples.length - 1);
    final isMoving = averageMovement > _movementThreshold;
    
    // Update last movement time if significant movement detected
    if (isMoving) {
      _lastMovementTime = DateTime.now();
    }
    
    // Create movement data
    final movementData = MovementData(
      isMoving: isMoving,
      movementIntensity: averageMovement,
      lastMovementTime: _lastMovementTime ?? DateTime.now(),
      timestamp: DateTime.now(),
    );
    
    // Emit movement data
    _movementController.add(movementData);
  }

  // Get time since last movement
  static Duration? getTimeSinceLastMovement() {
    if (_lastMovementTime == null) return null;
    return DateTime.now().difference(_lastMovementTime!);
  }

  // Check if user is currently moving
  static bool get isCurrentlyMoving {
    final timeSinceLastMovement = getTimeSinceLastMovement();
    if (timeSinceLastMovement == null) return false;
    return timeSinceLastMovement.inSeconds < 5; // Consider moving if moved within last 5 seconds
  }

  // Dispose resources
  static void dispose() {
    stopMonitoring();
    _movementController.close();
  }
}

// Movement data model
class MovementData {
  final bool isMoving;
  final double movementIntensity;
  final DateTime lastMovementTime;
  final DateTime timestamp;

  MovementData({
    required this.isMoving,
    required this.movementIntensity,
    required this.lastMovementTime,
    required this.timestamp,
  });

  @override
  String toString() {
    return 'MovementData(isMoving: $isMoving, intensity: ${movementIntensity.toStringAsFixed(3)}, lastMovement: $lastMovementTime)';
  }
}