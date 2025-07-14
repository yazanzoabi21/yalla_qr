import 'package:flutter/material.dart';
import '../screens/meals/meals_screen.dart';
import '../screens/gym/gym_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/home/home_screen.dart';

class NavigationHelper {
  /// Navigate to the appropriate category screen based on category name
  static void navigateToCategory(BuildContext context, String categoryName) {
    if (!context.mounted) return;

    switch (categoryName.toLowerCase()) {
      case 'meals':
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => const MealsScreen(),
            settings: const RouteSettings(name: '/meals'), // Set route name for identification
          ),
          (Route<dynamic> route) => false, // Remove all previous routes
        );
        break;
      case 'gym':
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => const GymScreen(),
            settings: const RouteSettings(name: '/gym'), // Set route name for identification
          ),
          (Route<dynamic> route) => false, // Remove all previous routes
        );
        break;
      default:
        // For unimplemented categories, go to home screen
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => const HomeScreen(),
            settings: const RouteSettings(name: '/home'),
          ),
          (Route<dynamic> route) => false,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$categoryName screen coming soon!'),
            backgroundColor: Colors.orange,
          ),
        );
        break;
    }
  }

  /// Navigate to login screen
  static void navigateToLogin(BuildContext context, {String? intendedDestination}) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => LoginScreen(intendedDestination: intendedDestination),
        settings: const RouteSettings(name: '/login'),
      ),
      (Route<dynamic> route) => false, // Remove all previous routes
    );
  }

  /// Navigate to home screen
  static void navigateToHome(BuildContext context) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => const HomeScreen(),
        settings: const RouteSettings(name: '/home'),
      ),
      (Route<dynamic> route) => false, // Remove all previous routes
    );
  }

  /// Check if a category screen exists
  static bool categoryScreenExists(String categoryName) {
    switch (categoryName.toLowerCase()) {
      case 'meals':
      case 'gym':
        return true;
      default:
        return false;
    }
  }
}
