import 'package:flutter/material.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart'
    show SharedPreferences;
import '../services/custom_auth_service.dart';
import '../mixins/unconscious_activity_mixin.dart';

// Provider to store auth ID globally
final authIdProvider = StateProvider<String?>((ref) => null);

class OTPScreen extends ConsumerStatefulWidget {
  final String phoneNumber;

  const OTPScreen({Key? key, required this.phoneNumber}) : super(key: key);

  @override
  ConsumerState<OTPScreen> createState() => _OTPScreenState();
}

class _OTPScreenState extends ConsumerState<OTPScreen>
    with UnconsciousActivityMixin {
  final TextEditingController _otpController = TextEditingController();
  final CustomAuthService _authService = CustomAuthService();

  bool _isLoading = false;
  bool _canResend = false;
  int _resendTimer = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
  }

  void _startResendTimer() {
    _canResend = false;
    _resendTimer = 60;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_resendTimer > 0) {
          _resendTimer--;
        } else {
          _canResend = true;
          timer.cancel();
        }
      });
    });
  }

  void _verifyOTP() async {
    if (_otpController.text.trim().length != 6) {
      _showSnackBar('Please enter complete OTP', Colors.red);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final phoneNumber = widget.phoneNumber;
    final otp = _otpController.text.trim();

    // Debug prints before sending
    print("Sending OTP verification request");
    print("Phone Number: '$phoneNumber'");
    print("OTP: '$otp'");

    try {
      final result = await _authService.verifyOTP(phoneNumber, otp);

      setState(() {
        _isLoading = false;
      });

      print("Response from server: $result"); // Debug print server response

      if (result['status'] == 'verified') {
        final generatedAuthId = result['uid'];
        print("OTP verified! Generated Auth ID: $generatedAuthId");

        // Look up existing victim document by phone and reuse authId when present
        final phoneDoc = widget.phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
        final docRef = FirebaseFirestore.instance.collection('victims').doc(phoneDoc);
        final userDoc = await docRef.get();

        String authIdToUse = generatedAuthId;

        if (userDoc.exists) {
          final data = userDoc.data();
          final existingAuthId = data != null ? (data['authId'] as String?) : null;
          if (existingAuthId != null && existingAuthId.isNotEmpty) {
            // Reuse existing authId
            authIdToUse = existingAuthId;
            print('Reusing existing authId for ${widget.phoneNumber}: $authIdToUse');
          } else {
            // Backfill missing authId on existing user
            await docRef.update({'authId': generatedAuthId, 'updatedAt': Timestamp.now()});
            print('Backfilled authId on existing user: $generatedAuthId');
          }
        }

        // Store authentication data for session persistence
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('phone_number', widget.phoneNumber);
        await prefs.setString('auth_id', authIdToUse);
        print("Stored phone: ${widget.phoneNumber}, authId: $authIdToUse");

        // Share in-memory authId
        ref.read(authIdProvider.notifier).state = authIdToUse;
        _showSnackBar('Phone verified successfully!', Colors.green);

        // Navigate
        if (userDoc.exists) {
          context.go('/home');
        } else {
          // New user -> continue to signup, keep generated authId in provider/prefs
          context.push('/signup', extra: {'phoneNumber': widget.phoneNumber});
        }
      } else {
        print(
          "Verification failed: ${result['reason']}",
        ); // Debug print error reason
        _showSnackBar(result['reason'] ?? 'Invalid OTP', Colors.red);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print("Error during OTP verification: $e"); // Debug print exception
      _showSnackBar('Error: $e', Colors.red);
    }
  }

  void _resendOTP() async {
    if (!_canResend) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _authService.requestOTP(widget.phoneNumber);

      setState(() {
        _isLoading = false;
      });

      if (result['status'] == 'otp_sent') {
        _showSnackBar('OTP sent successfully', Colors.green);
        _startResendTimer();
      } else {
        _showSnackBar(result['reason'] ?? 'Failed to resend OTP', Colors.red);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showSnackBar('Error: $e', Colors.red);
    }
  }


  void _showSnackBar(String message, Color backgroundColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: backgroundColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Verify OTP', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              const Icon(Icons.message, size: 80, color: Colors.green),
              const SizedBox(height: 30),
              const Text(
                'Enter Verification Code',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'We sent a code to ${widget.phoneNumber}',
                style: const TextStyle(color: Colors.white70, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              PinCodeTextField(
                appContext: context,
                length: 6,
                controller: _otpController,
                keyboardType: TextInputType.number,
                animationType: AnimationType.fade,
                animationDuration: const Duration(milliseconds: 300),
                pinTheme: PinTheme(
                  shape: PinCodeFieldShape.box,
                  borderRadius: BorderRadius.circular(10),
                  fieldHeight: 55,
                  fieldWidth: 45,
                  borderWidth: 2,
                  activeFillColor: Colors.black,
                  inactiveFillColor: Colors.black,
                  selectedFillColor: Colors.black,
                  activeColor: Colors.green,
                  inactiveColor: Colors.green.withOpacity(0.5),
                  selectedColor: Colors.green,
                ),
                textStyle: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                backgroundColor: Colors.transparent,
                enableActiveFill: true,
                onCompleted: (value) {
                  _verifyOTP();
                },
                onChanged: (value) {},
              ),
              const SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Didn't receive code? ",
                    style: TextStyle(color: Colors.white70),
                  ),
                  GestureDetector(
                    onTap: _canResend ? _resendOTP : null,
                    child: Text(
                      _canResend ? 'Resend' : 'Resend in ${_resendTimer}s',
                      style: TextStyle(
                        color: _canResend
                            ? Colors.green
                            : Colors.green.withOpacity(0.5),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _verifyOTP,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Verify OTP',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.green, width: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Change Phone Number',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    super.dispose();
  }
}
