import 'package:flutter/material.dart';
import 'package:hexcolor/hexcolor.dart';
import 'custom_bottom_navigation.dart';
import '../../features/board/presentation/pages/board_page.dart';
import '../../features/history/presentation/pages/history_page.dart';

class MainWrapper extends StatefulWidget {
  const MainWrapper({super.key});

  @override
  State<MainWrapper> createState() => _MainWrapperState();
}

class _MainWrapperState extends State<MainWrapper> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const BoardPage(),
    const Center(child: Text('Recording Feature - Coming Soon')),
    const HistoryPage(),
  ];

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Set your desired background color here
      body: _pages[_currentIndex],
      bottomNavigationBar: CustomBottomNavigation(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
      ),
    );
  }
}