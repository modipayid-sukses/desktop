import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:modipay/login/forgot_password_screen.dart';
import 'package:modipay/login/login_router.dart';
import 'package:modipay/design/design.dart';
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
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: cardBg,
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                width: 62,
                                height: 62,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFEFF3FA),
                                  shape: BoxShape.circle,
                                ),
                                child: ClipOval(
                                  child: auth.userAvatar != null && auth.userAvatar!.isNotEmpty
                                      ? CachedNetworkImage(
                                          imageUrl: ApiService.avatarUrl(auth.userAvatar),
                                          cacheKey: auth.userAvatar,
                                          fit: BoxFit.cover,
                                          fadeInDuration: Duration.zero,
                                          errorWidget: (_, __, ___) =>
                                              Image.asset('images/man4.png', fit: BoxFit.cover),
                                        )
                                      : Image.asset('images/man4.png', fit: BoxFit.cover),
                                ),
                              ),
                              Positioned(
                                right: -2,
                                bottom: -2,
                                child: InkWell(
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const EditProfile()),
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  child: Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF20467A),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2),
                                    ),
                                    child: const Icon(Icons.edit, color: Colors.white, size: 12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Halo, $firstName',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFF18202A),
                                    fontFamily: 'Gilroy Bold',
                                    fontSize: 20,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  auth.userEmail,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFF728095),
                                    fontFamily: 'Gilroy Medium',
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          _kycBadge(auth),
                          const SizedBox(width: 8),
                          _circleIconButton(
                            icon: Icons.notifications_none_rounded,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const Notifications()),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _circleIconButton(
                            icon: Icons.language_outlined,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const Language()),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F6FB),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(_levelIcon(levelName), color: _levelColor(levelName), size: 18),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Member Level',
                                    style: TextStyle(
                                      color: Color(0xFF8A93A3),
                                      fontFamily: 'Gilroy Medium',
                                      fontSize: 11,
                                    ),
                                  ),
                                  Text(
                                    'Member $levelName',
                                    style: const TextStyle(
                                      color: Color(0xFF18202A),
                                      fontFamily: 'Gilroy Bold',
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const LevelDetailScreen()),
                              ),
                              style: TextButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFF20467A),
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
                    ),
                    const SizedBox(height: 12),
                    if (auth.referralCode != null && auth.referralCode!.isNotEmpty)
                      _referralCodeStrip(auth.referralCode!)
                    else
                      const SizedBox(height: 8),
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
                    icon: Icons.lock_reset_outlined,
                    title: 'Reset Password',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ForgotPasswordScreen(initialEmail: auth.userEmail),
                      ),
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
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
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
                    const SizedBox(height: 4),
                    _securityToggleRow(
                      icon: Icons.fingerprint,
                      title: 'Login Biometrik',
                      subtitle: _biometricAvailable
                          ? 'Gunakan Face ID / sidik jari untuk login lebih cepat.'
                          : 'Biometrik tidak tersedia di perangkat ini.',
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
                    ),
                    const Divider(height: 18),
                    _pinRequiredToggle(auth),
                    const SizedBox(height: 4),
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

  Widget _referralCodeStrip(String referralCode) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        color: Color(0xFFEAF0FB),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: RichText(
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                style: const TextStyle(
                  color: Color(0xFF18202A),
                  fontFamily: 'Gilroy Medium',
                  fontSize: 13,
                ),
                children: [
                  const TextSpan(text: 'Kode Referral Saya: '),
                  TextSpan(
                    text: referralCode,
                    style: const TextStyle(fontFamily: 'Gilroy Bold'),
                  ),
                ],
              ),
            ),
          ),
          InkWell(
            onTap: () async {
              await Clipboard.setData(ClipboardData(text: referralCode));
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Kode referral disalin')),
              );
            },
            borderRadius: BorderRadius.circular(8),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.copy_outlined, color: Color(0xFF20467A), size: 16),
                  SizedBox(width: 4),
                  Text(
                    'Salin Kode',
                    style: TextStyle(
                      color: Color(0xFF20467A),
                      fontFamily: 'Gilroy Bold',
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kycBadge(AuthProvider auth) {
    final isApproved = auth.kycStatus.toLowerCase() == 'approved';
    final accent = isApproved ? const Color(0xFF2E7D32) : const Color(0xFFC0392B);
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const KycScreen()),
      ),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: accent.withOpacity(0.1),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          isApproved ? 'KYC Terverifikasi' : 'KYC Belum Lengkap',
          style: TextStyle(
            color: accent,
            fontFamily: 'Gilroy Bold',
            fontSize: 11,
          ),
        ),
      ),
    );
  }

  Widget _circleIconButton({required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 36,
        height: 36,
        decoration: const BoxDecoration(
          color: Color(0xFFEFF3FA),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: const Color(0xFF20467A), size: 18),
      ),
    );
  }

  Widget _sectionCard({required String title, required List<Widget> children}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
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
    final confirmed = await AppDialog.confirm(
      context: context,
      title: 'Keluar',
      description: 'Apakah Anda yakin ingin keluar?',
      confirmText: CustomStrings.logout,
      cancelText: CustomStrings.cancel,
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    await auth.logout();
    if (!mounted) return;
    final loginScreen = await resolveLoginScreen();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => loginScreen),
      (route) => false,
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
    return _securityToggleRow(
      icon: Icons.lock_outline,
      title: 'PIN untuk Transaksi',
      value: hasPin && pinRequired,
      onChanged: !hasPin ? null : (val) => _onTogglePin(auth, val),
    );
  }

  Widget _securityToggleRow({
    required IconData icon,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFFEFF3FA),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: const Color(0xFF20467A), size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Gilroy Medium',
                  color: Color(0xFF202A36),
                  fontSize: 14,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontFamily: 'Gilroy Medium',
                    color: Color(0xFF728095),
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        Switch.adaptive(
          value: value,
          onChanged: onChanged,
          activeColor: notifire.getbluecolor,
        ),
      ],
    );
  }

  Future<void> _onTogglePin(AuthProvider auth, bool newVal) async {
    final pinController = TextEditingController();
    final confirmed = await AppDialog.show(
      context: context,
      title: newVal ? 'Aktifkan PIN Transaksi' : 'Nonaktifkan PIN Transaksi',
      description: 'Masukkan PIN kamu untuk konfirmasi',
      body: TextField(
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
      secondaryActionText: 'Batal',
      primaryActionText: 'Konfirmasi',
    );

    if (confirmed != true || pinController.text.length != 4) return;
    final result = await auth.togglePinRequired(pinController.text, newVal);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Gagal'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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
