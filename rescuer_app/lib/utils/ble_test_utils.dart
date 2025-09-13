// TODO Implement this library.
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/ble_provider.dart';

/// Utility class for testing BLE functionality
class BleTestUtils {
  static final Random _random = Random();

  /// Start advertising as a test victim
  static Future<void> startTestVictimAdvertising(WidgetRef ref) async {
    final bleService = ref.read(bleServiceProvider);
    
    // Generate random victim data
    final victimId = 'TestVictim_${_random.nextInt(9999)}';
    final disasterZone = 'Test Zone ${_random.nextInt(5) + 1}';
    
    await bleService.startAdvertising(
      victimId: victimId,
      disasterZone: disasterZone,
    );
    
    debugPrint('Started advertising as test victim: $victimId in $disasterZone');
  }

  /// Stop test victim advertising
  static Future<void> stopTestVictimAdvertising(WidgetRef ref) async {
    final bleService = ref.read(bleServiceProvider);
    await bleService.stopAdvertising();
    debugPrint('Stopped test victim advertising');
  }

  /// Show test controls dialog
  static void showTestControlsDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('BLE Test Controls'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Testing BLE Victim Detection:',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              '✅ Rescuer App: Scanning for victims\n'
              '📱 Victim App: Broadcasting beacon\n'
              '🔍 Check console logs for device discovery',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Look for "✅ DISCOVERED VICTIM" in console logs',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await startTestVictimAdvertising(ref);
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            },
            child: const Text('Start Test Victim'),
          ),
          TextButton(
            onPressed: () async {
              await stopTestVictimAdvertising(ref);
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            },
            child: const Text('Stop Test Victim'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  /// Get BLE status information
  static String getBleStatusInfo(WidgetRef ref) {
    final isScanning = ref.read(isScanningProvider);
    final victimCount = ref.read(victimCountProvider);
    final victims = ref.read(discoveredVictimsProvider);
    
    final buffer = StringBuffer();
    buffer.writeln('BLE Status:');
    buffer.writeln('Scanning: ${isScanning ? "Yes" : "No"}');
    buffer.writeln('Victims Found: $victimCount');
    
    if (victims.isNotEmpty) {
      buffer.writeln('\nDiscovered Victims:');
      for (final victim in victims) {
        buffer.writeln('- ${victim.id}: ${victim.distance.toStringAsFixed(1)}m away');
      }
    }
    
    return buffer.toString();
  }

  /// Simulate multiple test victims (for development/testing)
  static Future<void> simulateMultipleVictims(WidgetRef ref) async {
    // Note: In a real scenario, you would have multiple devices
    // This is just for demonstration purposes
    debugPrint('Simulating multiple victims...');
    debugPrint('In a real scenario, each victim would be on a separate device');
    
    // Start advertising as one test victim
    await startTestVictimAdvertising(ref);
  }
}