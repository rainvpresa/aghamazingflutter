import 'package:flutter/material.dart';

class ARScanScreen extends StatelessWidget {
  const ARScanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AR Scan')),
      body: const Center(child: Text('AR Scan flow goes here')),
    );
  }
}