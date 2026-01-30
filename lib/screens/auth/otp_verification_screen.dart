import 'package:flutter/material.dart';

// Deprecated: phone/WhatsApp OTP removed. Use email reset flow instead.
class OTPVerificationScreen extends StatelessWidget {
  const OTPVerificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verification (Deprecated)'), backgroundColor: Colors.blueAccent),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('This verification flow has been replaced by the email reset flow.'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
              child: const Text('Back to Login'),
            ),
          ],
        ),
      ),
    );
  }
}
