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
import 'services/route_observer.dart';
import 'dart:ui' as ui;

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
      navigatorObservers: [routeObserver],
      title: 'AGHAMazing',
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        return child!;
        final mq = MediaQuery.of(context);

        // Tablet in portrait: render on a virtual phone-width canvas and
        // scale it up to fill the whole screen.
        final isTabletPortrait =
            mq.size.shortestSide >= 600 && mq.size.height > mq.size.width;
        if (isTabletPortrait) {
          const vw = 500.0;
          final s = vw / mq.size.width;
          final vh = mq.size.height * s;
          return FittedBox(
            fit: BoxFit.fill,
            child: SizedBox(
              width: vw,
              height: vh,
              child: MediaQuery(
                data: mq.copyWith(
                  size: Size(vw, vh),
                  padding: mq.padding * s,
                  viewPadding: mq.viewPadding * s,
                  viewInsets: mq.viewInsets * s,
                ),
                child: child!,
              ),
            ),
          );
        }

        const maxW = 480.0;
        final maxH = maxW * 2.1;
        if (mq.size.width <= maxW && mq.size.height <= maxH) return child!;
        final w = mq.size.width < maxW ? mq.size.width : maxW;
        final h = mq.size.height < maxH ? mq.size.height : maxH;
        return Stack(
          children: [
            Positioned.fill(
              child: ImageFiltered(
                imageFilter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                child: Image.asset(
                  'assets/images/backgrounds/login_screen.png',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                  const ColoredBox(color: Colors.black),
                ),
              ),
            ),
            Positioned.fill(
              child: ColoredBox(color: Colors.black.withValues(alpha: 0.25)),
            ),
            Center(
              child: FittedBox(
                fit: BoxFit.contain,
                child: SizedBox(
                  width: 500,
                  height: 800,
                  child: MediaQuery(
                    data: mq.copyWith(size: const Size(500, 800)),
                    child: child!,
                  ),
                ),
              ),
            ),
          ],
        );
      },
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