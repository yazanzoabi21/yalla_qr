import 'package:flutter/material.dart';
// import '../../widgets/navbar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yalla_qr/services/auth_service.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart';
import '../../utils/navigation_helper.dart';

class SignupScreen extends StatefulWidget {
  final String? intendedDestination; // The screen to navigate to after signup

  const SignupScreen({super.key, this.intendedDestination});

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
              NavigationHelper.navigateToLogin(context);
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
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.green, Colors.green.shade300],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(50),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.withValues(alpha: 0.3),
                              blurRadius: 15,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.person_add,
                          size: 40,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Create Account',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Sign up to get started with your meals journey',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

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
                        // Name Field
                        TextFormField(
                          controller: _nameController,
                          keyboardType: TextInputType.name,
                          decoration: InputDecoration(
                            labelText: 'Full Name',
                            hintText: 'Enter your full name',
                            prefixIcon: Icon(
                              Icons.person,
                              color: _nameError ? Colors.red : Colors.green,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.grey.shade300,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: _nameError
                                    ? Colors.red
                                    : Colors.grey.shade300,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: _nameError ? Colors.red : Colors.green,
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
                          ),
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

                        // Email Field
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            labelText: 'Email',
                            hintText: 'Enter your email',
                            prefixIcon: Icon(
                              Icons.email,
                              color: _emailError ? Colors.red : Colors.green,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.grey.shade300,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: _emailError
                                    ? Colors.red
                                    : Colors.grey.shade300,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: _emailError ? Colors.red : Colors.green,
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
                          ),
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

                        // Password Field
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            hintText: 'Enter your password',
                            prefixIcon: Icon(
                              Icons.lock,
                              color: _passwordError ? Colors.red : Colors.green,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                                color: Colors.grey,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.grey.shade300,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: _passwordError
                                    ? Colors.red
                                    : Colors.grey.shade300,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: _passwordError
                                    ? Colors.red
                                    : Colors.green,
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
                          ),
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

                        // Confirm Password Field
                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: _obscureConfirmPassword,
                          decoration: InputDecoration(
                            labelText: 'Confirm Password',
                            hintText: 'Confirm your password',
                            prefixIcon: Icon(
                              Icons.lock_outline,
                              color: _confirmPasswordError
                                  ? Colors.red
                                  : Colors.green,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirmPassword
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                                color: Colors.grey,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscureConfirmPassword =
                                      !_obscureConfirmPassword;
                                });
                              },
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.grey.shade300,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: _confirmPasswordError
                                    ? Colors.red
                                    : Colors.grey.shade300,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: _confirmPasswordError
                                    ? Colors.red
                                    : Colors.green,
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
                          ),
                          validator: _validateConfirmPassword,
                          onChanged: (value) {
                            // Safe error clearing with null checks
                            if (mounted &&
                                _confirmPasswordError &&
                                value.isNotEmpty) {
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
                                child: const Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Password Requirements:',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.red,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      '• At least 6 characters\n• Must contain a special character (!@#\$%^&*...)',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.red,
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

                        // Phone Number Field
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: 'Phone Number',
                            hintText: 'Enter your phone number',
                            prefixIcon: Icon(
                              Icons.phone,
                              color: _phoneError ? Colors.red : Colors.green,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.grey.shade300,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: _phoneError
                                    ? Colors.red
                                    : Colors.grey.shade300,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: _phoneError ? Colors.red : Colors.green,
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
                          ),
                          validator: _validatePhone,
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

                        // Description Field
                        TextFormField(
                          controller: _descriptionController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            labelText: 'Description',
                            hintText: 'Describe your business',
                            prefixIcon: Icon(
                              Icons.description,
                              color: _descriptionError
                                  ? Colors.red
                                  : Colors.green,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.grey.shade300,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: _descriptionError
                                    ? Colors.red
                                    : Colors.grey.shade300,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: _descriptionError
                                    ? Colors.red
                                    : Colors.green,
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
                          ),
                          validator: _validateDescription,
                          onChanged: (value) {
                            // Safe error clearing with null checks
                            if (mounted &&
                                _descriptionError &&
                                value.isNotEmpty) {
                              setState(() {
                                _descriptionError = false;
                                _descriptionErrorText = null;
                              });
                            }
                          },
                        ),

                        const SizedBox(height: 20),

                        // Location Address Field
                        TextFormField(
                          controller: _locationAddressController,
                          decoration: InputDecoration(
                            labelText: 'Location Address',
                            hintText: 'Enter your address',
                            prefixIcon: Icon(
                              Icons.location_on,
                              color: _locationAddressError
                                  ? Colors.red
                                  : Colors.green,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.grey.shade300,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: _locationAddressError
                                    ? Colors.red
                                    : Colors.grey.shade300,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: _locationAddressError
                                    ? Colors.red
                                    : Colors.green,
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
                          ),
                          validator: _validateLocationAddress,
                          onChanged: (value) {
                            // Safe error clearing with null checks
                            if (mounted &&
                                _locationAddressError &&
                                value.isNotEmpty) {
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
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 3,
                          ),
                          child: _isLoading
                              ? const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Text('Creating Account...'),
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
                              "Already have an account? ",
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
                  Text(country['name'] ?? ''),
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
        prefixIcon: const Icon(Icons.public, color: Colors.green),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.green, width: 2),
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
    if (_phoneController.text.trim().isNotEmpty) {
      try {
        String phoneNumber = _phoneController.text.trim();
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
        await authService.signUpUser(
          email: _emailController.text,
          password: _passwordController.text,
          name: _nameController.text,
          phone: normalizedPhone,
          description: _descriptionController.text,
          locationAddress: _locationAddressController.text,
          categoryName: widget.intendedDestination, // Associate with category
          role: 'ORG', // All new accounts are organizations
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

        // Navigate based on intended destination
        if (!mounted) return;
        if (widget.intendedDestination != null) {
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
        if (error.toString().contains('already registered') ||
            error.toString().contains('User already registered')) {
          errorMessage =
              'This email is already registered. Please try signing in instead.';
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
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }
}
