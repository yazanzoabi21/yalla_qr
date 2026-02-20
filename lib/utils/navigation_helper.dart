import 'package:flutter/material.dart';
import '../screens/auth/login_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/meals/meals_screen.dart';
import '../screens/electronics/electronics_screen.dart';
import '../screens/gym/gym_screen.dart';
import '../screens/super_market/super_market_screen.dart';

class NavigationHelper {
  /// Navigate to login screen with optional intended destination
  static void navigateToLogin(BuildContext context, {String? intendedDestination, bool registerAsClient = false}) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => LoginScreen(
          intendedDestination: intendedDestination,
          registerAsClient: registerAsClient,
        ),
        settings: const RouteSettings(name: '/login'),
      ),
      (route) => false, // Remove all previous routes
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
      (route) => false, // Remove all previous routes
    );
  }

  /// Navigate to meals screen
  static void navigateToMeals(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const MealsScreen(),
        settings: const RouteSettings(name: '/meals'),
      ),
    );
  }

  /// Navigate to electronics screen
  static void navigateToElectronics(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const ElectronicsScreen(),
        settings: const RouteSettings(name: '/electronics'),
      ),
    );
  }

  /// Navigate to gym screen
  static void navigateToGym(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const GymScreen(),
        settings: const RouteSettings(name: '/gym'),
      ),
    );
  }

  /// Navigate to super market screen
  static void navigateToSuperMarket(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const SuperMarketScreen(),
        settings: const RouteSettings(name: '/super-market'),
      ),
    );
  }

  /// Navigate to specific category after authentication
  static void navigateToCategory(BuildContext context, String? category) {
    switch (category?.toLowerCase()) {
      case 'meals':
        navigateToMeals(context);
        break;
      case 'electronics':
        navigateToElectronics(context);
        break;
      case 'gym':
        navigateToGym(context);
        break;
      case 'super market':
        navigateToSuperMarket(context);
        break;
      default:
        navigateToHome(context);
        break;
    }
  }

  /// Get the current route name
  static String? getCurrentRouteName(BuildContext context) {
    final route = ModalRoute.of(context);
    return route?.settings.name;
  }

  /// Check if currently on a specific route
  static bool isOnRoute(BuildContext context, String routeName) {
    return getCurrentRouteName(context) == routeName;
  }

  /// Navigate back with fallback to home if no previous route
  static void navigateBackOrHome(BuildContext context) {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      navigateToHome(context);
    }
  }

  /// Show a confirmation dialog before navigation (useful for logout, etc.)
  static Future<bool> showConfirmationDialog({
    required BuildContext context,
    required String title,
    required String message,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    Color? confirmColor,
  }) async {
    return await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(cancelText),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: confirmColor != null
                  ? ElevatedButton.styleFrom(backgroundColor: confirmColor)
                  : null,
              child: Text(
                confirmText,
                style: TextStyle(
                  color: confirmColor != null ? Colors.white : null,
                ),
              ),
            ),
          ],
        );
      },
    ) ?? false;
  }

  /// Navigate with slide transition animation
  static void navigateWithSlideTransition(
    BuildContext context,
    Widget destination, {
    String? routeName,
    bool replace = false,
  }) {
    final route = PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => destination,
      settings: RouteSettings(name: routeName),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.ease;

        var tween = Tween(begin: begin, end: end).chain(
          CurveTween(curve: curve),
        );

        return SlideTransition(
          position: animation.drive(tween),
          child: child,
        );
      },
    );

    if (replace) {
      Navigator.pushReplacement(context, route);
    } else {
      Navigator.push(context, route);
    }
  }

  /// Navigate with fade transition animation
  static void navigateWithFadeTransition(
    BuildContext context,
    Widget destination, {
    String? routeName,
    bool replace = false,
  }) {
    final route = PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => destination,
      settings: RouteSettings(name: routeName),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
    );

    if (replace) {
      Navigator.pushReplacement(context, route);
    } else {
      Navigator.push(context, route);
    }
  }
}
