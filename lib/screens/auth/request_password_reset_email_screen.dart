import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'reset_password_screen.dart';

class RequestPasswordResetEmailScreen extends StatefulWidget {
  const RequestPasswordResetEmailScreen({super.key});

  @override
  State<RequestPasswordResetEmailScreen> createState() => _RequestPasswordResetEmailScreenState();
}

class _RequestPasswordResetEmailScreenState extends State<RequestPasswordResetEmailScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendReset() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSending = true);

    try {
      final authService = AuthService(Supabase.instance.client);
      await authService.sendPasswordResetEmail(email: _emailController.text.trim());

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset email sent. Check your inbox.')),
      );
      // Navigate to in-app OTP / token completion screen so users who
      // received a numeric code (OTP) can complete the reset without
      // opening the web reset page.
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ResetPasswordScreen(email: _emailController.text.trim())),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send reset email: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Render the redesigned reset screen here so the app shows the new UI
    // wherever `RequestPasswordResetEmailScreen` is used.
    return ResetPasswordScreen(email: _emailController.text.trim());
  }
}
