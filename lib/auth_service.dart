// lib/auth_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;

class AuthService {
  static const String baseUrl = 'https://unauthorised-boyce-telegrammatic.ngrok-free.dev/dj-rest-auth/login/';  // Replace with your backend URL

  // Method to handle user login
  Future<void> loginUser(String email, String password) async {
    final url = Uri.parse('$baseUrl/login');  // Replace with your actual login URL

    try {
      // Sending POST request with email and password in the request body
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',  // Indicating we are sending JSON data
        },
        body: json.encode({
          'email': email,  // Sending email
          'password': password,  // Sending password
        }),
      );

      if (response.statusCode == 200) {
        // Handle successful login response
        print('Login successful');
        // You can handle token storage, navigation, etc. here
      } else {
        // Handle failed login
        print('Login failed: ${response.body}');
      }
    } catch (error) {
      // Handle any errors, such as no internet connection or backend issues
      print('Error: $error');
    }
  }
}