import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rescuer_app/widgets/bottom_navbar.dart';
import 'package:rescuer_app/providers/ble_provider.dart';
import 'package:rescuer_app/services/ble_service.dart';
import 'package:permission_handler/permission_handler.dart';

class VictimsScreen extends ConsumerStatefulWidget {
  const VictimsScreen({super.key});

  @override
  ConsumerState<VictimsScreen> createState() => _VictimsScreenState();
}

class _VictimsScreenState extends ConsumerState<VictimsScreen> 
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _fadeController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _fadeAnimation;
  
  bool _isBluetoothEnabled = false;
  bool _isCheckingBluetooth = true;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );

    // Check Bluetooth status and initialize BLE service when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkBluetoothStatus();
      _fadeController.forward();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _checkBluetoothStatus() async {
    setState(() {
      _isCheckingBluetooth = true;
    });

    try {
      final bleService = ref.read(bleServiceProvider);
      final isEnabled = await bleService.isBluetoothEnabled();
      
      debugPrint('Bluetooth check result: $isEnabled');
      
      setState(() {
        _isBluetoothEnabled = isEnabled;
        _isCheckingBluetooth = false;
      });

      if (isEnabled) {
        await _initializeBle();
      }
    } catch (e) {
      debugPrint('Error checking Bluetooth status: $e');
      setState(() {
        _isBluetoothEnabled = false;
        _isCheckingBluetooth = false;
      });
    }
  }

  Future<void> _initializeBle() async {
    try {
      final bleService = ref.read(bleServiceProvider);
      final success = await bleService.initialize();
      if (success) {
        debugPrint('BLE initialized successfully');
      } else {
        debugPrint('BLE initialization failed');
      }
    } catch (e) {
      debugPrint('Error initializing BLE: $e');
    }
  }

  Future<void> _openBluetoothSettings() async {
    try {
      // First try to open Bluetooth settings directly
      await openAppSettings();
      
      // Alternative method using intent (Android specific)
      // You might need to add android_intent_plus package for this
      /*
      if (Platform.isAndroid) {
        final AndroidIntent intent = AndroidIntent(
          action: 'android.bluetooth.adapter.action.REQUEST_ENABLE',
        );
        await intent.launch();
      }
      */
      
      // Check again after a delay to see if Bluetooth was enabled
      Future.delayed(const Duration(seconds: 2), () {
        _checkBluetoothStatus();
      });
    } catch (e) {
      debugPrint('Error opening Bluetooth settings: $e');
      // Fallback to app settings
      openAppSettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    final victimsAsync = ref.watch(victimsStreamProvider);
    final isScanning = ref.watch(isScanningProvider);
    final bleInitialized = ref.watch(bleInitializedProvider);
    final victimCount = ref.watch(victimCountProvider);
    final nearestVictim = ref.watch(nearestVictimProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _buildAppBar(context),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: _isCheckingBluetooth 
          ? _buildLoadingState()
          : !_isBluetoothEnabled
            ? _buildBluetoothDisabledState()
            : _buildMainContent(victimsAsync, isScanning, victimCount, nearestVictim),
      ),
      floatingActionButton: _isBluetoothEnabled ? _buildEnhancedFAB(isScanning) : null,
      bottomNavigationBar: Bottom_NavBar(indexx: 2),
    );
  }

  Widget _buildMainContent(AsyncValue victimsAsync, bool isScanning, int victimCount, VictimBeacon? nearestVictim) {
    return Column(
      children: [
        _buildEnhancedStatusCard(victimCount, nearestVictim, isScanning),
        Expanded(
          child: victimsAsync.when(
            data: (victims) => _buildVictimsList(victims),
            loading: () => _buildScanningLoadingState(),
            error: (error, stack) => _buildVictimScanError('Error: $error'),
          ),
        ),
      ],
    );
  }

  Widget _buildScanningLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.grey[900],
              shape: BoxShape.circle,
            ),
            child: const CircularProgressIndicator(
              color: Colors.redAccent,
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'SCANNING FOR VICTIMS...',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVictimScanError(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.orangeAccent.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.orangeAccent.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.warning_amber_outlined,
                size: 48,
                color: Colors.orangeAccent,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'SCAN ERROR',
              style: TextStyle(
                color: Colors.orangeAccent,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 14,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                final bleService = ref.read(bleServiceProvider);
                await bleService.startScanning();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orangeAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'RETRY SCAN',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.black,
      elevation: 0,
      title: Row(
        children: [
          Container(
            width: 4,
            height: 28,
            decoration: BoxDecoration(
              color: Colors.redAccent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            "VICTIMS DETECTION",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: Colors.white,
            ),
          ),
        ],
      ),
      titleSpacing: 20,
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 16),
          child: IconButton(
            onPressed: () => _showSettingsDialog(),
            icon: const Icon(Icons.settings, color: Colors.white70),
          ),
        ),
      ],
    );
  }

  Widget _buildBluetoothDisabledState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.blueAccent.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.blueAccent.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.bluetooth_disabled,
                size: 48,
                color: Colors.blueAccent,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'BLUETOOTH DISABLED',
              style: TextStyle(
                color: Colors.blueAccent,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Bluetooth is required for victim detection.\nPlease enable Bluetooth to continue.',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 14,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _openBluetoothSettings,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 4,
              ),
              icon: const Icon(Icons.bluetooth, size: 20),
              label: const Text(
                'TURN ON BLUETOOTH',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _checkBluetoothStatus,
              child: Text(
                'REFRESH STATUS',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedFAB(bool isScanning) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: isScanning ? _pulseAnimation.value : 1.0,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: isScanning 
                    ? Colors.redAccent.withOpacity(0.3)
                    : Colors.blueAccent.withOpacity(0.3),
                  blurRadius: 15,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: FloatingActionButton.extended(
              onPressed: _toggleScanning,
              backgroundColor: isScanning ? Colors.redAccent : Colors.blueAccent,
              foregroundColor: Colors.white,
              elevation: 8,
              icon: Icon(
                isScanning ? Icons.stop_circle : Icons.radar,
                size: 24,
              ),
              label: Text(
                isScanning ? 'STOP' : 'SCAN',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEnhancedStatusCard(int victimCount, VictimBeacon? nearestVictim, bool isScanning) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.grey[900]!,
            Colors.grey[850]!,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isScanning ? Colors.redAccent.withOpacity(0.3) : Colors.grey[700]!,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: isScanning ? _pulseAnimation.value * 0.1 + 0.9 : 1.0,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isScanning 
                            ? Colors.redAccent.withOpacity(0.2)
                            : Colors.grey[700]!.withOpacity(0.3),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.radar,
                          color: isScanning ? Colors.redAccent : Colors.grey[400],
                          size: 24,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isScanning ? 'SCANNING ACTIVE' : 'SCANNING STOPPED',
                        style: TextStyle(
                          color: isScanning ? Colors.redAccent : Colors.grey[400],
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                      Text(
                        isScanning ? 'Searching for victims in area...' : 'Tap scan to begin detection',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildEnhancedStatItem(
                    'TOTAL VICTIMS',
                    victimCount.toString(),
                    Icons.people_outline,
                    victimCount > 0 ? Colors.redAccent : Colors.grey[500]!,
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: Colors.grey[700],
                  ),
                  if (nearestVictim != null)
                    _buildEnhancedStatItem(
                      'NEAREST',
                      '${nearestVictim.distance.toStringAsFixed(1)}M',
                      Icons.near_me,
                      _getDistanceColor(nearestVictim.distance),
                    )
                  else
                    _buildEnhancedStatItem(
                      'NEAREST',
                      '---',
                      Icons.near_me_disabled,
                      Colors.grey[500]!,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 24,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 11,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }

  Widget _buildVictimsList(List<VictimBeacon> victims) {
    if (victims.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[900]!.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.bluetooth_disabled,
                size: 48,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'NO VICTIMS DETECTED',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Ensure BLE scanning is active and victims are within range',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }

    // Sort victims by distance (closest first)
    victims.sort((a, b) => a.distance.compareTo(b.distance));

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: victims.length,
      itemBuilder: (context, index) {
        final victim = victims[index];
        return _buildEnhancedVictimCard(victim, index);
      },
    );
  }

  Widget _buildEnhancedVictimCard(VictimBeacon victim, int index) {
    final distanceColor = _getDistanceColor(victim.distance);
    final signalStrength = _getSignalStrength(victim.rssi);
    final isPhoneNumber = _isMobileNumber(victim.id);

    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 300 + (index * 100)),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.grey[900]!,
                    Colors.grey[850]!,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: distanceColor.withOpacity(0.3),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _showVictimDetails(victim),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                distanceColor.withOpacity(0.2),
                                distanceColor.withOpacity(0.1),
                              ],
                            ),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: distanceColor.withOpacity(0.5),
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            isPhoneNumber ? Icons.phone_android : Icons.person,
                            color: distanceColor,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    isPhoneNumber ? 'MOBILE' : 'VICTIM',
                                    style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: distanceColor.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      _getPriorityLabel(victim.distance),
                                      style: TextStyle(
                                        color: distanceColor,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                isPhoneNumber ? victim.id : 'ID: ${victim.id}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Zone: ${victim.disasterZone}',
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    Icons.location_on,
                                    size: 14,
                                    color: distanceColor,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${victim.distance.toStringAsFixed(1)}m',
                                    style: TextStyle(
                                      color: distanceColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Icon(
                                    _getSignalIcon(victim.rssi),
                                    size: 14,
                                    color: signalStrength.color,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    signalStrength.label,
                                    style: TextStyle(
                                      color: signalStrength.color,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          color: Colors.grey[600],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _getPriorityLabel(double distance) {
    if (distance < 5) return 'CRITICAL';
    if (distance < 15) return 'HIGH';
    if (distance < 50) return 'MEDIUM';
    return 'LOW';
  }

  IconData _getSignalIcon(int rssi) {
    if (rssi > -50) return Icons.signal_cellular_4_bar;
    if (rssi > -70) return Icons.signal_cellular_4_bar;
    if (rssi > -85) return Icons.signal_cellular_alt_2_bar;
    return Icons.signal_cellular_alt_1_bar;
  }

  Color _getDistanceColor(double distance) {
    if (distance < 5) return Colors.redAccent;
    if (distance < 15) return Colors.orangeAccent;
    if (distance < 50) return Colors.yellowAccent;
    return Colors.greenAccent;
  }

  ({Color color, String label}) _getSignalStrength(int rssi) {
    if (rssi > -50) return (color: Colors.greenAccent, label: 'Excellent');
    if (rssi > -70) return (color: Colors.yellowAccent, label: 'Good');
    if (rssi > -85) return (color: Colors.orangeAccent, label: 'Fair');
    return (color: Colors.redAccent, label: 'Poor');
  }

  String _formatLastSeen(DateTime lastSeen) {
    final now = DateTime.now();
    final difference = now.difference(lastSeen);
    
    if (difference.inSeconds < 60) {
      return '${difference.inSeconds}s ago';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else {
      return '${difference.inHours}h ago';
    }
  }

  bool _isMobileNumber(String text) {
    final cleanText = text.replaceAll(RegExp(r'[^\d+]'), '');
    final phoneRegex = RegExp(r'^\+?[1-9]\d{6,14}$');
    return phoneRegex.hasMatch(cleanText);
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.grey[900],
              shape: BoxShape.circle,
            ),
            child: const CircularProgressIndicator(
              color: Colors.blueAccent,
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'CHECKING BLUETOOTH...',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.redAccent.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.error_outline,
                size: 48,
                color: Colors.redAccent,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'CONNECTION ERROR',
              style: TextStyle(
                color: Colors.redAccent,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 14,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => _initializeBle(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'RETRY CONNECTION',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleScanning() {
    final bleService = ref.read(bleServiceProvider);
    final isScanning = ref.read(isScanningProvider);
    
    if (isScanning) {
      bleService.stopScanning();
    } else {
      bleService.startScanning();
    }
  }

  void _showVictimDetails(VictimBeacon victim) {
    final isPhoneNumber = _isMobileNumber(victim.id);
    final distanceColor = _getDistanceColor(victim.distance);
    final signalStrength = _getSignalStrength(victim.rssi);
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          distanceColor.withOpacity(0.2),
                          distanceColor.withOpacity(0.1),
                        ],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isPhoneNumber ? Icons.phone_android : Icons.person,
                      color: distanceColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isPhoneNumber ? 'MOBILE DEVICE' : 'VICTIM DETECTED',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                        Text(
                          isPhoneNumber ? victim.id : 'ID: ${victim.id}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildEnhancedDetailRow('Zone', victim.disasterZone, Icons.location_city),
              _buildEnhancedDetailRow('Distance', '${victim.distance.toStringAsFixed(1)} meters', Icons.location_on),
              _buildEnhancedDetailRow('Signal', '${victim.rssi} dBm (${signalStrength.label})', Icons.signal_cellular_alt),
              _buildEnhancedDetailRow('Last Seen', _formatLastSeen(victim.lastSeen), Icons.access_time),
              _buildEnhancedDetailRow('Priority', _getPriorityLabel(victim.distance), Icons.priority_high),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'CLOSE',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEnhancedDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: Colors.grey[500],
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                color: Colors.grey[500],
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'SCAN SETTINGS',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                Icons.bluetooth, 
                color: _isBluetoothEnabled ? Colors.blueAccent : Colors.grey,
              ),
              title: const Text('Bluetooth Status', style: TextStyle(color: Colors.white)),
              subtitle: Text(
                _isBluetoothEnabled ? 'Enabled' : 'Disabled', 
                style: TextStyle(
                  color: _isBluetoothEnabled ? Colors.greenAccent : Colors.redAccent,
                ),
              ),
              trailing: !_isBluetoothEnabled ? IconButton(
                onPressed: _openBluetoothSettings,
                icon: const Icon(Icons.settings, color: Colors.blueAccent),
              ) : null,
            ),
            ListTile(
              leading: const Icon(Icons.location_on, color: Colors.greenAccent),
              title: const Text('Location Services', style: TextStyle(color: Colors.white)),
              subtitle: Text('Required for BLE', style: TextStyle(color: Colors.grey[400])),
            ),
          ],
        ),
        actions: [
          if (!_isBluetoothEnabled)
            TextButton(
              onPressed: _openBluetoothSettings,
              child: const Text('ENABLE BLUETOOTH'),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('CLOSE'),
          ),
        ],
      ),
    );
  }
}