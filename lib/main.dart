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
import 'push_notification_service.dart';

final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

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
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      title: 'AI Trader Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF059669), // Emerald Green
          secondary: Color(0xFF2563EB), // Royal Blue
          surface: Color(0xFFFFFFFF),
          error: Color(0xFFEF4444),
          onPrimary: Colors.white,
          onSurface: Color(0xFF0F172A),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF0F172A),
          elevation: 0,
          scrolledUnderElevation: 1,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
          iconTheme: IconThemeData(color: Color(0xFF1E293B)),
        ),
        cardTheme: CardTheme(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
          ),
          margin: const EdgeInsets.symmetric(vertical: 6),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF1F5F9),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF059669), width: 1.5),
          ),
          labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
        ),
        textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme).apply(
          bodyColor: const Color(0xFF0F172A),
          displayColor: const Color(0xFF0F172A),
        ),
      ),
      home: const LoginScreen(),
    );
  }
}

// NAVIGASI UTAMA (4 TAB)
class MainNav extends ConsumerStatefulWidget {
  const MainNav({super.key});
  @override
  ConsumerState<MainNav> createState() => _MainNavState();
}

class _MainNavState extends ConsumerState<MainNav> {
  int _idx = 0;
  final _screens = [
    const DashboardScreen(),
    const MarketScreen(),
    const HistoryScreen(),
    const ControlScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PushNotificationService.initialize(ref, context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_idx],
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
        ),
        child: NavigationBar(
          backgroundColor: Colors.white,
          indicatorColor: const Color(0xFFD1FAE5), // Mint Green Indicator
          selectedIndex: _idx,
          elevation: 0,
          onDestinationSelected: (i) => setState(() => _idx = i),
          destinations: const [
            NavigationDestination(
              icon: Icon(PhosphorIcons.house, color: Color(0xFF64748B)),
              selectedIcon: Icon(PhosphorIcons.houseFill, color: Color(0xFF059669)),
              label: "Dashboard",
            ),
            NavigationDestination(
              icon: Icon(PhosphorIcons.chartLineUp, color: Color(0xFF64748B)),
              selectedIcon: Icon(PhosphorIcons.chartLineUpFill, color: Color(0xFF059669)),
              label: "Market",
            ),
            NavigationDestination(
              icon: Icon(PhosphorIcons.clockCounterClockwise, color: Color(0xFF64748B)),
              selectedIcon: Icon(PhosphorIcons.clockCounterClockwiseFill, color: Color(0xFF059669)),
              label: "History",
            ),
            NavigationDestination(
              icon: Icon(PhosphorIcons.cpu, color: Color(0xFF64748B)),
              selectedIcon: Icon(PhosphorIcons.cpuFill, color: Color(0xFF059669)),
              label: "Control",
            ),
          ],
        ),
      ),
    );
  }
}