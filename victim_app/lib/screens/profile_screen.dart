import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:victim_app/providers/auth_provider.dart' show authProvider;
import 'package:victim_app/widgets/bottom_navbar.dart' show Bottom_NavBar;
import '../l10n/app_localizations.dart';
import '../theme/theme_provider.dart';
import '../locale_provider.dart';
import '../mixins/unconscious_activity_mixin.dart';

// Profile Data Model
class ProfileData {
  final String name;
  final DateTime dateOfBirth;
  final String gender;
  final String contactNumber;
  final String city;
  final String status;
  final String bloodGroup;
  final String location;
  final String? profileImageUrl;

  ProfileData({
    required this.name,
    required this.dateOfBirth,
    required this.gender,
    required this.contactNumber,
    required this.city,
    required this.status,
    required this.bloodGroup,
    required this.location,
    this.profileImageUrl,
  });

  int get age {
    final now = DateTime.now();
    int age = now.year - dateOfBirth.year;
    if (now.month < dateOfBirth.month || 
        (now.month == dateOfBirth.month && now.day < dateOfBirth.day)) {
      age--;
    }
    return age;
  }

  ProfileData copyWith({
    String? name,
    DateTime? dateOfBirth,
    String? gender,
    String? contactNumber,
    String? city,
    String? status,
    String? bloodGroup,
    String? location,
    String? profileImageUrl,
  }) {
    return ProfileData(
      name: name ?? this.name,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      gender: gender ?? this.gender,
      contactNumber: contactNumber ?? this.contactNumber,
      city: city ?? this.city,
      status: status ?? this.status,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      location: location ?? this.location,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
    );
  }
}

// Profile State Notifier
class ProfileNotifier extends StateNotifier<ProfileData> {
  ProfileNotifier() : super(_defaultProfile);

  static final _defaultProfile = ProfileData(
    name: "John Doe",
    dateOfBirth: DateTime(1990, 5, 15),
    gender: "Male",
    contactNumber: "+1 234 567 8900",
    city: "New York",
    status: "Active",
    bloodGroup: "O+",
    location: "40.7128° N, 74.0060° W",
    profileImageUrl: null,
  );

  void updateProfile(ProfileData newProfile) {
    state = newProfile;
    // TODO: Save to Firebase here
    _saveToFirebase(newProfile);
  }

  Future<void> _saveToFirebase(ProfileData profile) async {
    // TODO: Implement Firebase save logic
    await Future.delayed(const Duration(milliseconds: 500)); // Simulate API call
    print('Profile saved to Firebase: ${profile.name}');
  }

  Future<void> loadFromFirebase() async {
    // TODO: Implement Firebase load logic
    await Future.delayed(const Duration(seconds: 1)); // Simulate API call
    // state = loadedProfile;
  }
}

// Provider
final profileProvider = StateNotifierProvider<ProfileNotifier, ProfileData>((ref) {
  return ProfileNotifier();
});

// Edit Mode Provider
final editModeProvider = StateProvider<bool>((ref) => false);

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});
  
  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with SingleTickerProviderStateMixin, UnconsciousActivityMixin {
  late AnimationController _animationController;
  final _formKey = GlobalKey<FormState>();
  
  // Controllers for editing
  late TextEditingController _nameController;
  late TextEditingController _contactController;
  late TextEditingController _cityController;
  late TextEditingController _locationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _animationController.repeat(reverse: true);
    
    // Initialize controllers
    final profile = ref.read(profileProvider);
    _nameController = TextEditingController(text: profile.name);
    _contactController = TextEditingController(text: profile.contactNumber);
    _cityController = TextEditingController(text: profile.city);
    _locationController = TextEditingController(text: profile.location);

    // Load profile from Firestore for the current logged-in user
    _loadProfileFromFirestore();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _nameController.dispose();
    _contactController.dispose();
    _cityController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileFromFirestore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedPhone = prefs.getString('phone_number');
      final storedAuthId = prefs.getString('auth_id');

      if (storedPhone == null || storedAuthId == null) {
        return;
      }

      final docId = storedPhone.replaceAll(RegExp(r'[^\d]'), '');
      final snapshot = await FirebaseFirestore.instance
          .collection('victims')
          .doc(docId)
          .get();

      if (!snapshot.exists) {
        return;
      }

      final data = snapshot.data() as Map<String, dynamic>;

      // Optionally validate authId matches
      final existingAuthId = data['authId'] as String?;
      if (existingAuthId != null && existingAuthId.isNotEmpty && existingAuthId != storedAuthId) {
        // Keep going but do not overwrite prefs here
      }

      final String name = (data['name'] as String?) ?? '';
      final Timestamp? dobTs = data['dateOfBirth'] as Timestamp?;
      final DateTime dateOfBirth = dobTs?.toDate() ?? DateTime(1990, 1, 1);
      final String gender = (data['gender'] as String?) ?? 'Other';
      final String contact = (data['phoneNumber'] as String?) ?? storedPhone;
      final String city = (data['city'] as String?) ?? '';
      final bool isActive = (data['isActive'] as bool?) ?? true;
      final String status = isActive ? 'Active' : 'Inactive';
      final String bloodGroup = (data['bloodGroup'] as String?) ?? '';
      final double? lat = (data['latitude'] as num?)?.toDouble();
      final double? lon = (data['longitude'] as num?)?.toDouble();
      final String location = (lat != null && lon != null) ? '${lat.toStringAsFixed(6)}, ${lon.toStringAsFixed(6)}' : '';

      final fetched = ProfileData(
        name: name,
        dateOfBirth: dateOfBirth,
        gender: gender,
        contactNumber: contact,
        city: city,
        status: status,
        bloodGroup: bloodGroup,
        location: location,
        profileImageUrl: null,
      );

      // Update provider and controllers
      ref.read(profileProvider.notifier).updateProfile(fetched);
      _nameController.text = fetched.name;
      _contactController.text = fetched.contactNumber;
      _cityController.text = fetched.city;
      _locationController.text = fetched.location;
      setState(() {});
    } catch (e) {
      // Non-fatal: log and proceed with defaults
      // ignore: avoid_print
      print('Failed to load profile from Firestore: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context)!;
    final screenSize = MediaQuery.of(context).size;
    final profile = ref.watch(profileProvider);
    final isEditing = ref.watch(editModeProvider);

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.grey[50],
      bottomNavigationBar: Bottom_NavBar(indexx: 4),
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // App Bar with Settings
            SliverAppBar(
              expandedHeight: 80,
              floating: true,
              pinned: false,
              backgroundColor: isDark ? Colors.black : Colors.white,
              elevation: 0,
              actions: [
                IconButton(
                  onPressed: () {
                    _showSettingsBottomSheet(context, isDark, ref);
                  },
                  icon: Icon(
                    Icons.settings,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              flexibleSpace: FlexibleSpaceBar(
                title: Text(
                  loc.profile,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : Colors.black,
                    letterSpacing: 2,
                  ),
                ),
                titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
              ),
            ),

            // Content
            SliverPadding(
              padding: EdgeInsets.symmetric(
                horizontal: screenSize.width > 600 ? 40 : 20,
                vertical: 20,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // Profile Image Section
                        _buildProfileImageSection(isDark, profile),
                  const SizedBox(height: 32),

                        // Edit/Save Button
                        _buildEditSaveButton(isDark, isEditing, profile),
                        const SizedBox(height: 24),

                        // Profile Fields
                        _buildResponsiveLayout(
                          screenSize,
                          isDark,
                          profile,
                          isEditing,
                        ),
                      ],
                    ),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
 
  Widget _buildProfileImageSection(bool isDark, ProfileData profile) {
    return Center(
      child: Stack(
        children: [
          AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (profile.status == "Active" ? Colors.green : Colors.red)
                          .withOpacity(0.3 + (_animationController.value * 0.4)),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 60,
                  backgroundColor: isDark ? Colors.grey[800] : Colors.grey[300],
                  backgroundImage: profile.profileImageUrl != null 
                    ? NetworkImage(profile.profileImageUrl!) 
                    : null,
                  child: profile.profileImageUrl == null
                    ? Icon(
                        Icons.person,
                        size: 60,
                        color: isDark ? Colors.white70 : Colors.grey[600],
                      )
                    : null,
                ),
              );
            },
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: profile.status == "Active" ? Colors.green : Colors.red,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? Colors.black : Colors.white,
                  width: 3,
                ),
              ),
              child: Icon(
                profile.status == "Active" ? Icons.check : Icons.close,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditSaveButton(bool isDark, bool isEditing, ProfileData profile) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {
          if (isEditing) {
            _saveProfile(profile);
          } else {
            ref.read(editModeProvider.notifier).state = true;
          }
        },
        icon: Icon(isEditing ? Icons.save : Icons.edit),
        label: Text(isEditing ? 'Save Changes' : 'Edit Profile'),
        style: ElevatedButton.styleFrom(
          backgroundColor: isEditing ? Colors.green : Colors.blue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildResponsiveLayout(Size screenSize, bool isDark, ProfileData profile, bool isEditing) {
    if (screenSize.width > 800) {
      // Desktop/Tablet layout - 2 columns
      return Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildNameField(isDark, profile, isEditing)),
              const SizedBox(width: 16),
              Expanded(child: _buildAgeField(isDark, profile, isEditing)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildGenderField(isDark, profile, isEditing)),
              const SizedBox(width: 16),
              Expanded(child: _buildContactField(isDark, profile, isEditing)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildCityField(isDark, profile, isEditing)),
              const SizedBox(width: 16),
              Expanded(child: _buildStatusField(isDark, profile, isEditing)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildBloodGroupField(isDark, profile, isEditing)),
              const SizedBox(width: 16),
              Expanded(child: _buildLocationField(isDark, profile, isEditing)),
            ],
          ),
        ],
      );
    } else {
      // Mobile layout - single column
      return Column(
        children: [
          _buildNameField(isDark, profile, isEditing),
          const SizedBox(height: 16),
          _buildAgeField(isDark, profile, isEditing),
          const SizedBox(height: 16),
          _buildGenderField(isDark, profile, isEditing),
          const SizedBox(height: 16),
          _buildContactField(isDark, profile, isEditing),
          const SizedBox(height: 16),
          _buildCityField(isDark, profile, isEditing),
          const SizedBox(height: 16),
          _buildStatusField(isDark, profile, isEditing),
          const SizedBox(height: 16),
          _buildBloodGroupField(isDark, profile, isEditing),
          const SizedBox(height: 16),
          _buildLocationField(isDark, profile, isEditing),
        ],
      );
    }
  }

  Widget _buildProfileField({
    required String label,
    required String value,
    required IconData icon,
    required bool isDark,
    required bool isEditing,
    Widget? editWidget,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.blue, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (isEditing && editWidget != null)
            editWidget
          else
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNameField(bool isDark, ProfileData profile, bool isEditing) {
    return _buildProfileField(
      label: 'Name',
      value: profile.name,
      icon: Icons.person,
      isDark: isDark,
      isEditing: isEditing,
      editWidget: TextFormField(
        controller: _nameController,
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black87,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: 'Enter name',
          hintStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Name is required';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildAgeField(bool isDark, ProfileData profile, bool isEditing) {
    return _buildProfileField(
      label: 'Age',
      value: '${profile.age} years old',
      icon: Icons.cake,
      isDark: isDark,
      isEditing: isEditing,
      editWidget: InkWell(
        onTap: () => _selectDate(context, profile),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            '${profile.age} years old (Tap to change DOB)',
            style: TextStyle(
              color: Colors.blue,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGenderField(bool isDark, ProfileData profile, bool isEditing) {
    return _buildProfileField(
      label: 'Gender',
      value: profile.gender,
      icon: Icons.person_outline,
      isDark: isDark,
      isEditing: isEditing,
      editWidget: DropdownButtonFormField<String>(
        value: profile.gender,
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black87,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        decoration: const InputDecoration(border: InputBorder.none),
        dropdownColor: isDark ? Colors.grey[800] : Colors.white,
        items: ['Male', 'Female', 'Other'].map((String value) {
          return DropdownMenuItem<String>(
            value: value,
            child: Text(value),
          );
        }).toList(),
        onChanged: (String? newValue) {
          if (newValue != null) {
            ref.read(profileProvider.notifier).updateProfile(
              profile.copyWith(gender: newValue),
            );
          }
        },
      ),
    );
  }

  Widget _buildContactField(bool isDark, ProfileData profile, bool isEditing) {
    return _buildProfileField(
      label: 'Contact Number',
      value: profile.contactNumber,
      icon: Icons.phone,
      isDark: isDark,
      isEditing: isEditing,
      editWidget: TextFormField(
        controller: _contactController,
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black87,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: 'Enter contact number',
          hintStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
        ),
        keyboardType: TextInputType.phone,
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Contact number is required';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildCityField(bool isDark, ProfileData profile, bool isEditing) {
    return _buildProfileField(
      label: 'City',
      value: profile.city,
      icon: Icons.location_city,
      isDark: isDark,
      isEditing: isEditing,
      editWidget: TextFormField(
        controller: _cityController,
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black87,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: 'Enter city',
          hintStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'City is required';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildStatusField(bool isDark, ProfileData profile, bool isEditing) {
    return _buildProfileField(
      label: 'Status',
      value: profile.status,
      icon: Icons.radio_button_checked,
      isDark: isDark,
      isEditing: isEditing,
      editWidget: DropdownButtonFormField<String>(
        value: profile.status,
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black87,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        decoration: const InputDecoration(border: InputBorder.none),
        dropdownColor: isDark ? Colors.grey[800] : Colors.white,
        items: ['Active', 'Inactive'].map((String value) {
          return DropdownMenuItem<String>(
            value: value,
            child: Text(value),
          );
        }).toList(),
        onChanged: (String? newValue) {
          if (newValue != null) {
            ref.read(profileProvider.notifier).updateProfile(
              profile.copyWith(status: newValue),
            );
          }
        },
      ),
    );
  }

  Widget _buildBloodGroupField(bool isDark, ProfileData profile, bool isEditing) {
    return _buildProfileField(
      label: 'Blood Group',
      value: profile.bloodGroup,
      icon: Icons.bloodtype,
      isDark: isDark,
      isEditing: isEditing,
      editWidget: DropdownButtonFormField<String>(
        value: profile.bloodGroup,
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black87,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        decoration: const InputDecoration(border: InputBorder.none),
        dropdownColor: isDark ? Colors.grey[800] : Colors.white,
        items: ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'].map((String value) {
          return DropdownMenuItem<String>(
            value: value,
            child: Text(value),
          );
        }).toList(),
        onChanged: (String? newValue) {
          if (newValue != null) {
            ref.read(profileProvider.notifier).updateProfile(
              profile.copyWith(bloodGroup: newValue),
            );
          }
        },
      ),
    );
  }

  Widget _buildLocationField(bool isDark, ProfileData profile, bool isEditing) {
    return _buildProfileField(
      label: 'Location',
      value: profile.location,
      icon: Icons.location_on,
      isDark: isDark,
      isEditing: isEditing,
      editWidget: TextFormField(
        controller: _locationController,
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black87,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: 'Enter location coordinates',
          hintStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Location is required';
          }
          return null;
        },
      ),
    );
  }

  Future<void> _selectDate(BuildContext context, ProfileData profile) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: profile.dateOfBirth,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != profile.dateOfBirth) {
      ref.read(profileProvider.notifier).updateProfile(
        profile.copyWith(dateOfBirth: picked),
      );
    }
  }

  void _saveProfile(ProfileData profile) {
    if (_formKey.currentState!.validate()) {
      final updatedProfile = profile.copyWith(
        name: _nameController.text.trim(),
        contactNumber: _contactController.text.trim(),
        city: _cityController.text.trim(),
        location: _locationController.text.trim(),
      );
      
      ref.read(profileProvider.notifier).updateProfile(updatedProfile);
      ref.read(editModeProvider.notifier).state = false;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
  void _showSettingsBottomSheet(BuildContext context, bool isDark, WidgetRef ref) {
  showModalBottomSheet(
    context: context,
    backgroundColor: isDark ? Colors.grey[900] : Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag indicator
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[600] : Colors.grey[400],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Title
          Text(
            'Settings',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 20),

          // Dark / Light mode toggle
          ListTile(
            leading: Icon(
              isDark ? Icons.dark_mode : Icons.light_mode,
              color: isDark ? Colors.white : Colors.black,
            ),
            title: Text(
              isDark ? "Dark Mode" : "Light Mode",
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
            ),
            onTap: () {
              ref.read(themeModeProvider.notifier).state =
                  isDark ? ThemeMode.light : ThemeMode.dark;
              Navigator.pop(context);
            },
          ),

          // Language selector
          ListTile(
            leading: Icon(Icons.language,
                color: isDark ? Colors.white : Colors.black),
            title: Text(
              "Language",
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
            ),
            trailing: PopupMenuButton<Locale?>(
              icon: const Icon(Icons.arrow_drop_down),
              onSelected: (locale) {
                ref.read(localeProvider.notifier).state = locale;
                Navigator.pop(context);
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: null,
                  child: Text("System Default"),
                ),
                PopupMenuItem(
                  value: Locale('en'),
                  child: Text("English"),
                ),
                PopupMenuItem(
                  value: Locale('hi'),
                  child: Text("हिंदी"),
                ),
                PopupMenuItem(
                  value: Locale('mr'),
                  child: Text("मराठी"),
                ),
              ],
            ),
          ),

          // Apply for Rescuer
          ListTile(
            leading: Icon(Icons.volunteer_activism,
                color: isDark ? Colors.white : Colors.black),
            title: Text(
              "Apply for Rescuer",
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
            ),
            onTap: () {
              Navigator.pop(context);
              // Navigator.push(context, MaterialPageRoute(builder: (_) => RescuerApplicationPage()));
            },
          ),

          // Logout
          ListTile(
            leading: Icon(Icons.logout,
                color: isDark ? Colors.white : Colors.black),
            title: Text(
              "Logout",
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
            ),
            onTap: () {
              Navigator.pop(context);
              _showLogoutDialog(); // call your logout dialog
            },
          ),

          const SizedBox(height: 20),
        ],
      ),
    ),
  );
}

  Future<void> _performLogout() async {
    try {
      // Clear SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('phone_number');
      await prefs.remove('auth_id');
      
      // Clear auth provider state
      ref.read(authProvider.notifier).signOut();
      
      // Navigate to phone input screen
      if (context.mounted) {
        context.go('/phone');
      }
    } catch (e) {
      print('Error during logout: $e');
      // Still navigate even if there's an error
      if (context.mounted) {
        context.go('/phone');
      }
    }
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.logout, color: Colors.red),
              SizedBox(width: 8),
              Text('Logout'),
            ],
          ),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _performLogout();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Logout', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }
}