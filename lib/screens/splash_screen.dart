import 'package:flutter/material.dart';
import 'dart:async';

class SplashScreen extends StatefulWidget {
  final VoidCallback onSplashComplete;

  const SplashScreen({super.key, required this.onSplashComplete});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
  with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Create animation controller for 3 seconds
    _animationController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );

    // Slide up animation (from bottom to top)
    _slideAnimation =
        Tween<Offset>(
          begin: const Offset(0, 0.5), // Start from bottom
          end: const Offset(0, 0), // End at center
        ).animate(
          CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
        );

    // Fade in animation
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    // Start animation
    _animationController.forward();

    // Navigate to next screen after 3 seconds
    Timer(const Duration(seconds: 5), () {
      if (mounted) {
        widget.onSplashComplete();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SlideTransition(
          position: _slideAnimation,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo with enhanced design
                Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(35),
                    gradient: LinearGradient(
                      colors: [
                        Colors.orange.shade50,
                        Colors.white,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.withOpacity(0.25),
                        blurRadius: 30,
                        spreadRadius: 5,
                        offset: const Offset(0, 10),
                      ),
                      BoxShadow(
                        color: Colors.orange.withOpacity(0.1),
                        blurRadius: 50,
                        spreadRadius: 10,
                        offset: const Offset(0, 20),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(25),
                    child: Image.asset(
                      'assets/icon/yalla_qr_img.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(height: 40),

                // App name with animation
                ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    colors: [
                      Colors.orange.shade600,
                      Colors.deepOrange.shade700,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ).createShader(bounds),
                  child: const Text(
                    'YallaQR',
                    style: TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 1.5,
                      height: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Professional tagline
                Text(
                  'Smart Delivery & Order Management',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade700,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 6),
                
                // Sub-tagline
                Text(
                  'Real-time tracking • QR-powered • Seamless logistics',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: Colors.grey.shade500,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 60),

                // Loading indicator
                SizedBox(
                  width: 50,
                  child: LinearProgressIndicator(
                    value: _animationController.value,
                    minHeight: 4,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.deepOrange.withOpacity(0.8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
