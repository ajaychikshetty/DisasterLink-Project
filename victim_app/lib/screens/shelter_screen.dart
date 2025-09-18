// ignore_for_file: unused_result

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:victim_app/widgets/bottom_navbar.dart' show Bottom_NavBar;
import '../l10n/app_localizations.dart';
import '../models/shelter_model.dart';
import '../services/shelter_service.dart';
import '../services/location_service.dart';
import '../mixins/unconscious_activity_mixin.dart';
import 'package:url_launcher/url_launcher.dart';

// Riverpod provider for shelters
final sheltersProvider = FutureProvider<List<ShelterModel>>((ref) async {
  return await ShelterService.getAllShelters();
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

  // Default map center (you can change this to your preferred location)
  static const LatLng _defaultCenter = LatLng(19.0760, 72.8777); // Mumbai

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    print('Initializing services...');

    // Get user location
    await _getUserLocation();
    print('Location initialized');

    // Debug existing shelters
    await ShelterService.debugShelters();

    // Force refresh the provider after initialization
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        ref.refresh(sheltersProvider);
      }
    });
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

  void _createMarkers(List<ShelterModel> shelters) {
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

    // Add shelter markers
    for (final shelter in shelters) {
      final occupancyPercentage = shelter.currentOccupancy / shelter.capacity;
      Color markerColor = const Color(0xFF1976D2); // Professional blue
      
      // Keep the same logic for different occupancy levels but with professional colors
      if (occupancyPercentage >= 1.0) {
        markerColor = const Color(0xFFD32F2F); // Professional red
      } else if (occupancyPercentage >= 0.8) {
        markerColor = const Color(0xFFFF8F00); // Professional orange
      }

      markers.add(
        Marker(
          point: LatLng(shelter.latitude, shelter.longitude),
          width: 36,
          height: 44,
          child: GestureDetector(
            onTap: () => _showShelterDetails(shelter),
            child: _buildGoogleStylePin(
              color: markerColor,
              icon: Icons.home_rounded,
              size: 28,
            ),
          ),
        ),
      );
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
    final sheltersAsync = ref.watch(sheltersProvider);

    return Scaffold(
      backgroundColor: Colors.black, // Keep black background as requested
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
                  loc.shelters,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                  'Find nearby emergency shelters',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[400],
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
                  onPressed: () => ref.refresh(sheltersProvider),
                  icon: const Icon(
                  Icons.refresh_rounded,
                  color: Colors.white,
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
                FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _userLatitude != null && _userLongitude != null
                    ? LatLng(_userLatitude!, _userLongitude!)
                    : _defaultCenter,
                  initialZoom: 12,
                  minZoom: 5,
                  maxZoom: 18,
                  interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all,
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

                // My Location Button (like Google Maps)
                Positioned(
                right: 16,
                bottom: 16,
                child: Container(
                  decoration: BoxDecoration(
                  color: Colors.white,
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
                  onPressed: _centerMapOnUser,
                  icon: const Icon(
                    Icons.my_location,
                    color: Color(0xFF4285F4),
                  ),
                  iconSize: 20,
                  ),
              ),
            ),
          ],
              ),
            ),
            ),

            // Enhanced Map Legend
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
                const Color(0xFF1976D2),
                'Available',
                Icons.home_rounded,
              ),
              _buildEnhancedLegendItem(
                const Color(0xFFFF8F00),
                'Limited',
                Icons.home_rounded,
              ),
              _buildEnhancedLegendItem(
                const Color(0xFFD32F2F),
                'Full',
                Icons.home_rounded,
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
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.white),
          SizedBox(height: 16),
          Text(
            'Loading shelters...',
            style: TextStyle(color: Colors.white),
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
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          const Text(
            'Error loading shelters',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            error.toString(),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => ref.refresh(sheltersProvider),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildSheltersList(List<ShelterModel> shelters, bool isDark) {
    if (shelters.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.home_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No shelters available',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            SizedBox(height: 8),
            Text(
              'Check back later for available shelters',
              style: TextStyle(color: Colors.grey),
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
        return _buildProfessionalShelterCard(shelters[index], isDark);
    },
  );
}

  Widget _buildProfessionalShelterCard(ShelterModel shelter, bool isDark) {
    final distance = _userLatitude != null && _userLongitude != null
        ? shelter.calculateDistance(_userLatitude!, _userLongitude!)
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
                    // Status indicator with enhanced design
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
                    
                    // Distance with enhanced styling
                    if (_userLatitude != null && _userLongitude != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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

                // Address with enhanced styling
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
                
                // Capacity info with enhanced design
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
                        color: availableSpaces > 0 ? const Color(0xFF4CAF50) : const Color(0xFFD32F2F),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Enhanced capacity bar
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
                
                const SizedBox(height: 20),
                
                // Enhanced action buttons
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

void _showShelterDetails(ShelterModel shelter) {
  final distance = _userLatitude != null && _userLongitude != null
      ? shelter.calculateDistance(_userLatitude!, _userLongitude!)
      : 0.0;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => DraggableScrollableSheet( // Changed to DraggableScrollableSheet
      expand: false,
      initialChildSize: 0.7, // Initial size when opened
      minChildSize: 0.5, // Minimum size when dragged down
      maxChildSize: 0.9, // Maximum size when dragged up
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
          controller: scrollController, // Connect the scroll controller
        child: Column(
          mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar with improved visibility
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

              // Shelter header with enhanced design
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
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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

              // Detailed information in cards
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

              // Address card
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

              // Amenities section
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
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF4285F4).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFF4285F4).withOpacity(0.3),
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

              // Enhanced action buttons
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

  void _getDirectionsToShelter(ShelterModel shelter) {
    print('Getting directions to ${shelter.name} at ${shelter.latitude}, ${shelter.longitude}');
    final url = 'https://www.google.com/maps/dir/?api=1&destination=${shelter.latitude},${shelter.longitude}';
    launchUrl(Uri.parse(url));
  }

  void _callShelter(ShelterModel shelter) {
    print('Calling ${shelter.name} at ${shelter.contactNumber}');
    final url = 'tel:${shelter.contactNumber}';
    launchUrl(Uri.parse(url));
  }
}