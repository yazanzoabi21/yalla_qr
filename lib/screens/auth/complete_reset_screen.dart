import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import '../../services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'enter_new_password_screen.dart';

class CompleteResetScreen extends StatefulWidget {
  final String? email;
  const CompleteResetScreen({super.key, this.email});

  @override
  State<CompleteResetScreen> createState() => _CompleteResetScreenState();
}

class _CompleteResetScreenState extends State<CompleteResetScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _tokenController = TextEditingController();
  // For numeric PIN input (6 digits)
  final List<TextEditingController> _pinControllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _pinFocus = List.generate(6, (_) => FocusNode());
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isLoading = false;
  bool _obscure = true;
  Timer? _timer;
  int _secondsRemaining = 0;
  static const int _initialCountdown = 60;
  bool get _canResend => _secondsRemaining == 0;

  @override
  void initState() {
    super.initState();
    if (widget.email != null) _emailController.text = widget.email!;
    // Start with a short cooldown before allowing resend to avoid spamming
    _startCountdown();
    // If there is a token prefilled, split into pin fields
    if (_tokenController.text.isNotEmpty) {
      final t = _tokenController.text.trim();
      for (var i = 0; i < _pinControllers.length && i < t.length; i++) {
        _pinControllers[i].text = t[i];
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _tokenController.dispose();
    for (final c in _pinControllers) c.dispose();
    for (final f in _pinFocus) f.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _stopCountdown();
    super.dispose();
  }

  void _startCountdown([int seconds = _initialCountdown]) {
    _stopCountdown();
    setState(() => _secondsRemaining = seconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        if (_secondsRemaining > 0) _secondsRemaining -= 1;
        if (_secondsRemaining == 0) _stopCountdown();
      });
    });
  }

  void _stopCountdown() {
    try {
      _timer?.cancel();
    } catch (_) {}
    _timer = null;
  }

  String _formatSeconds(int s) {
    final mm = (s ~/ 60).toString().padLeft(2, '0');
    final ss = (s % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  Future<void> _resendCode() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter email to resend code')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final authService = AuthService(Supabase.instance.client);
      await authService.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Verification code resent. Check your email.'),
        ),
      );
      _startCountdown();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to resend code: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submit() async {
    // Assemble PIN from fields
    final pin = _pinControllers.map((c) => c.text).join();
    if (pin.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter the full verification code')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final token = pin.trim();
      final email = _emailController.text.trim();
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => EnterNewPasswordScreen(
            token: token,
            email: email.isEmpty ? null : email,
          ),
        ),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
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
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.black87),
        onPressed: () => Navigator.of(context).maybePop(),
      ), title: const Text('Complete Reset', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),),
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
                          'Enter the code you received and choose a new password.',
                          style: TextStyle(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _emailController,
                          decoration: InputDecoration(
                            labelText: 'Email (optional)',
                            labelStyle: TextStyle(color: Colors.black87.withOpacity(0.85), fontWeight: FontWeight.w600),
                            filled: true,
                            fillColor: const Color(0xFFF6F8FF),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: primary, width: 1.5)),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 16),
                        Text('Code / Token', style: TextStyle(fontSize: 13, color: Colors.black87, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: List.generate(6, (i) {
                            return SizedBox(
                              width: 48,
                              child: TextFormField(
                                controller: _pinControllers[i],
                                focusNode: _pinFocus[i],
                                textAlign: TextAlign.center,
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(1)],
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: const Color(0xFFF6F8FF),
                                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                                ),
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: 4, color: Colors.black87),
                                onChanged: (v) {
                                  if (v.isNotEmpty) {
                                    if (i + 1 < _pinFocus.length) {
                                      _pinFocus[i + 1].requestFocus();
                                    } else {
                                      _pinFocus[i].unfocus();
                                    }
                                  } else {
                                    if (i - 1 >= 0) _pinFocus[i - 1].requestFocus();
                                  }
                                },
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 18),
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
                                : const Text('Verify Code', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            TextButton(
                              onPressed: _canResend && !_isLoading ? _resendCode : null,
                              child: Text('Resend Code', style: TextStyle(color: primary, fontWeight: FontWeight.w600)),
                            ),
                            const SizedBox(width: 8),
                            if (!_canResend) Text('Resend in ${_formatSeconds(_secondsRemaining)}', style: TextStyle(color: Colors.black54)),
                          ],
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

// Inline import to avoid circular import issues in patch sequence. This file
// expects `EnterNewPasswordScreen` to be available. Create the file next.
