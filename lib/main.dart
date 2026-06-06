import 'package:flutter/material.dart';
import 'screens/dashboard_screen.dart';
import 'screens/wifi_config_screen.dart';

void main() {
  runApp(const Esp32PhoneServerApp());
}

class Esp32PhoneServerApp extends StatelessWidget {
  const Esp32PhoneServerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ESP32 Phone Server',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      // Bottom navigation between the two screens
      home: const _AppShell(),
    );
  }
}

/// _AppShell provides a BottomNavigationBar that switches between
/// [DashboardScreen] and [WiFiConfigScreen].
///
/// Using IndexedStack keeps both screens alive (preserving state) when
/// the user switches tabs.
class _AppShell extends StatefulWidget {
  const _AppShell();

  @override
  State<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<_AppShell> {
  int _selectedIndex = 0;

  static const _screens = [
    DashboardScreen(),
    WiFiConfigScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.wifi_outlined),
            selectedIcon: Icon(Icons.wifi),
            label: 'WiFi Config',
          ),
        ],
      ),
    );
  }
}
