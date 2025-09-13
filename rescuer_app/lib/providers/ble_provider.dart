// TODO Implement this library.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/ble_service.dart';

/// Provider for BLE service instance
final bleServiceProvider = Provider<BleService>((ref) {
  final service = BleService();
  
  // Dispose service when provider is disposed
  ref.onDispose(() {
    service.dispose();
  });
  
  return service;
});

/// Provider for discovered victims stream
final victimsStreamProvider = StreamProvider<List<VictimBeacon>>((ref) {
  final bleService = ref.watch(bleServiceProvider);
  return bleService.victimsStream;
});

/// Provider for scanning status
final isScanningProvider = StateProvider<bool>((ref) {
  final bleService = ref.watch(bleServiceProvider);
  return bleService.isScanning;
});

/// Provider for BLE initialization status
final bleInitializedProvider = FutureProvider<bool>((ref) async {
  final bleService = ref.watch(bleServiceProvider);
  return await bleService.initialize();
});

/// Provider for current discovered victims list
final discoveredVictimsProvider = Provider<List<VictimBeacon>>((ref) {
  final victimsAsync = ref.watch(victimsStreamProvider);
  return victimsAsync.when(
    data: (victims) => victims,
    loading: () => [],
    error: (_, __) => [],
  );
});

/// Provider for victim count
final victimCountProvider = Provider<int>((ref) {
  final victims = ref.watch(discoveredVictimsProvider);
  return victims.length;
});

/// Provider for nearest victim
final nearestVictimProvider = Provider<VictimBeacon?>((ref) {
  final victims = ref.watch(discoveredVictimsProvider);
  if (victims.isEmpty) return null;
  
  // Sort by distance (closest first)
  victims.sort((a, b) => a.distance.compareTo(b.distance));
  return victims.first;
});