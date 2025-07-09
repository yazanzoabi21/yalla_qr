import 'package:flutter/material.dart';
import '../screens/auth/login_screen.dart';

class Navbar extends StatelessWidget implements PreferredSizeWidget {
  final bool showLoginButton;

  const Navbar({super.key, this.showLoginButton = false});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      automaticallyImplyLeading: false,
      title: Container(
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            // IconButton(
            //   icon: const Icon(Icons.arrow_back, color: Colors.grey),
            //   onPressed: () {
            //     Navigator.pop(context);
            //   },
            // ),
            const Expanded(
              child: TextField(
                textAlignVertical: TextAlignVertical.center,
                decoration: InputDecoration(
                  hintText: 'Search',
                  hintStyle: TextStyle(color: Colors.grey),
                  border: InputBorder.none,
                  prefixIcon: Icon(Icons.search, color: Colors.grey),
                  contentPadding: EdgeInsets.symmetric(vertical: 0),
                ),
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.menu, color: Colors.grey),
              onSelected: (String value) {
                _handleMenuSelection(context, value);
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                const PopupMenuItem<String>(
                  value: 'contact',
                  child: ListTile(
                    leading: Icon(Icons.contact_support),
                    title: Text('Contact'),
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'feedback',
                  child: ListTile(
                    leading: Icon(Icons.feedback),
                    title: Text('Feedback'),
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'settings',
                  child: ListTile(
                    leading: Icon(Icons.settings),
                    title: Text('Settings'),
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'about',
                  child: ListTile(
                    leading: Icon(Icons.info),
                    title: Text('About'),
                  ),
                ),
                if (showLoginButton) ...[
                  const PopupMenuDivider(),
                  const PopupMenuItem<String>(
                    value: 'login',
                    child: ListTile(
                      leading: Icon(Icons.login),
                      title: Text('Login'),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _handleMenuSelection(BuildContext context, String value) {
    switch (value) {
      case 'contact':
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Contact selected')));
        break;
      case 'feedback':
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Feedback selected')));
        break;
      case 'settings':
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Settings selected')));
        break;
      case 'about':
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('About selected')));
        break;
      case 'login':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
        break;
    }
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 10);
}
