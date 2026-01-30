import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EnterNewPasswordScreen extends StatefulWidget {
  final String token;
  final String? email;
  const EnterNewPasswordScreen({super.key, required this.token, this.email});

  @override
  State<EnterNewPasswordScreen> createState() => _EnterNewPasswordScreenState();
}

class _EnterNewPasswordScreenState extends State<EnterNewPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isLoading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final authService = AuthService(Supabase.instance.client);
      await authService.completePasswordReset(token: widget.token, newPassword: _passwordController.text);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password updated successfully.')));
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to reset password: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = const Color(0xFF4A7CFF);
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F6FB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('Set New Password', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: screenWidth > 600 ? 540 : screenWidth),
              child: Card(
                elevation: 6,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          widget.email != null ? 'Setting password for ${widget.email}' : 'Set a new password',
                          style: TextStyle(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscure,
                          decoration: InputDecoration(
                            labelText: 'New password',
                            labelStyle: TextStyle(color: Colors.black87.withOpacity(0.85), fontWeight: FontWeight.w600),
                            filled: true,
                            fillColor: const Color(0xFFF6F8FF),
                            contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: primary, width: 1.5)),
                            suffixIcon: IconButton(
                              icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off, color: primary),
                              onPressed: () => setState(() => _obscure = !_obscure),
                              tooltip: _obscure ? 'Show password' : 'Hide password',
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Enter a new password';
                            if (v.length < 6) return 'Password must be at least 6 characters';
                            return null;
                          },
                          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w400),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _confirmController,
                          obscureText: _obscure,
                          decoration: InputDecoration(
                            labelText: 'Confirm password',
                            labelStyle: TextStyle(color: Colors.black87.withOpacity(0.85), fontWeight: FontWeight.w600),
                            filled: true,
                            fillColor: const Color(0xFFF6F8FF),
                            contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: primary, width: 1.5)),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Confirm your password';
                            if (v != _passwordController.text) return 'Passwords do not match';
                            return null;
                          },
                          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w400),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primary,
                              disabledBackgroundColor: primary.withOpacity(0.45),
                              shape: const StadiumBorder(),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              elevation: 2,
                            ),
                            child: _isLoading
                                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Text('Save Password', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
