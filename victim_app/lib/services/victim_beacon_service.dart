import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';

class VictimBeaconService {
  static final VictimBeaconService _instance = VictimBeaconService._internal();
  factory VictimBeaconService() => _instance;
  VictimBeaconService._internal();

  bool _isAdvertising = false;
  String? _currentVictimId;
  String? _currentDisasterZone;

  // Same service UUID as the rescuer app
  static const String serviceUuid = "12345678-1234-1234-1234-123456789ABC";

  /// Start advertising as a victim beacon
  Future<bool> startAdvertising({
    required String victimId,
    required String disasterZone,
    required String victimName,
  }) async {
    try {
      if (_isAdvertising) {
        await stopAdvertising();
      }

      debugPrint('Starting victim beacon advertising...');
      
      // Create manufacturer data with victim info
      final zoneId = disasterZone.hashCode & 0xFFFF;
      final victimIdBytes = victimId.codeUnits;
      final manufacturerData = Uint8List.fromList([
        (zoneId >> 8) & 0xFF,
        zoneId & 0xFF,
        ...victimIdBytes,
      ]);

      // Create advertisement data
      final advertisementData = AdvertiseData(
        serviceUuid: serviceUuid,
        localName: 'Victim_$victimId',
        manufacturerId: 0x1234, // Use a test manufacturer ID
        manufacturerData: manufacturerData,
      );

      // Start advertising
      await FlutterBlePeripheral().start(advertiseData: advertisementData);

      _isAdvertising = true;
      _currentVictimId = victimId;
      _currentDisasterZone = disasterZone;

      debugPrint('Started advertising as victim: $victimId in $disasterZone');
      return true;
    } catch (e) {
      debugPrint('Failed to start victim advertising: $e');
      return false;
    }
  }

  /// Stop advertising
  Future<void> stopAdvertising() async {
    try {
      if (_isAdvertising) {
        await FlutterBlePeripheral().stop();
        _isAdvertising = false;
        _currentVictimId = null;
        _currentDisasterZone = null;
        debugPrint('Stopped victim advertising');
      }
    } catch (e) {
      debugPrint('Failed to stop victim advertising: $e');
    }
  }

  /// Check if currently advertising
  bool get isAdvertising => _isAdvertising;

  /// Get current victim info
  String? get currentVictimId => _currentVictimId;
  String? get currentDisasterZone => _currentDisasterZone;

  /// Check if BLE peripheral is supported
  Future<bool> isSupported() async {
    return await FlutterBlePeripheral().isSupported;
  }

  /// Check if we have permission to advertise
  Future<bool> hasPermission() async {
    final state = await FlutterBlePeripheral().hasPermission();
    return state == BluetoothPeripheralState.granted;
  }

  /// Request permission to advertise
  Future<bool> requestPermission() async {
    final state = await FlutterBlePeripheral().hasPermission();
    if (state == BluetoothPeripheralState.granted) {
      return true;
    }
    
    // Request permission
    await FlutterBlePeripheral().requestPermission();
    final newState = await FlutterBlePeripheral().hasPermission();
    return newState == BluetoothPeripheralState.granted;
  }
}