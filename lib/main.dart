import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/welcome_screen.dart';
import 'services/auth_service.dart';
import 'services/energy_manager.dart';  // ADD THIS
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/mainmenu_screen.dart';
import 'screens/trivia_game1/main_trivia_screen.dart';
import 'screens/gemgrab/gem_grab_game_screen.dart';
import 'screens/tictactoe_screen.dart';
import 'screens/sun_intro_screen.dart';

void main() async {
  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Enforce Portrait Only Mode
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize Firebase
  await Firebase.initializeApp();

  // Initialize Energy System (ADD THIS)
  await EnergyManager.instance.initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AGHAMazing',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      // Use AuthWrapper to check authentication state
      home: const SunIntroScreen(),
      routes: {
        '/welcome': (_) => const WelcomeScreen(),
        '/login': (_) => const LoginScreen(),
        '/register': (_) => const RegisterScreen(),
        '/mainmenu': (_) => const MainMenuScreen(),
        '/profile': (_) => const ProfileScreen(),
        '/trivia': (_) => const MainTriviaScreen(),
        '/gemgrab': (_) => const GemGrabGameScreen(),  // ADD THIS LINE
        '/tictactoe': (_) => const TicTacToeStartScreen(),
      },
    );
  }
}

// This widget checks if user is logged in
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        // Show loading while checking auth state
// In AuthWrapper, replace the loading state:
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF0D0D1A), // matches intro bg color
            body: SizedBox.shrink(),
          );
        }

        // User is logged in - go to main menu
        if (snapshot.hasData) {
          return const MainMenuScreen();
        }

        // User is not logged in - show welcome screen
        return const WelcomeScreen();
      },
    );
  }
}
