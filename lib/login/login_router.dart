import 'package:flutter/material.dart';

import 'login.dart';
import 'login_with_password.dart';
import '../services/api_service.dart';

/// Tentukan layar login yang sesuai berdasarkan setting `is_otp_required`
/// dari `/api/app-config`:
///  - true  -> Login() : nomor HP -> OTP -> PIN (tanpa password).
///  - false -> LoginWithPassword() : nomor HP + password (tanpa OTP).
///
/// Dipakai di setiap titik yang mengarahkan pengguna ke layar login
/// (pilihan login awal, sesi habis, logout) agar konsisten dengan setting
/// panel admin.
Future<Widget> resolveLoginScreen() async {
  final otpRequired = await ApiService.isOtpRequired();
  return otpRequired ? const Login() : const LoginWithPassword();
}
