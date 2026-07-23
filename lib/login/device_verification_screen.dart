import 'dart:async';

import 'package:flutter/material.dart';
import 'package:modipay/utils/toast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:modipay/bottombar/bottombar.dart';
import 'package:modipay/login/setup_pin_screen.dart';
import 'package:modipay/providers/auth_provider.dart';
import 'package:modipay/services/api_service.dart';
import 'package:modipay/services/app_exception.dart';
import 'package:modipay/utils/color.dart';
import 'package:modipay/utils/responsive.dart';

import 'desktop_auth_panel.dart';

/// Ditampilkan saat login (password/PIN) dari perangkat yang belum dikenal
/// backend. Polling `GET /device-verification/{pendingToken}/status` tiap
/// beberapa detik; begitu link WhatsApp diklik, auto-login lalu masuk ke
/// home (atau setup PIN dulu kalau akun belum punya PIN).
class DeviceVerificationScreen extends StatefulWidget {
  const DeviceVerificationScreen({super.key, required this.pendingToken});

  final String pendingToken;

  @override
  State<DeviceVerificationScreen> createState() =>
      _DeviceVerificationScreenState();
}

class _DeviceVerificationScreenState extends State<DeviceVerificationScreen> {
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _checkStatus();
    // Backend membatasi 20 polling/menit per IP+token; interval 4 detik
    // (15/menit) menyisakan headroom dari batas itu.
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) => _checkStatus());
  }

  Future<void> _checkStatus() async {
    try {
      final result = await ApiService.deviceVerificationStatus(widget.pendingToken);
      if (!mounted) return;

      if (result['verified'] != true) return;

      final hasToken = (result['token']?.toString() ?? '').isNotEmpty;
      if (hasToken) {
        _pollTimer?.cancel();
        await _completeLogin(result);
      }
    } on AppException catch (e) {
      // Backend balikin 422 + expired:true kalau pending_token tidak
      // ditemukan atau link 15 menit sudah lewat — user harus login ulang.
      final details = e.details;
      final expired = details is Map && details['expired'] == true;
      if (expired) {
        _pollTimer?.cancel();
        if (!mounted) return;
        showToast(msg: e.message);
        Navigator.pop(context);
        return;
      }
      // Selain itu (mis. 429 rate limit) transien — coba lagi di interval berikutnya.
    } catch (_) {
      // Error jaringan transien — coba lagi di interval berikutnya.
    }
  }

  Future<void> _completeLogin(Map<String, dynamic> result) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final success = await auth.loginWithPasswordResult(result);
    if (!mounted) return;

    if (!success) {
      showToast(msg: auth.error ?? 'Gagal masuk');
      return;
    }

    showToast(msg: 'Perangkat berhasil diverifikasi.');
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => auth.hasPin ? const Bottombar() : const SetupPinScreen(),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isDesktop(context)) {
      return DesktopAuthShell(child: _buildContent());
    }
    return _buildMobileScaffold(context);
  }

  Widget _buildMobileScaffold(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: grey900),
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: screenWidth * 0.08,
          vertical: screenHeight * 0.02,
        ),
        child: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(strokeWidth: 2.4),
        const SizedBox(height: 24),
        Text(
          'Menunggu Verifikasi Perangkat',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: grey900,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Perangkat ini belum dikenali. Silakan cek WhatsApp kamu dan klik link verifikasi yang sudah dikirim.',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: grey500,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}
