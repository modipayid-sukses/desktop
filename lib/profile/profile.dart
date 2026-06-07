import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:modipay/login/login.dart';
import 'package:modipay/providers/auth_provider.dart';
import 'package:modipay/services/api_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/biometric_service.dart';
import '../utils/colornotifire.dart';
import '../utils/media.dart';
import '../utils/string.dart';
import 'change_pin_screen.dart';
import 'editprofile.dart';
import 'helpsupport.dart';
import 'language.dart';
import 'legalandpolicy.dart';
import 'level_detail_screen.dart';
import 'kyc_screen.dart';
import 'notification.dart';
import 'receipt_settings_screen.dart';
import 'agent_management_screen.dart';

class Profile extends StatefulWidget {
  const Profile({Key? key}) : super(key: key);

  @override
  State<Profile> createState() => _ProfileState();
}

class _ProfileState extends State<Profile> {
  late ColorNotifire notifire;
  bool _switchValue = false;
  bool _biometricAvailable = false;
  bool _biometricEnabled = false;

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
    getdarkmodepreviousstate();
    _loadBiometric();
  }

  Future<void> _loadBiometric() async {
    final available = await BiometricService.isAvailable();
    final enabled = await BiometricService.isEnabled();
    if (mounted) {
      setState(() {
        _biometricAvailable = available;
        _biometricEnabled = enabled;
      });
    }
  }

  Color _levelColor(String level) {
    switch (level.toLowerCase()) {
      case 'gold':
        return const Color(0xFFD4A017);
      case 'platinum':
        return const Color(0xFF8C9EAF);
      default:
        return const Color(0xFFCD7F32);
    }
  }

  IconData _levelIcon(String level) {
    switch (level.toLowerCase()) {
      case 'gold':
        return Icons.workspace_premium;
      case 'platinum':
        return Icons.diamond_outlined;
      default:
        return Icons.shield_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    notifire = Provider.of<ColorNotifire>(context, listen: true);
    final auth = Provider.of<AuthProvider>(context);
    const cardBg = Colors.white;
    const pageBg = Color(0xFFF3F6FB);
    final levelName = auth.userLevel.isEmpty ? 'Bronze' : auth.userLevel;
    final firstName = auth.userName.trim().split(' ').first;

    return Scaffold(
      backgroundColor: pageBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  color: notifire.getbluecolor,
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x2A143A66),
                      blurRadius: 20,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 62,
                          height: 62,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withOpacity(0.35)),
                          ),
                          child: ClipOval(
                            child: auth.userAvatar != null && auth.userAvatar!.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: ApiService.avatarUrl(auth.userAvatar),
                                    fit: BoxFit.cover,
                                    fadeInDuration: Duration.zero,
                                    errorWidget: (_, __, ___) =>
                                        Image.asset('images/man4.png', fit: BoxFit.cover),
                                  )
                                : Image.asset('images/man4.png', fit: BoxFit.cover),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Halo, $firstName',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontFamily: 'Gilroy Bold',
                                  fontSize: 22,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                auth.userEmail,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.88),
                                  fontFamily: 'Gilroy Medium',
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        InkWell(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const EditProfile()),
                          ),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.edit_outlined, color: Colors.white, size: 18),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          Icon(_levelIcon(levelName), color: _levelColor(levelName), size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Member $levelName',
                              style: const TextStyle(
                                color: Colors.white,
                                fontFamily: 'Gilroy Bold',
                                fontSize: 14,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const LevelDetailScreen()),
                            ),
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.white.withOpacity(0.2),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text(
                              'Lihat Level',
                              style: TextStyle(fontFamily: 'Gilroy Bold', fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _profileStatPill(
                      icon: Icons.verified_user_outlined,
                      label: auth.kycStatus.toLowerCase() == 'approved' ? 'KYC Terverifikasi' : 'KYC Belum Lengkap',
                      accent: auth.kycStatus.toLowerCase() == 'approved'
                          ? const Color(0xFF2E7D32)
                          : const Color(0xFFB26A00),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const KycScreen()),
                      ),
                    ),
                    _profileStatPill(
                      icon: Icons.notifications_none_rounded,
                      label: 'Notifikasi',
                      accent: const Color(0xFF3F6FB4),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const Notifications()),
                      ),
                    ),
                    _profileStatPill(
                      icon: Icons.language_outlined,
                      label: 'Bahasa',
                      accent: const Color(0xFF4B5FA9),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const Language()),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _sectionCard(
                title: 'Akun',
                children: [
                  _menuTile(
                    icon: Icons.manage_accounts_outlined,
                    title: 'Pengaturan Akun',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const EditProfile()),
                    ),
                  ),
                  _menuTile(
                    icon: Icons.pin_outlined,
                    title: 'Ganti PIN',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ChangePinScreen()),
                    ),
                  ),
                  _menuTile(
                    icon: Icons.bar_chart_rounded,
                    title: 'Level Member',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LevelDetailScreen()),
                    ),
                    showDivider: auth.isMasterAgent,
                  ),
                  if (auth.isMasterAgent)
                    _menuTile(
                      icon: Icons.supervised_user_circle_outlined,
                      title: 'Kelola Agen',
                      showDivider: false,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AgentManagementScreen()),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Keamanan',
                      style: TextStyle(
                        color: Color(0xFF18202A),
                        fontFamily: 'Gilroy Bold',
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: _biometricEnabled,
                      onChanged: !_biometricAvailable
                          ? null
                          : (val) async {
                              if (val) {
                                final ok = await BiometricService.authenticate(
                                  reason: 'Aktifkan login biometrik',
                                );
                                if (!ok) return;
                              }
                              await BiometricService.setEnabled(val);
                              if (mounted) setState(() => _biometricEnabled = val);
                            },
                      activeColor: notifire.getbluecolor,
                      title: const Text(
                        'Login Biometrik',
                        style: TextStyle(
                          fontFamily: 'Gilroy Medium',
                          color: Color(0xFF202A36),
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Text(
                        _biometricAvailable
                            ? 'Gunakan Face ID / sidik jari untuk login lebih cepat.'
                            : 'Biometrik tidak tersedia di perangkat ini.',
                        style: const TextStyle(
                          fontFamily: 'Gilroy Medium',
                          color: Color(0xFF728095),
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const Divider(height: 10),
                    _pinRequiredToggle(auth),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _sectionCard(
                title: 'Informasi',
                children: [
                  _menuTile(
                    icon: Icons.receipt_long_outlined,
                    title: 'Pengaturan Struk',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ReceiptSettingsScreen()),
                    ),
                  ),
                  _menuTile(
                    icon: Icons.help_outline_rounded,
                    title: 'Bantuan',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const HelpSupport(CustomStrings.helpandsupports),
                      ),
                    ),
                  ),
                  _menuTile(
                    icon: Icons.article_outlined,
                    title: 'Syarat & Ketentuan',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const LegalPolicy('Syarat & Ketentuan'),
                      ),
                    ),
                  ),
                  _menuTile(
                    icon: Icons.verified_user_outlined,
                    title: 'Kebijakan Privasi',
                    showDivider: false,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const LegalPolicy('Kebijakan Privasi'),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: _showMyDialog,
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: const Color(0xFFE74C3C),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.logout_rounded, color: Colors.white),
                  label: const Text(
                    'Keluar',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Gilroy Bold',
                      fontSize: 16,
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

  Widget _sectionCard({required String title, required List<Widget> children}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF18202A),
              fontFamily: 'Gilroy Bold',
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Widget _profileStatPill({
    required IconData icon,
    required String label,
    required Color accent,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: accent.withOpacity(0.1),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: accent),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: accent,
                fontFamily: 'Gilroy Bold',
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _menuTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool showDivider = true,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 12),
        decoration: BoxDecoration(
          border: showDivider
              ? const Border(bottom: BorderSide(color: Color(0xFFE9E9EE), width: 1))
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF3FA),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: const Color(0xFF20467A), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF1D2735),
                  fontFamily: 'Gilroy Medium',
                  fontSize: 14,
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF8E99AA), size: 22),
          ],
        ),
      ),
    );
  }

  Future<void> _showMyDialog() async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(
              Radius.circular(32.0),
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: notifire.getprimerycolor,
              borderRadius: const BorderRadius.all(
                Radius.circular(20),
              ),
            ),
            height: height / 3,
            child: Column(
              children: [
                SizedBox(
                  height: height / 40,
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                  },
                  child: Row(
                    children: [
                      const Spacer(),
                      Icon(
                        Icons.clear,
                        color: notifire.getdarkscolor,
                      ),
                      SizedBox(
                        width: width / 20,
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: height / 40,
                ),
                Text(
                  CustomStrings.sure,
                  style: TextStyle(
                    color: notifire.getdarkscolor,
                    fontFamily: 'Gilroy Bold',
                    fontSize: height / 40,
                  ),
                ),
                Text(
                  CustomStrings.log,
                  style: TextStyle(
                    color: notifire.getdarkscolor,
                    fontFamily: 'Gilroy Bold',
                    fontSize: height / 40,
                  ),
                ),
                SizedBox(
                  height: height / 20,
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                  },
                  child: Container(
                    height: height / 18,
                    width: width / 2.5,
                    decoration: BoxDecoration(
                      color: notifire.getbluecolor,
                      borderRadius: const BorderRadius.all(
                        Radius.circular(20),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        CustomStrings.cancel,
                        style: TextStyle(
                            color: Colors.white,
                            fontFamily: 'Gilroy Bold',
                            fontSize: height / 55),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  height: height / 100,
                ),
                GestureDetector(
                  onTap: () async {
                    final auth = Provider.of<AuthProvider>(context, listen: false);
                    await auth.logout();
                    if (mounted) {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => const Login()),
                        (route) => false,
                      );
                    }
                  },
                  child: Container(
                    height: height / 18,
                    width: width / 2.5,
                    decoration: const BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.all(
                        Radius.circular(20),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        CustomStrings.logout,
                        style: TextStyle(
                            color: const Color(0xffEB5757),
                            fontFamily: 'Gilroy Bold',
                            fontSize: height / 55),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget faceid(image, title) {
    return Row(
      children: [
        SizedBox(width: width / 20),
        Image.asset(
          image,
          height: height / 34,
          color: notifire.getdarkscolor,
        ),
        SizedBox(width: width / 30),
        Text(
          title,
          style: TextStyle(
            color: notifire.getdarkscolor,
            fontSize: height / 50,
            fontFamily: 'Gilroy Bold',
          ),
        ),
        const Spacer(),
        Transform.scale(
          scale: 0.7,
          child: CupertinoSwitch(
            trackColor: notifire.getdarkgreycolor,
            thumbColor: Colors.white,
            activeColor: notifire.getbluecolor,
            value: _switchValue,
            onChanged: (value) {
              setState(
                () {
                  _switchValue = value;
                },
              );
            },
          ),
        ),
        SizedBox(width: width / 20)
      ],
    );
  }

  Widget darkmode(image, title) {
    return Row(
      children: [
        SizedBox(width: width / 20),
        Image.asset(
          image,
          height: height / 34,
          color: notifire.getdarkscolor,
        ),
        SizedBox(width: width / 30),
        Text(
          title,
          style: TextStyle(
            color: notifire.getdarkscolor,
            fontSize: height / 50,
            fontFamily: 'Gilroy Bold',
          ),
        ),
        const Spacer(),
        Transform.scale(
          scale: 0.7,
          child: CupertinoSwitch(
            trackColor: notifire.getdarkgreycolor,
            thumbColor: Colors.white,
            activeColor: notifire.getbluecolor,
            value: notifire.getIsDark,
            onChanged: (val) async {
              final prefs = await SharedPreferences.getInstance();
              setState(
                () {
                  notifire.setIsDark = val;
                  prefs.setBool("setIsDark", val);
                },
              );
            },
          ),
        ),
        SizedBox(width: width / 20)
      ],
    );
  }

  Widget _pinRequiredToggle(AuthProvider auth) {
    final hasPin = auth.hasPin;
    final pinRequired = auth.pinRequired;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: width / 20),
      child: Container(
        color: Colors.transparent,
        child: Row(
          children: [
            Icon(Icons.lock_outline, size: height / 34, color: notifire.getdarkscolor),
            SizedBox(width: width / 25),
            Expanded(
              child: Text(
                'PIN untuk Transaksi',
                style: TextStyle(
                  fontSize: height / 50,
                  color: notifire.getdarkscolor,
                  fontFamily: 'Gilroy Medium',
                ),
              ),
            ),
            CupertinoSwitch(
              value: hasPin && pinRequired,
              activeTrackColor: notifire.getbluecolor,
              onChanged: !hasPin ? null : (val) => _onTogglePin(auth, val),
            ),
          ],
        ),
      ),
    );
  }

  void _onTogglePin(AuthProvider auth, bool newVal) {
    final pinController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: notifire.getprimerycolor,
          title: Text(
            newVal ? 'Aktifkan PIN Transaksi' : 'Nonaktifkan PIN Transaksi',
            style: TextStyle(fontFamily: 'Gilroy Bold', color: notifire.getdarkscolor, fontSize: 16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Masukkan PIN kamu untuk konfirmasi',
                style: TextStyle(fontFamily: 'Gilroy Medium', color: notifire.getdarkgreycolor, fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: pinController,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 4,
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Gilroy Bold', fontSize: 24, letterSpacing: 8, color: notifire.getdarkscolor),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '    ',
                  filled: true,
                  fillColor: notifire.getdarkwhitecolor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.withOpacity(0.2))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.withOpacity(0.2))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1565C0), width: 1.5)),
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Batal', style: TextStyle(fontFamily: 'Gilroy Medium', color: notifire.getdarkgreycolor)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (pinController.text.length != 4) return;
                Navigator.pop(ctx);
                final result = await auth.togglePinRequired(pinController.text, newVal);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(result['message'] ?? 'Gagal'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Konfirmasi', style: TextStyle(fontFamily: 'Gilroy Bold', color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Widget settingtype(image, title) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: width / 20),
      child: Container(
        color: Colors.transparent,
        child: Row(
          children: [
            Image.asset(
              image,
              height: height / 34,
              color: notifire.getdarkscolor,
            ),
            SizedBox(width: width / 30),
            Text(
              title,
              style: TextStyle(
                color: notifire.getdarkscolor,
                fontSize: height / 50,
                fontFamily: 'Gilroy Bold',
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _kycSettingItem(AuthProvider auth) {
    final status = auth.kycStatus;
    Color statusColor;
    String statusText;
    switch (status) {
      case 'pending':
        statusColor = const Color(0xFFFF9800);
        statusText = 'Menunggu';
        break;
      case 'approved':
        statusColor = const Color(0xFF4CAF50);
        statusText = 'Terverifikasi';
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusText = 'Ditolak';
        break;
      default:
        statusColor = Colors.grey;
        statusText = 'Belum';
    }
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: width / 20),
      child: Container(
        color: Colors.transparent,
        child: Row(
          children: [
            Icon(Icons.verified_user_outlined, color: notifire.getdarkscolor, size: height / 34),
            SizedBox(width: width / 30),
            Text(
              'Verifikasi KYC',
              style: TextStyle(
                color: notifire.getdarkscolor,
                fontSize: height / 50,
                fontFamily: 'Gilroy Bold',
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                statusText,
                style: TextStyle(
                  color: statusColor,
                  fontSize: height / 62,
                  fontFamily: 'Gilroy Bold',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget logout(image, title) {
    return Row(
      children: [
        SizedBox(width: width / 20),
        Image.asset(image, height: height / 27),
        SizedBox(width: width / 30),
        Text(
          title,
          style: TextStyle(
            color: const Color(0xffF75555),
            fontSize: height / 50,
            fontFamily: 'Gilroy Bold',
          ),
        ),
      ],
    );
  }
}
