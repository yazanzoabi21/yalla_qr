import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
// import '../../widgets/navbar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yalla_qr/services/auth_service.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart';
import '../../utils/navigation_helper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:io';

class SignupScreen extends StatefulWidget {
  final String? intendedDestination; // The screen to navigate to after signup
  final bool
  registerAsClient; // If true, register as USER (client), otherwise as ORG
  final bool
  showAccountTypeToggle; // Show toggle to switch between USER and ORG

  const SignupScreen({
    super.key,
    this.intendedDestination,
    this.registerAsClient = false,
    this.showAccountTypeToggle = false,
  });

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationAddressController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  bool _nameError = false;
  bool _emailError = false;
  bool _passwordError = false;
  bool _confirmPasswordError = false;
  bool _phoneError = false;
  bool _descriptionError = false;
  bool _locationAddressError = false;
  String? _nameErrorText;
  String? _emailErrorText;
  String? _passwordErrorText;
  String? _confirmPasswordErrorText;
  String? _phoneErrorText;
  String? _descriptionErrorText;
  String? _locationAddressErrorText;
  String _selectedRole = 'USER'; // Role: 'USER', 'ORG', or 'DELIVERY'
  File? _selectedImage; // Selected profile image
  final ImagePicker _imagePicker = ImagePicker();

  // List of countries with ISO codes and flags
  final List<Map<String, String>> _countries = [
    {'name': 'Lebanon', 'isoCode': 'LB', 'flag': '🇱🇧'},
    {'name': 'United States', 'isoCode': 'US', 'flag': '🇺🇸'},
    {'name': 'United Kingdom', 'isoCode': 'GB', 'flag': '🇬🇧'},
    {'name': 'France', 'isoCode': 'FR', 'flag': '🇫🇷'},
    {'name': 'Germany', 'isoCode': 'DE', 'flag': '🇩🇪'},
  ];

  // Selected country
  Map<String, String> _selectedCountry = {
    'name': 'Lebanon',
    'isoCode': 'LB',
    'flag': '🇱🇧',
  };

  @override
  void initState() {
    super.initState();

    // Debug: Log what type of registration this is
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('📝 [SignupScreen.initState] Screen initialized');
    debugPrint('   📋 widget.registerAsClient = ${widget.registerAsClient}');
    debugPrint(
      '   📁 widget.intendedDestination = ${widget.intendedDestination}',
    );
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  }

  void _clearFields() {
    _nameController.clear();
    _emailController.clear();
    _passwordController.clear();
    _confirmPasswordController.clear();
    _phoneController.clear();
    _descriptionController.clear();
    _locationAddressController.clear();
    setState(() {
      _nameError = false;
      _emailError = false;
      _passwordError = false;
      _confirmPasswordError = false;
      _phoneError = false;
      _descriptionError = false;
      _locationAddressError = false;
      _nameErrorText = null;
      _emailErrorText = null;
      _passwordErrorText = null;
      _confirmPasswordErrorText = null;
      _phoneErrorText = null;
      _descriptionErrorText = null;
      _locationAddressErrorText = null;
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
    _descriptionController.dispose();
    _locationAddressController.dispose();
    super.dispose();
  }

  String? _validateName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your full name';
    }
    if (value.trim().length < 3) {
      return 'Name must be at least 3 characters';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your email';
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your password';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(value)) {
      return 'Password must contain at least one special character (!@#\$%^&*...)';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }
    if (value != _passwordController.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your phone number';
    }

    // Basic validation - allow various formats
    String cleanPhone = value.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleanPhone.length < 8) {
      return 'Phone number is too short';
    }
    if (cleanPhone.length > 15) {
      return 'Phone number is too long';
    }

    return null; // More detailed validation happens in _handleSignup
  }

  String? _validateDescription(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a description';
    }
    if (value.trim().length < 10) {
      return 'Description must be at least 10 characters';
    }
    return null;
  }

  String? _validateLocationAddress(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your location address';
    }
    if (value.trim().length < 5) {
      return 'Address must be at least 5 characters';
    }
    return null;
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to pick image: $e')));
      }
    }
  }

  Future<String?> _uploadProfileImage() async {
    if (_selectedImage == null) return null;

    try {
      final supabase = Supabase.instance.client;

      // Validate file size (max 5MB)
      final fileSize = await _selectedImage!.length();
      if (fileSize > 5 * 1024 * 1024) {
        throw Exception('Image size must be less than 5MB');
      }

      // Generate unique filename with user email or timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final email = _emailController.text.replaceAll(
        RegExp(r'[^a-zA-Z0-9]'),
        '_',
      );
      final fileName = 'profile_${email}_$timestamp.jpg';

      debugPrint(
        '📤 Uploading profile image: $fileName (${(fileSize / 1024).toStringAsFixed(2)} KB)',
      );

      // Check if bucket exists
      try {
        final buckets = await supabase.storage.listBuckets();
        final bucketExists = buckets.any(
          (bucket) => bucket.name == 'profile-images',
        );

        if (!bucketExists) {
          debugPrint('📦 Creating profile-images bucket...');
          await supabase.storage.createBucket(
            'profile-images',
            const BucketOptions(public: true),
          );
        }
      } catch (e) {
        debugPrint('⚠️ Bucket check warning: $e');
        // Continue anyway - bucket likely exists
      }

      // Upload the image
      await supabase.storage
          .from('profile-images')
          .upload(
            fileName,
            _selectedImage!,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
          );

      // Get the public URL
      final imageUrl = supabase.storage
          .from('profile-images')
          .getPublicUrl(fileName);

      debugPrint('✅ Profile image uploaded successfully: $imageUrl');
      return imageUrl;
    } catch (e) {
      debugPrint('❌ Error uploading profile image: $e');

      String errorMessage = 'Failed to upload profile image';
      if (e.toString().contains('size')) {
        errorMessage = 'Image is too large (max 5MB)';
      } else if (e.toString().contains('already exists')) {
        errorMessage = 'Image already exists, please try again';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      }

      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        // Clear fields whenever pop is invoked, regardless of success
        // This ensures clean state when user returns to the screen
        _clearFields();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFEFF0F3),
        // appBar: const Navbar(),
        appBar: AppBar(
          backgroundColor: const Color(0xFFEFF0F3),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.grey),
            onPressed: () {
              Navigator.pop(
                context,
              ); // Just go back instead of creating new login
            },
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),

                // Welcome Header
                Center(
                  child: Column(
                    children: [
                      // Container(
                      //   padding: const EdgeInsets.all(20),
                      //   decoration: BoxDecoration(
                      //     gradient: LinearGradient(
                      //       colors: [Colors.green, Colors.green.shade300],
                      //       begin: Alignment.topLeft,
                      //       end: Alignment.bottomRight,
                      //     ),
                      //     borderRadius: BorderRadius.circular(50),
                      //     boxShadow: [
                      //       BoxShadow(
                      //         color: Colors.green.withValues(alpha: 0.3),
                      //         blurRadius: 15,
                      //         offset: const Offset(0, 8),
                      //       ),
                      //     ],
                      //   ),
                      //   child: const Icon(
                      //     Icons.person_add,
                      //     size: 40,
                      //     color: Colors.white,
                      //   ),
                      // ),
                      // const SizedBox(height: 24),
                      const Text(
                        'Create Account',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.black38,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Sign up to get started with your journey',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 24),

                      // Profile Image Picker
                      GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.green, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withValues(alpha: 0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: _selectedImage != null
                              ? ClipOval(
                                  child: Image.file(
                                    _selectedImage!,
                                    fit: BoxFit.cover,
                                    width: 120,
                                    height: 120,
                                  ),
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.add_a_photo,
                                      size: 40,
                                      color: Colors.green,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Add Photo',
                                      style: TextStyle(
                                        color: Colors.grey.shade700,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // Account Type Toggle (if enabled)
                if (widget.showAccountTypeToggle) ...[
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // User option
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedRole = 'USER';
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: _selectedRole == 'USER'
                                    ? Colors.green
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.person,
                                    color: _selectedRole == 'USER'
                                        ? Colors.white
                                        : Colors.grey,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'User',
                                    style: TextStyle(
                                      color: _selectedRole == 'USER'
                                          ? Colors.white
                                          : Colors.grey,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Organization option
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedRole = 'ORG';
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: _selectedRole == 'ORG'
                                    ? Colors.purple
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.business,
                                    color: _selectedRole == 'ORG'
                                        ? Colors.white
                                        : Colors.grey,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Organization',
                                    style: TextStyle(
                                      color: _selectedRole == 'ORG'
                                          ? Colors.white
                                          : Colors.grey,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Delivery option
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedRole = 'DELIVERY';
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: _selectedRole == 'DELIVERY'
                                    ? Colors.orange
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.delivery_dining,
                                    color: _selectedRole == 'DELIVERY'
                                        ? Colors.white
                                        : Colors.grey,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Delivery',
                                    style: TextStyle(
                                      color: _selectedRole == 'DELIVERY'
                                          ? Colors.white
                                          : Colors.grey,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Signup Form
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withValues(alpha: 0.1),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Name Field (force light input style)
                        TextFormField(
                          controller: _nameController,
                          keyboardType: TextInputType.name,
                          decoration: InputDecoration(
                            labelText: 'Full Name',
                            labelStyle: TextStyle(color: Colors.black38, fontWeight: FontWeight.w600),
                            hintText: 'Enter your full name',
                            hintStyle: TextStyle(color: Colors.black38),
                            prefixIcon: Icon(
                              Icons.person,
                              color: _nameError ? Colors.red : const Color(0xFF2E7D32),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: const Color(0xFFECEFF1),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: _nameError ? Colors.red : const Color(0xFFECEFF1),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: _nameError ? Colors.red : const Color(0xFF2E7D32),
                                width: 2,
                              ),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Colors.red,
                                width: 2,
                              ),
                            ),
                            focusedErrorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Colors.red,
                                width: 2,
                              ),
                            ),
                            errorText: _nameErrorText,
                            errorStyle: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w700),
                          ),
                          style: TextStyle(color: Colors.black87),
                          validator: _validateName,
                          onChanged: (value) {
                            // Safe error clearing with null checks
                            if (mounted && _nameError && value.isNotEmpty) {
                              setState(() {
                                _nameError = false;
                                _nameErrorText = null;
                              });
                            }
                          },
                        ),

                        const SizedBox(height: 20),

                        // Email Field (force light input style)
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            labelText: 'Email',
                            labelStyle: TextStyle(color: Colors.black38, fontWeight: FontWeight.w600),
                            hintText: 'Enter your email',
                            hintStyle: TextStyle(color: Colors.black38),
                            prefixIcon: Icon(
                              Icons.email,
                              color: _emailError ? Colors.red : const Color(0xFF2E7D32),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: const Color(0xFFECEFF1),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: _emailError ? Colors.red : const Color(0xFFECEFF1),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: _emailError ? Colors.red : const Color(0xFF2E7D32),
                                width: 2,
                              ),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Colors.red,
                                width: 2,
                              ),
                            ),
                            focusedErrorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Colors.red,
                                width: 2,
                              ),
                            ),
                            errorText: _emailErrorText,
                            errorStyle: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w700),
                          ),
                          style: TextStyle(color: Colors.black87),
                          validator: _validateEmail,
                          onChanged: (value) {
                            // Safe error clearing with null checks
                            if (mounted && _emailError && value.isNotEmpty) {
                              setState(() {
                                _emailError = false;
                                _emailErrorText = null;
                              });
                            }
                          },
                        ),

                        const SizedBox(height: 20),

                        // Password Field (force light input style)
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            labelStyle: TextStyle(color: Colors.black38, fontWeight: FontWeight.w600),
                            hintText: 'Enter your password',
                            hintStyle: TextStyle(color: Colors.black38),
                            prefixIcon: Icon(
                              Icons.lock,
                              color: _passwordError ? Colors.red : const Color(0xFF2E7D32),
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility : Icons.visibility_off,
                                color: const Color(0xFF757575),
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: const Color(0xFFECEFF1),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: _passwordError ? Colors.red : const Color(0xFFECEFF1),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: _passwordError ? Colors.red : const Color(0xFF2E7D32),
                                width: 2,
                              ),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Colors.red,
                                width: 2,
                              ),
                            ),
                            focusedErrorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Colors.red,
                                width: 2,
                              ),
                            ),
                            errorText: _passwordErrorText,
                            errorStyle: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w700),
                          ),
                          style: TextStyle(color: Colors.black87),
                          validator: _validatePassword,
                          onChanged: (value) {
                            // Safe error clearing with null checks
                            if (mounted && _passwordError && value.isNotEmpty) {
                              setState(() {
                                _passwordError = false;
                                _passwordErrorText = null;
                              });
                            }
                          },
                        ),

                        const SizedBox(height: 8),

                        // Confirm Password Field (force light input style)
                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: _obscureConfirmPassword,
                          decoration: InputDecoration(
                            labelText: 'Confirm Password',
                            labelStyle: TextStyle(color: Colors.black38, fontWeight: FontWeight.w600),
                            hintText: 'Confirm your password',
                            hintStyle: TextStyle(color: Colors.black38),
                            prefixIcon: Icon(
                              Icons.lock_outline,
                              color: _confirmPasswordError ? Colors.red : const Color(0xFF2E7D32),
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
                                color: const Color(0xFF757575),
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscureConfirmPassword = !_obscureConfirmPassword;
                                });
                              },
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: const Color(0xFFECEFF1),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: _confirmPasswordError ? Colors.red : const Color(0xFFECEFF1),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: _confirmPasswordError ? Colors.red : const Color(0xFF2E7D32),
                                width: 2,
                              ),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Colors.red,
                                width: 2,
                              ),
                            ),
                            focusedErrorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Colors.red,
                                width: 2,
                              ),
                            ),
                            errorText: _confirmPasswordErrorText,
                            errorStyle: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w700),
                          ),
                          style: TextStyle(color: Colors.black87),
                          validator: _validateConfirmPassword,
                          onChanged: (value) {
                            // Safe error clearing with null checks
                            if (mounted && _confirmPasswordError && value.isNotEmpty) {
                              setState(() {
                                _confirmPasswordError = false;
                                _confirmPasswordErrorText = null;
                              });
                            }
                          },
                        ),

                        // Password Requirements Hint - Show only when there's a password error
                        if (_passwordError && _passwordErrorText != null)
                          Column(
                            children: [
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.red.shade200,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Password Requirements:',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.red.shade700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '• At least 6 characters\n• Must contain a special character (!@#\$%^&*...)',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.red.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                        const SizedBox(height: 20),

                        // Country Dropdown Field
                        _buildCountryDropdown(),

                        const SizedBox(height: 20),

                        // Phone Number Field (force light input style)
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: 'Phone Number',
                            labelStyle: TextStyle(color: Colors.black38, fontWeight: FontWeight.w600),
                            hintText: 'Enter your phone number',
                            hintStyle: TextStyle(color: Colors.black38),
                            prefixIcon: Icon(
                              Icons.phone,
                              color: _phoneError ? Colors.red : const Color(0xFF2E7D32),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: const Color(0xFFECEFF1),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: _phoneError ? Colors.red : const Color(0xFFECEFF1),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: _phoneError ? Colors.red : const Color(0xFF2E7D32),
                                width: 2,
                              ),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Colors.red,
                                width: 2,
                              ),
                            ),
                            focusedErrorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Colors.red,
                                width: 2,
                              ),
                            ),
                            errorText: _phoneErrorText,
                            errorStyle: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w700),
                          ),
                          style: TextStyle(color: Colors.black87),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) return 'Please enter your phone number.';
                            return _validatePhone(value);
                          },
                          onChanged: (value) {
                            // Safe error clearing with null checks
                            if (mounted && _phoneError && value.isNotEmpty) {
                              setState(() {
                                _phoneError = false;
                                _phoneErrorText = null;
                              });
                            }
                          },
                        ),

                        const SizedBox(height: 20),

                        // Description Field (force light input style)
                        TextFormField(
                          controller: _descriptionController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            labelText: 'Description',
                            labelStyle: TextStyle(color: Colors.black38, fontWeight: FontWeight.w600),
                            hintText: 'Describe your business',
                            hintStyle: TextStyle(color: Colors.black38),
                            prefixIcon: Icon(
                              Icons.description,
                              color: _descriptionError ? Colors.red : const Color(0xFF2E7D32),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: const Color(0xFFECEFF1),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: _descriptionError ? Colors.red : const Color(0xFFECEFF1),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: _descriptionError ? Colors.red : const Color(0xFF2E7D32),
                                width: 2,
                              ),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Colors.red,
                                width: 2,
                              ),
                            ),
                            focusedErrorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Colors.red,
                                width: 2,
                              ),
                            ),
                            errorText: _descriptionErrorText,
                            errorStyle: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w700),
                          ),
                          style: TextStyle(color: Colors.black87),
                          validator: _validateDescription,
                          onChanged: (value) {
                            // Safe error clearing with null checks
                            if (mounted && _descriptionError && value.isNotEmpty) {
                              setState(() {
                                _descriptionError = false;
                                _descriptionErrorText = null;
                              });
                            }
                          },
                        ),

                        const SizedBox(height: 20),

                        // Location Address Field (force light input style)
                        TextFormField(
                          controller: _locationAddressController,
                          decoration: InputDecoration(
                            labelText: 'Location Address',
                            labelStyle: TextStyle(color: Colors.black38, fontWeight: FontWeight.w600),
                            hintText: 'Enter your address',
                            hintStyle: TextStyle(color: Colors.black38),
                            prefixIcon: Icon(
                              Icons.location_on,
                              color: _locationAddressError ? Colors.red : const Color(0xFF2E7D32),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: const Color(0xFFECEFF1),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: _locationAddressError ? Colors.red : const Color(0xFFECEFF1),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: _locationAddressError ? Colors.red : const Color(0xFF2E7D32),
                                width: 2,
                              ),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Colors.red,
                                width: 2,
                              ),
                            ),
                            focusedErrorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Colors.red,
                                width: 2,
                              ),
                            ),
                            errorText: _locationAddressErrorText,
                            errorStyle: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w700),
                          ),
                          style: TextStyle(color: Colors.black87),
                          validator: _validateLocationAddress,
                          onChanged: (value) {
                            // Safe error clearing with null checks
                            if (mounted && _locationAddressError && value.isNotEmpty) {
                              setState(() {
                                _locationAddressError = false;
                                _locationAddressErrorText = null;
                              });
                            }
                          },
                        ),

                        const SizedBox(height: 20),

                        // Signup Button
                        ElevatedButton(
                          onPressed: _isLoading ? null : _handleSignup,
                          style: ButtonStyle(
                            backgroundColor: MaterialStateProperty.resolveWith<Color?>(
                              (states) => Colors.green,
                            ),
                            foregroundColor: MaterialStateProperty.resolveWith<Color?>(
                              (states) => Colors.white,
                            ),
                            padding: MaterialStateProperty.all(const EdgeInsets.symmetric(vertical: 16)),
                            shape: MaterialStateProperty.all(
                              RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            elevation: MaterialStateProperty.all(3),
                          ),
                          child: _isLoading
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Creating Account...',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                )
                              : const Text(
                                  'Create Account',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),

                        const SizedBox(height: 20),

                        // Login Link
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              "Already have an account?",
                              style: TextStyle(color: Colors.grey),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context); // Go back to login
                              },
                              child: const Text(
                                'Sign In',
                                style: TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCountryDropdown() {
    return DropdownButtonFormField<Map<String, String>>(
      style: TextStyle(color: Colors.black87),
      dropdownColor: Colors.white,
      icon: const Icon(Icons.arrow_drop_down, color: Colors.black54),
      value: _countries.firstWhere(
        (country) => country['isoCode'] == _selectedCountry['isoCode'],
        orElse: () => _countries.first,
      ),
      items: _countries
          .map(
            (country) => DropdownMenuItem<Map<String, String>>(
              value: country,
              child: Row(
                children: [
                  Text(
                    country['flag'] ?? '',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(width: 8),
                  Text(country['name'] ?? '', style: const TextStyle(color: Colors.black87)),
                ],
              ),
            ),
          )
          .toList(),
      onChanged: (value) {
        setState(() {
          _selectedCountry = value!;
        });
      },
      decoration: InputDecoration(
        labelText: 'Country',
        labelStyle: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
        prefixIcon: const Icon(Icons.public, color: Color(0xFF2E7D32)),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: const Color(0xFFECEFF1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: const Color(0xFFECEFF1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2E7D32), width: 2),
        ),
      ),
    );
  }

  void _handleSignup() async {
    // Clear previous errors
    setState(() {
      _nameError = false;
      _emailError = false;
      _passwordError = false;
      _confirmPasswordError = false;
      _phoneError = false;
      _descriptionError = false;
      _locationAddressError = false;
      _nameErrorText = null;
      _emailErrorText = null;
      _passwordErrorText = null;
      _confirmPasswordErrorText = null;
      _phoneErrorText = null;
      _descriptionErrorText = null;
      _locationAddressErrorText = null;
    });

    // Check if fields are empty and validate
    bool hasErrors = false;

    // Validate name
    String? nameValidation = _validateName(_nameController.text);
    if (nameValidation != null) {
      setState(() {
        _nameError = true;
        _nameErrorText = nameValidation;
      });
      hasErrors = true;
    }

    // Validate email
    String? emailValidation = _validateEmail(_emailController.text);
    if (emailValidation != null) {
      setState(() {
        _emailError = true;
        _emailErrorText = emailValidation;
      });
      hasErrors = true;
    }

    // Validate password
    String? passwordValidation = _validatePassword(_passwordController.text);
    if (passwordValidation != null) {
      setState(() {
        _passwordError = true;
        _passwordErrorText = passwordValidation;
      });
      hasErrors = true;
    }

    // Validate confirm password
    String? confirmPasswordValidation = _validateConfirmPassword(
      _confirmPasswordController.text,
    );
    if (confirmPasswordValidation != null) {
      setState(() {
        _confirmPasswordError = true;
        _confirmPasswordErrorText = confirmPasswordValidation;
      });
      hasErrors = true;
    }

    // Validate phone using phone_numbers_parser
    String normalizedPhone = _phoneController.text.trim();

    // If phone is empty, mark error immediately so it shows alongside other field errors
    if (normalizedPhone.isEmpty) {
      setState(() {
        _phoneError = true;
        _phoneErrorText = 'Please enter your phone number';
      });
      hasErrors = true;
    } else {
      try {
        String phoneNumber = normalizedPhone;
        String isoCode = _selectedCountry['isoCode'] as String;

        // Parse the phone number
        PhoneNumber parsedPhone = PhoneNumber.parse(
          phoneNumber,
          callerCountry: IsoCode.fromJson(isoCode),
        );

        // Check if the phone number is valid
        bool isValid = parsedPhone.isValid();

        if (!isValid) {
          setState(() {
            _phoneError = true;
            _phoneErrorText =
                'Please enter a valid ${_selectedCountry['name']} phone number';
          });
          hasErrors = true;
        } else {
          // Get the normalized international format
          normalizedPhone = parsedPhone.international;
        }
      } catch (e) {
        setState(() {
          _phoneError = true;
          _phoneErrorText = 'Please enter a valid phone number format';
        });
        hasErrors = true;
      }
    }

    // Validate description
    String? descriptionValidation = _validateDescription(
      _descriptionController.text,
    );
    if (descriptionValidation != null) {
      setState(() {
        _descriptionError = true;
        _descriptionErrorText = descriptionValidation;
      });
      hasErrors = true;
    }

    // Validate location address
    String? locationValidation = _validateLocationAddress(
      _locationAddressController.text,
    );
    if (locationValidation != null) {
      setState(() {
        _locationAddressError = true;
        _locationAddressErrorText = locationValidation;
      });
      hasErrors = true;
    }

    // If there are errors, don't proceed
    if (hasErrors) {
      return;
    }

    // If form validation passes, proceed with signup
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        final authService = AuthService(Supabase.instance.client);

        // Upload profile image if selected
        String? logoUrl;
        if (_selectedImage != null) {
          logoUrl = await _uploadProfileImage();
          if (logoUrl == null) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Warning: Failed to upload profile image. Continuing with registration...',
                  ),
                ),
              );
            }
          }
        }

        // Debug: Log the registration type
        // Determine role based on toggle (if shown) or registerAsClient parameter
        String role;
        if (widget.showAccountTypeToggle) {
          role = _selectedRole;
        } else {
          role = widget.registerAsClient ? 'USER' : 'ORG';
        }

        debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        debugPrint('🎯 [SignupScreen] BEFORE calling signUpUser:');
        debugPrint(
          '   📋 widget.registerAsClient = ${widget.registerAsClient}',
        );
        debugPrint(
          '   📋 widget.showAccountTypeToggle = ${widget.showAccountTypeToggle}',
        );
        debugPrint('   📋 _selectedRole = $_selectedRole');
        debugPrint('   🎭 Calculated role = $role');
        debugPrint('   📧 Email = ${_emailController.text}');
        debugPrint('   👤 Name = ${_nameController.text}');
        debugPrint('   📁 Category = ${widget.intendedDestination}');
        debugPrint('   🖼️  Logo URL = $logoUrl');
        debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

        await authService.signUpUser(
          email: _emailController.text,
          password: _passwordController.text,
          name: _nameController.text,
          phone: normalizedPhone,
          description: _descriptionController.text,
          locationAddress: _locationAddressController.text,
          categoryName: widget.intendedDestination, // Associate with category
          role: role, // USER for clients, ORG for organizations
          logoUrl: logoUrl, // Profile image URL
        );

        if (!mounted) return;

        // Verify user is authenticated and has token after signup
        final currentUser = authService.getCurrentUser();
        final sessionInfo = authService.getSessionInfo();

        if (currentUser == null || !sessionInfo['sessionValid']) {
          throw Exception(
            'Authentication failed after signup - no valid session created',
          );
        }

        setState(() {
          _isLoading = false;
        });

        // Save login context to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        String loginContext;
        if (role == 'ORG') {
          loginContext = 'ORG';
        } else if (role == 'DELIVERY') {
          loginContext = 'DELIVERY';
        } else {
          loginContext = 'CLIENT';
        }
        await prefs.setString('login_context', loginContext);
        debugPrint('🔖 Signup: Login context saved: $loginContext');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.intendedDestination != null
                  ? 'Account Created Successfully for "${widget.intendedDestination}"! Redirecting to dashboard...'
                  : 'Account Created Successfully! Welcome!',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );

        // Small delay to show the success message
        await Future.delayed(const Duration(milliseconds: 1000));

        // Navigate based on account type and context
        if (!mounted) return;

        if (widget.showAccountTypeToggle) {
          // New flow: navigate based on toggle selection
          if (_selectedRole == 'ORG') {
            // Navigate to ORG home screen
            Navigator.pushReplacementNamed(context, '/home');
          } else if (_selectedRole == 'DELIVERY') {
            // Navigate to DELIVERY page
            Navigator.pushReplacementNamed(context, '/delivery');
          } else {
            // Navigate to CLIENT page
            Navigator.pushReplacementNamed(context, '/client');
          }
        } else if (widget.registerAsClient) {
          // Old flow: Client registration - return to previous screen (client page)
          Navigator.pop(context);
        } else if (widget.intendedDestination != null) {
          // Navigate directly to the category screen after signup with fresh token
          NavigationHelper.navigateToCategory(
            context,
            widget.intendedDestination!,
          );
        } else {
          Navigator.pop(context);
        }
      } catch (error) {
        setState(() {
          _isLoading = false;
        });

        String errorMessage = 'Error creating account: ${error.toString()}';
        bool showSignInAction = false;

        debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        debugPrint('❌ [SignupScreen] Signup error caught');
        debugPrint('   Error type: ${error.runtimeType}');
        debugPrint('   Error message: $error');
        debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

        // Handle location-specific errors
        if (error.toString().contains('location_services_disabled')) {
          errorMessage =
              'Location services are disabled. Please enable them in device settings and try again.';
          if (mounted) {
            _showLocationErrorDialog(
              'Location Services Disabled',
              errorMessage,
              onEnable: () {
                Geolocator.openLocationSettings();
              },
            );
          }
          return;
        } else if (error.toString().contains('location_permission_permanently_denied')) {
          errorMessage =
              'Location permission is permanently denied. Please enable it in app settings.';
          if (mounted) {
            _showLocationErrorDialog(
              'Location Permission Required',
              errorMessage,
              onEnable: () {
                Geolocator.openAppSettings();
              },
            );
          }
          return;
        } else if (error.toString().contains('location_permission_denied')) {
          errorMessage =
              'Location access is required to create an account. Please grant location permission.';
          if (mounted) {
            _showLocationErrorDialog(
              'Location Permission Required',
              errorMessage,
              onRetry: _handleSignup,
            );
          }
          return;
        } else if (error.toString().contains('already registered') ||
            error.toString().contains('User already registered')) {
          errorMessage =
              'This email is already registered. Please try signing in instead.';
          showSignInAction = true;
        } else if (error.toString().contains('Invalid email') ||
            error.toString().contains('invalid_email')) {
          errorMessage = 'Please enter a valid email address.';
        } else if (error.toString().contains('Password') ||
            error.toString().contains('weak_password')) {
          errorMessage = 'Password does not meet requirements.';
        } else if (error.toString().contains('email_address_invalid')) {
          errorMessage = 'Please enter a valid email address.';
        } else if (error.toString().contains('signup_disabled')) {
          errorMessage = 'Account creation is currently disabled.';
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
              duration: Duration(seconds: showSignInAction ? 6 : 3),
              action: showSignInAction
                  ? SnackBarAction(
                      label: 'Sign In',
                      textColor: Colors.white,
                      onPressed: () {
                        Navigator.pop(context);
                      },
                    )
                  : null,
            ),
          );
        }
      }
    }
  }

  /// Show location error dialog with action buttons
  void _showLocationErrorDialog(
    String title,
    String message, {
    VoidCallback? onEnable,
    VoidCallback? onRetry,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.location_on, color: Colors.red.shade600),
            const SizedBox(width: 12),
            Expanded(child: Text(title)),
          ],
        ),
        content: Text(message),
        actions: [
          if (onRetry != null)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                onRetry();
              },
              child: const Text('Retry'),
            ),
          if (onEnable != null)
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                onEnable();
              },
              icon: const Icon(Icons.settings),
              label: const Text('Open Settings'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
              ),
            ),
        ],
      ),
    );
  }
}
