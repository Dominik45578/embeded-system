import 'package:flutter/material.dart';
import 'package:lockly_app/ui/screens/tabs/device_tab.dart';
import 'package:lockly_app/ui/screens/tabs/event_tab.dart';
import 'package:lockly_app/ui/screens/tabs/profile_tab.dart';


class RootLayout extends StatefulWidget {
  const RootLayout({super.key});

  @override
  State<RootLayout> createState() => _RootLayoutState();
}

class _RootLayoutState extends State<RootLayout> {
  int _currentIndex = 0;

  final List<Widget> _tabs = const [
    DevicesTab(),
    EventsTab(),
    ProfileTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: IndexedStack(
          index: _currentIndex,
          children: _tabs,
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: Color(0xFF2C2C2E), width: 1),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          backgroundColor: const Color(0xFF161616),
          selectedItemColor: const Color(0xFF00ADB5),
          unselectedItemColor: const Color(0xFF8E8E93),
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.developer_board_rounded),
              activeIcon: Icon(Icons.developer_board_rounded, color: Color(0xFF00ADB5)),
              label: 'Urządzenia',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history_toggle_off_rounded),
              activeIcon: Icon(Icons.history_toggle_off_rounded, color: Color(0xFF00ADB5)),
              label: 'Zdarzenia',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline_rounded),
              activeIcon: Icon(Icons.person_rounded, color: Color(0xFF00ADB5)),
              label: 'Profil',
            ),
          ],
        ),
      ),
    );
  }
}