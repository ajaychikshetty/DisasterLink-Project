// ignore_for_file: unused_result

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:victim_app/widgets/bottom_navbar.dart' show Bottom_NavBar;
import '../l10n/app_localizations.dart';
import '../models/shelter_model.dart';
import '../services/location_service.dart';
import '../services/sms_service.dart';
import '../mixins/unconscious_activity_mixin.dart';
import 'package:url_launcher/url_launcher.dart';

// SMS-based shelter model for disaster shelters
class SmsShelterModel {
  final String name;
  final double latitude;
  final double longitude;
  final String contactNumber;
  final double distanceKm;
  final DateTime receivedAt;
  
  SmsShelterModel({
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.contactNumber,
    required this.distanceKm,
    required this.receivedAt,
  });

  double calculateDistance(double userLat, double userLon) {
    const double earthRadius = 6371; 
    
    double dLat = _degreesToRadians(latitude - userLat);
    double dLon = _degreesToRadians(longitude - userLon);
    
    double a = (sin(dLat / 2) * sin(dLat / 2)) +
        cos(_degreesToRadians(userLat)) * cos(_degreesToRadians(latitude)) *
        (sin(dLon / 2) * sin(dLon / 2));
    
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }
  
  double _degreesToRadians(double degrees) {
    return degrees * (pi / 180);
  }
}

// Riverpod provider for SMS-based shelters
final smsSheltersProvider = FutureProvider<List<SmsShelterModel>>((ref) async {
  return await _parseSheltersFromSms();
});

class ShelterScreen extends ConsumerStatefulWidget {
  const ShelterScreen({super.key});
  @override
  ConsumerState<ShelterScreen> createState() => _ShelterScreenState();
}

class _ShelterScreenState extends ConsumerState<ShelterScreen>
    with SingleTickerProviderStateMixin, UnconsciousActivityMixin {
  final MapController _mapController = MapController();
  List<Marker> _markers = [];
  
  // User location
  double? _userLatitude;
  double? _userLongitude;
  bool _isInDisasterArea = false;

  // Default map center (you can change this to your preferred location)
  static const LatLng _defaultCenter = LatLng(19.0760, 72.8777); // Mumbai

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    print('Initializing shelter services...');

    // Get user location
    await _getUserLocation();
    
    // Check disaster status
    await _checkDisasterStatus();
    
    print('Location and disaster status initialized');

    // Force refresh the provider after initialization
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        ref.refresh(smsSheltersProvider);
      }
    });
  }

  Future<void> _checkDisasterStatus() async {
    try {
      final smsMessages = await SmsService.getSmsFromLast7Days();
      
      bool hasDisasterMessage = false;
      for (final message in smsMessages) {
        if (message.body.contains('DISASTERLINKx9040') && 
            message.body.contains('Nearest shelters:')) {
          hasDisasterMessage = true;
          break;
        }
      }
      
      setState(() {
        _isInDisasterArea = hasDisasterMessage;
      });
      
      print('Disaster status: $_isInDisasterArea');
    } catch (e) {
      print('Error checking disaster status: $e');
      setState(() {
        _isInDisasterArea = false;
      });
    }
  }

  Future<void> _getUserLocation() async {
    try {
      final position = await LocationService.getLocationWithPermission();
      if (position != null) {
        setState(() {
          _userLatitude = position.latitude;
          _userLongitude = position.longitude;
        });
      }
    } catch (e) {
      print('Error getting location: $e');
    }
  }

  Widget _buildGoogleStylePin({
    required Color color,
    required IconData icon,
    bool isUser = false,
    double size = 32,
  }) {
    return Container(
      width: size,
      height: size + 8,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Pin shadow
          Positioned(
            bottom: 0,
            child: Container(
              width: size * 0.3,
              height: size * 0.15,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(100),
              ),
            ),
          ),
          // Main pin body
          Positioned(
            top: 0,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: 2.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: size * 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _createMarkers(List<SmsShelterModel> shelters) {
    final markers = <Marker>[];

    // Add user location marker if available
    if (_userLatitude != null && _userLongitude != null) {
      markers.add(
        Marker(
          point: LatLng(_userLatitude!, _userLongitude!),
          width: 40,
          height: 48,
          child: GestureDetector(
            onTap: () => _showUserLocationDetails(),
            child: _buildGoogleStylePin(
              color: const Color(0xFF4285F4), // Google blue
              icon: Icons.my_location,
              isUser: true,
              size: 32,
            ),
          ),
        ),
      );
    }

    // Add SMS shelter markers only if in disaster area
    if (_isInDisasterArea) {
      for (final shelter in shelters) {
        markers.add(
          Marker(
            point: LatLng(shelter.latitude, shelter.longitude),
            width: 36,
            height: 44,
            child: GestureDetector(
              onTap: () => _showSmsShelterDetails(shelter),
              child: _buildGoogleStylePin(
                color: const Color(0xFFD32F2F), // Emergency red for disaster shelters
                icon: Icons.local_hospital_rounded,
                size: 28,
              ),
            ),
          ),
        );
      }
    }

    setState(() {
      _markers = markers;
    });

    // Fit map to show all markers
    if (markers.isNotEmpty) {
      _fitMapToMarkers();
    }
  }

  void _showUserLocationDetails() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Location header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4285F4).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.my_location,
                    color: Color(0xFF4285F4),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Text(
                    'Your Current Location',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Location details
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                children: [
                  _buildLocationInfoRow(
                    Icons.location_on_outlined,
                    'Coordinates',
                    '${_userLatitude?.toStringAsFixed(6)}, ${_userLongitude?.toStringAsFixed(6)}',
                  ),
                  const Divider(height: 24),
                  _buildLocationInfoRow(
                    Icons.access_time_outlined,
                    'Last Updated',
                    'Just now',
                  ),
                  const Divider(height: 24),
                  _buildLocationInfoRow(
                    Icons.gps_fixed_outlined,
                    'Accuracy',
                    'High precision GPS',
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Action button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _centerMapOnUser();
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
                icon: const Icon(Icons.center_focus_strong),
                label: const Text(
                  'Center Map Here',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            
            SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            fontSize: 15,
            color: Colors.grey[700],
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  void _centerMapOnUser() {
    if (_userLatitude != null && _userLongitude != null) {
      _mapController.move(
        LatLng(_userLatitude!, _userLongitude!),
        15.0,
      );
    }
  }

  void _fitMapToMarkers() {
    if (_markers.isEmpty) return;

    final bounds = _calculateBounds();
    
    // Add some padding around the bounds
    const padding = EdgeInsets.all(60);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: padding,
        ),
      );
    });
  }

  LatLngBounds _calculateBounds() {
    final latitudes = _markers.map((m) => m.point.latitude).toList();
    final longitudes = _markers.map((m) => m.point.longitude).toList();

    return LatLngBounds(
      LatLng(
        latitudes.reduce((a, b) => a < b ? a : b),
        longitudes.reduce((a, b) => a < b ? a : b),
      ),
      LatLng(
        latitudes.reduce((a, b) => a > b ? a : b),
        longitudes.reduce((a, b) => a > b ? a : b),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context)!;
    final sheltersAsync = ref.watch(smsSheltersProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      bottomNavigationBar: const Bottom_NavBar(indexx: 1),
      body: SafeArea(
        child: sheltersAsync.when(
          data: (shelters) {
            _createMarkers(shelters);
            return SingleChildScrollView(
              child: Column(
                children: [
                  Container(
                    height: 90,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.grey[800]!,
                          width: 0.5,
                        ),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        children: [
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _isInDisasterArea ? 'Emergency Shelters' : loc.shelters,
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: _isInDisasterArea ? Colors.red[400] : Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _isInDisasterArea 
                                    ? 'Disaster response shelters'
                                    : 'No emergency shelters available',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: _isInDisasterArea ? Colors.grey[400] : Colors.grey[600],
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.grey[900],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: IconButton(
                              onPressed: () {
                                _checkDisasterStatus();
                                ref.refresh(smsSheltersProvider);
                              },
                              icon: Icon(
                                Icons.refresh_rounded,
                                color: _isInDisasterArea ? Colors.white : Colors.grey[600],
                                size: 22,
                              ),
                              tooltip: 'Refresh shelters',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Enhanced Map Section
                  Container(
                    height: 280,
                    margin: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Stack(
                        children: [
                          // Grey overlay when no disaster
                          if (!_isInDisasterArea)
                            Container(
                              width: double.infinity,
                              height: double.infinity,
                              color: Colors.grey.withOpacity(0.7),
                              child: const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.location_off,
                                      size: 48,
                                      color: Colors.grey,
                                    ),
                                    SizedBox(height: 12),
                                    Text(
                                      'No Emergency Active',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    Text(
                                      'Shelters unavailable',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          
                          FlutterMap(
                            mapController: _mapController,
                            options: MapOptions(
                              initialCenter: _userLatitude != null && _userLongitude != null
                                  ? LatLng(_userLatitude!, _userLongitude!)
                                  : _defaultCenter,
                              initialZoom: 12,
                              minZoom: 5,
                              maxZoom: 18,
                              interactionOptions: InteractionOptions(
                                flags: _isInDisasterArea ? InteractiveFlag.all : InteractiveFlag.none,
                              ),
                            ),
                            children: [
                              // OpenStreetMap Tiles
                              TileLayer(
                                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                userAgentPackageName: 'com.example.victim_app',
                                maxZoom: 18,
                              ),

                              // Markers Layer
                              MarkerLayer(markers: _markers),

                              // Attribution
                              RichAttributionWidget(
                                attributions: [
                                  TextSourceAttribution(
                                    '© OpenStreetMap',
                                    onTap: () {},
                                  ),
                                ],
                              ),
                            ],
                          ),

                          // My Location Button (disabled when no disaster)
                          Positioned(
                            right: 16,
                            bottom: 16,
                            child: Container(
                              decoration: BoxDecoration(
                                color: _isInDisasterArea ? Colors.white : Colors.grey[400],
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: IconButton(
                                onPressed: _isInDisasterArea ? _centerMapOnUser : null,
                                icon: Icon(
                                  Icons.my_location,
                                  color: _isInDisasterArea ? const Color(0xFF4285F4) : Colors.grey[600],
                                ),
                                iconSize: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Enhanced Map Legend (only show when disaster is active)
                  if (_isInDisasterArea)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[900],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey[800]!),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildEnhancedLegendItem(
                            const Color(0xFF4285F4),
                            'Your Location',
                            Icons.my_location,
                          ),
                          _buildEnhancedLegendItem(
                            const Color(0xFFD32F2F),
                            'Emergency Shelter',
                            Icons.local_hospital_rounded,
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey[700]!),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.info_outline, color: Colors.grey[600], size: 16),
                          const SizedBox(width: 8),
                          Text(
                            'Emergency shelters will appear during disasters',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 20),

                  // Enhanced Shelters List Section
                  Container(
                    height: MediaQuery.of(context).size.height * 0.6,
                    child: _buildSheltersList(shelters, isDark),
                  ),
                ],
              ),
            );
          },
          loading: () => _buildLoadingState(),
          error: (error, stack) => _buildErrorState(error),
        ),
      ),
    );
  }

  Widget _buildEnhancedLegendItem(Color color, String label, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Icon(icon, size: 10, color: Colors.white),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: _isInDisasterArea ? Colors.red : Colors.grey),
          const SizedBox(height: 16),
          Text(
            _isInDisasterArea ? 'Loading emergency shelters...' : 'Checking for shelters...',
            style: TextStyle(color: _isInDisasterArea ? Colors.white : Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(Object error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: _isInDisasterArea ? Colors.red : Colors.grey),
          const SizedBox(height: 16),
          Text(
            'Error loading shelters',
            style: TextStyle(
              fontSize: 18, 
              fontWeight: FontWeight.bold, 
              color: _isInDisasterArea ? Colors.white : Colors.grey
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error.toString(),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              _checkDisasterStatus();
              ref.refresh(smsSheltersProvider);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _isInDisasterArea ? Colors.red : Colors.grey,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildSheltersList(List<SmsShelterModel> shelters, bool isDark) {
    if (!_isInDisasterArea) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shield_outlined, size: 64, color: Colors.grey[600]),
            const SizedBox(height: 16),
            Text(
              'No Emergency Active',
              style: TextStyle(
                fontSize: 18, 
                fontWeight: FontWeight.bold, 
                color: Colors.grey[600]
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Emergency shelters will be available during disasters',
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (shelters.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.orange),
            SizedBox(height: 16),
            Text(
              'No Emergency Shelters Found',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            SizedBox(height: 8),
            Text(
              'Waiting for shelter information from authorities',
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Sort shelters by distance if location is available
    if (_userLatitude != null && _userLongitude != null) {
      shelters.sort((a, b) {
        final distanceA = a.calculateDistance(_userLatitude!, _userLongitude!);
        final distanceB = b.calculateDistance(_userLatitude!, _userLongitude!);
        return distanceA.compareTo(distanceB);
      });
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      itemCount: shelters.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        return _buildEmergencyShelterCard(shelters[index], isDark);
      },
    );
  }

  Widget _buildEmergencyShelterCard(SmsShelterModel shelter, bool isDark) {
    final distance = _userLatitude != null && _userLongitude != null
        ? shelter.calculateDistance(_userLatitude!, _userLongitude!)
        : shelter.distanceKm;

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.red.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _showSmsShelterDetails(shelter),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Emergency status indicator
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD32F2F),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFD32F2F).withOpacity(0.5),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    
                    // Shelter name
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
                    
                    // Distance
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD32F2F).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFD32F2F).withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        '${distance.toStringAsFixed(1)} km',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFFD32F2F),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Emergency shelter label
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.emergency, size: 12, color: Colors.red),
                      SizedBox(width: 4),
                      Text(
                        'EMERGENCY SHELTER',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Location info
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.location_on,
                        size: 18,
                        color: Colors.grey[300],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Coordinates',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey,
                            ),
                          ),
                          Text(
                            '${shelter.latitude.toStringAsFixed(6)}, ${shelter.longitude.toStringAsFixed(6)}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Received time
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.access_time,
                        size: 18,
                        color: Colors.grey[300],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Received ${_formatTimeAgo(shelter.receivedAt)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[400],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 20),
                
                // Enhanced action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _getDirectionsToSmsShelter(shelter),
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
                          onPressed: () => _callSmsShelter(shelter),
                          icon: const Icon(Icons.phone_rounded, size: 18),
                          label: const Text('Call'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD32F2F),
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

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  void _showSmsShelterDetails(SmsShelterModel shelter) {
    final distance = _userLatitude != null && _userLongitude != null
        ? shelter.calculateDistance(_userLatitude!, _userLongitude!)
        : shelter.distanceKm;

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
                // Handle bar
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

                // Emergency shelter header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD32F2F).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFD32F2F).withOpacity(0.3),
                        ),
                      ),
                      child: const Icon(
                        Icons.local_hospital_rounded,
                        color: Color(0xFFD32F2F),
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
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD32F2F).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFD32F2F).withOpacity(0.3),
                              ),
                            ),
                            child: const Text(
                              'EMERGENCY SHELTER',
                              style: TextStyle(
                                color: Color(0xFFD32F2F),
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

                // Detailed information
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
                        const Color(0xFFD32F2F),
                      ),
                      const Divider(height: 24, color: Colors.grey),
                      _buildEnhancedInfoRow(
                        Icons.gps_fixed_rounded,
                        'Coordinates',
                        '${shelter.latitude.toStringAsFixed(6)}, ${shelter.longitude.toStringAsFixed(6)}',
                        const Color(0xFF4285F4),
                      ),
                      const Divider(height: 24, color: Colors.grey),
                      _buildEnhancedInfoRow(
                        Icons.access_time_rounded,
                        'Information Received',
                        _formatTimeAgo(shelter.receivedAt),
                        const Color(0xFF9C27B0),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Contact information
                if (shelter.contactNumber.isNotEmpty)
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
                                'Emergency Contact',
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

                const SizedBox(height: 24),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _getDirectionsToSmsShelter(shelter);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD32F2F),
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
                            _callSmsShelter(shelter);
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

  Widget _buildEnhancedInfoRow(IconData icon, String label, String value, Color iconColor) {
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

  void _getDirectionsToSmsShelter(SmsShelterModel shelter) {
    print('Getting directions to ${shelter.name} at ${shelter.latitude}, ${shelter.longitude}');
    final url = 'https://www.google.com/maps/dir/?api=1&destination=${shelter.latitude},${shelter.longitude}';
    launchUrl(Uri.parse(url));
  }

  void _callSmsShelter(SmsShelterModel shelter) {
    print('Calling ${shelter.name} at ${shelter.contactNumber}');
    final url = 'tel:${shelter.contactNumber}';
    launchUrl(Uri.parse(url));
  }
}

// Function to parse shelters from SMS messages
Future<List<SmsShelterModel>> _parseSheltersFromSms() async {
  try {
    final smsMessages = await SmsService.getSmsFromLast7Days();
    final List<SmsShelterModel> shelters = [];

    for (final message in smsMessages) {
      if (message.body.contains('DISASTERLINKx9040') && 
          message.body.contains('Nearest shelters:')) {
        
        final shelterData = _extractShelterData(message.body, message.date);
        shelters.addAll(shelterData);
      }
    }

    // Remove duplicates based on coordinates
    final uniqueShelters = <String, SmsShelterModel>{};
    for (final shelter in shelters) {
      final key = '${shelter.latitude}_${shelter.longitude}';
      if (!uniqueShelters.containsKey(key) || 
          uniqueShelters[key]!.receivedAt.isBefore(shelter.receivedAt)) {
        uniqueShelters[key] = shelter;
      }
    }

    return uniqueShelters.values.toList();
  } catch (e) {
    print('Error parsing shelters from SMS: $e');
    return [];
  }
}

List<SmsShelterModel> _extractShelterData(String messageBody, DateTime receivedAt) {
  final List<SmsShelterModel> shelters = [];
  
  // Split message by lines and look for shelter information
  final lines = messageBody.split('\n');
  
  for (final line in lines) {
    // Look for pattern: Name (distance km, lat, lon, phone)
    final shelterPattern = RegExp(r'(.+?)\s*\((\d+\.?\d*)\s*km,\s*([+-]?\d+\.?\d*),\s*([+-]?\d+\.?\d*),?\s*([+\d\s-]+)?\)');
    final match = shelterPattern.firstMatch(line);
    
    if (match != null) {
      try {
        final name = match.group(1)?.trim() ?? 'Unknown Shelter';
        final distance = double.tryParse(match.group(2) ?? '0') ?? 0.0;
        final latitude = double.tryParse(match.group(3) ?? '0') ?? 0.0;
        final longitude = double.tryParse(match.group(4) ?? '0') ?? 0.0;
        final contactNumber = match.group(5)?.replaceAll(RegExp(r'[^\d+]'), '') ?? '';
        
        if (latitude != 0.0 && longitude != 0.0) {
          shelters.add(SmsShelterModel(
            name: name,
            latitude: latitude,
            longitude: longitude,
            contactNumber: contactNumber,
            distanceKm: distance,
            receivedAt: receivedAt,
          ));
        }
      } catch (e) {
        print('Error parsing shelter line: $line - $e');
      }
    }
  }
  
  return shelters;
}