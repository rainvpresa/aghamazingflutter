// lib/login_screen.dart

import 'package:flutter/material.dart';
import 'auth_service.dart';  // Import AuthService to handle login requests

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailController = TextEditingController();  // Controller for email input
  final TextEditingController passwordController = TextEditingController();  // Controller for password input
  final AuthService authService = AuthService();  // Instance of AuthService to call login

  // Function to handle the login action when the button is pressed
  void _login() {
    final email = emailController.text;
    final password = passwordController.text;

    // Call the login function from AuthService
    authService.loginUser(email, password);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Login')),  // App bar with title
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: emailController,  // Link to email input controller
              decoration: InputDecoration(labelText: 'Email'),  // Email field label
            ),
            TextField(
              controller: passwordController,  // Link to password input controller
              obscureText: true,  // Obscure password input
              decoration: InputDecoration(labelText: 'Password'),  // Password field label
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _login,  // Call _login when the button is pressed
              child: Text('Login'),  // Button text
            ),
          ],
        ),
      ),
    );
  }
}
