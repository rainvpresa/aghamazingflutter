import 'package:aghamazing/services/auth_api.dart';

// Create a single shared instance of AuthApi for the app.
// Replace the URLs below with your API endpoints (same as Unity).
final AuthApi authApi = AuthApi(
  registerUrl: 'https://unauthorised-boyce-telegrammatic.ngrok-free.dev/api/auth/registration/',
  loginUrl: 'https://unauthorised-boyce-telegrammatic.ngrok-free.dev/api/auth/login/',
  otpRequestUrl: 'https://unauthorised-boyce-telegrammatic.ngrok-free.dev/api/auth/otp/request/',
  otpVerifyUrl: 'https://unauthorised-boyce-telegrammatic.ngrok-free.dev/api/otp/verify/',
  timeout: const Duration(seconds: 10),
  allowBadCertificateInDebug: true,
);