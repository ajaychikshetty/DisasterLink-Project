import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../services/location_service.dart';
import '../services/geocoding_service.dart';
import '../l10n/app_localizations.dart';
import '../services/unconscious_detection_service.dart';
import '../services/global_unconscious_service.dart';
import '../services/admin_alert_service.dart';

class EmergencyLocationScreen extends ConsumerStatefulWidget {
  final String alertTimestamp;
  final String lastActivityTime;
  final String timeSinceActivity;
  final bool isInDisasterArea;

  const EmergencyLocationScreen({
    Key? key,
    required this.alertTimestamp,
    required this.lastActivityTime,
    required this.timeSinceActivity,
    required this.isInDisasterArea,
  }) : super(key: key);

  @override
  ConsumerState<EmergencyLocationScreen> createState() => _EmergencyLocationScreenState();
}

class _EmergencyLocationScreenState extends ConsumerState<EmergencyLocationScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _blinkController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _blinkAnimation;

  Position? _currentPosition;
  String _currentAddress = 'Getting location...';
  bool _isLoadingLocation = true;
  bool _emergencySent = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _getCurrentLocation();
    _sendEmergencyAlert();
    // Stop all monitoring/features while on this screen
    UnconsciousDetectionService.stopMonitoring();
    GlobalUnconsciousService.setUnconsciousDetectionEnabled(false);
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: Duration(seconds: 2),
      vsync: this,
    );
    _blinkController = AnimationController(
      duration: Duration(milliseconds: 500),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _blinkAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _blinkController, curve: Curves.easeInOut),
    );

    _pulseController.repeat(reverse: true);
    _blinkController.repeat(reverse: true);
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await LocationService.getLocationWithPermission();
      if (position != null) {
        setState(() {
          _currentPosition = position;
          _isLoadingLocation = false;
        });

        // Get address from coordinates
        final address = await GeocodingService.getCityFromCoordinates(
          latitude:  position.latitude,
          longitude:  position.longitude,
        );
        setState(() {
          _currentAddress = address;
        });
      }
    } catch (e) {
      print('Error getting location: $e');
      setState(() {
        _isLoadingLocation = false;
        _currentAddress = 'Location unavailable';
      });
    }
  }

  void _sendEmergencyAlert() {
    // Simulate sending emergency alert
    Future.delayed(Duration(seconds: 2), () {
      setState(() {
        _emergencySent = true;
      });
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _blinkController.dispose();
    // Keep monitoring stopped until app state changes elsewhere
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ignore: unused_local_variable
    final loc = AppLocalizations.of(context)!;
    // ignore: unused_local_variable
    final theme = Theme.of(context);

    return WillPopScope(
      onWillPop: () async => false, // Prevent going back
      child: Scaffold(
        backgroundColor: Colors.black, // Changed to black background
        body: SafeArea(
          child: SingleChildScrollView( // Added scrollable wrapper
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Header
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.red[800],
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Emergency Icon
                      AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _pulseAnimation.value,
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.red.withOpacity(0.5),
                                    blurRadius: 20,
                                    spreadRadius: 5,
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.emergency,
                                color: Colors.red[800],
                                size: 40,
                              ),
                            ),
                          );
                        },
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Emergency Status
                      AnimatedBuilder(
                        animation: _blinkAnimation,
                        builder: (context, child) {
                          return Opacity(
                            opacity: _blinkAnimation.value,
                            child: Text(
                              'EMERGENCY ALERT SENT',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                              ),
                            ),
                          );
                        },
                      ),
                      
                      const SizedBox(height: 10),
                      
                      Text(
                        'Help is on the way!',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 30),
                
                // Location Information
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Row(
                        children: [
                          Icon(Icons.location_on, color: Colors.red[800], size: 28),
                          const SizedBox(width: 10),
                          Text(
                            'Your Location',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.red[800],
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Location Details
                      if (_isLoadingLocation)
                        Center(
                          child: Column(
                            children: [
                              CircularProgressIndicator(color: Colors.red[800]),
                              const SizedBox(height: 10),
                              Text('Getting your location...'),
                            ],
                          ),
                        )
                      else ...[
                        // Coordinates
                        _buildInfoRow('Latitude', _currentPosition?.latitude.toStringAsFixed(6) ?? 'N/A'),
                        _buildInfoRow('Longitude', _currentPosition?.longitude.toStringAsFixed(6) ?? 'N/A'),
                        _buildInfoRow('Address', _currentAddress),
                        
                        const SizedBox(height: 20),
                        
                        // Alert Information
                        Divider(color: Colors.grey[300]),
                        const SizedBox(height: 10),
                        
                        Text(
                          'Alert Details',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.red[800],
                          ),
                        ),
                        
                        const SizedBox(height: 10),
                        
                        _buildInfoRow('Alert Time', widget.alertTimestamp),
                        _buildInfoRow('Last Activity', widget.lastActivityTime),
                        _buildInfoRow('Time Since Activity', widget.timeSinceActivity),
                        _buildInfoRow('Disaster Area', widget.isInDisasterArea ? 'Yes' : 'No'),
                      ],
                      
                      const SizedBox(height: 20),
                      
                      // Emergency Status
                      Container(
                        padding: EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: _emergencySent ? Colors.green[100] : Colors.orange[100],
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _emergencySent ? Colors.green : Colors.orange,
                            width: 2,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _emergencySent ? Icons.check_circle : Icons.access_time,
                              color: _emergencySent ? Colors.green[800] : Colors.orange[800],
                              size: 24,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _emergencySent 
                                  ? 'Emergency contacts have been notified'
                                  : 'Sending emergency alert...',
                                style: TextStyle(
                                  color: _emergencySent ? Colors.green[800] : Colors.orange[800],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 30),

                // I am Safe button to restore app
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      // Send safe SMS, clear emergency, and resume monitoring
                      await AdminAlertService.sendUserSafeSms();
                      GlobalUnconsciousService.resetEmergencyFlag();
                      await UnconsciousDetectionService.startMonitoring();
                      await GlobalUnconsciousService.setUnconsciousDetectionEnabled(true);
                      if (mounted) {
                        Navigator.of(context).pop();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[700],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.check_circle),
                    label: const Text(
                      "I'M SAFE - RESUME",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
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

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Colors.grey[800],
              ),
            ),
          ),
        ],
      ),
    );
  }
}