import 'package:flutter/material.dart';
// import '../../widgets/navbar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

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
  String? _nameErrorText;
  String? _emailErrorText;
  String? _passwordErrorText;
  String? _confirmPasswordErrorText;
  // String? _selectedCategoryId;

  @override
  void initState() {
    super.initState();

    // Add listeners to clear errors when user types
    _nameController.addListener(() {
      if (_nameError && _nameController.text.isNotEmpty) {
        setState(() {
          _nameError = false;
          _nameErrorText = null;
        });
      }
    });

    _emailController.addListener(() {
      if (_emailError && _emailController.text.isNotEmpty) {
        setState(() {
          _emailError = false;
          _emailErrorText = null;
        });
      }
    });

    _passwordController.addListener(() {
      if (_passwordError && _passwordController.text.isNotEmpty) {
        setState(() {
          _passwordError = false;
          _passwordErrorText = null;
        });
      }
    });

    _confirmPasswordController.addListener(() {
      if (_confirmPasswordError && _confirmPasswordController.text.isNotEmpty) {
        setState(() {
          _confirmPasswordError = false;
          _confirmPasswordErrorText = null;
        });
      }
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
    if (value.length < 2) {
      return 'Name must be at least 2 characters';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFF0F3),
      // appBar: const Navbar(),
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
                            borderSide: BorderSide(color: Colors.grey.shade300),
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
                          if (_nameError) {
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
                            borderSide: BorderSide(color: Colors.grey.shade300),
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
                          if (_emailError) {
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
                            borderSide: BorderSide(color: Colors.grey.shade300),
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
                              color: _passwordError ? Colors.red : Colors.green,
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
                          if (_passwordError) {
                            setState(() {
                              _passwordError = false;
                              _passwordErrorText = null;
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
                                border: Border.all(color: Colors.red.shade200),
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
                            borderSide: BorderSide(color: Colors.grey.shade300),
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
                          if (_confirmPasswordError) {
                            setState(() {
                              _confirmPasswordError = false;
                              _confirmPasswordErrorText = null;
                            });
                          }
                        },
                      ),

                      const SizedBox(height: 30),

                      // Phone Number Field
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: 'Phone Number',
                          hintText: 'Enter your phone number',
                          prefixIcon: const Icon(
                            Icons.phone,
                            color: Colors.green,
                          ),
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
                            borderSide: const BorderSide(
                              color: Colors.green,
                              width: 2,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Description Field
                      TextFormField(
                        controller: _descriptionController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: 'Description',
                          hintText: 'Describe your business',
                          prefixIcon: const Icon(
                            Icons.description,
                            color: Colors.green,
                          ),
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
                            borderSide: const BorderSide(
                              color: Colors.green,
                              width: 2,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Location Address Field
                      TextFormField(
                        controller: _locationAddressController,
                        decoration: InputDecoration(
                          labelText: 'Location Address',
                          hintText: 'Enter your address',
                          prefixIcon: const Icon(
                            Icons.location_on,
                            color: Colors.green,
                          ),
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
                            borderSide: const BorderSide(
                              color: Colors.green,
                              width: 2,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Category Dropdown Field
                      // DropdownButtonFormField<String>(
                      //   value: _selectedCategoryId,
                      //   items: const [
                      //     DropdownMenuItem(
                      //       value: '1',
                      //       child: Text('Category A'),
                      //     ),
                      //     DropdownMenuItem(
                      //       value: '2',
                      //       child: Text('Category B'),
                      //     ),
                      //   ],
                      //   onChanged: (value) {
                      //     setState(() {
                      //       _selectedCategoryId = value;
                      //     });
                      //   },
                      //   decoration: InputDecoration(
                      //     labelText: 'Category',
                      //     prefixIcon: const Icon(
                      //       Icons.category,
                      //       color: Colors.green,
                      //     ),
                      //     border: OutlineInputBorder(
                      //       borderRadius: BorderRadius.circular(12),
                      //       borderSide: BorderSide(color: Colors.grey.shade300),
                      //     ),
                      //     enabledBorder: OutlineInputBorder(
                      //       borderRadius: BorderRadius.circular(12),
                      //       borderSide: BorderSide(color: Colors.grey.shade300),
                      //     ),
                      //     focusedBorder: OutlineInputBorder(
                      //       borderRadius: BorderRadius.circular(12),
                      //       borderSide: const BorderSide(
                      //         color: Colors.green,
                      //         width: 2,
                      //       ),
                      //     ),
                      //   ),
                      // ),
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
                                      valueColor: AlwaysStoppedAnimation<Color>(
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
    );
  }

  Future<void> _handleSignup() async {
    // Clear previous errors
    setState(() {
      _nameError = false;
      _emailError = false;
      _passwordError = false;
      _confirmPasswordError = false;
      _nameErrorText = null;
      _emailErrorText = null;
      _passwordErrorText = null;
      _confirmPasswordErrorText = null;
    });

    // Check if fields are empty and validate
    bool hasErrors = false;

    if (_nameController.text.isEmpty) {
      setState(() {
        _nameError = true;
        _nameErrorText = 'Please enter your full name';
      });
      hasErrors = true;
    } else {
      String? nameError = _validateName(_nameController.text);
      if (nameError != null) {
        setState(() {
          _nameError = true;
          _nameErrorText = nameError;
        });
        hasErrors = true;
      }
    }

    if (_emailController.text.isEmpty) {
      setState(() {
        _emailError = true;
        _emailErrorText = 'Please enter your email';
      });
      hasErrors = true;
    } else {
      String? emailError = _validateEmail(_emailController.text);
      if (emailError != null) {
        setState(() {
          _emailError = true;
          _emailErrorText = emailError;
        });
        hasErrors = true;
      }
    }

    if (_passwordController.text.isEmpty) {
      setState(() {
        _passwordError = true;
        _passwordErrorText = 'Please enter your password';
      });
      hasErrors = true;
    } else {
      String? passwordError = _validatePassword(_passwordController.text);
      if (passwordError != null) {
        setState(() {
          _passwordError = true;
          _passwordErrorText = passwordError;
        });
        hasErrors = true;
      }
    }

    if (_confirmPasswordController.text.isEmpty) {
      setState(() {
        _confirmPasswordError = true;
        _confirmPasswordErrorText = 'Please confirm your password';
      });
      hasErrors = true;
    } else {
      String? confirmPasswordError = _validateConfirmPassword(
        _confirmPasswordController.text,
      );
      if (confirmPasswordError != null) {
        setState(() {
          _confirmPasswordError = true;
          _confirmPasswordErrorText = confirmPasswordError;
        });
        hasErrors = true;
      }
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
        // First, sign up the user with Supabase Auth
        final AuthResponse response = await Supabase.instance.client.auth
            .signUp(
              email: _emailController.text,
              password: _passwordController.text,
            );

        if (response.user == null) {
          throw Exception('Failed to create user account - no user returned');
        }

        // Get the user ID and ensure it's valid
        final String userId = response.user!.id;
        if (userId.isEmpty) {
          throw Exception('Invalid user ID received from authentication');
        }

        // Add a small delay to ensure the auth session is properly established
        await Future.delayed(const Duration(milliseconds: 500));

        // Verify the user is properly authenticated before creating account record
        final currentUser = Supabase.instance.client.auth.currentUser;
        if (currentUser == null || currentUser.id != userId) {
          throw Exception('Authentication session not properly established');
        }

        // Then create the account record in the accounts table
        final accountData = {
          'owner_id': userId,
          'name': _nameController.text.trim(),
          'phone': _phoneController.text.trim().isNotEmpty
              ? _phoneController.text.trim()
              : null,
          'description': _descriptionController.text.trim().isNotEmpty
              ? _descriptionController.text.trim()
              : null,
          'location_address': _locationAddressController.text.trim().isNotEmpty
              ? _locationAddressController.text.trim()
              : null,
          'location_lat': null,
          'location_lng': null,
          'logo_url': null,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        };

        await Supabase.instance.client.from('accounts').insert(accountData);

        if (!mounted) return;

        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Account Created Successfully! Please check your email for verification.',
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );

        Navigator.pop(context);
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
