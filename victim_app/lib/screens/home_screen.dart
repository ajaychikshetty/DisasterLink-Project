import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:victim_app/widgets/bottom_navbar.dart' show Bottom_NavBar;
import '../l10n/app_localizations.dart';
import '../models/shelter_model.dart';
import '../services/shelter_service.dart';
import '../services/location_service.dart';
import '../services/geocoding_service.dart';
import '../services/connectivity_service.dart';
import '../mixins/unconscious_activity_mixin.dart';
import '../services/global_unconscious_service.dart';
import '../services/sms_service.dart';
import '../services/victim_beacon_service.dart';
import 'package:telephony/telephony.dart';
import 'package:intl/intl.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Homescreen extends ConsumerStatefulWidget {
  const Homescreen({super.key});

  @override
  ConsumerState<Homescreen> createState() => _HomescreenState();
}

class _HomescreenState extends ConsumerState<Homescreen>
    with SingleTickerProviderStateMixin, UnconsciousActivityMixin {
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;

  // Real data for shelters
  List<ShelterModel> nearbyShelters = [];
  bool _isLoadingShelters = true;
  String _currentCity = 'Loading...';
  bool _isOnline = true;
  double? _userLat;
  double? _userLon;
  bool _isInDisasterArea = false; // Default to false
  bool _unconsciousDetectionEnabled = true;
  String _disasterName = '';
  int _remainingHours = 0;

  // Master emergency toggle - controls all emergency features
  bool _emergencyFeaturesEnabled = true;

  // Beacon service
  final VictimBeaconService _beaconService = VictimBeaconService();
  bool _isBeaconSupported = false;
  bool _hasBeaconPermission = false;
  bool _isBeaconAdvertising = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    // Only start subtle pulsing for specific cards
    _animationController.repeat(reverse: true);

    // Initialize services
    _initializeServices();

    // Record user activity when screen is opened
    recordUserActivity();
  }

  Future<void> _initializeServices() async {
    // Initialize connectivity service
    await ConnectivityService.initialize();

    // Listen to connectivity changes
    ConnectivityService.connectionStream.listen((isConnected) {
      if (mounted) {
        setState(() {
          _isOnline = isConnected;
        });
      }
    });

    // Get user location and load shelters
    await _getUserLocationAndLoadShelters();
    
    // Load disaster information
    await _loadDisasterInfo();
    
    // Check disaster status from existing SMS messages
    await _loadDisasterInfo();

    // Initialize beacon service
    await _initializeBeaconService();
    
    if (!_isInDisasterArea) {
      print('No disaster messages found - emergency features disabled');
    } else {
      print('Disaster detected: $_disasterName - emergency features available');
    }

    // Update unconscious detection based on emergency features toggle
    _updateUnconsciousDetection();
  }

  // Method to update unconscious detection based on emergency toggle
  void _updateUnconsciousDetection() async {
    // Only enable unconscious detection if BOTH disaster is active AND emergency features are enabled
    final shouldEnable = _areEmergencyFeaturesActive && _unconsciousDetectionEnabled;
    await GlobalUnconsciousService.setUnconsciousDetectionEnabled(shouldEnable);
    // Don't set disaster area status here - it should only come from SMS detection
  }

  Future<void> _getUserLocationAndLoadShelters() async {
    try {
      // Get current location
      final position = await LocationService.getLocationWithPermission();
      if (position != null) {
        setState(() {
          _userLat = position.latitude;
          _userLon = position.longitude;
        });

        // Get city name
        final city = await GeocodingService.getCityFromCoordinates(
          latitude: position.latitude,
          longitude: position.longitude,
        );

        if (mounted) {
          setState(() {
            _currentCity = city;
          });
        }

        // Load nearby shelters
        await _loadNearbyShelters();
      } else {
        if (mounted) {
          setState(() {
            _currentCity = 'Location not available';
            _isLoadingShelters = false;
          });
        }
      }
    } catch (e) {
      print('Error getting location: $e');
      if (mounted) {
        setState(() {
          _currentCity = 'Error getting location';
          _isLoadingShelters = false;
        });
      }
    }
  }

  Future<void> _loadDisasterInfo() async {
    try {
      // Check if there are any SMS messages in notifications (DISASTERLINKx9040 messages)
      final smsMessages = await SmsService.getSmsFromLast7Days();
      
      // Check if any messages contain disaster keywords
      bool hasDisasterMessage = false;
      String disasterName = '';
      
      for (final message in smsMessages) {
        if (_isDisasterMessage(message.body)) {
          hasDisasterMessage = true;
          disasterName = _extractDisasterName(message.body);
          break; // Use the first disaster message found
        }
      }
      
      if (mounted) {
        setState(() {
          _isInDisasterArea = hasDisasterMessage;
          _disasterName = disasterName;
          _remainingHours = 0; // Not tracking hours for now
        });
      }
      
      print('Disaster status: $_isInDisasterArea, Name: $_disasterName');
    } catch (e) {
      print('Error loading disaster info: $e');
      if (mounted) {
        setState(() {
          _isInDisasterArea = false;
          _disasterName = '';
          _remainingHours = 0;
        });
      }
    }
  }

  Future<void> _initializeBeaconService() async {
    try {
      // Check if beacon is supported
      _isBeaconSupported = await _beaconService.isSupported();
      
      if (_isBeaconSupported) {
        // Check permissions
        _hasBeaconPermission = await _beaconService.hasPermission();
        
        if (!_hasBeaconPermission) {
          // Request permission
          _hasBeaconPermission = await _beaconService.requestPermission();
        }
      }
      
      // Sync UI state with actual beacon service state
      _isBeaconAdvertising = _beaconService.isAdvertising;
      
      if (mounted) {
        setState(() {});
      }
      
      print('Beacon support: $_isBeaconSupported, Permission: $_hasBeaconPermission, Advertising: $_isBeaconAdvertising');
    } catch (e) {
      print('Error initializing beacon service: $e');
    }
  }

  Future<void> _startBeacon() async {
    if (!_isBeaconSupported || !_hasBeaconPermission) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Beacon not supported or permission denied'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // Get user's phone number for victim ID
      final prefs = await SharedPreferences.getInstance();
      final phoneNumber = prefs.getString('phone_number') ?? 'unknown';
      
      // Use current city as disaster zone
      final disasterZone = _currentCity.isNotEmpty ? _currentCity : 'Unknown';
      
      final success = await _beaconService.startAdvertising(
        victimId: phoneNumber,
        disasterZone: disasterZone,
      );
      
      if (success) {
        setState(() {
          _isBeaconAdvertising = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Beacon started successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start beacon'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error starting beacon: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _stopBeacon() async {
    try {
      await _beaconService.stopAdvertising();
      setState(() {
        _isBeaconAdvertising = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Beacon stopped'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error stopping beacon: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  bool _isDisasterMessage(String messageBody) {
    final lowerBody = messageBody.toLowerCase();
    const disasterKeywords = [
      'disaster', 'emergency', 'flood', 'earthquake', 'cyclone', 
      'tsunami', 'fire', 'storm', 'warning', 'alert', 'evacuate', 'shelter'
    ];
    return disasterKeywords.any((keyword) => lowerBody.contains(keyword));
  }
  
  String _extractDisasterName(String messageBody) {
    final lowerBody = messageBody.toLowerCase();
    if (lowerBody.contains('flood')) return 'Flood';
    if (lowerBody.contains('earthquake')) return 'Earthquake';
    if (lowerBody.contains('cyclone')) return 'Cyclone';
    if (lowerBody.contains('tsunami')) return 'Tsunami';
    if (lowerBody.contains('fire')) return 'Fire';
    if (lowerBody.contains('storm')) return 'Storm';
    if (lowerBody.contains('disaster')) return 'Disaster';
    if (lowerBody.contains('emergency')) return 'Emergency';
    return 'Disaster';
  }

  String _getDisasterAdvice(String disasterName) {
    switch (disasterName.toLowerCase()) {
      case 'flood':
        return 'Stay near shelters and avoid low-lying areas';
      case 'earthquake':
        return 'Drop, cover, and hold on. Stay away from buildings';
      case 'cyclone':
        return 'Stay indoors and away from windows';
      case 'tsunami':
        return 'Move to higher ground immediately';
      case 'fire':
        return 'Evacuate immediately and follow emergency routes';
      case 'storm':
        return 'Stay indoors and avoid outdoor activities';
      case 'disaster':
        return 'Follow emergency instructions and stay safe';
      case 'emergency':
        return 'Follow local emergency guidelines';
      default:
        return 'Follow emergency instructions and stay safe';
    }
  }

  Future<void> _loadNearbyShelters() async {
    if (_userLat == null || _userLon == null) return;

    setState(() {
      _isLoadingShelters = true;
    });

    try {
      final shelters = await ShelterService.getSheltersWithinRadius(
        userLat: _userLat!,
        userLon: _userLon!,
        radiusKm: _shelterRadius,
      );

      if (mounted) {
        setState(() {
          nearbyShelters = shelters;
          _isLoadingShelters = false;
          // Don't change _isInDisasterArea here - it should only come from SMS detection
        });

        // Update unconscious detection when disaster area status changes
        _updateUnconsciousDetection();
      }
    } catch (e) {
      print('Error loading shelters: $e');
      if (mounted) {
        setState(() {
          _isLoadingShelters = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // Helper method to check if emergency features should be active
  bool get _areEmergencyFeaturesActive =>
      _emergencyFeaturesEnabled && _isInDisasterArea;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context)!;
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.grey[50],
      bottomNavigationBar: Bottom_NavBar(indexx: 0),
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Modern App Bar
            SliverAppBar(
              expandedHeight: 80,
              floating: true,
              pinned: false,
              backgroundColor: isDark ? Colors.black : Colors.white,
              elevation: 0,
              flexibleSpace: FlexibleSpaceBar(
                title: Text(
                  loc.appTitle,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : Colors.black,
                    letterSpacing: 2,
                  ),
                ),
                titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
              ),
            ),

            // Content
            SliverPadding(
              padding: const EdgeInsets.all(20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Alert Section
                  _buildAlertSection(isDark, loc),

                  const SizedBox(height: 32),

                  // Emergency Actions Section
                  _buildEmergencyActionsSection(loc, isDark, screenSize),

                  const SizedBox(height: 20),
                  _buildUnconsciousDetectionStatus(isDark, loc),
                  const SizedBox(height: 20),
                  _buildLocationAndStatus(isDark, loc),
                  const SizedBox(height: 32),
                  // Shelters Section
                  _buildSheltersSection(loc, isDark, screenSize),

                  const SizedBox(height: 32),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertSection(bool isDark, AppLocalizations loc) {
    // Alert should be grey if emergency features are disabled OR not in disaster area
    final isActive = _areEmergencyFeaturesActive;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: isActive
            ? LinearGradient(
          colors: [Color(0xFFE53935), Color(0xFFD32F2F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
              )
            : LinearGradient(
                colors: [Colors.grey[600]!, Colors.grey[700]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isActive ? Icons.warning : Icons.check_circle,
              color: isActive ? Colors.red : Colors.grey,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isActive
                      ? "${_disasterName.toUpperCase()} ALERT"
                      : (_isInDisasterArea
                            ? 'Emergency Features Disabled'
                            : 'No Alerts'),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isActive
                      ? _getDisasterAdvice(_disasterName)
                      : (_isInDisasterArea
                            ? 'Turn on emergency features to enable alerts'
                            : 'Your area is currently safe'),
                  style: TextStyle(fontSize: 14, color: Colors.white70),
                ),
                if (isActive && _remainingHours > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Alert expires in $_remainingHours hours',
                    style: TextStyle(fontSize: 12, color: Colors.white60),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyActionsSection(
    AppLocalizations loc,
    bool isDark,
    Size screenSize,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row with title and toggle
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          loc.emergency,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : Colors.black,
            letterSpacing: 2,
          ),
        ),
        Text(
          loc.actions,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : Colors.black,
            letterSpacing: 2,
          ),
                ),
              ],
            ),

            // Master emergency toggle
            Row(
              children: [
                Text(
                  (_emergencyFeaturesEnabled && _isInDisasterArea) ? 'ON' : 'OFF',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: (_emergencyFeaturesEnabled && _isInDisasterArea)
                        ? Colors.green
                        : Colors.red,
                  ),
                ),
                const SizedBox(width: 8),
                Switch(
                  value: _emergencyFeaturesEnabled && _isInDisasterArea,
                  onChanged: _isInDisasterArea ? (value) {
                    recordUserActivity();
                    setState(() {
                      _emergencyFeaturesEnabled = value;
                    });
                    // Update unconscious detection when toggle changes
                    _updateUnconsciousDetection();
                  } : (value) {
                    // Show message when trying to enable without disaster
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('No disaster detected. Emergency features can only be enabled during disasters.'),
                        backgroundColor: Colors.orange,
                        duration: Duration(seconds: 3),
                      ),
                    );
                  },
                  activeColor: Colors.green,
                  inactiveThumbColor: Colors.red,
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: 20),

        // Beacon Controls
        if (_isBeaconSupported && _hasBeaconPermission) ...[
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Victim Beacon',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[800],
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Broadcast your location to rescuers',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue[600],
                  ),
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isBeaconAdvertising ? null : _startBeacon,
                        icon: Icon(Icons.play_arrow, size: 18),
                        label: Text('Start Beacon'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isBeaconAdvertising ? Colors.grey : Colors.green,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isBeaconAdvertising ? _stopBeacon : null,
                        icon: Icon(Icons.stop, size: 18),
                        label: Text('Stop Beacon'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isBeaconAdvertising ? Colors.red : Colors.grey,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_isBeaconAdvertising) ...[
                  SizedBox(height: 8),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.green.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'BROADCASTING',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green[700],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Victim ID: ${_beaconService.currentVictimId}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.green[600],
                    ),
                  ),
                  Text(
                    'Location: ${_beaconService.currentDisasterZone}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.green[600],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],

        // Emergency actions with SOS on left and info on right
        Container(
          height: 220,
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[900] : Colors.grey[100],
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // SOS Button - Left side
              Expanded(
                flex: 1,
                child: AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _areEmergencyFeaturesActive
                          ? _pulseAnimation.value
                          : 1.0,
                      child: Container(
                        margin: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: _areEmergencyFeaturesActive
                              ? const LinearGradient(
                                  colors: [
                                    Color(0xFFFF5252),
                                    Color(0xFFD32F2F),
                                  ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                )
                              : LinearGradient(
                                  colors: [
                                    Colors.grey[600]!,
                                    Colors.grey[700]!,
                                  ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: _areEmergencyFeaturesActive
                                ? () {
                                    recordUserActivity();
                                    _showHelpDialog();
                                  }
                                : null,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 70,
                                  height: 70,
                                  decoration: BoxDecoration(
                                    color: _areEmergencyFeaturesActive
                                        ? Colors.white
                                        : Colors.grey[300],
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Icon(
                                      Icons.sos,
                                      size: 36,
                                      color: _areEmergencyFeaturesActive
                                          ? const Color(0xFFD32F2F)
                                          : Colors.grey[600],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  loc.sendHelp,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: _areEmergencyFeaturesActive
                                        ? Colors.white
                                        : Colors.grey[300],
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Explanation - Right side
              Expanded(
                flex: 1,
                  child: Container(
                  padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: _areEmergencyFeaturesActive
                            ? (isDark ? Colors.blue[300] : Colors.blue[700])
                            : Colors.grey,
                        size: 24,
                      ),
                      const SizedBox(height: 12),
                              Text(
                        'Emergency Assistance',
                        style: TextStyle(
                          fontSize: screenSize.width < 350 ? 14 : 16,
                                  fontWeight: FontWeight.bold,
                          color: _areEmergencyFeaturesActive
                              ? (isDark ? Colors.white : Colors.black)
                              : Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _areEmergencyFeaturesActive
                            ? 'Press to send your location and alert emergency contacts immediately'
                            : (!_emergencyFeaturesEnabled
                                  ? 'Emergency features are disabled. Turn on the toggle to enable.'
                                  : 'Emergency features are disabled as your area is safe'),
                        style: TextStyle(
                          fontSize: screenSize.width < 350 ? 11 : 13,
                          color: _areEmergencyFeaturesActive
                              ? (isDark ? Colors.white70 : Colors.black54)
                              : Colors.grey[500],
                          height: 1.3,
                          ),
                        ),
                      ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  double _shelterRadius = 30.0;
  Widget _buildSheltersSection(
    AppLocalizations loc,
    bool isDark,
    Size screenSize,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          loc.nearby,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : Colors.black,
            letterSpacing: 2,
          ),
        ),
        Text(
          loc.shelters,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : Colors.black,
            letterSpacing: 2,
          ),
        ),
              ],
            ),

            // Filter button
            IconButton(
              onPressed: _showRadiusFilterDialog,
              icon: Icon(
                Icons.filter_list,
                color: isDark ? Colors.white : Colors.black,
              ),
              tooltip: 'Filter by distance',
            ),
          ],
        ),

        // Radius indicator
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            'Within ${_shelterRadius.toStringAsFixed(0)} km',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
        ),

        const SizedBox(height: 10),

        _isLoadingShelters
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(40.0),
                  child: CircularProgressIndicator(),
                ),
              )
            : nearbyShelters.isEmpty
            ? _buildNoSheltersFound(isDark)
            : Column(
                children: [
                  ...nearbyShelters
                      .map(
                        (shelter) => Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _buildProfessionalShelterCard(shelter, isDark),
                        ),
                      )
                      .toList(),
                ],
              ),
      ],
    );
  }

  void _showRadiusFilterDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Filter Nearby Shelters'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Select maximum distance (km):'),
                  SizedBox(height: 20),
                  Slider(
                    value: _shelterRadius,
                    min: 5,
                    max: 100,
                    divisions: 19,
                    label: _shelterRadius.round().toString(),
                    onChanged: (value) {
                      setState(() {
                        _shelterRadius = value;
                      });
                    },
                  ),
                  Text('${_shelterRadius.toStringAsFixed(0)} km'),
                  SizedBox(height: 20),
                  OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      context.go('/shelter');
                    },
                    child: Text('View All Shelters'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _loadNearbyShelters();
                  },
                  child: Text('Apply Filter'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildNoSheltersFound(bool isDark) {
    return Container(
      height: 200,
      margin: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.home_work_outlined, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No Shelters Found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No shelters found within 10km radius',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadNearbyShelters,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfessionalShelterCard(ShelterModel shelter, bool isDark) {
    final distance = _userLat != null && _userLon != null
        ? shelter.calculateDistance(_userLat!, _userLon!)
        : 0.0;

    final availableSpaces = shelter.capacity - shelter.currentOccupancy;
    final occupancyPercentage = shelter.currentOccupancy / shelter.capacity;

    Color statusColor;

    if (occupancyPercentage >= 1.0) {
      statusColor = const Color(0xFFD32F2F);
    } else if (occupancyPercentage >= 0.8) {
      statusColor = const Color(0xFFFF8F00);
    } else {
      statusColor = const Color(0xFF1976D2);
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey[800]!, width: 1),
              boxShadow: [
                BoxShadow(
            color: Colors.black.withOpacity(0.2),
                  blurRadius: 12,
            offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _showShelterDetails(shelter),
                child: Padding(
            padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                Row(
                  children: [
                    Container(
                      width: 14,
                      height: 14,
                            decoration: BoxDecoration(
                        color: statusColor,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                            color: statusColor.withOpacity(0.5),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                    ),
                    const SizedBox(width: 16),

                    Expanded(
                      child: Text(
                        shelter.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),

                    if (_userLat != null && _userLon != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4285F4).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFF4285F4).withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          '${distance.toStringAsFixed(1)} km',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF4285F4),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                      ),

                      const SizedBox(height: 12),

                Text(
                  shelter.address,
                          style: TextStyle(
                            fontSize: 14,
                    color: Colors.grey[400],
                    height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 20),

                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.people_rounded,
                        size: 18,
                        color: Colors.grey[300],
                      ),
                    ),
                    const SizedBox(width: 12),
                      Text(
                      'Capacity: ${shelter.currentOccupancy}/${shelter.capacity}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '$availableSpaces spaces available',
                      style: TextStyle(
                        fontSize: 14,
                        color: availableSpaces > 0
                            ? const Color(0xFF4CAF50)
                            : const Color(0xFFD32F2F),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                Row(
                  children: [
                      Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                        color: shelter.status == 'Closed'
                            ? Colors.red.withOpacity(0.2)
                            : Colors.green.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: shelter.status == 'Closed'
                              ? Colors.red.withOpacity(0.3)
                              : Colors.green.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            shelter.status == 'Open'
                                ? Icons.check_circle
                                : shelter.status == 'Closed'
                                ? Icons.cancel
                                : Icons.info,
                            color: shelter.status == 'Closed'
                                ? Colors.red
                                : Colors.green,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            shelter.status,
                          style: TextStyle(
                              color: shelter.status == 'Closed'
                                  ? Colors.red
                                  : Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 10),
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: occupancyPercentage.clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: [
                          BoxShadow(
                            color: statusColor.withOpacity(0.5),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _getDirectionsToShelter(shelter),
                        icon: const Icon(Icons.directions_rounded, size: 18),
                        label: const Text('Directions'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(color: Colors.grey[700]!),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (shelter.contactNumber.isNotEmpty)
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _callShelter(shelter),
                          icon: const Icon(Icons.phone_rounded, size: 18),
                          label: const Text('Call'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4285F4),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
              ),
            ),
          ),
    );
  }

  Widget _buildLocationAndStatus(bool isDark, AppLocalizations loc) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [Colors.grey[850]!, Colors.grey[900]!]
              : [Colors.white, Colors.grey[100]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.3)
                : Colors.grey.withOpacity(0.2),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Location
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.location_on, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
              Text(
                loc.locationLabel,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    if (_userLat != null && _userLon != null)
                      Text(
                        'Lat: ${_userLat!.toStringAsFixed(6)}, Lon: ${_userLon!.toStringAsFixed(6)}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      )
                    else
                      Text(
                        'Location not available',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue[300],
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.location_city, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loc.city,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    Text(
                      _currentCity,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _isOnline ? Colors.green : Colors.orange,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isOnline
                      ? Icons.signal_cellular_4_bar
                      : Icons.signal_cellular_off,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _isOnline ? 'Online' : 'Offline',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: (_isOnline ? Colors.green : Colors.orange).withOpacity(
                    0.2,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _isOnline ? 'Online' : 'Offline',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: _isOnline ? Colors.green : Colors.orange,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUnconsciousDetectionStatus(bool isDark, AppLocalizations loc) {
    // Show as disabled/grey when emergency features are off
    final isUnconsciousActive =
        _areEmergencyFeaturesActive && _unconsciousDetectionEnabled;

    return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [Colors.grey[850]!, Colors.grey[900]!]
              : [Colors.white, Colors.grey[100]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.3)
                : Colors.grey.withOpacity(0.2),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
        ),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isUnconsciousActive ? Colors.green : Colors.grey,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isUnconsciousActive ? Icons.visibility : Icons.visibility_off,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
            Text(
                'Unconscious Detection',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const Spacer(),
              Switch(
                value: _unconsciousDetectionEnabled,
                onChanged: _areEmergencyFeaturesActive
                    ? (value) async {
                        setState(() {
                          _unconsciousDetectionEnabled = value;
                        });
                        _updateUnconsciousDetection();
                      }
                    : null, // Disable switch if emergency features are off
                activeColor: Colors.green,
            ),
          ],
        ),

          const SizedBox(height: 12),

          Row(
            children: [
              Icon(
                !_emergencyFeaturesEnabled
                    ? Icons.toggle_off
                    : (_isInDisasterArea ? Icons.warning : Icons.check_circle),
                color: !_emergencyFeaturesEnabled
                    ? Colors.grey
                    : (_isInDisasterArea ? Colors.orange : Colors.green),
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                !_emergencyFeaturesEnabled
                    ? 'Emergency Features Off'
                    : (_isInDisasterArea ? 'In Disaster Area' : 'Safe Area'),
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Text(
            !_emergencyFeaturesEnabled
                ? 'Turn on emergency features to enable unconscious detection'
                : (_areEmergencyFeaturesActive
                      ? (_unconsciousDetectionEnabled
                            ? 'Monitoring movement and activity for unconscious detection'
                            : 'Unconscious detection is disabled')
                      : 'Unconscious detection is disabled as your area is safe'),
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  void _showHelpDialog() {
    recordUserActivity();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        final loc = AppLocalizations.of(context)!;
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.sos, color: Colors.red),
              const SizedBox(width: 8),
              Text(loc.sendRequest),
            ],
          ),
          content: Text(loc.sendRequestMsg),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                recordUserActivity();
              },
              child: Text(loc.cancel),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _sendHelpRequest();
                recordUserActivity();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(loc.sendHelp, style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _showShelterDetails(ShelterModel shelter) {
    final distance = _userLat != null && _userLon != null
        ? shelter.calculateDistance(_userLat!, _userLon!)
        : 0.0;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 60,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[500],
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1976D2).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFF1976D2).withOpacity(0.3),
                        ),
                      ),
                      child: const Icon(
                        Icons.home_rounded,
                        color: Color(0xFF1976D2),
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            shelter.name,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: shelter.status == 'Available'
                                  ? const Color(0xFF4CAF50).withOpacity(0.2)
                                  : const Color(0xFFFF8F00).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: shelter.status == 'Available'
                                    ? const Color(0xFF4CAF50).withOpacity(0.3)
                                    : const Color(0xFFFF8F00).withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              shelter.status,
                              style: TextStyle(
                                color: shelter.status == 'Available'
                                    ? const Color(0xFF4CAF50)
                                    : const Color(0xFFFF8F00),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey[700]!),
                  ),
                  child: Column(
                    children: [
                      _buildEnhancedInfoRow(
                        Icons.location_on_rounded,
                        'Distance',
                        '${distance.toStringAsFixed(1)} km away',
                        const Color(0xFF4285F4),
                      ),
                      const Divider(height: 24, color: Colors.grey),
                      _buildEnhancedInfoRow(
                        Icons.people_rounded,
                        'Total Capacity',
                        '${shelter.capacity} people',
                        const Color(0xFF9C27B0),
                      ),
                      const Divider(height: 24, color: Colors.grey),
                      _buildEnhancedInfoRow(
                        Icons.group_rounded,
                        'Currently Occupied',
                        '${shelter.currentOccupancy} people',
                        const Color(0xFFFF5722),
                      ),
                      const Divider(height: 24, color: Colors.grey),
                      _buildEnhancedInfoRow(
                        Icons.meeting_room_rounded,
                        'Available Spaces',
                        '${shelter.capacity - shelter.currentOccupancy} spaces',
                        const Color(0xFF4CAF50),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey[700]!),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE91E63).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.place_rounded,
                          color: Color(0xFFE91E63),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Address',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              shelter.address,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                if (shelter.contactNumber.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey[700]!),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00BCD4).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.phone_rounded,
                            color: Color(0xFF00BCD4),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Contact',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                shelter.contactNumber,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                if (shelter.amenities.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey[700]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.apartment_rounded,
                              color: Color(0xFFFFC107),
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Amenities',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: shelter.amenities
                              .map(
                                (amenity) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF4285F4,
                                    ).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(
                                        0xFF4285F4,
                                      ).withOpacity(0.3),
                                    ),
                                  ),
                                  child: Text(
                                    amenity,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF4285F4),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _getDirectionsToShelter(shelter);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4285F4),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        icon: const Icon(Icons.directions_rounded),
                        label: const Text(
                          'Get Directions',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (shelter.contactNumber.isNotEmpty)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _callShelter(shelter);
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(color: Colors.grey[600]!),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.phone_rounded),
                          label: const Text(
                            'Call Shelter',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                  ],
                ),

                SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEnhancedInfoRow(
    IconData icon,
    String label,
    String value,
    Color iconColor,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: iconColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _sendHelpRequest() {
    // Only send help request if emergency features are active
    if (!_areEmergencyFeaturesActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.warning, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                'Emergency features are disabled',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      return;
    }

    final telephony = Telephony.instance;
    final battery = Battery();
    final loc = AppLocalizations.of(context)!;

    print("Starting to send help request...");

    telephony.requestPhoneAndSmsPermissions
        .then((isGranted) {
          if (isGranted ?? false) {
            print("Permissions granted");

            battery.batteryLevel
                .then((batteryLevel) {
                  print("Battery level fetched: $batteryLevel%");

                  String timestamp = DateFormat(
                    "yyyy-MM-dd HH:mm:ss",
                  ).format(DateTime.now());
                  print("Timestamp: $timestamp");

                  Map<String, dynamic> messageJson = {
                    "lat": _userLat,
                    "lon": _userLon,
                    "msg": "Help needed",
                    "bat": batteryLevel,
                    "sos": "102",
                    "time": timestamp,
                  };

                  String jsonPart = jsonEncode(messageJson);
                  String message = "DISASTERLINKx9040\n$jsonPart";

                  print("--------------------------------");
                  print("Message with header: $message");
                  print("Message length: ${message.length} characters");
                  print("Phone number: 917400358566");

                  if (message.length > 160) {
                    print(
                      "WARNING: Message exceeds standard SMS length (160 chars)",
                    );
                  }
                  if (message.length > 1600) {
                    print(
                      "ERROR: Message exceeds extended SMS length (1600 chars)",
                    );
                  }

                  telephony
                      .sendSms(to: "917400358566", message: message)
                      .then((value) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
                                Text(
                                  loc.helpSentSuccess,
                                  style: TextStyle(color: Colors.white),
                                ),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        );
                      })
                      .catchError((error) {
                        print("=== SMS SEND ERROR ===");
                        print("Error: $error");
                        print("Error type: ${error.runtimeType}");
                        print("Failed message: $message");
                        print("Failed phone: 917400358566");

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("SMS Failed: $error"),
                            backgroundColor: Colors.red,
                          ),
                        );
                      });
                })
                .catchError((batteryError) {
                  print("Battery level error: $batteryError");
                });
          } else {
            print("Permissions denied");
          }
        })
        .catchError((permissionError) {
          print("Permission request error: $permissionError");
        });
  }

  void _getDirectionsToShelter(ShelterModel shelter) {
    print(
      'Getting directions to ${shelter.name} at ${shelter.latitude}, ${shelter.longitude}',
    );
    final url =
        'https://www.google.com/maps/dir/?api=1&destination=${shelter.latitude},${shelter.longitude}';
    launchUrl(Uri.parse(url));
  }

  void _callShelter(ShelterModel shelter) {
    print('Calling ${shelter.name} at ${shelter.contactNumber}');
    final url = 'tel:${shelter.contactNumber}';
    launchUrl(Uri.parse(url));
  }
}
