import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/sun_intro_screen.dart';
import 'screens/welcome_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/mainmenu_screen.dart';
import 'screens/trivia_game1/main_trivia_screen.dart';
import 'screens/gemgrab/gem_grab_game_screen.dart';
import 'screens/tictactoe_screen.dart';

import 'services/auth_service.dart';
import 'services/energy_manager.dart';
import 'services/sound_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock portrait mode
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize game systems
  await EnergyManager.instance.initialize();
  await SoundManager.instance.initialize();

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

      // Start with intro screen
      home: const SunIntroScreen(),

      routes: {
        '/auth': (_) => const AuthWrapper(),
        '/welcome': (_) => const WelcomeScreen(),
        '/login': (_) => const LoginScreen(),
        '/register': (_) => const RegisterScreen(),
        '/mainmenu': (_) => const MainMenuScreen(),
        '/profile': (_) => const ProfileScreen(),
        '/trivia': (_) => const MainTriviaScreen(),
        '/gemgrab': (_) => const GemGrabGameScreen(),
        '/tictactoe': (_) => const TicTacToeStartScreen(),
      },
    );
  }
}

/// Checks authentication state via Laravel token and routes user accordingly.
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return FutureBuilder<Map<String, dynamic>?>(
      future: authService.getCurrentUser(),
      builder: (context, snapshot) {
        // Smooth loading screen (prevents flicker after intro)
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF0D0D1A),
            body: SizedBox.shrink(),
          );
        }

        // Token is valid & user is authenticated → Main Menu
        if (snapshot.hasData && snapshot.data != null) {
          return const MainMenuScreen();
        }

        // Not logged in or token expired → Welcome Screen
        return const WelcomeScreen();
      },
    );
  }
}