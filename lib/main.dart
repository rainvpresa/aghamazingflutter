// lib/main.dart

import 'package:flutter/material.dart';
import 'login_screen.dart';  // Import the login screen

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Login App',  // App title
      theme: ThemeData(
        primarySwatch: Colors.blue,  // Default app theme color
      ),
      home: LoginScreen(),  // Set the home screen to LoginScreen
    );
  }
}
