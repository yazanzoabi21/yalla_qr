import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'complete_reset_screen.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String? email;
  const ResetPasswordScreen({Key? key, this.email}) : super(key: key);

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _sent = false;
  String? _errorText;

  static final _emailRegex = RegExp(r"^[^@\s]+@[^@\s]+\.[^@\s]+$");

  bool get _isEmailValid => _emailRegex.hasMatch(_emailController.text.trim());

  Future<void> _submit() async {
    setState(() => _errorText = null);

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authService = AuthService(Supabase.instance.client);
      await authService.sendPasswordResetEmail(email: _emailController.text.trim());

      if (!mounted) return;
      // show success briefly and navigate to the code entry screen
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verification code sent. Check your email.')),
      );
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => CompleteResetScreen(email: _emailController.text.trim()),
      ));
      setState(() => _sent = true);
    } catch (e) {
      setState(() {
        _errorText = 'Failed to send verification code. Please try again.';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    if (widget.email != null && widget.email!.isNotEmpty) {
      _emailController.text = widget.email!.trim();
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
          tooltip: 'Back',
        ),
        title: const Text(
          'Reset Password',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: false,
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
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      const Text(
                        'Enter your email and we\'ll send you a verification code.',
                        style: TextStyle(fontSize: 14, color: Colors.black87, height: 1.4),
                      ),
                      const SizedBox(height: 20),
                      Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              autofillHints: const [AutofillHints.email],
                              textInputAction: TextInputAction.done,
                              onChanged: (_) {
                                if (_errorText != null) {
                                  setState(() => _errorText = null);
                                } else {
                                  setState(() {});
                                }
                              },
                              decoration: InputDecoration(
                                prefixIcon: Icon(Icons.email_outlined, color: _isEmailValid ? primary : Colors.grey.shade500),
                                labelText: 'Email',
                                labelStyle: TextStyle(color: primary, fontWeight: FontWeight.w600),
                                hintText: _emailController.text.isEmpty ? 'you@company.com' : null,
                                hintStyle: TextStyle(color: primary.withOpacity(0.6), fontWeight: FontWeight.w500),
                                filled: true,
                                fillColor: const Color(0xFFF6F8FF),
                                contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: primary.withOpacity(0.15), width: 1),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: primary, width: 1.5),
                                ),
                                errorText: _errorText,
                                errorStyle: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w600),
                                errorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.red.shade700, width: 1.2),
                                ),
                                focusedErrorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.red.shade700, width: 1.6),
                                ),
                              ),
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) return 'Email is required.';
                                if (!_emailRegex.hasMatch(value.trim())) return 'Enter a valid email.';
                                return null;
                              },
                            ),
                            const SizedBox(height: 18),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: (_emailController.text.trim().isEmpty || _isLoading) ? null : _submit,
                                style: ButtonStyle(
                                  backgroundColor: MaterialStateProperty.resolveWith<Color?>((states) {
                                    if (states.contains(MaterialState.disabled)) return primary.withOpacity(0.45);
                                    return primary;
                                  }),
                                  foregroundColor: MaterialStateProperty.all<Color>(Colors.white),
                                  shape: MaterialStateProperty.all<OutlinedBorder>(const StadiumBorder()),
                                  padding: MaterialStateProperty.all(const EdgeInsets.symmetric(vertical: 16)),
                                  elevation: MaterialStateProperty.resolveWith<double?>((states) => states.contains(MaterialState.disabled) ? 0 : 4),
                                  overlayColor: MaterialStateProperty.resolveWith<Color?>((states) => states.contains(MaterialState.pressed) ? primary.withOpacity(0.12) : null),
                                ),
                                child: _isLoading
                                    ? SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                          strokeWidth: 2.2,
                                        ),
                                      )
                                    : const Text(
                                        'Send Verification Code',
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (_sent)
                              Row(
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      color: primary.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    padding: const EdgeInsets.all(8),
                                    child: Icon(Icons.check_circle_outline, color: primary),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Verification code sent. Please check your email.',
                                      style: TextStyle(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
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



