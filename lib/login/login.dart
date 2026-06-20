import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:modipay/login/forgot_pin_screen.dart';
import 'package:modipay/login/login_otp_screen.dart';
import 'package:modipay/services/api_service.dart';
import 'package:modipay/utils/color.dart';
import 'package:modipay/utils/responsive.dart';
import 'package:google_fonts/google_fonts.dart';

import 'desktop_auth_panel.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final _phoneController = TextEditingController();
  bool _isPhoneValid = false;
  bool _isCheckingPhone = false;
  bool _phoneNotFound = false;
  String? _phoneCheckError;

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(_onPhoneChanged);
  }

  void _onPhoneChanged() {
    final text = _phoneController.text;

    // Keep input consistent with +62 prefix by stripping leading 0.
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

    if (_phoneNotFound) {
      setState(() => _phoneNotFound = false);
    }

    if (_phoneCheckError != null) {
      setState(() => _phoneCheckError = null);
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
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

  bool _isNotFoundMessage(dynamic message) {
    final text = (message ?? '').toString().toLowerCase();
    return text.contains('tidak ditemukan') ||
        text.contains('not found') ||
        text.contains('tidak terdaftar');
  }

  bool _isRegisteredPhoneMessage(String message) {
    final text = message.toLowerCase();
    if (_isNotFoundMessage(text)) {
      return false;
    }

    return text.contains('kata sandi salah') ||
        text.contains('password salah') ||
        text.contains('akun ini tidak memiliki kata sandi') ||
        text.contains('invalid credentials') ||
        text.contains('login successful');
  }

  Future<({String? phone, String? errorMessage})> _findRegisteredPhone(
    String rawPhone,
  ) async {
    final candidates = _phoneCandidates(rawPhone);
    String? lastErrorMessage;

    for (final candidate in candidates) {
      try {
        final response = await ApiService.login(candidate, '__dummy_password__');
        if (response.containsKey('token')) {
          return (phone: candidate, errorMessage: null);
        }

        final message = (response['message'] ?? '').toString();
        if (_isNotFoundMessage(message)) {
          continue;
        }

        if (_isRegisteredPhoneMessage(message)) {
          return (phone: candidate, errorMessage: null);
        }

        if (message.isNotEmpty) {
          lastErrorMessage = message;
        }
      } catch (e) {
        final message = ApiService.userFriendlyMessage(
          e,
          fallback: 'Gagal memeriksa nomor HP',
        );

        if (_isNotFoundMessage(message)) {
          continue;
        }

        if (_isRegisteredPhoneMessage(message)) {
          return (phone: candidate, errorMessage: null);
        }

        lastErrorMessage = message;
      }
    }

    return (phone: null, errorMessage: lastErrorMessage);
  }

  Future<void> _goToPinLogin() async {
    final rawPhone = _phoneController.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (rawPhone.isEmpty) {
      Fluttertoast.showToast(msg: 'Masukkan nomor HP');
      return;
    }

    setState(() {
      _isCheckingPhone = true;
      _phoneNotFound = false;
      _phoneCheckError = null;
    });

    try {
      final result = await _findRegisteredPhone(rawPhone);
      if (!mounted) return;

      if (result.phone == null) {
        setState(() {
          _isCheckingPhone = false;
          _phoneNotFound = result.errorMessage == null;
          _phoneCheckError = result.errorMessage;
        });

        if (result.errorMessage != null) {
          Fluttertoast.showToast(msg: result.errorMessage!);
        }
        return;
      }

      setState(() => _isCheckingPhone = false);

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LoginOtpScreen(phone: result.phone!),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCheckingPhone = false);
      Fluttertoast.showToast(msg: 'Gagal memeriksa nomor HP');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEnabled = _isPhoneValid && !_isCheckingPhone;
    if (isDesktop(context)) {
      return DesktopAuthShell(child: _buildDesktopForm(isEnabled));
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
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Bantuan'),
                      content: const Text(
                        'Jika nomor HP kamu bermasalah, hubungi layanan pelanggan kami di support@Modipay.id',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Tutup'),
                        ),
                      ],
                    ),
                  );
                },
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: primaryBlue50,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.help_outline,
                    color: primaryBlue500,
                    size: 20,
                  ),
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
              padding: EdgeInsets.symmetric(
                horizontal: screenWidth * 0.08,
                vertical: screenHeight * 0.04,
              ),
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
                    'Masukkan nomor HP, lalu lanjutkan login dengan PIN kamu.',
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
                          Text(
                            '🇮🇩 +62',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: grey700,
                            ),
                          ),
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
                                  color: _phoneNotFound ? error500 : grey300,
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
                          color: _phoneNotFound ? error500 : (_isPhoneValid ? primaryBlue500 : grey200),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: screenHeight * 0.04),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ForgotPinScreen(),
                        ),
                      );
                    },
                    child: Text(
                      'Lupa PIN?',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: primaryBlue500,
                      ),
                    ),
                  ),
                    if (_phoneNotFound)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Nomor HP tidak terdaftar',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: error500,
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
                    gradient: const LinearGradient(
                      colors: [primaryBlue500, primaryBlue600],
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
                      onTap: isEnabled ? _goToPinLogin : null,
                      borderRadius: BorderRadius.circular(14),
                      child: Center(
                        child: Text(
                          _isCheckingPhone ? 'Memeriksa...' : 'Lanjutkan',
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Desktop layout (split-panel, gaya login.jpeg) ─────────────────────────

  Widget _buildDesktopForm(bool isEnabled) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text.rich(
          const TextSpan(text: 'Selamat Datang Kembali \u{1F44B}'),
          style: GoogleFonts.hankenGrotesk(fontSize: 28, fontWeight: FontWeight.w700, color: desktopTextPrimary, letterSpacing: -0.3),
        ),
        const SizedBox(height: 8),
        Text(
          'Masukkan nomor HP, lalu lanjutkan login dengan PIN kamu.',
          style: GoogleFonts.hankenGrotesk(fontSize: 14, color: desktopTextSecondary),
        ),
        const SizedBox(height: 32),
        Text('Nomor HP', style: GoogleFonts.hankenGrotesk(fontSize: 14, fontWeight: FontWeight.w700, color: desktopTextPrimary)),
        const SizedBox(height: 8),
        desktopBorderedField(
          icon: Icons.person_outline,
          controller: _phoneController,
          hint: 'Masukkan nomor HP',
          keyboardType: TextInputType.phone,
        ),
        if (_phoneNotFound) ...[
          const SizedBox(height: 8),
          Text(
            'Nomor HP tidak terdaftar',
            style: GoogleFonts.hankenGrotesk(fontSize: 12, fontWeight: FontWeight.w600, color: desktopErrorRed),
          ),
        ],
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerRight,
          child: GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPinScreen())),
            child: Text(
              'Lupa PIN?',
              style: GoogleFonts.hankenGrotesk(fontSize: 13, fontWeight: FontWeight.w700, color: desktopAccentBlue),
            ),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: isEnabled ? _goToPinLogin : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: desktopPrimaryBtn,
              disabledBackgroundColor: desktopPrimaryBtn.withOpacity(0.4),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isCheckingPhone
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                  )
                : Text('Lanjutkan', style: GoogleFonts.hankenGrotesk(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
          ),
        ),
      ],
    );
  }
}
