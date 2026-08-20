import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mytrading/login_screen.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'dashboard_screen.dart';
import 'market_screen.dart';   // Akan dibuat di Part 2
import 'control_screen.dart';  // Akan dibuat di Part 2
import 'history_screen.dart'; // Import halaman baru

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(); // Konek ke Firebase
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Trader Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E676), // Hijau Profit
          secondary: Color(0xFF2979FF), // Biru Info
          surface: Color(0xFF1E1E1E),
        ),
      ),
      home: const LoginScreen(),
    );
  }
}

// NAVIGASI UTAMA (3 TAB)
class MainNav extends StatefulWidget {
  const MainNav({super.key});
  @override
  State<MainNav> createState() => _MainNavState();
}

class _MainNavState extends State<MainNav> {
  int _idx = 0;
  final _screens = [
    const DashboardScreen(), // Ganti HomeScreen jadi DashboardScreen
    const MarketScreen(),
    const HistoryScreen(),   // Tab Baru
    const ControlScreen()
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_idx],
      bottomNavigationBar: NavigationBar(
        backgroundColor: const Color(0xFF1E1E1E),
        selectedIndex: _idx,
        onDestinationSelected: (i) => setState(() => _idx = i),
        destinations: const [
          NavigationDestination(icon: Icon(PhosphorIcons.house), label: "Dashboard"),
          NavigationDestination(icon: Icon(PhosphorIcons.chartLineUp), label: "Market"),
          NavigationDestination(icon: Icon(PhosphorIcons.clockCounterClockwise), label: "History"),
          NavigationDestination(icon: Icon(PhosphorIcons.cpu), label: "Control"),
        ],
      ),
    );
  }
}