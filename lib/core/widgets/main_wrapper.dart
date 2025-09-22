import 'package:flutter/material.dart';
import 'package:swarana/features/transkrip/presentation/pages/transkrip_page.dart';
import '../../features/setting/presentation/pages/setting_page.dart';
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
    const TranskripPage(),
    const HistoryPage(),
    const SettingPage(),
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
      bottomNavigationBar: CustomBottomNavigation(currentIndex: _currentIndex, onTap: _onTabTapped),
    );
  }
}
