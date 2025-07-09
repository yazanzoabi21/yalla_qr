import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_item.dart';
import '../../widgets/navbar.dart';
import '../meals/meals_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? lastClicked;

  @override
  void initState() {
    super.initState();
    loadLastClicked();
  }

  Future<void> loadLastClicked() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? savedTitle = prefs.getString('lastClicked');

    if (!mounted) return;
    if (savedTitle != null) {
      setState(() {
        lastClicked = savedTitle;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Last Clicked: $savedTitle')));
    }
  }

  Future<void> updateLastClicked(String title) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('lastClicked', title);

    if (!mounted) return;
    setState(() {
      lastClicked = title;
    });

    // Navigate to specific screens based on the clicked card
    if (title == 'Meals') {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const MealsScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFF0F3),
      appBar: const Navbar(),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.6, // Makes cards taller (width/height ratio)
          children: [
            HomeItem(
              title: 'GYM',
              color: Colors.teal,
              imagePath: 'assets/images/GYM.png',
              lastClicked: lastClicked,
              onTap: updateLastClicked,
            ),
            HomeItem(
              title: 'Meals',
              color: Colors.deepOrange,
              imagePath: 'assets/images/Meals.png',
              lastClicked: lastClicked,
              onTap: updateLastClicked,
            ),
            HomeItem(
              title: 'Comming Soon',
              color: Colors.indigo,
              lastClicked: lastClicked,
              onTap: updateLastClicked,
            ),
            HomeItem(
              title: 'Comming Soon',
              color: Colors.amber,
              lastClicked: lastClicked,
              onTap: updateLastClicked,
            ),
            HomeItem(
              title: 'Comming Soon',
              color: Colors.pink,
              lastClicked: lastClicked,
              onTap: updateLastClicked,
            ),
            HomeItem(
              title: 'Comming Soon',
              color: Colors.lime,
              lastClicked: lastClicked,
              onTap: updateLastClicked,
            ),
            HomeItem(
              title: 'Comming Soon',
              color: Colors.cyan,
              lastClicked: lastClicked,
              onTap: updateLastClicked,
            ),
            HomeItem(
              title: 'Comming Soon',
              color: Colors.brown,
              lastClicked: lastClicked,
              onTap: updateLastClicked,
            ),
          ],
        ),
      ),
    );
  }
}
