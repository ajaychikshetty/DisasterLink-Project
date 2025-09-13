import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import '../services/unconscious_detection_service.dart';
import '../services/global_unconscious_service.dart';
import 'emergency_location_screen.dart';
import '../services/admin_alert_service.dart';

class EmergencySosScreen extends ConsumerStatefulWidget {
  final UnconsciousAlert alert;
  
  const EmergencySosScreen({
    super.key,
    required this.alert,
  });

  @override
  ConsumerState<EmergencySosScreen> createState() => _EmergencySosScreenState();
}

class _EmergencySosScreenState extends ConsumerState<EmergencySosScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _countdownController;
  late Animation<double> _pulseAnimation;
  
  Timer? _countdownTimer;
  int _remainingSeconds = 30;
  bool _hasResponded = false;

  @override
  void initState() {
    super.initState();
    
    // Initialize animations
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _countdownController = AnimationController(
      duration: const Duration(seconds: 30),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    // Start pulsing animation
    _pulseController.repeat(reverse: true);
    
    // Start countdown
    _startCountdown();
  }

  void _startCountdown() {
    _countdownController.forward();
    
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _remainingSeconds = 30 - timer.tick;
        });
        
        if (_remainingSeconds <= 0 && !_hasResponded) {
          _handleTimeout();
        }
      }
    });
  }

  void _handleTimeout() {
    if (_hasResponded) return;
    
    _hasResponded = true;
    _countdownTimer?.cancel();
    
    print('🚨 EMERGENCY SOS TIMEOUT - USER MARKED AS UNSAFE 🚨');
    _triggerEmergencyAlert(); // sends SMS once
    _navigateToEmergencyLocationScreen();
  }

  void _handleSafeResponse() {
    if (_hasResponded) return;
    
    _hasResponded = true;
    _countdownTimer?.cancel();
    
    print('✅ USER RESPONDED SAFE - EMERGENCY CANCELLED ✅');
    // Re-arm global detector so it can prompt again in the future
    GlobalUnconsciousService.resetEmergencyFlag();
    UnconsciousDetectionService.recordUserActivity();
    UnconsciousDetectionService.resetIncident();
    // Inform admin user is safe now
    AdminAlertService.sendUserSafeSms();
    
    // Show safe confirmation and close
    _showSafeConfirmation();
  }

  void _handleUnsafeResponse() {
    if (_hasResponded) return;
    
    _hasResponded = true;
    _countdownTimer?.cancel();
    
    print('🚨 USER CONFIRMED UNSAFE - EMERGENCY ALERT TRIGGERED 🚨');
    _triggerEmergencyAlert(); // sends SMS once
    _navigateToEmergencyLocationScreen();
  }

  void _triggerEmergencyAlert() {
    if (_smsSent) {
      print('Emergency SMS already sent - skipping duplicate');
      return;
    }
    _smsSent = true;
    // Print to console as requested
    print('UNCONSCIOUS ALERT');  //////////////////////////////////////////////// api call unconsious //////////
    print('Timestamp: ${widget.alert.timestamp}');
    print('Last Activity: ${widget.alert.lastActivityTime}');
    print('Time Since Activity: ${widget.alert.timeSinceLastActivity.inMinutes} minutes');
    print('Last Movement: ${widget.alert.lastMovementTime}');
    print('In Disaster Area: ${widget.alert.isInDisasterArea}');
    print('Confidence Level: ${widget.alert.confidence}%');
    print('=====================================');
    
    // Best-effort admin SMS via telephony (no UI blocking)
    AdminAlertService.sendUnconsciousSms(
      latitude: widget.alert.lastMovementTime != null ? null : null,
      longitude: widget.alert.lastMovementTime != null ? null : null,
      batteryPercent: null,
    );
  }

  bool _smsSent = false;

  void _navigateToEmergencyLocationScreen() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => EmergencyLocationScreen(
          alertTimestamp: widget.alert.timestamp.toString(),
          lastActivityTime: widget.alert.lastActivityTime.toString(),
          timeSinceActivity: '${widget.alert.timeSinceLastActivity.inMinutes} minutes',
          isInDisasterArea: widget.alert.isInDisasterArea,
        ),
      ),
    );
  }

  void _showSafeConfirmation() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.red[800]!, width: 2),
        ),
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            const SizedBox(width: 12),
            Text('You\'re Safe!', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Text('Emergency alert cancelled. Stay safe!', style: TextStyle(color: Colors.white70)),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(); // Close SOS screen
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }
  @override
  void dispose() {
    _pulseController.dispose();
    _countdownController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    
    return WillPopScope(
      onWillPop: () async => false, // Prevent back button
      child: Scaffold(
        backgroundColor: Colors.black, // Changed to black background
        body: SafeArea(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black,
                  Colors.black,
                  Colors.black,
                ],
              ),
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Icon(
                        Icons.warning,
                        color: Colors.red[800],
                        size: 60,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'EMERGENCY SOS',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.red[800],
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Are you safe?',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Countdown Timer
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 40),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.red[800]!),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Respond within',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 8),
                      AnimatedBuilder(
                        animation: _countdownController,
                        builder: (context, child) {
                          return Text(
                            '$_remainingSeconds',
                            style: TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              color: _remainingSeconds <= 10 ? Colors.yellow : Colors.red[800],
                            ),
                          );
                        },
                      ),
                      Text(
                        'seconds',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Progress bar
                      LinearProgressIndicator(
                        value: _remainingSeconds / 30,
                        backgroundColor: Colors.grey[800],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _remainingSeconds <= 10 ? Colors.yellow : Colors.red[800]!,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const Spacer(),
                
                // Action Buttons
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Safe Button
                      AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _pulseAnimation.value,
                            child: SizedBox(
                              width: double.infinity,
                              height: 60,
                              child: ElevatedButton(
                                onPressed: _hasResponded ? null : _handleSafeResponse,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green[800],
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  elevation: 8,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.check_circle, size: 28),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        'I\'M SAFE',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Unsafe Button
                      SizedBox(
                        width: double.infinity,
                        height: 60,
                        child: ElevatedButton(
                          onPressed: _hasResponded ? null : _handleUnsafeResponse,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red[800],
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            elevation: 8,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.warning, size: 28),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  'I NEED HELP',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}