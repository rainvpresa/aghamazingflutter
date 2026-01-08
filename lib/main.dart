// lib/main.dart

import 'package:flutter/material.dart';
import 'package:aghamazing/welcome_screen.dart'; // package import
import 'login_screen.dart';
import 'register_screen.dart';
import 'otp_screen.dart';

void main() {
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
      ),
      // Show the welcome screen first (non-const instance)
      home: WelcomeScreen(),
        routes: {
          '/login': (_) => const LoginScreen(),
          '/register': (_) => const RegisterScreen(),
          '/otp': (_) => const OtpScreen(),
        }
    );
  }
}