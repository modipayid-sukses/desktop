import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:modipay/bottombar/bottombar.dart';
import 'package:modipay/login/auth_choice_screen.dart';
import 'package:modipay/onbonding.dart';
import 'package:modipay/login/setup_pin_screen.dart';
import 'package:modipay/providers/auth_provider.dart';
import 'package:modipay/utils/colornotifire.dart';
import 'package:modipay/services/root_detection_service.dart';
import 'package:modipay/design/design.dart';
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
  static const Duration _minimumSplashDuration = Duration.zero;

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
      await AppDialog.show(
        context: context,
        barrierDismissible: false,
        tone: AppDialogTone.error,
        title: 'Peringatan Keamanan',
        description:
            'Device Anda terdeteksi dalam kondisi tidak aman '
            '(root/jailbreak atau mode developer aktif).\n\n'
            'Demi keamanan transaksi finansial, aplikasi tidak dapat digunakan di perangkat ini.',
        primaryActionText: 'Tutup Aplikasi',
      );
      SystemNavigator.pop();
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
      await AppDialog.show(
        context: context,
        barrierDismissible: false,
        tone: AppDialogTone.error,
        title: 'Login dari Perangkat Lain',
        description: 'Akun ini sedang aktif di perangkat lain. Silakan login kembali jika ini bukan Anda.',
        primaryActionText: 'Mengerti',
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
    return const Scaffold(
      backgroundColor: Colors.white,
      body: SizedBox.shrink(),
    );
  }
}
