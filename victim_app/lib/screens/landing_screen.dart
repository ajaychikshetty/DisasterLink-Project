import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/auth_provider.dart';
import '../mixins/unconscious_activity_mixin.dart';
import '../services/unconscious_detection_service.dart';
import 'emergency_sos_screen.dart';

class LandingScreen extends ConsumerStatefulWidget {
  const LandingScreen({super.key});

  @override
  ConsumerState<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends ConsumerState<LandingScreen>
    with UnconsciousActivityMixin {
  bool _hasNavigated = false;
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    try {
      print('Checking auth status...');
      final prefs = await SharedPreferences.getInstance();
      // If an emergency is active, force SOS screen and bail out
      final bool emergencyActive = prefs.getBool('emergency_active') ?? false;
      if (emergencyActive && mounted && !_hasNavigated) {
        _hasNavigated = true;
        setState(() { _isChecking = false; });
        // Build a minimal synthetic alert
        final alert = UnconsciousAlert(
          timestamp: DateTime.now(),
          lastActivityTime: DateTime.now(),
          timeSinceLastActivity: const Duration(minutes: 0),
          lastMovementTime: DateTime.now(),
          isInDisasterArea: true,
          confidence: 100.0,
        );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => EmergencySosScreen(alert: alert),
          );
        });
        return;
      }
      final storedPhoneNumber = prefs.getString('phone_number');
      final storedAuthId = prefs.getString('auth_id');

      print('Stored phone: $storedPhoneNumber');
      print('Stored auth ID: $storedAuthId');

      if (storedPhoneNumber != null && storedAuthId != null) {
        try {
          // Clean phone number for document ID (remove all non-digits)
          final docId = storedPhoneNumber.replaceAll(RegExp(r'[^\d]'), '');

          final user = await ref
              .read(authProvider.notifier)
              .getUserByPhone(docId);

          print('User fetched from Firestore: $user');
          print('Stored authId: $storedAuthId');
          print('User authId: ${user?.authId}');

          if (user != null && user.authId == storedAuthId) {
            if (mounted && !_hasNavigated) {
              print('Valid user found, navigating to /home');
              _hasNavigated = true;
              context.go('/home');
              return;
            }
          } else {
            print('Invalid user or authId mismatch, clearing stored auth');
            await _clearStoredAuth();
          }
        } catch (e) {
          print('Error loading user: $e');
          await _clearStoredAuth();
        }
      } else {
        print('No stored credentials found');
      }

      if (mounted && !_hasNavigated) {
        print('Navigating to /phone');
        _hasNavigated = true;
        setState(() {
          _isChecking = false;
        });
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          context.go('/phone');
        }
      }
    } catch (e) {
      print('Error checking auth status: $e');
      if (mounted && !_hasNavigated) {
        print('Fallback navigation to /phone');
        _hasNavigated = true;
        setState(() {
          _isChecking = false;
        });
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          context.go('/phone');
        }
      }
    }
  }

  Future<void> _clearStoredAuth() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('phone_number');
    await prefs.remove('auth_id');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App Logo or Icon
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(60),
                border: Border.all(color: Colors.green, width: 2),
              ),
              child: const Icon(Icons.security, size: 60, color: Colors.green),
            ),
            const SizedBox(height: 30),

            // App Name
            const Text(
              'Victim Safety App',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),

            // Tagline
            const Text(
              'Your safety is our priority',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 50),

            // Loading indicator
            if (_isChecking) ...[
              const CircularProgressIndicator(
                color: Colors.green,
                strokeWidth: 3,
              ),
              const SizedBox(height: 20),
              const Text(
                'Checking authentication...',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            ] else ...[
              // Show briefly before navigation
              const CircularProgressIndicator(
                color: Colors.green,
                strokeWidth: 3,
              ),
              const SizedBox(height: 20),
              const Text(
                'Starting app...',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
