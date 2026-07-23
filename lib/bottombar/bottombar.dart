import 'package:flutter/material.dart';
import 'package:modipay/utils/responsive.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:modipay/login/login_router.dart';
import 'package:modipay/home/home.dart';
import 'package:modipay/home/topup/topup_channel_screen.dart';
import 'package:modipay/providers/auth_provider.dart';
import 'package:modipay/utils/colornotifire.dart';
import 'package:modipay/design/design.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../home/seealltransaction.dart';
import '../promo/promo_screen.dart';
import '../profile/profile.dart' as profile_page;

class Bottombar extends StatefulWidget {
  const Bottombar({super.key});

  @override
  State<Bottombar> createState() => _BottombarState();
}

class _BottombarState extends State<Bottombar> {
  late ColorNotifire notifire;
  int currentTab = 0;

  final List<Widget> screens = [
    const Home(),
    const Seealltransaction(),
    const PromoScreen(),
    const profile_page.Profile(),
  ];

  final PageStorageBucket bucket = PageStorageBucket();
  Widget currentScreen = const Home();

  getdarkmodepreviousstate() async {
    final prefs = await SharedPreferences.getInstance();
    bool? previusstate = prefs.getBool("setIsDark");
    if (previusstate == null) {
      notifire.setIsDark = false;
    } else {
      notifire.setIsDark = previusstate;
    }
  }

  @override
  void initState() {
    super.initState();
  }

  static const _activeColor = Color(0xFF0D47A1);
  static const _inactiveColor = Color(0xFFB0BEC5);

  @override
  Widget build(BuildContext context) {
    notifire = Provider.of<ColorNotifire>(context, listen: true);
    final auth = Provider.of<AuthProvider>(context);

    if (!auth.isLoggedIn) {
      final wasKicked = auth.kickedByOtherDevice;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        if (wasKicked) {
          auth.consumeKickedByOtherDevice();
          await _showDeviceMismatchDialog(context);
          if (!mounted) return;
        }
        final loginScreen = await resolveLoginScreen();
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => loginScreen),
          (route) => false,
        );
      });
      return const SizedBox.shrink();
    }

    final showBottomNav = !isDesktop(context);

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: notifire.getprimerycolor,
        body: PageStorage(bucket: bucket, child: currentScreen),
        resizeToAvoidBottomInset: false,
        floatingActionButtonLocation: showBottomNav ? FloatingActionButtonLocation.centerDocked : null,
        floatingActionButton: showBottomNav ? _buildTopupFab() : null,
        bottomNavigationBar: showBottomNav ? _buildBottomNav(context) : null,
      ),
    );
  }

  void _onNavTap(int index) {
    if (currentTab == index) return;
    HapticFeedback.lightImpact();
    setState(() {
      currentTab = index;
      currentScreen = screens[index];
    });
  }

  Widget _buildNavItem({
    required int index,
    required String asset,
    required String label,
  }) {
    final isActive = currentTab == index;
    return GestureDetector(
      onTap: () => _onNavTap(index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 52,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              asset,
              width: 20,
              height: 20,
              colorFilter: ColorFilter.mode(
                isActive ? _activeColor : _inactiveColor,
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isActive ? _activeColor : _inactiveColor,
                fontSize: 10,
                fontFamily: isActive ? 'Gilroy Bold' : 'Gilroy Medium',
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopupFab() {
    return Container(
      width: 62,
      height: 62,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFF1976D2), Color(0xFF0D47A1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0D47A1).withValues(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: FloatingActionButton(
        onPressed: () {
          HapticFeedback.mediumImpact();
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const TopupChannelScreen()),
          );
        },
        elevation: 0,
        backgroundColor: Colors.transparent,
        shape: const CircleBorder(),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 30),
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    final safePadding = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(10, 8, 10, safePadding > 0 ? 8 : 12),
      decoration: BoxDecoration(
        color: notifire.getprimerycolor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 24,
            spreadRadius: 2,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: _buildNavItem(
                index: 0,
                asset: 'images/home.svg',
                label: 'Beranda',
              ),
            ),
            Expanded(
              child: _buildNavItem(
                index: 1,
                asset: 'images/history.svg',
                label: 'Transaksi',
              ),
            ),
            const SizedBox(width: 70),
            Expanded(
              child: _buildNavItem(
                index: 2,
                asset: 'images/promo.svg',
                label: 'Promo',
              ),
            ),
            Expanded(
              child: _buildNavItem(
                index: 3,
                asset: 'images/profile.svg',
                label: 'Profil',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDeviceMismatchDialog(BuildContext context) async {
    await AppDialog.show(
      context: context,
      barrierDismissible: false,
      tone: AppDialogTone.error,
      title: 'Login dari Perangkat Lain',
      description:
          'Akun ini sedang aktif di perangkat lain. Demi keamanan, sesi di perangkat ini telah diakhiri. Silakan login kembali jika ini bukan Anda.',
      primaryActionText: 'Mengerti',
    );
  }
}
