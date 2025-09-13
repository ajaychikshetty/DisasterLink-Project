import 'dart:convert';
import 'package:http/http.dart' as http;

class CustomAuthService {
  static const String baseUrl = 'https://yourowncustommessagingservice.onrender.com';
  Future<Map<String, dynamic>> requestOTP(String phoneNumber) async {
  try {
    final response = await http.post(
      Uri.parse('$baseUrl/request_otp'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'number': phoneNumber,
        'msg': 'Requesting OTP',  // Added msg field
      }),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      return {
        'status': 'failed',
        'reason': 'Server error: ${response.statusCode}'
      };
    }
  } catch (e) {
    return {
      'status': 'failed',
      'reason': 'Network error: $e'
    };
  }
}

  // Verify OTP and get auth ID
  Future<Map<String, dynamic>> verifyOTP(String phoneNumber, String otp) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/verify_otp'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'number': phoneNumber,
          'otp': otp,
        }),
      );

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        if (result['status'] == 'success') {
          // Generate auth ID for the user (you can modify this logic as needed)
          final authId = _generateAuthId(phoneNumber);
          return {
            'status': 'verified',
            'uid': authId,
          };
        }
        return result;
      } else {
        return {
          'status': 'failed',
          'reason': 'Server error: ${response.statusCode}'
        };
      }
    } catch (e) {
      return {
        'status': 'failed',
        'reason': 'Network error: $e'
      };
    }
  }

  // Generate a unique auth ID (you can customize this)
  String _generateAuthId(String phoneNumber) {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    return 'auth_${cleanPhone}_$timestamp';
  }
}