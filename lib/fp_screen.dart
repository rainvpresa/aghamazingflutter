import 'package:flutter/material.dart';

class FpScreen extends StatelessWidget {
  const FpScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Forgot Password')),
      body: const Center(child: Text('Forgot password flow goes here')),
    );
  }
}