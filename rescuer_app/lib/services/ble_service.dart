// TODO Implement this library.
import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';

class VictimBeacon {
  final String id;
  final String disasterZone;
  final int rssi;
  final DateTime lastSeen;
  final double distance; // Approximate distance in meters

  VictimBeacon({
    required this.id,
    required this.disasterZone,
    required this.rssi,
    required this.lastSeen,
    required this.distance,
  });

  factory VictimBeacon.fromAdvertisement(DiscoveredDevice device, Map<String, dynamic> data) {
    // Calculate approximate distance based on RSSI
    // This is a rough estimation - actual distance depends on many factors
    double distance = _calculateDistance(device.rssi);
    
    return VictimBeacon(
      id: data['id'] ?? device.id,
      disasterZone: data['zone'] ?? 'Unknown',
      rssi: device.rssi,
      lastSeen: DateTime.now(),
      distance: distance,
    );
  }

  static double _calculateDistance(int rssi) {
    // Free space path loss formula approximation
    // This is a rough estimate and may vary significantly in real conditions
    if (rssi == 0) return -1.0;
    
    double ratio = rssi * 1.0;
    if (ratio < 0) {
      return pow(10, ((ratio + 100) / 20)).toDouble();
    } else {
      return pow(10, ((ratio - 100) / 20)).toDouble();
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'disasterZone': disasterZone,
      'rssi': rssi,
      'lastSeen': lastSeen.toIso8601String(),
      'distance': distance,
    };
  }
}

class BleService {
  static final BleService _instance = BleService._internal();
  factory BleService() => _instance;
  BleService._internal();

  final FlutterReactiveBle _ble = FlutterReactiveBle();
  final StreamController<List<VictimBeacon>> _victimsController = 
      StreamController<List<VictimBeacon>>.broadcast();
  
  Stream<List<VictimBeacon>> get victimsStream => _victimsController.stream;
  
  final Map<String, VictimBeacon> _discoveredVictims = {};
  StreamSubscription<DiscoveredDevice>? _scanSubscription;
  bool _isScanning = false;
  Timer? _cleanupTimer;

  // BLE Service UUID for disaster rescue
  static const String serviceUuid = "12345678-1234-1234-1234-123456789ABC";
  static const String characteristicUuid = "12345678-1234-1234-1234-123456789ABD";

  /// Initialize BLE service and request permissions
  Future<bool> initialize() async {
    try {
      debugPrint('Initializing BLE service...');
      
      // Request permissions first
      await _requestPermissions();
      
      // Wait for BLE to be ready with a timeout
      try {
        final status = await _ble.statusStream
            .where((status) => status == BleStatus.ready)
            .timeout(const Duration(seconds: 10))
            .first;
        
        if (status == BleStatus.ready) {
          debugPrint('BLE is ready');
          // Start cleanup timer to remove old beacons
          _startCleanupTimer();
          return true;
        } else {
          debugPrint('BLE not ready, status: $status');
          return false;
        }
      } catch (timeoutError) {
        debugPrint('BLE initialization timeout: $timeoutError');
        // Check current status as fallback
        final currentStatus = _ble.status;
        debugPrint('Current BLE status after timeout: $currentStatus');
        
        if (currentStatus == BleStatus.ready) {
          debugPrint('BLE is ready (fallback check)');
          _startCleanupTimer();
          return true;
        }
        return false;
      }
    } catch (e) {
      debugPrint('Failed to initialize BLE service: $e');
      // Try to get current status for debugging
      try {
        final currentStatus = _ble.status;
        debugPrint('Current BLE status: $currentStatus');
      } catch (statusError) {
        debugPrint('Could not get BLE status: $statusError');
      }
      return false;
    }
  }

  /// Request necessary permissions for BLE
  Future<void> _requestPermissions() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        debugPrint('Requesting Android BLE permissions...');
        
        // Request Bluetooth permissions
        final bluetoothScanStatus = await Permission.bluetoothScan.request();
        final bluetoothConnectStatus = await Permission.bluetoothConnect.request();
        final locationStatus = await Permission.locationWhenInUse.request();
        
        debugPrint('Bluetooth Scan: $bluetoothScanStatus');
        debugPrint('Bluetooth Connect: $bluetoothConnectStatus');
        debugPrint('Location: $locationStatus');
        
        if (bluetoothScanStatus != PermissionStatus.granted ||
            bluetoothConnectStatus != PermissionStatus.granted ||
            locationStatus != PermissionStatus.granted) {
          debugPrint('Some BLE permissions were denied');
        }
      }
    } catch (e) {
      debugPrint('Error requesting BLE permissions: $e');
    }
  }

  /// Start scanning for victim beacons
  Future<void> startScanning() async {
    if (_isScanning) return;

    try {
      _isScanning = true;
      debugPrint('Starting BLE scan for victim beacons...');

      _scanSubscription = _ble.scanForDevices(
        withServices: [], // Scan for all devices, not just specific service UUID
        scanMode: ScanMode.lowLatency,
        requireLocationServicesEnabled: false,
      ).listen(
        _onDeviceDiscovered,
        onError: (error) {
          debugPrint('BLE scan error: $error');
          _isScanning = false;
        },
      );
    } catch (e) {
      debugPrint('Failed to start BLE scanning: $e');
      _isScanning = false;
    }
  }

  /// Stop scanning for victim beacons
  Future<void> stopScanning() async {
    if (!_isScanning) return;

    try {
      await _scanSubscription?.cancel();
      _scanSubscription = null;
      _isScanning = false;
      debugPrint('BLE scanning stopped');
    } catch (e) {
      debugPrint('Failed to stop BLE scanning: $e');
    }
  }

  /// Handle discovered devices
  void _onDeviceDiscovered(DiscoveredDevice device) {
    try {
      // Debug: Log all discovered devices
      debugPrint('Discovered BLE device: ${device.name} (${device.id}) RSSI: ${device.rssi}');
      debugPrint('  Service UUIDs: ${device.serviceUuids}');
      debugPrint('  Manufacturer Data: ${device.manufacturerData}');
      
      // Check if it looks like a mobile number
      if (_isMobileNumber(device.name.toLowerCase())) {
        debugPrint('  📱 Mobile number detected: ${device.name}');
      }
      
      // Parse advertisement data
      final advertisementData = _parseAdvertisementData(device);
      
      if (advertisementData != null) {
        final victim = VictimBeacon.fromAdvertisement(device, advertisementData);
        _discoveredVictims[victim.id] = victim;
        
        debugPrint('✅ DISCOVERED VICTIM: ${victim.id} at ${victim.distance.toStringAsFixed(1)}m');
        
        // Emit updated list
        _victimsController.add(_discoveredVictims.values.toList());
      } else {
        debugPrint('  → Not a victim device (filtered out)');
      }
    } catch (e) {
      debugPrint('Error parsing device ${device.id}: $e');
    }
  }

  /// Check if a device name looks like a mobile number
  bool _isMobileNumber(String deviceName) {
    // Remove any non-digit characters except + for international numbers
    final cleanName = deviceName.replaceAll(RegExp(r'[^\d+]'), '');
    
    // Check if it looks like a phone number (7-15 digits, optionally starting with +)
    final phoneRegex = RegExp(r'^\+?[1-9]\d{6,14}$');
    return phoneRegex.hasMatch(cleanName);
  }

  /// Extract phone number from manufacturer data
  String _extractPhoneNumberFromManufacturerData(Uint8List data) {
    try {
      // Convert bytes to string and look for phone number patterns
      final dataString = String.fromCharCodes(data);
      debugPrint('  Manufacturer data as string: $dataString');
      
      // Look for phone number patterns in the data
      final phoneRegex = RegExp(r'\+?[1-9]\d{6,14}');
      final match = phoneRegex.firstMatch(dataString);
      if (match != null) {
        return match.group(0)!;
      }
      
      // Alternative: Look for sequences of digits that could be phone numbers
      final digitSequence = RegExp(r'\d{7,15}');
      final digitMatch = digitSequence.firstMatch(dataString);
      if (digitMatch != null) {
        final digits = digitMatch.group(0)!;
        // Check if it looks like a valid phone number
        if (digits.length >= 10 && digits.length <= 15) {
          return '+$digits'; // Add + prefix for international format
        }
      }
      
      // Special case: Look for the specific pattern from your victim app
      // Based on your logs: [52, 18, 229, 135, 43, 57, 49, 57, 57, 54, 55, 54, 52, 51, 51, 53, 49]
      // This contains "+919967643351" encoded as bytes
      if (data.length >= 17) {
        // Look for the + sign (43 in ASCII) followed by digits
        for (int i = 0; i < data.length - 10; i++) {
          if (data[i] == 43) { // + sign
            final phoneBytes = data.sublist(i, i + 13); // +919967643351 = 13 characters
            final phoneString = String.fromCharCodes(phoneBytes);
            if (phoneString.startsWith('+') && phoneString.length >= 10) {
              debugPrint('  📱 Found phone number in manufacturer data: $phoneString');
              return phoneString;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('  Error extracting phone number: $e');
    }
    return '';
  }

  /// Extract location from manufacturer data
  String _extractLocationFromManufacturerData(Uint8List data) {
    try {
      // Convert bytes to string and look for location patterns
      final dataString = String.fromCharCodes(data);
      
      // Look for common location patterns
      final locationPatterns = [
        RegExp(r'in\s+([A-Za-z]+)', caseSensitive: false),
        RegExp(r'zone\s+([A-Za-z]+)', caseSensitive: false),
        RegExp(r'location\s+([A-Za-z]+)', caseSensitive: false),
      ];
      
      for (final pattern in locationPatterns) {
        final match = pattern.firstMatch(dataString);
        if (match != null) {
          final location = match.group(1)!;
          return location[0].toUpperCase() + location.substring(1).toLowerCase();
        }
      }
    } catch (e) {
      debugPrint('  Error extracting location: $e');
    }
    return '';
  }

  /// Parse advertisement data from BLE device
  Map<String, dynamic>? _parseAdvertisementData(DiscoveredDevice device) {
    try {
      // Look for victim devices by name pattern or service UUID
      final deviceName = device.name.toLowerCase();
      final serviceUuids = device.serviceUuids.map((uuid) => uuid.toString().toUpperCase());
      
      // Check if it's a victim device by name pattern or service UUID
      bool isVictimDevice = false;
      
      // Check by service UUID first (your victim app uses this UUID)
      if (serviceUuids.contains(serviceUuid.toUpperCase()) || 
          serviceUuids.contains('12345678-1234-1234-1234-123456789abc'.toUpperCase())) {
        isVictimDevice = true;
        debugPrint('  ✅ Victim device detected by service UUID');
      }
      // Check by name pattern (victim devices often have "victim" in the name)
      else if (deviceName.contains('victim') || 
               deviceName.contains('beacon') ||
               deviceName.startsWith('victim_')) {
        isVictimDevice = true;
        debugPrint('  ✅ Victim device detected by name pattern');
      }
      // Check if it's a mobile number (victim devices advertising with phone numbers)
      else if (_isMobileNumber(deviceName)) {
        isVictimDevice = true;
        debugPrint('  ✅ Victim device detected by mobile number');
      }
      // Check if manufacturer data contains phone number patterns
      else if (device.manufacturerData.isNotEmpty) {
        // Get the first manufacturer data entry
        final manufacturerData = device.manufacturerData;
        final phoneNumber = _extractPhoneNumberFromManufacturerData(manufacturerData);
        if (phoneNumber.isNotEmpty) {
          isVictimDevice = true;
          debugPrint('  ✅ Victim device detected by manufacturer data phone number');
        }
      }
      
      if (isVictimDevice) {
        // Try to extract victim info from manufacturer data first
        String victimId = device.name.isNotEmpty ? device.name : device.id;
        String zone = 'Disaster Zone';
        
        // Check manufacturer data for encoded phone number
        if (device.manufacturerData.isNotEmpty) {
          try {
            // Use manufacturer data directly as Uint8List
            final manufacturerData = device.manufacturerData;
            debugPrint('  Parsing manufacturer data: $manufacturerData');
            
            // Look for phone number pattern in manufacturer data
            final phoneNumber = _extractPhoneNumberFromManufacturerData(manufacturerData);
            if (phoneNumber.isNotEmpty) {
              victimId = phoneNumber;
              debugPrint('  📱 Extracted phone number: $phoneNumber');
            }
            
            // Look for location info in manufacturer data
            final location = _extractLocationFromManufacturerData(manufacturerData);
            if (location.isNotEmpty) {
              zone = location;
              debugPrint('  📍 Extracted location: $location');
            }
          } catch (e) {
            debugPrint('  Error parsing manufacturer data: $e');
          }
        }
        
        // Fallback: If device name contains location info (like "in Kalyan"), extract it
        if (device.name.toLowerCase().contains(' in ')) {
          final parts = device.name.toLowerCase().split(' in ');
          if (parts.length == 2) {
            victimId = parts[0].trim();
            zone = parts[1].trim().split(' ')[0]; // Take first word after "in"
            zone = zone[0].toUpperCase() + zone.substring(1); // Capitalize first letter
          }
        }
        
        return {
          'id': victimId,
          'zone': zone,
        };
      }
    } catch (e) {
      debugPrint('Error parsing advertisement data: $e');
    }
    
    return null;
  }


  /// Note: flutter_reactive_ble doesn't support advertising
  /// For victim devices, you would need to use a different approach
  /// such as a separate victim app or hardware beacons
  Future<void> startAdvertising({
    required String victimId,
    required String disasterZone,
  }) async {
    debugPrint('Advertising not supported in flutter_reactive_ble');
    debugPrint('For testing, use the victim app or hardware beacons');
  }

  /// Stop advertising
  Future<void> stopAdvertising() async {
    debugPrint('Advertising not supported in flutter_reactive_ble');
  }

  /// Start cleanup timer to remove old beacons
  void _startCleanupTimer() {
    _cleanupTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _cleanupOldBeacons();
    });
  }

  /// Remove beacons that haven't been seen recently
  void _cleanupOldBeacons() {
    final now = DateTime.now();
    final oldBeacons = <String>[];

    for (final entry in _discoveredVictims.entries) {
      if (now.difference(entry.value.lastSeen).inSeconds > 60) {
        oldBeacons.add(entry.key);
      }
    }

    for (final beaconId in oldBeacons) {
      _discoveredVictims.remove(beaconId);
    }

    if (oldBeacons.isNotEmpty) {
      _victimsController.add(_discoveredVictims.values.toList());
    }
  }

  /// Get current list of discovered victims
  List<VictimBeacon> get discoveredVictims => _discoveredVictims.values.toList();

  /// Check if currently scanning
  bool get isScanning => _isScanning;

  /// Dispose resources
  void dispose() {
    stopScanning();
    _cleanupTimer?.cancel();
    _victimsController.close();
  }
}