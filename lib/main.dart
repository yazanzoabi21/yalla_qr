import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/auth/welcome_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/client/client_categories_screen.dart';
import 'utils/supabase_setup.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Supabase.initialize(
      url: 'https://fhsqvuyzoptmkpapxyfl.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZoc3F2dXl6b3B0bWtwYXB4eWZsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTEyODY5NjcsImV4cCI6MjA2Njg2Mjk2N30._ERJc5TyJr_Q-KL06FjfpR05mtPm5o12m9mqFsfugVs',
    );
    debugPrint('Startup currentSession user: ${Supabase.instance.client.auth.currentUser?.email}');
    await SupabaseSetup.initializeStorage();
  } catch (e) {
    debugPrint('Initialization error: $e');
  }
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Yalla QR',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const WelcomeScreen(),
      routes: {
        '/home': (context) => const HomeScreen(),
        '/client': (context) => const ClientCategoriesScreen(),
      },
    );
  }
}
