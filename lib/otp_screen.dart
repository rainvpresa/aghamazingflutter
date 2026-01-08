import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aghamazing/services/api_client.dart';
import 'package:aghamazing/services/auth_api.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({Key? key}) : super(key: key);

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _otpCtl = TextEditingController();
  String _email = '';
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _loadPendingEmail();
  }

  Future<void> _loadPendingEmail() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _email = prefs.getString('PendingVerificationEmail') ?? '');
  }

  @override
  void dispose() {
    _otpCtl.dispose();
    super.dispose();
  }

  Future<void> _verifyOtp() async {
    final otp = _otpCtl.text.trim();
    if (otp.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter OTP')));
      return;
    }

    setState(() => _isBusy = true);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await authApi.verifyOtp(email: _email, otp: otp);

      if (!mounted) return;
      Navigator.of(context).pop(); // close loader

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('OTP verified'), backgroundColor: Colors.green));

      // Navigate to login or home screen
      Navigator.of(context).pushReplacementNamed('/login');
    } on ApiException catch (e) {
      if (mounted) Navigator.of(context).pop();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: Colors.red));
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('OTP verification failed: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify OTP')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text('Verification email: $_email'),
            const SizedBox(height: 12),
            TextField(
              controller: _otpCtl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(hintText: 'OTP code'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _isBusy ? null : _verifyOtp,
              child: const Text('Verify OTP'),
            ),
          ],
        ),
      ),
    );
  }
}