import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:gobank/bottombar/bottombar.dart';
import 'package:gobank/login/auth_choice_screen.dart';
import 'package:gobank/onbonding.dart';
import 'package:gobank/login/setup_pin_screen.dart';
import 'package:gobank/providers/auth_provider.dart';
import 'package:gobank/utils/colornotifire.dart';
import 'package:gobank/services/root_detection_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Splashscreen extends StatefulWidget {
  const Splashscreen({Key? key}) : super(key: key);

  @override
  State<Splashscreen> createState() => _SplashscreenState();
}

class _SplashscreenState extends State<Splashscreen> {
  late ColorNotifire notifire;
  static const String _onboardingSeenKey = 'onboarding_seen_v2';
  static const Duration _minimumSplashDuration = Duration(milliseconds: 100);

  getdarkmodepreviousstate() async {
    final prefs = await SharedPreferences.getInstance();
    bool? previusstate = prefs.getBool("setIsDark");
    if (previusstate == null) {
      notifire.setIsDark = false;
    } else {
      notifire.setIsDark = previusstate;
    }
  }

  /// Check if device is compromised and show close-only dialog
  Future<void> _checkRootStatus() async {
    // Temporary bypass: allow app to open normally for now.
    _proceedWithNavigation();
    return;

    final isCompromised = await RootDetectionService.isDeviceCompromised();
    if (isCompromised && mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) => AlertDialog(
          title: const Text('Peringatan Keamanan'),
          content: const Text(
            'Device Anda terdeteksi dalam kondisi tidak aman '
            '(root/jailbreak atau mode developer aktif).\n\n'
            'Demi keamanan transaksi finansial, aplikasi tidak dapat digunakan di perangkat ini.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                SystemNavigator.pop();
              },
              child: const Text('Tutup Aplikasi'),
            ),
          ],
        ),
      );
    } else {
      // Device is safe, proceed normally
      _proceedWithNavigation();
    }
  }

  /// Navigate based on user's login state
  Future<void> _proceedWithNavigation() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final prefs = await SharedPreferences.getInstance();
    final onboardingSeen = prefs.getBool(_onboardingSeenKey) ?? false;
    await auth.loadToken();

    // If the saved token was rejected because the account is now bound to a
    // different device, surface the reason before falling back to login.
    if (!auth.isLoggedIn && auth.kickedByOtherDevice && mounted) {
      auth.consumeKickedByOtherDevice();
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Login dari Perangkat Lain',
            style: TextStyle(fontFamily: 'Gilroy Bold', fontSize: 16),
          ),
          content: const Text(
            'Akun ini sedang aktif di perangkat lain. Silakan login kembali jika ini bukan Anda.',
            style: TextStyle(fontFamily: 'Gilroy Medium', fontSize: 13.5, height: 1.45),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Mengerti', style: TextStyle(fontFamily: 'Gilroy Bold')),
            ),
          ],
        ),
      );
      if (!mounted) return;
    }

    if (auth.isLoggedIn && mounted) {
      if (!auth.hasPin) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const SetupPinScreen()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const Bottombar()),
        );
      }
    } else if (mounted) {
      if (!onboardingSeen) {
        await prefs.setBool(_onboardingSeenKey, true);
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const Onbonding()),
        );
        return;
      }
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AuthChoiceScreen()),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    getdarkmodepreviousstate();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(_minimumSplashDuration);
      if (!mounted) return;
      _checkRootStatus();
    });
  }

  @override
  Widget build(BuildContext context) {
    notifire = Provider.of<ColorNotifire>(context, listen: true);
    return Scaffold(
      backgroundColor: const Color(0xFF182974),
      body: SizedBox.expand(
        child: Center(
          child: SvgPicture.asset(
            'images/logo_modipay.svg',
            width: 240,
          ),
        ),
      ),
    );
  }
}
