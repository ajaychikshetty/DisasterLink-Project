import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart' show SharedPreferences;
import '../services/location_service.dart';
import '../mixins/unconscious_activity_mixin.dart';

// Import the auth ID provider from OTP screen
import 'otp_screen.dart'; // This should be your actual import path

class SignupScreen extends ConsumerStatefulWidget {
  final String? phoneNumber; // Add this to get phone number from navigation

  const SignupScreen({super.key, this.phoneNumber});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> with UnconsciousActivityMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _cityController = TextEditingController();
  
  DateTime? _selectedDate;
  String? _selectedGender;
  String? _selectedBloodGroup;
  bool _isLoading = false;
  bool _isGettingLocation = false;
  double? _latitude;
  double? _longitude;

  final List<String> _genders = ['Male', 'Female', 'Other'];
  final List<String> _bloodGroups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isGettingLocation = true;
    });

    try {
      final position = await LocationService.getLocationWithPermission();
      if (position != null) {
        setState(() {
          _latitude = position.latitude;
          _longitude = position.longitude;
        });
      } else {
        _showSnackBar('Location permission denied. Please enable location access.', Colors.orange);
      }
    } catch (e) {
      _showSnackBar('Error getting location: $e', Colors.red);
    } finally {
      setState(() {
        _isGettingLocation = false;
      });
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 20)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
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

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedDate == null) {
      _showSnackBar('Please select your date of birth', Colors.red);
      return;
    }

    if (_selectedGender == null) {
      _showSnackBar('Please select your gender', Colors.red);
      return;
    }

    if (_selectedBloodGroup == null) {
      _showSnackBar('Please select your blood group', Colors.red);
      return;
    }

    if (_latitude == null || _longitude == null) {
      _showSnackBar('Please enable location access', Colors.red);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Get the auth ID from the provider
      final authId = ref.read(authIdProvider);
      
      if (authId == null) {
        _showSnackBar('Authentication error. Please try again.', Colors.red);
        return;
      }

      // Get phone number - either from parameter or from navigation
      String phoneNumber = widget.phoneNumber ?? '';
      if (phoneNumber.isEmpty) {
        // Try to get from navigation extra or other source
        final extra = GoRouterState.of(context).extra as Map<String, dynamic>?;
        phoneNumber = extra?['phoneNumber'] ?? '';
      }

      if (phoneNumber.isEmpty) {
        _showSnackBar('Phone number not found. Please try again.', Colors.red);
        return;
      }

      // Clean phone number for document ID (only digits)
      final cleanPhoneNumber = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');

      // Create user data
      final userData = {
        'authId': authId,
        'phoneNumber': phoneNumber,
        'name': _nameController.text.trim(),
        'dateOfBirth': Timestamp.fromDate(_selectedDate!),
        'gender': _selectedGender!,
        'city': _cityController.text.trim(),
        'bloodGroup': _selectedBloodGroup!,
        'latitude': _latitude!,
        'longitude': _longitude!,
        'isActive': true,
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      };

      // Save to Firestore with phone number as document ID
      await FirebaseFirestore.instance
          .collection('victims')
          .doc(cleanPhoneNumber)
          .set(userData);

      // Store authentication credentials for future logins
      await _storeAuthCredentials(phoneNumber, authId);

      _showSnackBar('Registration completed successfully!', Colors.green);
      
      if (mounted) {
        context.go('/home');
      }
    } catch (e) {
      _showSnackBar('Error saving user details: $e', Colors.red);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _storeAuthCredentials(String phoneNumber, String authId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('phone_number', phoneNumber);
      await prefs.setString('auth_id', authId);
    } catch (e) {
      print('Error storing auth credentials: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Complete Your Profile',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Please provide your details to complete registration',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 30),

              // Name Field
              _buildTextField(
                controller: _nameController,
                label: 'Name',
                icon: Icons.person,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your name';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 20),

              // Date of Birth Field
              _buildDateField(),

              const SizedBox(height: 20),

              // Gender Field
              _buildDropdownField(
                label: 'Gender',
                icon: Icons.person_outline,
                value: _selectedGender,
                items: _genders,
                onChanged: (value) {
                  setState(() {
                    _selectedGender = value;
                  });
                },
              ),

              const SizedBox(height: 20),

              // City Field
              _buildTextField(
                controller: _cityController,
                label: 'City',
                icon: Icons.location_city,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your city';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 20),

              // Blood Group Field
              _buildDropdownField(
                label: 'Blood Group',
                icon: Icons.bloodtype,
                value: _selectedBloodGroup,
                items: _bloodGroups,
                onChanged: (value) {
                  setState(() {
                    _selectedBloodGroup = value;
                  });
                },
              ),

              const SizedBox(height: 20),

              // Location Field
              _buildLocationField(),

              const SizedBox(height: 40),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitForm,
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
                          'Complete Registration',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        prefixIcon: Icon(icon, color: Colors.white70),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.white),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.white),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.green),
        ),
      ),
    );
  }

  Widget _buildDateField() {
    return InkWell(
      onTap: _selectDate,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, color: Colors.white70),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _selectedDate == null
                    ? 'Select Date of Birth'
                    : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
                style: TextStyle(
                  color: _selectedDate == null ? Colors.white54 : Colors.white,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required IconData icon,
    required String? value,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        prefixIcon: Icon(icon, color: Colors.white70),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.white),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.white),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.green),
        ),
      ),
      dropdownColor: Colors.grey[900],
      items: items.map((String item) {
        return DropdownMenuItem<String>(
          value: item,
          child: Text(item, style: const TextStyle(color: Colors.white)),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildLocationField() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on, color: Colors.white70),
              const SizedBox(width: 12),
              const Text(
                'Location',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              if (_isGettingLocation)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              else
                IconButton(
                  onPressed: _getCurrentLocation,
                  icon: const Icon(Icons.refresh, color: Colors.green),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _latitude != null && _longitude != null
                ? 'Lat: ${_latitude!.toStringAsFixed(6)}, Lng: ${_longitude!.toStringAsFixed(6)}'
                : 'Location not available',
            style: TextStyle(
              color: _latitude != null ? Colors.green : Colors.red,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cityController.dispose();
    super.dispose();
  }
}