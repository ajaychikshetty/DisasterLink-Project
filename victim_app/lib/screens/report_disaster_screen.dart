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

// Riverpod provider for shelters
final sheltersProvider = FutureProvider<List<ShelterModel>>((ref) async {
  return await ShelterService.getAllShelters();
});

class ReportDisasterScreen extends ConsumerStatefulWidget {
  const ReportDisasterScreen({super.key});
  @override
  ConsumerState<ReportDisasterScreen> createState() =>
      _ReportDisasterScreenState();
}

class _ReportDisasterScreenState extends ConsumerState<ReportDisasterScreen>
    with SingleTickerProviderStateMixin, UnconsciousActivityMixin {
  final MapController _mapController = MapController();
  List<Marker> _markers = [];

  // User location
  double? _userLatitude;
  double? _userLongitude;

  // Fire report location
  LatLng? _selectedFireLocation;
  bool _isSelectingLocation = false;

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

    // Add sample data if needed (for testing)
    print('Sample data check completed');

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

        // Center map on user location with zoom
        _mapController.move(LatLng(_userLatitude!, _userLongitude!), 15.0);

        // Add user location marker
        _addUserLocationMarker();
      }
    } catch (e) {
      print('Error getting location: $e');
    }
  }

  void _addUserLocationMarker() {
    if (_userLatitude == null || _userLongitude == null) return;

    setState(() {
      _markers.add(
        Marker(
          point: LatLng(_userLatitude!, _userLongitude!),
          width: 40,
          height: 40,
          child: const Icon(Icons.location_pin, color: Colors.blue, size: 40),
        ),
      );
    });
  }

  void _addFireLocationMarker(LatLng point) {
    setState(() {
      // Remove any existing fire markers
      _markers.removeWhere(
        (marker) =>
            marker.child is Icon && (marker.child as Icon).color == Colors.red,
      );

      // Add new fire marker
      _markers.add(
        Marker(
          point: point,
          width: 50,
          height: 50,
          child: const Icon(
            Icons.local_fire_department,
            color: Colors.red,
            size: 50,
          ),
        ),
      );
    });
  }

  void _centerMapOnUserLocation() {
    if (_userLatitude != null && _userLongitude != null) {
      _mapController.move(LatLng(_userLatitude!, _userLongitude!), 15.0);
    }
  }

  void _selectCurrentLocation() {
    if (_userLatitude != null && _userLongitude != null) {
      setState(() {
        _selectedFireLocation = LatLng(_userLatitude!, _userLongitude!);
        _isSelectingLocation = true;
      });
      _addFireLocationMarker(_selectedFireLocation!);
    }
  }

  void _showConfirmationDialog() {
    if (_selectedFireLocation == null) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text(
            "Confirm the fire location",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLocationOption("Waldpawla Farm Langdon birth"),
                _buildLocationOption("Fokegoshi-Treigobar"),
                _buildLocationOption("Barnard Caribe Outa land"),
                _buildLocationOption("Untied migration"),
                const SizedBox(height: 16),
                const Divider(color: Colors.grey),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        "Cancel",
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        // Handle confirmation logic here
                        print("Fire location confirmed");
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      child: const Text("Confirm"),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLocationOption(String location) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.location_on, color: Colors.red, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              location,
              style: const TextStyle(color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context)!;
    final sheltersAsync = ref.watch(sheltersProvider);
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      bottomNavigationBar: const Bottom_NavBar(indexx: 2),
      body: SafeArea(
        child: Stack(
          children: [
            // Main content
            SingleChildScrollView(
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        children: [
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Report Disaster",
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  Container(
                    width: double.infinity,
                    height: screenSize.height * 0.72,
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
                              initialCenter:
                                  _userLatitude != null &&
                                      _userLongitude != null
                                  ? LatLng(_userLatitude!, _userLongitude!)
                                  : _defaultCenter,
                              initialZoom: 15.0,
                              minZoom: 5,
                              maxZoom: 18,
                              interactionOptions: const InteractionOptions(
                                flags: InteractiveFlag.all,
                              ),
                              onMapReady: () {
                                if (_userLatitude != null &&
                                    _userLongitude != null) {
                                  _mapController.move(
                                    LatLng(_userLatitude!, _userLongitude!),
                                    15.0,
                                  );
                                }
                              },
                              onTap: (tapPosition, point) {
                                setState(() {
                                  _selectedFireLocation = point;
                                  _isSelectingLocation = true;
                                });
                                _addFireLocationMarker(point);
                              },
                            ),
                            children: [
                              TileLayer(
                                urlTemplate:
                                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                userAgentPackageName: 'com.example.victim_app',
                                maxZoom: 18,
                              ),
                              MarkerLayer(markers: _markers),
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

                          // Current Location Button - Moved to top right
                          Positioned(
                            right: 16,
                            top: 16, // Changed from bottom to top
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
                                icon: const Icon(
                                  Icons.my_location,
                                  color: Colors.blue,
                                ),
                                onPressed: _centerMapOnUserLocation,
                              ),
                            ),
                          ),

                          // Select Current Location Button - Top right
                          Positioned(
                            right: 16,
                            top: 80, // Positioned below the location button
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
                                icon: const Icon(
                                  Icons.gps_fixed,
                                  color: Colors.red,
                                ),
                                onPressed: _selectCurrentLocation,
                                tooltip:
                                    "Select current location for fire report",
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 100),
                ],
              ),
            ),

            // Bottom overlay container with button - ALWAYS VISIBLE
            Positioned(
              bottom: 80,
              left: 40,
              right: 40,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title and status
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "DISASTERLINK",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[300],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Description - Changes based on selection state
                    // Text(
                    //   _isSelectingLocation
                    //     ? "Location selected. Ready to report fire."
                    //     : "Tap on map or use the GPS button to select fire location",
                    //   style: TextStyle(
                    //     fontSize: 14,
                    //     color: Colors.white70,
                    //   ),
                    // ),
                    const SizedBox(height: 16),

                    // Action button - Enabled only when location is selected
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isSelectingLocation
                            ? _showConfirmationDialog
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isSelectingLocation
                              ? Colors.red
                              : Colors.grey,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.report, size: 20),
                        label: const Text(
                          "Report Disaster",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 30,
              left: 40,
              right: 40,
              child: Center(
                child: Text(
                  _isSelectingLocation
                      ? "Location selected. Ready to report."
                      : "Tap on map or use the GPS button to select",
                  style: TextStyle(fontSize: 14, color: Colors.white70),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
