import 'package:flutter/material.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:modipay/login/login_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Onbonding extends StatefulWidget {
  const Onbonding({Key? key}) : super(key: key);

  @override
  State<Onbonding> createState() => _OnbondingState();
}

class _OnbondingState extends State<Onbonding> {
  static const String _onboardingSeenKey = 'onboarding_seen_v2';
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<_OnboardingItem> _items = [
    const _OnboardingItem(
      title: 'Biar Gak Hilang',
      description:
          'Semua bukti transaksi disimpen rapi, jadi kamu gak perlu panik nyari nanti',
      imagePath: 'images/onboarding_storage.png',
      buttonLabel: 'Izinkan Storage',
      permissionType: _PermissionType.storage,
    ),
    const _OnboardingItem(
      title: 'Auto Isi dari Kontak',
      description:
          'Ambil nomor langsung dari kontak, cepat & anti typo',
      imagePath: 'images/onboarding_contacts.png',
      buttonLabel: 'Izinkan Kontak',
      permissionType: _PermissionType.contacts,
    ),
    const _OnboardingItem(
      title: 'Jangan Sampai Ketinggalan',
      description:
          'Info penting & update transaksi langsung masuk, no drama telat info',
      imagePath: 'images/onboarding_notification.png',
      buttonLabel: 'Izinkan Notifikasi',
      permissionType: _PermissionType.notifications,
    ),
    const _OnboardingItem(
      title: 'Tinggal Scan Aja',
      description:
          'Scan QR atau upload bukti jadi super gampang, gak pake ribet',
      imagePath: 'images/onboarding_camera.png',
      buttonLabel: 'Izinkan Kamera',
      permissionType: _PermissionType.camera,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingSeenKey, true);

    final loginScreen = await resolveLoginScreen();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => loginScreen),
    );
  }

  Future<void> _onPrimaryTap() async {
    await _requestPermission(_items[_currentPage].permissionType);

    if (_currentPage < _items.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
      return;
    }
    await _finishOnboarding();
  }

  Future<void> _requestPermission(_PermissionType type) async {
    Permission permission;
    String label;
    switch (type) {
      case _PermissionType.storage:
        label = 'storage';
        final androidInfo = await _getAndroidInfo();
        if (androidInfo != null && androidInfo.version.sdkInt >= 33) {
          permission = Permission.photos;
        } else {
          permission = Permission.storage;
        }
        break;
      case _PermissionType.camera:
        permission = Permission.camera;
        label = 'kamera';
        break;
      case _PermissionType.contacts:
        permission = Permission.contacts;
        label = 'kontak';
        break;
      case _PermissionType.notifications:
        permission = Permission.notification;
        label = 'notifikasi';
        break;
    }

    final status = await permission.request();
    if (!mounted) return;

    if (status.isGranted || status.isLimited) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Izin $label belum diberikan. Kamu bisa aktifkan nanti di pengaturan.'),
      ),
    );
  }

  Future<AndroidDeviceInfo?> _getAndroidInfo() async {
    try {
      return await _deviceInfo.androidInfo;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = _items[_currentPage];

    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F8),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
          child: Column(
            children: [
              Row(
                children: List.generate(_items.length, (index) {
                  final active = index == _currentPage;
                  return Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: EdgeInsets.only(right: index == _items.length - 1 ? 0 : 8),
                      height: 4,
                      decoration: BoxDecoration(
                        color: active ? const Color(0xFF1F7AE0) : const Color(0xFFBFD5F3),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _items.length,
                  onPageChanged: (index) => setState(() => _currentPage = index),
                  itemBuilder: (context, index) {
                    final data = _items[index];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data.title,
                          style: const TextStyle(
                            color: Color(0xFF2C2E33),
                            fontFamily: 'Gilroy Bold',
                            height: 1.15,
                            fontSize: 34,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          data.description,
                          style: const TextStyle(
                            color: Color(0xFF6D7178),
                            fontFamily: 'Gilroy Medium',
                            height: 1.4,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 26),
                        Expanded(
                          child: Center(
                            child: Image.asset(
                              data.imagePath,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _onPrimaryTap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1F7AE0),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: Text(
                    item.buttonLabel,
                    style: const TextStyle(
                      fontFamily: 'Gilroy Bold',
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingItem {
  final String title;
  final String description;
  final String imagePath;
  final String buttonLabel;
  final _PermissionType permissionType;

  const _OnboardingItem({
    required this.title,
    required this.description,
    required this.imagePath,
    required this.buttonLabel,
    required this.permissionType,
  });
}

enum _PermissionType {
  storage,
  camera,
  contacts,
  notifications,
}
