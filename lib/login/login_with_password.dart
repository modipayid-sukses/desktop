import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:modipay/bottombar/bottombar.dart';
import 'package:modipay/login/forgot_password_screen.dart';
import 'package:modipay/login/register.dart';
import 'package:modipay/login/setup_pin_screen.dart';
import 'package:modipay/providers/auth_provider.dart';
import 'package:modipay/services/api_service.dart';
import 'package:modipay/utils/color.dart';
import 'package:modipay/utils/responsive.dart';
import 'package:modipay/design/design.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'desktop_auth_panel.dart';

class LoginWithPassword extends StatefulWidget {
  const LoginWithPassword({super.key});

  @override
  State<LoginWithPassword> createState() => _LoginWithPasswordState();
}

class _LoginWithPasswordState extends State<LoginWithPassword> {
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _isLoading = false;
  bool _isPhoneValid = false;
  bool _isPasswordValid = false;
  bool _obscurePassword = true;
  bool _rememberMe = true;

  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(_onPhoneChanged);
    _passwordController.addListener(_onPasswordChanged);
  }

  void _onPhoneChanged() {
    final text = _phoneController.text;
    
    if (!isDesktop(context)) {
      // Auto-delete leading 0
      if (text.startsWith('0') && text.length > 1) {
        _phoneController.text = text.substring(1);
        _phoneController.selection = TextSelection.fromPosition(
          TextPosition(offset: _phoneController.text.length),
        );
      }
      
      final digits = _phoneController.text.replaceAll(RegExp(r'[^0-9]'), '');
      final valid = digits.length >= 7;
      if (valid != _isPhoneValid) {
        setState(() => _isPhoneValid = valid);
      }
    } else {
      final valid = text.trim().length >= 3;
      if (valid != _isPhoneValid) {
        setState(() => _isPhoneValid = valid);
      }
    }
  }

  void _onPasswordChanged() {
    final valid = _passwordController.text.length >= 6;
    if (valid != _isPasswordValid) {
      setState(() => _isPasswordValid = valid);
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loginWithPassword() async {
    final input = _phoneController.text.trim();
    final password = _passwordController.text.trim();

    if (input.isEmpty) {
      Fluttertoast.showToast(msg: isDesktop(context) ? 'Masukkan username atau email' : 'Masukkan nomor HP');
      return;
    }
    if (password.isEmpty) {
      Fluttertoast.showToast(msg: 'Masukkan password');
      return;
    }

    final isPhone = RegExp(r'^\+?[0-9]+$').hasMatch(input);

    setState(() => _isLoading = true);
    try {
      Map<String, dynamic> result = {};
      if (isPhone) {
        final rawPhone = input.replaceAll(RegExp(r'[^0-9]'), '');
        final phoneCandidates = _phoneCandidates(rawPhone);
        for (final candidate in phoneCandidates) {
          result = await ApiService.login(candidate, password);
          if (_isLoginSuccess(result)) {
            break;
          }
        }
      } else {
        result = await ApiService.login(input, password);
      }

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (_isLoginSuccess(result)) {
        final auth = Provider.of<AuthProvider>(context, listen: false);
        final success = await auth.loginWithPasswordResult(result);
        if (!mounted) return;
        if (success) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) => auth.hasPin ? const Bottombar() : const SetupPinScreen(),
            ),
            (route) => false,
          );
        } else {
          Fluttertoast.showToast(msg: auth.error ?? 'Login gagal');
        }
      } else {
        Fluttertoast.showToast(msg: result['message'] ?? 'Username atau password salah');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      Fluttertoast.showToast(
        msg: ApiService.userFriendlyMessage(e, fallback: 'Gagal login'),
      );
    }
  }

  String _toInternationalPhone(String raw) {
    if (raw.startsWith('62')) return raw;
    if (raw.startsWith('0')) return '62${raw.substring(1)}';
    return '62$raw';
  }

  String _toLocalPhone(String raw) {
    if (raw.startsWith('0')) return raw;
    if (raw.startsWith('62')) return '0${raw.substring(2)}';
    return '0$raw';
  }

  String _toPlusInternationalPhone(String raw) {
    return '+${_toInternationalPhone(raw)}';
  }

  List<String> _phoneCandidates(String raw) {
    final candidates = <String>[
      raw,
      _toInternationalPhone(raw),
      _toLocalPhone(raw),
      _toPlusInternationalPhone(raw),
    ];
    return candidates.toSet().toList();
  }

  bool _isLoginSuccess(Map<String, dynamic> response) {
    return response.containsKey('token');
  }

  @override
  Widget build(BuildContext context) {
    final isEnabled = _isPhoneValid && _isPasswordValid && !_isLoading;
    if (isDesktop(context)) {
      return _buildDesktopLayout(context, isEnabled);
    }
    return _buildMobileLayout(context, isEnabled);
  }

  Widget _buildMobileLayout(BuildContext context, bool isEnabled) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(Icons.arrow_back, color: grey700, size: 28),
          splashRadius: 24,
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: GestureDetector(
                onTap: () {
                  AppDialog.show(
                    context: context,
                    title: 'Bantuan',
                    description: 'Jika ada pertanyaan, hubungi layanan pelanggan kami di support@Modipay.id',
                    primaryActionText: 'Tutup',
                  );
                },
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: primaryBlue50,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.help_outline, color: primaryBlue500, size: 20),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.08, vertical: screenHeight * 0.04),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: screenHeight * 0.02),
                  Text(
                    'Masuk ke Akun Kamu',
                    style: GoogleFonts.poppins(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: grey900,
                      height: 1.3,
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.015),
                  Text(
                    'Gunakan nomor HP dan password untuk masuk',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: grey500,
                      height: 1.4,
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.06),
                  Text(
                    'Nomor HP',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: grey700,
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.014),
                  Column(
                    children: [
                      Row(
                        children: [
                          Text('🇮🇩 +62', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: grey700)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: grey700,
                              ),
                              decoration: InputDecoration(
                                isDense: true,
                                hintText: '812345678',
                                hintStyle: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w400,
                                  color: grey300,
                                ),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(
                        width: double.infinity,
                        height: 2,
                        child: ColoredBox(
                          color: _isPhoneValid ? primaryBlue500 : grey200,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: screenHeight * 0.05),
                  Text(
                    'Password',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: grey700,
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.014),
                  Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: grey700,
                              ),
                              decoration: InputDecoration(
                                isDense: true,
                                hintText: '••••••••',
                                hintStyle: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w400,
                                  color: grey300,
                                ),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              setState(() => _obscurePassword = !_obscurePassword);
                            },
                            child: Icon(
                              _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              color: grey400,
                              size: 22,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(
                        width: double.infinity,
                        height: 2,
                        child: ColoredBox(
                          color: _isPasswordValid ? primaryBlue500 : grey200,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: screenHeight * 0.02),
                  Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ForgotPasswordScreen(),
                          ),
                        );
                      },
                      child: Text(
                        'Lupa Password?',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: primaryBlue500,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.02),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const Register()),
                      );
                    },
                    child: Text.rich(
                      textAlign: TextAlign.center,
                      TextSpan(
                        text: 'Belum punya akun? ',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: grey600,
                        ),
                        children: [
                          TextSpan(
                            text: 'Daftar',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: primaryBlue500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              screenWidth * 0.08,
              screenHeight * 0.02,
              screenWidth * 0.08,
              screenHeight * 0.04,
            ),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        primaryBlue500,
                        primaryBlue600,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: primaryBlue500.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: isEnabled ? _loginWithPassword : null,
                      borderRadius: BorderRadius.circular(14),
                      child: Center(
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Text(
                                'Masuk',
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
                if (!isEnabled && !_isLoading)
                  Padding(
                    padding: EdgeInsets.only(top: screenHeight * 0.02),
                    child: Text(
                      'Lengkapi semua field untuk melanjutkan',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: grey400,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Desktop layout (split-panel, gaya login.jpeg) ─────────────────────────

  Widget _buildDesktopLayout(BuildContext context, bool isEnabled) {
    return DesktopAuthShell(child: _buildDesktopForm(isEnabled));
  }

  Widget _buildDesktopForm(bool isEnabled) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text.rich(
          const TextSpan(text: 'Selamat Datang Kembali \u{1F44B}'),
          style: GoogleFonts.hankenGrotesk(fontSize: 32, fontWeight: FontWeight.w700, color: desktopTextPrimary, letterSpacing: -0.64),
        ),
        const SizedBox(height: 8),
        Text(
          'Masuk untuk melanjutkan ke dashboard Anda',
          style: GoogleFonts.hankenGrotesk(fontSize: 14, color: desktopTextSecondary),
        ),
        const SizedBox(height: 32),
        Text('Username / Email', style: GoogleFonts.hankenGrotesk(fontSize: 14, fontWeight: FontWeight.w700, color: desktopTextPrimary)),
        const SizedBox(height: 8),
        desktopBorderedField(
          icon: Icons.mail_outline,
          controller: _phoneController,
          hint: 'Masukkan username atau email',
          keyboardType: TextInputType.emailAddress,
          focusNode: _emailFocusNode,
          textInputAction: TextInputAction.next,
          onSubmitted: (_) => _passwordFocusNode.requestFocus(),
        ),
        const SizedBox(height: 20),
        Text('Password', style: GoogleFonts.hankenGrotesk(fontSize: 14, fontWeight: FontWeight.w700, color: desktopTextPrimary)),
        const SizedBox(height: 8),
        desktopBorderedField(
          icon: Icons.lock_outline,
          controller: _passwordController,
          hint: 'Masukkan password',
          obscureText: _obscurePassword,
          focusNode: _passwordFocusNode,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _loginWithPassword(),
          suffix: GestureDetector(
            onTap: () => setState(() => _obscurePassword = !_obscurePassword),
            child: Icon(
              _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              color: desktopTextSecondary.withOpacity(0.6),
              size: 20,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              onTap: () => setState(() => _rememberMe = !_rememberMe),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: Checkbox(
                      value: _rememberMe,
                      onChanged: (v) => setState(() => _rememberMe = v ?? true),
                      activeColor: desktopPrimaryBtn,
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('Ingat saya', style: GoogleFonts.hankenGrotesk(fontSize: 13, color: desktopTextSecondary)),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
              ),
              child: Text(
                'Lupa password?',
                style: GoogleFonts.hankenGrotesk(fontSize: 13, fontWeight: FontWeight.w700, color: desktopAccentBlue),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: isEnabled ? _loginWithPassword : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: desktopPrimaryBtn,
              disabledBackgroundColor: desktopPrimaryBtn.withOpacity(0.4),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                  )
                : Text('Masuk', style: GoogleFonts.hankenGrotesk(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
          ),
        ),
        const SizedBox(height: 28),
        Center(
          child: GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const Register())),
            child: Text.rich(
              TextSpan(
                text: 'Belum punya akun? ',
                style: GoogleFonts.hankenGrotesk(fontSize: 14, color: desktopTextSecondary),
                children: [
                  TextSpan(
                    text: 'Daftar Sekarang',
                    style: GoogleFonts.hankenGrotesk(fontSize: 14, fontWeight: FontWeight.w700, color: desktopAccentBlue),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

}
