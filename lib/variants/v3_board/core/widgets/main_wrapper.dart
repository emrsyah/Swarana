import 'package:flutter/material.dart';
import 'package:swarana/variants/v3_board/features/transkrip/presentation/pages/transkrip_page.dart';
import '../../features/setting/presentation/pages/setting_page.dart';
import '../services/v3_backend.dart';
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

  static const _tabRoutes = ['/v3/board', '/v3/transkrip', '/v3/history', '/v3/setting'];

  void _onTabTapped(int index) {
    // Tabs are not routes; report them so the tracker's path includes them.
    V3Backend.ux.onRoute(_tabRoutes[index]);
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
