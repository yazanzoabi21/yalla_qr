import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'signup_screen.dart';
import 'request_password_reset_email_screen.dart';
import '../../services/auth_service.dart';
import '../../exceptions/category_not_registered_exception.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/navigation_helper.dart';
import '../../services/secure_storage_service.dart';
import 'dart:convert';

class LoginScreen extends StatefulWidget {
  final String? intendedDestination; // The screen to navigate to after login
  final bool
  registerAsClient; // If true, register as USER (client), otherwise as ORG

  const LoginScreen({
    super.key,
    this.intendedDestination,
    this.registerAsClient = false,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _emailError = false;
  bool _passwordError = false;
  String? _emailErrorText;
  String? _passwordErrorText;

  @override
  void initState() {
    super.initState();

    // Debug: Log what type of registration this is
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('🔐 [LoginScreen.initState] Screen initialized');
    debugPrint('   📋 widget.registerAsClient = ${widget.registerAsClient}');
    debugPrint(
      '   📁 widget.intendedDestination = ${widget.intendedDestination}',
    );
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    // Add listeners to clear errors when user types
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
  }

  void _clearFields() {
    _emailController.clear();
    _passwordController.clear();
    setState(() {
      _emailError = false;
      _passwordError = false;
      _emailErrorText = null;
      _passwordErrorText = null;
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
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
        appBar: AppBar(
          backgroundColor: const Color(0xFFEFF0F3),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.grey),
            onPressed: () {
              Navigator.pop(
                context,
              ); // Just go back instead of navigating to home
            },
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),

                // Welcome Header
                Center(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.blueAccent, Colors.blue.shade300],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(50),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blueAccent.withValues(alpha: 0.3),
                              blurRadius: 15,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.lock_person,
                          size: 40,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Welcome Back!',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.intendedDestination != null
                            ? 'Sign in to access ${widget.intendedDestination} dashboard'
                            : 'Sign in to access your dashboard',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // Login Form
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
                        // Email Field
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          cursorColor: Colors.blueAccent,
                          style: const TextStyle(color: Colors.black87),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white,
                            labelText: 'Email',
                            hintText: 'Enter your email',
                            labelStyle: const TextStyle(
                              color: Colors.blueAccent,
                              fontWeight: FontWeight.bold,
                            ),
                            hintStyle: TextStyle(
                              color: Colors.blueAccent.withOpacity(0.75),
                              fontWeight: FontWeight.bold,
                            ),
                            prefixIcon: Icon(
                              Icons.email,
                              color: _emailError
                                  ? Colors.red.shade700
                                  : Colors.blueAccent,
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
                                color: _emailError
                                    ? Colors.red
                                    : Colors.blueAccent,
                                width: 2,
                              ),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.red.shade700,
                                width: 2,
                              ),
                            ),
                            focusedErrorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.red.shade700,
                                width: 2,
                              ),
                            ),
                            errorText: _emailErrorText,
                            errorStyle: TextStyle(
                              color: Colors.red.shade700,
                              fontWeight: FontWeight.w700,
                            ),
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
                          cursorColor: Colors.blueAccent,
                          style: const TextStyle(color: Colors.black87),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white,
                            labelText: 'Password',
                            hintText: 'Enter your password',
                            labelStyle: const TextStyle(
                              color: Colors.blueAccent,
                              fontWeight: FontWeight.bold,
                            ),
                            hintStyle: TextStyle(
                              color: Colors.blueAccent.withOpacity(0.75),
                              fontWeight: FontWeight.bold,
                            ),
                            prefixIcon: Icon(
                              Icons.lock,
                              color: _passwordError
                                  ? Colors.red.shade700
                                  : Colors.blueAccent,
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
                                    : Colors.blueAccent,
                                width: 2,
                              ),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.red.shade700,
                                width: 2,
                              ),
                            ),
                            focusedErrorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.red.shade700,
                                width: 2,
                              ),
                            ),
                            errorText: _passwordErrorText,
                            errorStyle: TextStyle(
                              color: Colors.red.shade700,
                              fontWeight: FontWeight.w700,
                            ),
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

                        // Password Requirements Hint
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Password Requirements:',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blueAccent,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                '• At least 6 characters\n• Must contain a special character (!@#\$%^&*...)',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.blue,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Forgot Password
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {
                              // Navigate to Forgot Password flow
                              // Open email-based password reset screen
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const RequestPasswordResetEmailScreen(),
                                ),
                              );
                            },
                            child: const Text(
                              'Forgot Password?',
                              style: TextStyle(color: Colors.blueAccent),
                            ),
                          ),
                        ),

                        const SizedBox(height: 15),

                        // Login Button
                        ElevatedButton(
                          onPressed: _isLoading ? null : _handleLogin,
                          style: ButtonStyle(
                            backgroundColor: MaterialStateProperty.resolveWith<Color>(
                              (states) {
                                // Keep strong blue background even when disabled (loading)
                                if (states.contains(MaterialState.disabled)) {
                                  return Colors.blueAccent;
                                }
                                return Colors.blueAccent;
                              },
                            ),
                            foregroundColor: MaterialStateProperty.all<Color>(Colors.white),
                            padding: MaterialStateProperty.all<EdgeInsets>(
                              const EdgeInsets.symmetric(vertical: 16),
                            ),
                            shape: MaterialStateProperty.all<OutlinedBorder>(
                              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            elevation: MaterialStateProperty.all<double>(3),
                          ),
                          child: _isLoading
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const SizedBox(
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
                                      'Signing In...',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                )
                              : const Text(
                                  'Sign In',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),

                        const SizedBox(height: 20),

                        // Sign Up Link
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              "Don't have an account? ",
                              style: TextStyle(color: Colors.grey),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const SignupScreen(
                                      showAccountTypeToggle: true,
                                    ),
                                  ),
                                );
                              },
                              child: const Text(
                                'Sign Up',
                                style: TextStyle(
                                  color: Colors.blueAccent,
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

  Future<void> _handleLogin() async {
    // Clear previous errors
    setState(() {
      _emailError = false;
      _passwordError = false;
      _emailErrorText = null;
      _passwordErrorText = null;
    });

    // Check if fields are empty first
    bool hasErrors = false;

    if (_emailController.text.isEmpty) {
      setState(() {
        _emailError = true;
        _emailErrorText = 'Please enter your email';
      });
      hasErrors = true;
    } else {
      // Validate email format
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
      // Validate password requirements
      String? passwordError = _validatePassword(_passwordController.text);
      if (passwordError != null) {
        setState(() {
          _passwordError = true;
          _passwordErrorText = passwordError;
        });
        hasErrors = true;
      }
    }

    // If there are errors, don't proceed
    if (hasErrors) {
      return;
    }

    // If form validation passes, proceed with login
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        // Perform category-specific login with Supabase
        final authService = AuthService(Supabase.instance.client);
        await authService.signInUserForCategory(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          categoryName:
              widget.intendedDestination, // Don't default to 'general'
        );

        if (!mounted) return;

        // Save Supabase session JSON in secure storage IMMEDIATELY after login
        final session = Supabase.instance.client.auth.currentSession;
        if (session != null) {
          debugPrint('💾 Saving session for user: ${session.user.email}');
          final sessionJson = jsonEncode(session.toJson());
          debugPrint('📝 Session JSON length: ${sessionJson.length}');

          await SecureStorageService.saveSessionJson(sessionJson);

          // Determine login context based on user's actual role in database
          debugPrint('🔍 Checking user role for login context...');
          final accountsResponse = await Supabase.instance.client
              .from('accounts')
              .select('role')
              .eq('owner_id', session.user.id);

          String loginContext = 'ORG'; // Default to ORG

          if (accountsResponse.isNotEmpty) {
            // Check what roles this user has
            final hasSuperAdminRole = accountsResponse.any(
              (acc) => acc['role'] == 'SUPER ADMIN',
            );
            final hasOrgRole = accountsResponse.any(
              (acc) => acc['role'] == 'ORG',
            );
            final hasUserRole = accountsResponse.any(
              (acc) => acc['role'] == 'USER',
            );
            final hasDeliveryRole = accountsResponse.any(
              (acc) => acc['role'] == 'DELIVERY',
            );

            debugPrint('   👤 Has SUPER ADMIN role: $hasSuperAdminRole');
            debugPrint('   👤 Has ORG role: $hasOrgRole');
            debugPrint('   👤 Has USER role: $hasUserRole');
            debugPrint('   👤 Has DELIVERY role: $hasDeliveryRole');

            // Set login context based on role priority
            if (hasSuperAdminRole) {
              loginContext = 'SUPER_ADMIN';
            } else if (hasDeliveryRole && !hasOrgRole && !hasUserRole) {
              loginContext = 'DELIVERY';
            } else if (hasUserRole && !hasOrgRole) {
              loginContext = 'CLIENT';
            } else if (hasOrgRole) {
              loginContext = 'ORG';
            }
          }

          // Save login context to SharedPreferences
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('login_context', loginContext);
          debugPrint(
            '🔖 Login context saved: $loginContext (based on actual role)',
          );

          // Double-check the session was saved
          final savedSession = await SecureStorageService.getSessionJson();
          if (savedSession != null) {
            debugPrint('✅ Session confirmed saved and retrievable');
          } else {
            debugPrint('❌ WARNING: Session was not saved properly!');
          }
        } else {
          debugPrint('⚠️ No session found after login');
        }

        setState(() {
          _isLoading = false;
        });

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.intendedDestination != null
                  ? 'Login Successful! Redirecting to ${widget.intendedDestination} dashboard...'
                  : 'Login Successful! Redirecting...',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 1),
          ),
        );

        // Small delay to show the success message
        await Future.delayed(const Duration(milliseconds: 800));

        // Navigate based on actual login context (role from database)
        if (!mounted) return;

        // Get the saved login context
        final prefs = await SharedPreferences.getInstance();
        final loginContext = prefs.getString('login_context');

        if (loginContext == 'SUPER_ADMIN') {
          Navigator.pushReplacementNamed(context, '/super-admin');
        } else if (loginContext == 'CLIENT') {
          // Navigate to CLIENT page
          Navigator.pushReplacementNamed(context, '/client');
        } else if (loginContext == 'DELIVERY') {
          // Navigate to DELIVERY page
          Navigator.pushReplacementNamed(context, '/delivery');
        } else if (widget.intendedDestination != null) {
          // Navigate directly to the category screen after login
          NavigationHelper.navigateToCategory(
            context,
            widget.intendedDestination!,
          );
        } else {
          // Navigate to ORG home screen
          Navigator.pushReplacementNamed(context, '/home');
        }
      } on CategoryNotRegisteredException catch (e) {
        if (!mounted) return;

        setState(() {
          _isLoading = false;
        });

        // Show category registration error with option to register
        _showCategoryRegistrationDialog(e);
      } catch (e) {
        if (!mounted) return;

        setState(() {
          _isLoading = false;
        });

        // Show error message
        String errorMessage = 'Login failed';
        bool showResendVerification = false;

        if (e.toString().contains('Invalid email or password') ||
            e.toString().contains('invalid_credentials')) {
          errorMessage = 'Invalid email or password';
        } else if (e.toString().contains('too_many_requests')) {
          errorMessage = 'Too many login attempts. Please try again later.';
        } else if (e.toString().contains('email_not_confirmed')) {
          errorMessage = 'Please verify your email before logging in.';
          showResendVerification = true;
        } else {
          // Show the full error for debugging
          errorMessage = 'Login failed: ${e.toString()}';
        }

        if (showResendVerification) {
          _showEmailVerificationDialog();
        } else {
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

  void _showCategoryRegistrationDialog(
    CategoryNotRegisteredException exception,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.orange, size: 28),
              const SizedBox(width: 8),
              const Text('Account Not Registered'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(exception.message, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Would you like to register for "${exception.categoryName}"?',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'You can create a new account specifically for this category.',
                      style: TextStyle(fontSize: 14, color: Colors.blue),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                // Navigate to signup with pre-filled category
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SignupScreen(
                      intendedDestination: widget.intendedDestination,
                      registerAsClient: widget.registerAsClient,
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
              ),
              child: const Text('Register Now'),
            ),
          ],
        );
      },
    );
  }

  void _showEmailVerificationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.email, color: Colors.orange, size: 28),
              const SizedBox(width: 8),
              const Text('Email Verification Required'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Please verify your email address before logging in.',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Check your email inbox',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Click the verification link in the email we sent you. If you didn\'t receive it, you can request a new one.',
                      style: TextStyle(fontSize: 14, color: Colors.orange),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
              },
              child: const Text('Close'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  final authService = AuthService(Supabase.instance.client);
                  await authService.resendEmailVerification(
                    _emailController.text.trim(),
                  );

                  if (context.mounted) {
                    Navigator.of(context).pop(); // Close dialog
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Verification email sent! Please check your inbox.',
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to send verification email: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: const Text('Resend Verification'),
            ),
          ],
        );
      },
    );
  }
}
