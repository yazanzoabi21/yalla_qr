import 'package:flutter/material.dart';
import '../../widgets/navbar.dart';
import '../../services/category_service.dart';

class GymScreen extends StatefulWidget {
  const GymScreen({super.key});

  @override
  State<GymScreen> createState() => _GymScreenState();
}

class _GymScreenState extends State<GymScreen> {
  String? gymCategoryId;

  @override
  void initState() {
    super.initState();
    _loadGymCategoryId();
  }

  Future<void> _loadGymCategoryId() async {
    try {
      final categories = await CategoryService.getCategoriesForAccount();
      final gymCategory = categories.firstWhere(
        (cat) => cat.name.toLowerCase().trim() == 'gym',
        orElse: () => categories.firstWhere(
          (cat) => cat.name.toLowerCase().contains('gym'),
        ),
      );
      setState(() {
        gymCategoryId = gymCategory.id;
      });
    } catch (e) {
      debugPrint('Error loading gym category: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFF0F3),
      appBar: Navbar(
        categoryId: gymCategoryId,
        showMenuButton: false, // Hide menu in sub-category
        onSearchReturn: () {
          // Refresh gym data when returning from search if needed
          setState(() {});
        },
      ), // Navbar auto-detects auth state
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Back button
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.pushReplacementNamed(context, '/home'),
                ),
                const Text(
                  'Gym',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Header Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.teal, Colors.teal.shade300],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.teal.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.fitness_center, color: Colors.white, size: 32),
                  SizedBox(height: 8),
                  Text(
                    'Gym Management',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Manage your gym activities and schedules',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Quick Actions Section
            const Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),

            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.2,
                children: [
                  _buildActionCard(
                    'Workout Schedule',
                    Icons.schedule,
                    Colors.teal,
                    () {
                      _showComingSoon('Workout Schedule');
                    },
                  ),
                  _buildActionCard(
                    'Exercise Plans',
                    Icons.assignment,
                    Colors.teal.shade400,
                    () {
                      _showComingSoon('Exercise Plans');
                    },
                  ),
                  _buildActionCard(
                    'Equipment Check',
                    Icons.fitness_center,
                    Colors.teal.shade600,
                    () {
                      _showComingSoon('Equipment Check');
                    },
                  ),
                  _buildActionCard(
                    'Member Status',
                    Icons.people,
                    Colors.teal.shade700,
                    () {
                      _showComingSoon('Member Status');
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              colors: [color, color.withValues(alpha: 0.8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: Colors.white),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature - Coming Soon!'),
        backgroundColor: Colors.teal,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
