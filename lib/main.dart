import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:workmanager/workmanager.dart';
import 'theme/app_theme.dart';
import 'theme/theme_provider.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/ai_guidance/ai_guidance_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/relax/relax_screen.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/auth/auth_screen.dart';
import 'screens/auth/onboarding_screen.dart';
import 'screens/settings/profile_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'utils/notification_service.dart';
import 'utils/sarcasm_engine.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'screens/settings/app_block_overlay.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp();
  
  // Initialize Notifications
  await NotificationService.init();

  // Start the Sarcasm Engine (polls every 10s)
  SarcasmEngine.start();

  // Initialize Workmanager for background tasks
  await Workmanager().initialize(
    callbackDispatcher,
    isInDebugMode: true,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: const LuminanceApp(),
    ),
  );
}

class LuminanceApp extends StatelessWidget {
  const LuminanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'Luminance',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.themeMode,
          home: StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return SplashScreen();
              }
              if (snapshot.hasData) {
                return MainNavigationScreen();
              }
              return const AuthScreen();
            },
          ),
          routes: {
            '/settings': (context) => const SettingsScreen(),
            '/dashboard': (context) => const DashboardScreen(),
            '/profile': (context) => const ProfileScreen(),
            '/onboarding': (context) => const OnboardingScreen(),
          },
        );
      },
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  String? _blockedAppPackage;
  Timer? _blockCheckTimer;

  final List<Widget> _screens = [
    const HomeScreen(),
    const RelaxScreen(),
    const DashboardScreen(),
    const AiGuidanceScreen(),
    const SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startBlockPolling();
    
    // Listen for Push notifications from Native
    const MethodChannel('com.luminance/usage').setMethodCallHandler((call) async {
      if (call.method == 'onBlockTriggered') {
        setState(() {
          _blockedAppPackage = call.arguments as String;
        });
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _blockCheckTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkBlockStatus();
    }
  }

  void _startBlockPolling() {
    _blockCheckTimer = Timer.periodic(const Duration(milliseconds: 500), (_) => _checkBlockStatus());
  }

  Future<void> _checkBlockStatus() async {
    try {
      const channel = MethodChannel('com.luminance/usage');
      final String? blockedPkg = await channel.invokeMethod('getPendingBlock');
      if (blockedPkg != null) {
        setState(() {
          _blockedAppPackage = blockedPkg;
        });
      }
    } catch (e) {
      print("Error checking block status: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          body: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _screens[_currentIndex],
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.spa_outlined),
                activeIcon: Icon(Icons.spa),
                label: 'Relax',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.dashboard_outlined),
                activeIcon: Icon(Icons.dashboard),
                label: 'Dashboard',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.psychology_outlined),
                activeIcon: Icon(Icons.psychology),
                label: 'AI Guidance',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.settings_outlined),
                activeIcon: Icon(Icons.settings),
                label: 'Settings',
              ),
            ],
          ),
        ),
        if (_blockedAppPackage != null)
          AppBlockOverlay(
            packageName: _blockedAppPackage!,
            onDismiss: () {
              setState(() {
                _blockedAppPackage = null;
                _currentIndex = 0; // Force redirect to Home Page
              });
            },
          ),
      ],
    );
  }
}
