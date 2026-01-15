import 'package:flutter/material.dart';

class ARScanScreen extends StatelessWidget {
  const ARScanScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AR Scan')),
      body: const Center(child: Text('AR Scan flow goes here')),
    );
  }
}