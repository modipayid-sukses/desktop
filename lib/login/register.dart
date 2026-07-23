import 'dart:async';

import 'package:flutter/material.dart';
import 'package:modipay/utils/toast.dart';
import 'package:modipay/bottombar/bottombar.dart';
import 'package:modipay/login/setup_pin_screen.dart';
import 'package:modipay/providers/auth_provider.dart';
import 'package:modipay/services/api_service.dart';
import 'package:modipay/services/app_exception.dart';
import 'package:modipay/utils/color.dart';
import 'package:modipay/utils/responsive.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:sms_autofill/sms_autofill.dart';

import 'desktop_auth_panel.dart';

class Register extends StatefulWidget {
  const Register({super.key});

  @override
  State<Register> createState() => _RegisterState();
}

class _RegisterState extends State<Register> {
  final _phoneController = TextEditingController();
  final _referralCodeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isPhoneValid = false;
  bool _isReferralValid = false;
  bool _isPasswordValid = false;
  bool _isConfirmPasswordValid = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  bool _phoneAlreadyRegistered = false;

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(_onPhoneChanged);
    _referralCodeController.addListener(_onReferralCodeChanged);
    _passwordController.addListener(_onPasswordChanged);
    _confirmPasswordController.addListener(_onConfirmPasswordChanged);
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _referralCodeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _onReferralCodeChanged() {
    final valid = _referralCodeController.text.trim().isNotEmpty;
    if (valid != _isReferralValid) {
      setState(() => _isReferralValid = valid);
    }
  }

  void _onPasswordChanged() {
    setState(() {
      _isPasswordValid = _passwordController.text.length >= 6;
      _isConfirmPasswordValid = _confirmPasswordController.text.isNotEmpty &&
          _confirmPasswordController.text == _passwordController.text;
    });
  }

  void _onConfirmPasswordChanged() {
    setState(() {
      _isConfirmPasswordValid = _confirmPasswordController.text.isNotEmpty &&
          _confirmPasswordController.text == _passwordController.text;
    });
  }

  void _onPhoneChanged() {
    final text = _phoneController.text;

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

    if (_phoneAlreadyRegistered) {
      setState(() => _phoneAlreadyRegistered = false);
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

  bool _isOtpSendSuccess(Map<String, dynamic> response) {
    if (response['success'] == true) return true;
    final msg = (response['message'] ?? '').toString().toLowerCase();
    return msg.contains('berhasil');
  }

  bool _isNotRegisteredMessage(String message) {
    final text = message.toLowerCase();
    return text.contains('tidak terdaftar') || text.contains('tidak ditemukan');
  }

  bool _isRateLimitMessage(String message) {
    final text = message.toLowerCase();
    return text.contains('tunggu') || text.contains('60 detik');
  }

  bool _isPhoneRegisteredFromMessage(String message) {
    final text = message.toLowerCase();
    if (_isNotRegisteredMessage(text)) {
      return false;
    }
    return text.contains('kata sandi salah') ||
        text.contains('akun ini tidak memiliki kata sandi') ||
        text.contains('login successful');
  }

  Future<String?> _findRegisteredPhone(String rawPhone) async {
    final candidates = _phoneCandidates(rawPhone);
    for (final candidate in candidates) {
      try {
        final response = await ApiService.login(candidate, '__dummy_password__');
        if (response.containsKey('token')) {
          return candidate;
        }
        final message = (response['message'] ?? '').toString();
        if (_isPhoneRegisteredFromMessage(message)) {
          return candidate;
        }
      } catch (e) {
        final message = ApiService.userFriendlyMessage(
          e,
          fallback: 'Gagal validasi nomor',
        );
        if (_isPhoneRegisteredFromMessage(message)) {
          return candidate;
        }
      }
    }
    return null;
  }

  String _generatedNameFromPhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length >= 4) {
      return 'User ${digits.substring(digits.length - 4)}';
    }
    return 'User Baru';
  }

  Future<void> _continueRegister() async {
    final rawPhone = _phoneController.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (rawPhone.isEmpty) {
      showToast(msg: 'Masukkan nomor HP');
      return;
    }
    if (_referralCodeController.text.trim().isEmpty) {
      showToast(msg: 'Masukkan kode referral master');
      return;
    }
    if (_passwordController.text.length < 6) {
      showToast(msg: 'Password minimal 6 karakter');
      return;
    }
    if (_confirmPasswordController.text != _passwordController.text) {
      showToast(msg: 'Konfirmasi password tidak sama');
      return;
    }

    setState(() {
      _isLoading = true;
      _phoneAlreadyRegistered = false;
    });

    final registeredPhone = await _findRegisteredPhone(rawPhone);
    if (!mounted) return;

    if (registeredPhone != null) {
      setState(() {
        _isLoading = false;
        _phoneAlreadyRegistered = true;
      });
      return;
    }

    final otpRequired = await ApiService.isOtpRequired();
    if (!mounted) return;

    if (!otpRequired) {
      await _registerAccount(_toInternationalPhone(rawPhone));
      return;
    }

    const channel = 'wa-generic';
    final candidates = _phoneCandidates(rawPhone);
    String? activePhone;
    String? lastErrorMessage;

    for (final candidate in candidates) {
      try {
        final result = await ApiService.sendOtp(
          candidate,
          channel: channel,
          type: 'register',
        );

        if (_isOtpSendSuccess(result)) {
          activePhone = candidate;
          break;
        }

        final msg = (result['message'] ?? '').toString();
        if (_isRateLimitMessage(msg)) {
          activePhone = candidate;
          showToast(msg: msg);
          break;
        }

        lastErrorMessage = msg;
      } catch (e) {
        final msg = ApiService.userFriendlyMessage(
          e,
          fallback: 'Gagal mengirim OTP',
        );
        lastErrorMessage = msg;

        if (_isRateLimitMessage(msg)) {
          activePhone = candidate;
          showToast(msg: msg);
          break;
        }
      }
    }

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (activePhone == null) {
      final message = lastErrorMessage ?? 'Gagal mengirim OTP';
      showToast(msg: message);
      return;
    }

    final verified = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _RegisterOtpScreen(phone: activePhone!, channel: channel),
      ),
    );

    if (verified == true && mounted) {
      await _registerAccount(activePhone);
    }
  }

  Future<void> _registerAccount(String phone) async {
    setState(() => _isLoading = true);
    try {
      final registerResult = await ApiService.register(
        name: _generatedNameFromPhone(phone),
        phone: phone,
        password: _passwordController.text,
        passwordConfirmation: _confirmPasswordController.text,
        referralCode: _referralCodeController.text.trim(),
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      final pendingToken = registerResult['pending_token']?.toString();
      if (pendingToken != null && pendingToken.isNotEmpty) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => _RegisterVerificationScreen(pendingToken: pendingToken),
          ),
          (route) => false,
        );
      } else if (registerResult.containsKey('token')) {
        final auth = Provider.of<AuthProvider>(context, listen: false);
        final success = await auth.loginWithPasswordResult(registerResult);
        if (!mounted) return;

        if (success) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const SetupPinScreen()),
            (route) => false,
          );
        } else {
          showToast(msg: auth.error ?? 'Gagal menyiapkan akun');
        }
      } else {
        showToast(
          msg: registerResult['message'] ?? 'Gagal mendaftarkan akun',
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      showToast(
        msg: ApiService.userFriendlyMessage(e, fallback: 'Gagal mendaftarkan akun'),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEnabled = _isPhoneValid &&
        _isReferralValid &&
        _isPasswordValid &&
        _isConfirmPasswordValid &&
        !_isLoading;
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
                    'Daftar dengan Nomor HP',
                    style: GoogleFonts.poppins(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: grey900,
                      height: 1.3,
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.015),
                  Text(
                    'Masukkan nomor HP yang akan digunakan untuk akun kamu.',
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
                                  color: _phoneAlreadyRegistered ? error500 : grey300,
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
                          color: _phoneAlreadyRegistered
                              ? error500
                              : (_isPhoneValid ? primaryBlue500 : grey200),
                        ),
                      ),
                    ],
                  ),
                  if (_phoneAlreadyRegistered)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Nomor HP sudah terdaftar',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: error500,
                        ),
                      ),
                    ),
                  SizedBox(height: screenHeight * 0.03),
                  Text(
                    'Kode Referral',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: grey700,
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.014),
                  Column(
                    children: [
                      TextField(
                        controller: _referralCodeController,
                        textCapitalization: TextCapitalization.characters,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: grey700,
                        ),
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: 'Masukkan kode referral master',
                          hintStyle: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: grey300,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                      SizedBox(
                        width: double.infinity,
                        height: 2,
                        child: ColoredBox(
                          color: _isReferralValid ? primaryBlue500 : grey200,
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Wajib diisi dengan kode referral dari agen master Anda.',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: grey500,
                      ),
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.03),
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
                                hintText: 'Minimal 6 karakter',
                                hintStyle: GoogleFonts.poppins(
                                  fontSize: 14,
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
                  SizedBox(height: screenHeight * 0.03),
                  Text(
                    'Konfirmasi Password',
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
                              controller: _confirmPasswordController,
                              obscureText: _obscureConfirmPassword,
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: grey700,
                              ),
                              decoration: InputDecoration(
                                isDense: true,
                                hintText: 'Ulangi password',
                                hintStyle: GoogleFonts.poppins(
                                  fontSize: 14,
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
                              setState(() => _obscureConfirmPassword = !_obscureConfirmPassword);
                            },
                            child: Icon(
                              _obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
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
                          color: _isConfirmPasswordValid ? primaryBlue500 : grey200,
                        ),
                      ),
                    ],
                  ),
                  if (_confirmPasswordController.text.isNotEmpty && !_isConfirmPasswordValid)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Konfirmasi password tidak sama',
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
            child: Container(
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
                  onTap: isEnabled ? _continueRegister : null,
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
                            'Lanjutkan',
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
          ),
        ],
      ),
    );
  }

  // ── Desktop layout (split-panel, gaya registration mockup) ────────────────

  Widget _buildDesktopForm(bool isEnabled) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Daftar Akun Baru',
          style: GoogleFonts.hankenGrotesk(fontSize: 28, fontWeight: FontWeight.w700, color: desktopTextPrimary, letterSpacing: -0.3),
        ),
        const SizedBox(height: 8),
        Text(
          'Masukkan nomor HP yang akan digunakan untuk akun kamu.',
          style: GoogleFonts.hankenGrotesk(fontSize: 14, color: desktopTextSecondary),
        ),
        const SizedBox(height: 28),
        Text('Nomor HP', style: GoogleFonts.hankenGrotesk(fontSize: 14, fontWeight: FontWeight.w700, color: desktopTextPrimary)),
        const SizedBox(height: 8),
        desktopBorderedField(
          icon: Icons.phone_outlined,
          controller: _phoneController,
          hint: 'Masukkan nomor HP',
          keyboardType: TextInputType.phone,
        ),
        if (_phoneAlreadyRegistered) ...[
          const SizedBox(height: 8),
          Text('Nomor HP sudah terdaftar', style: GoogleFonts.hankenGrotesk(fontSize: 12, fontWeight: FontWeight.w600, color: desktopErrorRed)),
        ],
        const SizedBox(height: 18),
        Text('Kode Referral', style: GoogleFonts.hankenGrotesk(fontSize: 14, fontWeight: FontWeight.w700, color: desktopTextPrimary)),
        const SizedBox(height: 8),
        desktopBorderedField(
          icon: Icons.card_giftcard_outlined,
          controller: _referralCodeController,
          hint: 'Masukkan kode referral master',
        ),
        const SizedBox(height: 6),
        Text('Wajib diisi dengan kode referral dari agen master Anda.',
            style: GoogleFonts.hankenGrotesk(fontSize: 12, color: desktopTextSecondary)),
        const SizedBox(height: 18),
        Text('Password', style: GoogleFonts.hankenGrotesk(fontSize: 14, fontWeight: FontWeight.w700, color: desktopTextPrimary)),
        const SizedBox(height: 8),
        desktopBorderedField(
          icon: Icons.lock_outline,
          controller: _passwordController,
          hint: 'Minimal 6 karakter',
          obscureText: _obscurePassword,
          suffix: GestureDetector(
            onTap: () => setState(() => _obscurePassword = !_obscurePassword),
            child: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: desktopTextSecondary.withOpacity(0.6), size: 20),
          ),
        ),
        const SizedBox(height: 18),
        Text('Konfirmasi Password', style: GoogleFonts.hankenGrotesk(fontSize: 14, fontWeight: FontWeight.w700, color: desktopTextPrimary)),
        const SizedBox(height: 8),
        desktopBorderedField(
          icon: Icons.lock_outline,
          controller: _confirmPasswordController,
          hint: 'Ulangi password',
          obscureText: _obscureConfirmPassword,
          suffix: GestureDetector(
            onTap: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
            child: Icon(_obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: desktopTextSecondary.withOpacity(0.6), size: 20),
          ),
        ),
        if (_confirmPasswordController.text.isNotEmpty && !_isConfirmPasswordValid) ...[
          const SizedBox(height: 8),
          Text('Konfirmasi password tidak sama', style: GoogleFonts.hankenGrotesk(fontSize: 12, fontWeight: FontWeight.w600, color: desktopErrorRed)),
        ],
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: isEnabled ? _continueRegister : null,
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
                : Text('Daftar Sekarang', style: GoogleFonts.hankenGrotesk(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: GestureDetector(
            onTap: () => Navigator.maybePop(context),
            child: Text.rich(
              TextSpan(
                text: 'Sudah punya akun? ',
                style: GoogleFonts.hankenGrotesk(fontSize: 14, color: desktopTextSecondary),
                children: [
                  TextSpan(
                    text: 'Masuk Sekarang',
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

class _RegisterOtpScreen extends StatefulWidget {
  const _RegisterOtpScreen({required this.phone, required this.channel});

  final String phone;
  final String channel;

  @override
  State<_RegisterOtpScreen> createState() => _RegisterOtpScreenState();
}

class _RegisterOtpScreenState extends State<_RegisterOtpScreen> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  final SmsAutoFill _smsAutoFill = SmsAutoFill();

  bool _isLoading = false;
  bool _isResending = false;
  bool _hasError = false;
  bool _isAutoFilling = false;
  int _countdown = 60;
  Timer? _timer;
  StreamSubscription<String>? _codeSubscription;

  String get _otpValue => _controllers.map((c) => c.text).join();

  @override
  void initState() {
    super.initState();
    _startCountdown();
    _codeSubscription = _smsAutoFill.code.listen((code) {
      if (!mounted || _isLoading) return;
      final digits = code.replaceAll(RegExp(r'[^0-9]'), '');
      if (digits.length < 4) return;

      final limited = digits.length > 6 ? digits.substring(0, 6) : digits;
      setState(() {
        _isAutoFilling = true;
        _hasError = false;
      });

      for (var i = 0; i < _controllers.length; i++) {
        _controllers[i].text = i < limited.length ? limited[i] : '';
      }

      if (_otpValue.length == 6) {
        _verifyOtp();
      }
    });
    _smsAutoFill.listenForCode();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _codeSubscription?.cancel();
    _smsAutoFill.unregisterListener();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _countdown = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_countdown <= 1) {
        timer.cancel();
        setState(() => _countdown = 0);
      } else {
        setState(() => _countdown--);
      }
    });
  }

  void _onOtpChanged(int index, String value) {
    if (_isAutoFilling) {
      _isAutoFilling = false;
    }
    if (value.length == 1 && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }

    if (_otpValue.length == 6 && !_isLoading) {
      _verifyOtp();
    }
  }

  Future<void> _verifyOtp() async {
    if (_otpValue.length != 6) {
      showToast(msg: 'Masukkan 6 digit kode OTP');
      return;
    }

    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final result = await ApiService.verifyOtp(
        widget.phone,
        _otpValue,
        type: 'register',
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (result['verified'] == true) {
        Navigator.pop(context, true);
      } else {
        setState(() => _hasError = true);
        showToast(msg: result['message'] ?? 'Kode OTP salah');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
      showToast(
        msg: ApiService.userFriendlyMessage(e, fallback: 'Gagal memverifikasi OTP'),
      );
    }
  }

  Future<void> _resendOtp() async {
    if (_countdown > 0) return;

    setState(() => _isResending = true);
    try {
      final result = await ApiService.sendOtp(
        widget.phone,
        channel: widget.channel,
        type: 'register',
      );
      if (!mounted) return;
      setState(() => _isResending = false);

      final msg = (result['message'] ?? '').toString().toLowerCase();
      if (msg.contains('berhasil')) {
        for (final c in _controllers) {
          c.clear();
        }
        setState(() => _hasError = false);
        _startCountdown();
        showToast(msg: 'OTP berhasil dikirim ulang');
      } else {
        showToast(msg: result['message'] ?? 'Gagal mengirim OTP');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isResending = false);
      showToast(
        msg: ApiService.userFriendlyMessage(e, fallback: 'Gagal mengirim ulang OTP'),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Verifikasi OTP',
              style: GoogleFonts.poppins(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: grey900,
              ),
            ),
            SizedBox(height: screenHeight * 0.012),
            Text(
              'Masukkan 6 digit OTP yang dikirim ke ${widget.phone}',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: grey500,
                height: 1.4,
              ),
            ),
            SizedBox(height: screenHeight * 0.05),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(6, (index) {
                return SizedBox(
                  width: 46,
                  child: TextField(
                    controller: _controllers[index],
                    focusNode: _focusNodes[index],
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 1,
                    onChanged: (value) => _onOtpChanged(index, value),
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: grey900,
                    ),
                    decoration: InputDecoration(
                      counterText: '',
                      filled: true,
                      fillColor: _hasError ? error50 : Colors.white,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: _hasError ? error500 : grey200,
                          width: 1.4,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: primaryBlue500,
                          width: 1.8,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
            SizedBox(height: screenHeight * 0.03),
            Center(
              child: TextButton(
                onPressed: _countdown == 0 && !_isResending ? _resendOtp : null,
                child: _isResending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        _countdown > 0
                            ? 'Kirim ulang dalam ${_countdown}s'
                            : 'Kirim ulang OTP',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          color: _countdown > 0 ? grey400 : primaryBlue500,
                        ),
                      ),
              ),
            ),
            const Spacer(),
            if (_isLoading)
              Padding(
                padding: EdgeInsets.only(bottom: screenHeight * 0.02),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Memverifikasi OTP...',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: grey500,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Menunggu verifikasi akun pasca `/register`: polling status setiap
/// beberapa detik, lalu beralih ke input OTP bila link sudah diklik tapi
/// OTP belum dikirim, dan mengarahkan ke halaman login setelah tuntas.
class _RegisterVerificationScreen extends StatefulWidget {
  const _RegisterVerificationScreen({required this.pendingToken});

  final String pendingToken;

  @override
  State<_RegisterVerificationScreen> createState() =>
      _RegisterVerificationScreenState();
}

class _RegisterVerificationScreenState
    extends State<_RegisterVerificationScreen> {
  final _otpController = TextEditingController();
  Timer? _pollTimer;
  bool _otpRequired = false;
  bool _isVerifyingOtp = false;
  bool _hasOtpError = false;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _otpController.dispose();
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
      final result =
          await ApiService.registerVerificationStatus(widget.pendingToken);
      if (!mounted) return;

      if (result['verified'] != true) return;

      final hasToken = (result['token']?.toString() ?? '').isNotEmpty;
      if (hasToken) {
        _pollTimer?.cancel();
        _completeVerification(result);
        return;
      }

      if (result['otp_required'] == true && !_otpRequired) {
        _pollTimer?.cancel();
        setState(() {
          _otpRequired = true;
          _statusMessage = result['message']?.toString();
        });
      }
    } on AppException catch (e) {
      // Backend balikin 422 + expired:true kalau pending_token tidak
      // ditemukan atau link 15 menit sudah lewat — keduanya butuh daftar
      // ulang, jadi hentikan polling dan arahkan balik ke form register.
      final details = e.details;
      final expired = details is Map && details['expired'] == true;
      if (expired) {
        _pollTimer?.cancel();
        if (!mounted) return;
        showToast(msg: e.message);
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const Register()),
          (route) => false,
        );
        return;
      }
      // Selain itu (mis. 429 rate limit) transien — coba lagi di interval berikutnya.
    } catch (_) {
      // Error jaringan transien — coba lagi di interval berikutnya.
    }
  }

  Future<void> _submitOtp() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      showToast(msg: 'Masukkan 6 digit kode OTP');
      return;
    }

    setState(() {
      _isVerifyingOtp = true;
      _hasOtpError = false;
    });

    try {
      final result =
          await ApiService.registerVerifyOtp(widget.pendingToken, otp);
      if (!mounted) return;
      setState(() => _isVerifyingOtp = false);

      if (result['verified'] == true) {
        _completeVerification(result);
      } else {
        setState(() => _hasOtpError = true);
        showToast(msg: result['message'] ?? 'Kode OTP salah');
      }
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() {
        _isVerifyingOtp = false;
        _hasOtpError = true;
      });
      showToast(msg: e.message);

      final details = e.details;
      if (details is Map && details['expired'] == true) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const Register()),
          (route) => false,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isVerifyingOtp = false;
        _hasOtpError = true;
      });
      showToast(
        msg: ApiService.userFriendlyMessage(e, fallback: 'Gagal memverifikasi OTP'),
      );
    }
  }

  /// Verifikasi tuntas: `result` berisi `token`+`user` dari backend, jadi
  /// langsung auto-login lalu arahkan ke home (atau setup PIN dulu kalau
  /// akun baru belum punya PIN) — sama seperti pola login lain di app.
  Future<void> _completeVerification(Map<String, dynamic> result) async {
    if (!mounted) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final success = await auth.loginWithPasswordResult(result);
    if (!mounted) return;

    if (!success) {
      showToast(msg: auth.error ?? 'Gagal menyiapkan akun');
      return;
    }

    showToast(msg: 'Akun berhasil diverifikasi.');
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
    final content = _otpRequired ? _buildOtpStep() : _buildWaitingStep();

    if (isDesktop(context)) {
      return DesktopAuthShell(child: content);
    }

    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: screenWidth * 0.08,
          vertical: screenHeight * 0.02,
        ),
        child: content,
      ),
    );
  }

  Widget _buildWaitingStep() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(strokeWidth: 2.4),
        const SizedBox(height: 24),
        Text(
          'Menunggu Verifikasi',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: grey900,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Silakan cek WhatsApp/email kamu dan klik link verifikasi yang sudah dikirim.',
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

  Widget _buildOtpStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Masukkan Kode OTP',
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: grey900,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          _statusMessage ??
              'Link sudah diklik. Masukkan kode OTP untuk menyelesaikan verifikasi.',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: grey500,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 32),
        TextField(
          controller: _otpController,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 6,
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: grey900,
            letterSpacing: 8,
          ),
          decoration: InputDecoration(
            counterText: '',
            filled: true,
            fillColor: _hasOtpError ? error50 : Colors.white,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: _hasOtpError ? error500 : grey200,
                width: 1.4,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: primaryBlue500, width: 1.8),
            ),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isVerifyingOtp ? null : _submitOtp,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryBlue500,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isVerifyingOtp
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    'Verifikasi',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}
