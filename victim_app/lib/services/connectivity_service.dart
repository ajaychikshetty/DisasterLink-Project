import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';

class ConnectivityService {
  static final Connectivity _connectivity = Connectivity();
  static StreamController<bool> _connectionController = StreamController<bool>.broadcast();
  
  static Stream<bool> get connectionStream => _connectionController.stream;
  static bool _isConnected = true;
  
  static bool get isConnected => _isConnected;

  static Future<void> initialize() async {
    // Check initial connectivity
    await _checkConnectivity();
    
    // Listen to connectivity changes
    _connectivity.onConnectivityChanged.listen((List<ConnectivityResult> results) {
      _updateConnectionStatus(results);
    });
  }

  static Future<void> _checkConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _updateConnectionStatus(results);
    } catch (e) {
      print('Error checking connectivity: $e');
      _updateConnectionStatus([ConnectivityResult.none]);
    }
  }

  static void _updateConnectionStatus(List<ConnectivityResult> results) {
    final wasConnected = _isConnected;
    _isConnected = !results.contains(ConnectivityResult.none);
    
    // Only notify if status changed
    if (wasConnected != _isConnected) {
      _connectionController.add(_isConnected);
    }
  }

  static Future<bool> checkConnection() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _isConnected = !results.contains(ConnectivityResult.none);
      return _isConnected;
    } catch (e) {
      print('Error checking connection: $e');
      _isConnected = false;
      return false;
    }
  }

  static void dispose() {
    _connectionController.close();
  }
}