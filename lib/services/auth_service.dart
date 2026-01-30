import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../exceptions/category_not_registered_exception.dart';
import 'qr_code_service.dart';

class AuthService {
  final SupabaseClient _client;
  late final QRCodeService _qrCodeService;

  AuthService(this._client) {
    _qrCodeService = QRCodeService(_client);
  }

  /// Get real GPS location from device - MANDATORY for signup
  /// Keeps requesting until permission is granted or throws error
  Future<Map<String, double>> _getMandatoryGpsLocation() async {
    try {
      debugPrint('📍 [AuthService] Starting mandatory GPS location request');
      
      // Check if location services are enabled
      final isLocationServiceEnabled =
          await Geolocator.isLocationServiceEnabled();
      
      if (!isLocationServiceEnabled) {
        debugPrint('❌ [AuthService] Location services are disabled');
        throw Exception(
          'location_services_disabled',
        );
      }

      // Request permission
      LocationPermission permission = await Geolocator.checkPermission();
      
      if (permission == LocationPermission.denied) {
        debugPrint('📍 [AuthService] Location permission not granted, requesting...');
        permission = await Geolocator.requestPermission();
      }
      
      if (permission == LocationPermission.deniedForever) {
        debugPrint('❌ [AuthService] Location permission permanently denied');
        throw Exception(
          'location_permission_permanently_denied',
        );
      }

      if (permission == LocationPermission.denied) {
        debugPrint('❌ [AuthService] Location permission denied by user');
        throw Exception(
          'location_permission_denied',
        );
      }

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 30),
      );
      
      debugPrint('✅ [AuthService] Got GPS location: ${position.latitude}, ${position.longitude}');
      return {'lat': position.latitude, 'lng': position.longitude};
    } catch (e) {
      debugPrint('❌ [AuthService] Error getting GPS location: $e');
      rethrow;
    }
  }

  Future<void> signUpUser({
    required String email,
    required String password,
    required String name,
    String? phone,
    String? description,
    String? locationAddress,
    String? categoryName, // Add category name parameter
    String? role, // Optional role (e.g. 'ADMIN') - should be used carefully
    String? logoUrl, // Profile image URL
  }) async {
    debugPrint('🔐 [AuthService.signUpUser] Starting registration');
    debugPrint('   📧 Email: $email');
    debugPrint('   👤 Name: $name');
    debugPrint('   📁 Category: $categoryName');
    debugPrint('   🎭 Role: ${role ?? "USER (default)"}');
    
    try {
      // ⚠️ IMPORTANT: Get GPS coordinates FIRST before auth.signUp()
      // This prevents creating orphaned auth users if location fails
      debugPrint('📍 [AuthService] Getting GPS location BEFORE auth signup...');
      final coords = await _getMandatoryGpsLocation();
      debugPrint('✅ [AuthService] GPS location confirmed: (${coords['lat']}, ${coords['lng']})');

      // Now that we have GPS, proceed with auth signup
      final AuthResponse response = await _client.auth.signUp(
        email: email,
        password: password,
      );

      if (response.user == null) {
        throw Exception('Failed to create user account - no user returned');
      }

    final String userId = response.user!.id;
    if (userId.isEmpty) {
      throw Exception('Invalid user ID received from authentication');
    }

    await Future.delayed(const Duration(milliseconds: 500));

    final currentUser = _client.auth.currentUser;
    if (currentUser == null || currentUser.id != userId) {
      throw Exception('Authentication session not properly established');
    }

    // Get category ID if category name is provided
    String? categoryId;
    if (categoryName != null) {
      final categoryResponse = await _client
          .from('categories')
          .select('id')
          .ilike('name', categoryName) // Use case-insensitive search
          .maybeSingle();

      if (categoryResponse != null) {
        categoryId = categoryResponse['id'] as String;
      }
    }

    final Map<String, dynamic> accountData = {
      'owner_id': userId,
      'email': email.trim(),
      'name': name.trim(),
      'phone': phone != null && phone.trim().isNotEmpty ? phone.trim() : null,
      'description': description != null && description.trim().isNotEmpty
        ? description.trim()
        : null,
      'location_address':
        locationAddress != null && locationAddress.trim().isNotEmpty
        ? locationAddress.trim()
        : null,
      'location_lat': coords['lat'],
      'location_lng': coords['lng'],
      'logo_url': logoUrl,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
      'role': role != null && role.trim().isNotEmpty ? role.trim().toUpperCase() : 'USER', // Default to USER if not specified
    };

    debugPrint('� [AuthService] Account data prepared:');
    debugPrint('   - owner_id: $userId');
    debugPrint('   - category_id: $categoryId');
    debugPrint('   - role: ${accountData['role']}');

    // Check if account already exists for this user
    final existingAccount = await _client
        .from('accounts')
        .select('id')
        .eq('owner_id', userId)
        .maybeSingle();

    String accountId;
    if (existingAccount != null) {
      // Update existing account
      await _client
          .from('accounts')
          .update(accountData)
          .eq('owner_id', userId);
      
      accountId = existingAccount['id'] as String;
    } else {
      // Insert new account
      final newAccount = await _client
          .from('accounts')
          .insert(accountData)
          .select('id')
          .single();
      accountId = newAccount['id'] as String;
      
      // Generate QR code for new account
      try {
        await _qrCodeService.createQRCodeForAccount(accountId);
      } catch (e) {
        // Log error but don't fail the signup
        print('Warning: Failed to create QR code for account: $e');
      }
    }

    // Link account to category in the join table
    if (categoryId != null) {
      // Specific category provided - link just that one
      try {
        await _client
            .from('account_categories')
            .upsert(
              {
                'account_id': accountId,
                'category_id': categoryId,
                'is_hidden': false,
              },
              onConflict: 'account_id,category_id',
            );
        debugPrint('✅ [AuthService] Linked account to category: $categoryName');
      } catch (e) {
        debugPrint('⚠️ [AuthService] Failed to link account to category: $e');
        // Do not fail signup on linkage error
      }
    } else if (role == 'ORG') {
      // ORG account with no specific category - link all parent categories
      try {
        debugPrint('🔗 [AuthService] Linking ORG account to all parent categories...');
        
        // Get all parent categories (categories with no parent_id)
        final parentCategories = await _client
            .from('categories')
            .select('id')
            .is_('parent_id', null);
        
        if (parentCategories.isNotEmpty) {
          // Create account_categories entries for all parent categories
          final categoriesToLink = (parentCategories as List).map((cat) => {
            'account_id': accountId,
            'category_id': cat['id'],
            'is_hidden': false,
          }).toList();
          
          await _client
              .from('account_categories')
              .upsert(
                categoriesToLink,
                onConflict: 'account_id,category_id',
              );
          
          debugPrint('✅ [AuthService] Linked ORG account to ${parentCategories.length} parent categories');
        } else {
          debugPrint('⚠️ [AuthService] No parent categories found to link');
        }
      } catch (e) {
        debugPrint('⚠️ [AuthService] Failed to link ORG account to categories: $e');
        // Do not fail signup on linkage error
      }
    }
    } catch (e) {
      String errorString = e.toString().toLowerCase();
      
      debugPrint('❌ [AuthService] Exception in signUpUser');
      debugPrint('   Raw error: $e');
      debugPrint('   Error lowercase: $errorString');
      debugPrint('   Error type: ${e.runtimeType}');
      
      if (errorString.contains('user already registered') || 
          errorString.contains('email already registered') ||
          errorString.contains('already registered')) {
        throw Exception('This email is already registered. Please try signing in instead.');
      } else if (errorString.contains('invalid email')) {
        throw Exception('Please enter a valid email address.');
      } else if (errorString.contains('password')) {
        throw Exception('Password does not meet requirements.');
      }
      
      // Re-throw the original exception if not matched
      debugPrint('❌ [AuthService.signUpUser] Signup error: $e');
      debugPrint('   Error string: $errorString');
      rethrow;
    }
  }

  /// Sign in user with email and password for a specific category with fresh token generation
  Future<User?> signInUserForCategory({
    required String email,
    required String password,
    String? categoryName, // Make this optional
  }) async {
    try {
      // Step 1: Always ensure clean state for fresh login
      await ensureCleanAuthState(email);
      
      // Step 2: Fresh authentication to generate new token
      final AuthResponse response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user == null) {
        throw Exception('Invalid email or password');
      }

      final user = response.user!;

      // Step 3: Verify the new session is properly established
      await Future.delayed(const Duration(milliseconds: 300));
      final currentSession = _client.auth.currentSession;
      if (currentSession == null || currentSession.user.id != user.id) {
        throw Exception('Authentication session could not be established');
      }

      // Check if email is confirmed (only if verification is enabled)
      if (user.emailConfirmedAt == null) {
        // Comment out for now since verification is disabled
        // await _client.auth.signOut();
        // throw Exception('email_not_confirmed');
      }

      // Step 4: Validate account access
      await validateAccountAccess(user, categoryName);

      return user;
    } on CategoryNotRegisteredException {
      rethrow; // Pass through category-specific exceptions
    } catch (e) {
      
      // Clean up on failure
      try {
        await _client.auth.signOut();
      } catch (cleanupError) {
        // Ignore cleanup errors
      }
      
      String errorString = e.toString().toLowerCase();
      
      if (errorString.contains('invalid login credentials') ||
          errorString.contains('invalid_credentials')) {
        throw Exception('Invalid email or password');
      } else if (errorString.contains('email_not_confirmed') ||
                 errorString.contains('email not confirmed')) {
        throw Exception('email_not_confirmed');
      } else if (errorString.contains('too_many_requests')) {
        throw Exception('too_many_requests');
      } else if (errorString.contains('signup_disabled')) {
        throw Exception('signup_disabled');
      }
      
      // For debugging - include the original error
      throw Exception('Login failed: $e');
    }
  }

  /// Ensure clean authentication state before new login
  Future<void> ensureCleanAuthState(String newUserEmail) async {
    final existingSession = _client.auth.currentSession;
    
    if (existingSession != null) {
      final existingUserEmail = existingSession.user.email;
      
      if (existingUserEmail != newUserEmail) {
        await forceCompleteLogout();
      } else {
        await forceCompleteLogout();
      }
      
      // Wait for complete cleanup
      await Future.delayed(const Duration(milliseconds: 500));
    }
  }

  /// Validate account access for category
  Future<void> validateAccountAccess(User user, String? categoryName) async {
    // If no category is specified, just check if user has any account
    // Don't fail if multiple accounts exist - this is now handled by login context
    if (categoryName == null || categoryName.isEmpty || categoryName == 'general') {
      final accountsResponse = await _client
          .from('accounts')
          .select('*')
          .eq('owner_id', user.id);

      if (accountsResponse.isEmpty) {
        // Do NOT sign out here; caller decides navigation.
        throw Exception('No account found for this user');
      }

      // User has at least one account - login context will determine which one to use
      return;
    }

    // Get the category ID by name
    final categoryResponse = await _client
        .from('categories')
        .select('id')
        .ilike('name', categoryName) // Use case-insensitive search
        .maybeSingle();

    if (categoryResponse == null) {
      throw Exception('Category "$categoryName" not found');
    }

    final categoryId = categoryResponse['id'] as String;

    // Get all accounts for this user
    final accountsResponse = await _client
        .from('accounts')
        .select('id')
        .eq('owner_id', user.id);

    if (accountsResponse.isEmpty) {
      throw Exception('No account found for this user');
    }

    final accountIds = (accountsResponse as List)
        .map((a) => a['id'] as String)
        .toList();

    // Check mapping in account_categories join table
    final mapping = await _client
        .from('account_categories')
        .select('id')
        .eq('category_id', categoryId)
        .in_('account_id', accountIds)
        .maybeSingle();

    if (mapping == null) {
      // User exists but not registered for this category. Do NOT sign out; let UI handle flow.
      throw CategoryNotRegisteredException(
        'Your account is not registered for "$categoryName". Please register for this category first.',
        categoryName,
        categoryId,
      );
    }
  }

  /// Sign out current user with complete session clearing
  Future<void> signOut() async {
    try {
      // Step 1: Clear the session from Supabase
      await _client.auth.signOut();
      
      // Step 2: Wait for proper cleanup
      await Future.delayed(const Duration(milliseconds: 800));
      
      // Step 3: Verify logout and force clear if needed
      final sessionAfterLogout = _client.auth.currentSession;
      if (sessionAfterLogout != null) {
        await forceCompleteLogout();
      }
    } catch (e) {
      // Force clear the session even if signOut fails
      await forceCompleteLogout();
    }
  }

  /// Force complete logout with aggressive session clearing
  Future<void> forceCompleteLogout() async {
    try {
      // Multiple aggressive signout attempts
      for (int i = 0; i < 5; i++) {
        try {
          await _client.auth.signOut();
          await Future.delayed(const Duration(milliseconds: 200));
          
          // Check if cleared
          final session = _client.auth.currentSession;
          if (session == null) {
            break;
          }
        } catch (e) {
          // Continue with next attempt
        }
      }
    } catch (e) {
      // Ignore errors during force logout
    }
  }

  /// Reset authentication state completely - useful for handling session conflicts
  Future<void> resetAuthState() async {
    try {
      await _client.auth.signOut();
      // Add a small delay to ensure state is properly cleared
      await Future.delayed(const Duration(milliseconds: 500));
    } catch (e) {
      // Continue anyway as we want to clear the state
    }
  }

  /// Force a complete authentication reset - use this as a last resort
  Future<void> forceAuthReset() async {
    try {
      // Multiple signout attempts
      for (int i = 0; i < 3; i++) {
        try {
          await _client.auth.signOut();
          await Future.delayed(const Duration(milliseconds: 300));
        } catch (e) {
          // Continue with next attempt
        }
      }
    } catch (e) {
      // Ignore errors during force reset
    }
  }

  /// Resend email verification
  Future<void> resendEmailVerification(String email) async {
    await _client.auth.resend(
      type: OtpType.signup,
      email: email,
    );
  }

  /// Send password reset email via Supabase (client-side flow)
  Future<void> sendPasswordResetEmail({required String email}) async {
    try {
      // Try calling the server-side Edge Function first (recommended).
      final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
      if (supabaseUrl.isNotEmpty) {
        // Typical functions host is <project>.functions.supabase.co
        final functionsHost = supabaseUrl.replaceFirst('.supabase.co', '.functions.supabase.co');
        final candidates = [
          '$functionsHost/send-reset',
          '$supabaseUrl/functions/v1/send-reset',
        ];

        for (final u in candidates) {
          try {
            final uri = Uri.parse(u);
            final resp = await http.post(
              uri,
              headers: {'Content-Type': 'application/json'},
              body: json.encode({'email': email}),
            ).timeout(const Duration(seconds: 8));

            if (resp.statusCode >= 200 && resp.statusCode < 300) {
              debugPrint('✅ [AuthService] send-reset function accepted the request (url=$u)');
              return;
            }
          } catch (err) {
            // Try next candidate
            debugPrint('⚠️ [AuthService] send-reset attempt failed for $u: $err');
          }
        }
      }

      // Fallback to client-side Supabase reset (less preferred)
      await _client.auth.resetPasswordForEmail(email);
    } catch (e) {
      debugPrint('❌ [AuthService.sendPasswordResetEmail] Error: $e');
      rethrow;
    }
  }

  /// Complete a password reset using a server-side token (Edge Function).
  /// Calls the `complete-reset` Edge Function with `token` and `new_password`.
  Future<void> completePasswordReset({required String token, required String newPassword}) async {
    try {
      final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
      String? lastError;
      if (supabaseUrl.isNotEmpty) {
        final functionsHost = supabaseUrl.replaceFirst('.supabase.co', '.functions.supabase.co');
        final candidates = [
          '$functionsHost/complete-reset',
          '$supabaseUrl/functions/v1/complete-reset',
        ];

        for (final u in candidates) {
          try {
            final uri = Uri.parse(u);
            final resp = await http
                .post(
                  uri,
                  headers: {'Content-Type': 'application/json'},
                  body: json.encode({'token': token, 'new_password': newPassword}),
                )
                .timeout(const Duration(seconds: 8));

            final body = resp.body.isNotEmpty ? resp.body : '<empty body>';
            debugPrint('ℹ️ [AuthService] complete-reset response: url=$u status=${resp.statusCode} body=$body');

            if (resp.statusCode >= 200 && resp.statusCode < 300) {
              debugPrint('✅ [AuthService] complete-reset accepted (url=$u)');
              return;
            }

            lastError = 'url=$u status=${resp.statusCode} body=$body';
          } catch (err) {
            debugPrint('⚠️ [AuthService] complete-reset attempt failed for $u: $err');
            lastError = err.toString();
          }
        }
      }

      final message = lastError != null ? 'Could not complete password reset via server function: $lastError' : 'Could not complete password reset via server function';
      throw Exception(message);
    } catch (e) {
      debugPrint('❌ [AuthService.completePasswordReset] Error: $e');
      rethrow;
    }
  }

  /// Verify a reset token/OTP without changing the password.
  /// Calls an edge function `verify-reset` that should validate the token
  /// and return success if the token is valid. This is purely a verification
  /// step to allow showing a separate UI for entering a new password.
  Future<void> verifyResetToken({required String token, String? email}) async {
    try {
      final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
      if (supabaseUrl.isNotEmpty) {
        final functionsHost = supabaseUrl.replaceFirst('.supabase.co', '.functions.supabase.co');
        final candidates = [
          '$functionsHost/verify-reset',
          '$supabaseUrl/functions/v1/verify-reset',
        ];

        final payload = <String, dynamic>{'token': token};
        if (email != null && email.isNotEmpty) payload['email'] = email;

        for (final u in candidates) {
          try {
            final uri = Uri.parse(u);
            final resp = await http
                .post(
                  uri,
                  headers: {'Content-Type': 'application/json'},
                  body: json.encode(payload),
                )
                .timeout(const Duration(seconds: 8));

            if (resp.statusCode >= 200 && resp.statusCode < 300) {
              debugPrint('✅ [AuthService] verify-reset accepted (url=$u)');
              return;
            }
          } catch (err) {
            debugPrint('⚠️ [AuthService] verify-reset attempt failed for $u: $err');
          }
        }
      }

      throw Exception('Could not verify reset token via server function');
    } catch (e) {
      debugPrint('❌ [AuthService.verifyResetToken] Error: $e');
      rethrow;
    }
  }

  /// Check if user is currently authenticated
  bool isAuthenticated() {
    return _client.auth.currentUser != null;
  }

  /// Get current user
  User? getCurrentUser() {
    return _client.auth.currentUser;
  }

  /// Get current user session
  Session? getCurrentSession() {
    return _client.auth.currentSession;
  }

  /// Get detailed session information for debugging
  Map<String, dynamic> getSessionInfo() {
    final session = _client.auth.currentSession;
    final user = _client.auth.currentUser;
    
    return {
      'hasSession': session != null,
      'hasUser': user != null,
      'userId': user?.id,
      'userEmail': user?.email,
      'hasAccessToken': session?.accessToken.isNotEmpty ?? false,
      'sessionValid': session != null && user != null,
    };
  }

  /// Clear session and verify it's completely cleared
  Future<bool> clearAndVerifySession() async {
    try {
      // Clear session
      await signOut();
      
      // Verify clearing
      final sessionInfo = getSessionInfo();
      
      final isCleared = !sessionInfo['hasSession'] && !sessionInfo['hasUser'];
      
      return isCleared;
    } catch (e) {
      return false;
    }
  }

  /// Reset a user's password by phone number using a server-side RPC/function.
  ///
  /// NOTE: This requires you to implement a secure Postgres function or server endpoint
  /// named `reset_password_by_phone` (or change the RPC name below) that accepts
  /// `phone` and `new_password` and performs the password update using a service role key.
  Future<void> resetPasswordByPhone({required String phone, required String newPassword}) async {
    try {
      final res = await _client.rpc('reset_password_by_phone', params: {
        'phone': phone,
        'new_password': newPassword,
      });

      // If the RPC returns an error structure, throw
      if (res == null) {
        throw Exception('Password reset RPC returned null');
      }
    } catch (e) {
      debugPrint('❌ [AuthService.resetPasswordByPhone] RPC error: $e');
      rethrow;
    }
  }
}
