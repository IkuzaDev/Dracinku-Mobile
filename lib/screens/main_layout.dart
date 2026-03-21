import 'package:flutter/material.dart';
import '../widgets/bottom_navbar.dart';
import 'home_screen.dart';
import 'browse_screen.dart';
import 'search_screen.dart';
import 'downloads_screen.dart';
import 'dashboard_screen.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 2; // Default to Home

  final List<Widget> _pages = [
    const SearchScreen(),
    const BrowseScreen(),
    const HomeScreen(),
    const DownloadsScreen(),
    const DashboardScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: CustomBottomNavbar(
        currentIndex: _currentIndex,
        onTap: (idx) {
          setState(() {
            _currentIndex = idx;
          });
        },
      ),
    );
  }
}
