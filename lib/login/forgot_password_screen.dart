import 'dart:async';
import 'package:modipay/widgets/desktop_title_wrapper.dart';


import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:modipay/utils/toast.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/api_service.dart';
import '../utils/color.dart';

/// Halaman lupa password (2 step):
///
///   Step 1 — input email, kirim ke `POST /forgot-password`.
///            Backend menentukan `verification_method` ('otp'/'pin')
///            sesuai setting `is_otp_required`.
///   Step 2 — input kode verifikasi (OTP 6 digit via WhatsApp, atau PIN
///            akun 4 digit) + password baru, submit ke
///            `POST /reset-password`.
///
/// Style mengikuti ForgotPinScreen / Login (Poppins, gradient primaryBlue).
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialEmail});

  /// Email akun yang sudah diketahui (mis. saat dibuka dari halaman Profil),
  /// dipakai untuk mengisi awal field email.
  final String? initialEmail;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

enum _Step { email, verify }

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  _Step _step = _Step.email;

  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _busy = false;
  String? _errorMessage;
  String _email = '';
  String _verificationMethod = 'otp';
  int _otpRemaining = 0;
  Timer? _otpTimer;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  bool _isEmailValid = false;
  bool _isCodeValid = false;
  bool _isPasswordValid = false;
  bool _isConfirmValid = false;

  @override
  void initState() {
    super.initState();
    final initialEmail = widget.initialEmail;
    if (initialEmail != null && initialEmail.isNotEmpty) {
      _emailController.text = initialEmail;
      _isEmailValid = initialEmail.trim().contains('@');
    }
    _emailController.addListener(_onEmailChanged);
    _codeController.addListener(_onCodeChanged);
    _passwordController.addListener(_onPasswordChanged);
    _confirmPasswordController.addListener(_onPasswordChanged);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _otpTimer?.cancel();
    super.dispose();
  }

  int get _codeLength => _verificationMethod == 'pin' ? 4 : 6;

  void _onEmailChanged() {
    final valid = _emailController.text.trim().contains('@');
    if (valid != _isEmailValid) setState(() => _isEmailValid = valid);
    if (_errorMessage != null) setState(() => _errorMessage = null);
  }

  void _onCodeChanged() {
    final valid = _codeController.text.trim().length == _codeLength;
    if (valid != _isCodeValid) setState(() => _isCodeValid = valid);
    if (_errorMessage != null) setState(() => _errorMessage = null);
  }

  void _onPasswordChanged() {
    final password = _passwordController.text;
    final confirm = _confirmPasswordController.text;
    final passwordValid = password.length >= 6;
    final confirmValid = confirm.isNotEmpty && confirm == password;
    if (passwordValid != _isPasswordValid || confirmValid != _isConfirmValid) {
      setState(() {
        _isPasswordValid = passwordValid;
        _isConfirmValid = confirmValid;
      });
    }
    if (_errorMessage != null) setState(() => _errorMessage = null);
  }

  /// Tentukan metode verifikasi sesuai setting `is_otp_required`:
  ///  - true  -> OTP wajib, PIN tidak dipakai.
  ///  - false -> PIN wajib, OTP tidak dipakai.
  ///
  /// Pakai `verification_method` dari response [forgotPassword] bila ada;
  /// jika tidak, jatuh ke `is_otp_required` dari `/api/app-config`.
  Future<String> _resolveVerificationMethod(Map<String, dynamic> response) async {
    final method = response['verification_method']?.toString();
    if (method == 'otp' || method == 'pin') return method!;

    final otpRequired = await ApiService.isOtpRequired();
    return otpRequired ? 'otp' : 'pin';
  }

  void _startOtpCountdown(int seconds) {
    _otpTimer?.cancel();
    setState(() => _otpRemaining = seconds);
    _otpTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _otpRemaining--);
      if (_otpRemaining <= 0) t.cancel();
    });
  }

  // ─────────────────── ACTIONS ───────────────────

  Future<void> _onSubmitEmail() async {
    final email = _emailController.text.trim();
    if (!email.contains('@')) {
      setState(() => _errorMessage = 'Masukkan email yang valid.');
      return;
    }
    setState(() {
      _busy = true;
      _errorMessage = null;
    });
    try {
      final response = await ApiService.forgotPassword(email);
      if (!mounted) return;

      final method = await _resolveVerificationMethod(response);
      if (!mounted) return;
      _email = email;
      _verificationMethod = method;

      if (_verificationMethod == 'otp') {
        final expiresIn = (response['expires_in'] as num?)?.toInt() ?? 300;
        _startOtpCountdown(expiresIn);
      } else {
        _otpTimer?.cancel();
        setState(() => _otpRemaining = 0);
      }

      setState(() {
        _step = _Step.verify;
        _codeController.clear();
        _passwordController.clear();
        _confirmPasswordController.clear();
        _isCodeValid = false;
        _isPasswordValid = false;
        _isConfirmValid = false;
      });

      final msg = response['message']?.toString();
      if (msg != null && msg.isNotEmpty) {
        showToast(msg: msg);
      }
    } catch (e) {
      setState(() => _errorMessage = ApiService.userFriendlyMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _onResetPassword() async {
    final code = _codeController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmPasswordController.text;

    if (code.length != _codeLength) {
      setState(() => _errorMessage = _verificationMethod == 'pin'
          ? 'PIN harus 4 digit.'
          : 'OTP harus 6 digit.');
      return;
    }
    if (password.length < 6) {
      setState(() => _errorMessage = 'Password minimal 6 karakter.');
      return;
    }
    if (password != confirm) {
      setState(() => _errorMessage = 'Konfirmasi password tidak sama.');
      return;
    }

    setState(() {
      _busy = true;
      _errorMessage = null;
    });
    try {
      final response = await ApiService.resetPassword(
        email: _email,
        code: code,
        password: password,
        passwordConfirmation: confirm,
        verificationMethod: _verificationMethod,
      );
      if (!mounted) return;
      _otpTimer?.cancel();
      showToast(
        msg: response['message']?.toString() ?? 'Password berhasil diubah.',
      );
      Navigator.pop(context);
    } catch (e) {
      setState(() => _errorMessage = ApiService.userFriendlyMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _goBackOrPop() {
    if (_step == _Step.verify) {
      _otpTimer?.cancel();
      setState(() {
        _step = _Step.email;
        _errorMessage = null;
      });
    } else {
      Navigator.pop(context);
    }
  }

  // ─────────────────── BUILD ───────────────────

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: grey700),
          onPressed: _goBackOrPop,
        ),
        title: DesktopTitleWrapper(child: Text(
          'Lupa Password',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: grey900,
          ),
        )),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: screenWidth * 0.08,
                vertical: screenHeight * 0.02,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStepIndicator(),
                  SizedBox(height: screenHeight * 0.04),
                  if (_step == _Step.email) _buildEmailStep(screenHeight),
                  if (_step == _Step.verify) _buildVerifyStep(screenHeight),
                  if (_errorMessage != null) ...[
                    SizedBox(height: screenHeight * 0.02),
                    _buildErrorBox(_errorMessage!),
                  ],
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              screenWidth * 0.08,
              0,
              screenWidth * 0.08,
              screenHeight * 0.04,
            ),
            child: _buildPrimaryButton(),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    Widget seg(bool active) => Expanded(
          child: Container(
            height: 4,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: active ? primaryBlue500 : grey200,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
    return Row(
      children: [
        seg(true),
        seg(_step == _Step.verify),
      ],
    );
  }

  Widget _buildErrorBox(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: error500.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: error500, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: error500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryButton() {
    String label;
    bool enabled;
    VoidCallback? onTap;

    switch (_step) {
      case _Step.email:
        label = _busy ? 'Mengirim...' : 'Lanjutkan';
        enabled = _isEmailValid && !_busy;
        onTap = _onSubmitEmail;
        break;
      case _Step.verify:
        label = _busy ? 'Menyimpan...' : 'Reset Password';
        enabled = _isCodeValid && _isPasswordValid && _isConfirmValid && !_busy;
        onTap = _onResetPassword;
        break;
    }

    return Container(
      width: double.infinity,
      height: 52,
      decoration: BoxDecoration(
        gradient: enabled
            ? const LinearGradient(
                colors: [primaryBlue500, primaryBlue600],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : const LinearGradient(colors: [grey200, grey200]),
        borderRadius: BorderRadius.circular(14),
        boxShadow: enabled
            ? [
                BoxShadow(
                  color: primaryBlue500.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(14),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────── STEP 1: EMAIL ───────────────────

  Widget _buildEmailStep(double screenHeight) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Reset Password',
          style: GoogleFonts.poppins(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: grey900,
            height: 1.3,
          ),
        ),
        SizedBox(height: screenHeight * 0.015),
        Text(
          'Masukkan email akun Anda. Kami akan mengirimkan kode verifikasi untuk reset password.',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: grey500,
            height: 1.4,
          ),
        ),
        SizedBox(height: screenHeight * 0.06),
        Text(
          'Email',
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: grey700,
          ),
        ),
        SizedBox(height: screenHeight * 0.014),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: grey700,
          ),
          decoration: InputDecoration(
            isDense: true,
            hintText: 'nama@email.com',
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
        SizedBox(
          width: double.infinity,
          height: 2,
          child: ColoredBox(
            color: _isEmailValid ? primaryBlue500 : grey200,
          ),
        ),
      ],
    );
  }

  // ─────────────────── STEP 2: VERIFIKASI + PASSWORD BARU ───────────────────

  Widget _buildVerifyStep(double screenHeight) {
    final isOtp = _verificationMethod == 'otp';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isOtp ? 'Masukkan Kode OTP' : 'Masukkan PIN Akun',
          style: GoogleFonts.poppins(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: grey900,
            height: 1.3,
          ),
        ),
        SizedBox(height: screenHeight * 0.015),
        Text(
          isOtp
              ? 'Kode 6 digit telah dikirim ke WhatsApp terdaftar untuk email $_email.'
              : 'Masukkan PIN akun Anda untuk memverifikasi permintaan reset password.',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: grey500,
            height: 1.4,
          ),
        ),
        SizedBox(height: screenHeight * 0.05),
        TextField(
          controller: _codeController,
          keyboardType: TextInputType.number,
          obscureText: !isOtp,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(_codeLength),
          ],
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: grey900,
            letterSpacing: isOtp ? 8 : 12,
          ),
          decoration: InputDecoration(
            hintText: isOtp ? '······' : '····',
            hintStyle: GoogleFonts.poppins(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: grey200,
              letterSpacing: isOtp ? 8 : 12,
            ),
            filled: true,
            fillColor: grey50,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: grey200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: grey200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: primaryBlue500, width: 1.5),
            ),
          ),
        ),
        if (isOtp) ...[
          SizedBox(height: screenHeight * 0.018),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _otpRemaining > 0
                    ? 'Kode berlaku ${_formatDuration(_otpRemaining)}'
                    : 'Kode kedaluwarsa',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: _otpRemaining > 0 ? grey500 : error500,
                ),
              ),
              GestureDetector(
                onTap: (_busy || _otpRemaining > 0) ? null : _onSubmitEmail,
                child: Text(
                  'Kirim ulang',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _otpRemaining > 0 ? grey300 : primaryBlue500,
                  ),
                ),
              ),
            ],
          ),
        ],
        SizedBox(height: screenHeight * 0.04),
        Text(
          'Password Baru',
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
                  onTap: () => setState(() => _obscurePassword = !_obscurePassword),
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
                  onTap: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
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
                color: _isConfirmValid ? primaryBlue500 : grey200,
              ),
            ),
          ],
        ),
        if (_confirmPasswordController.text.isNotEmpty && !_isConfirmValid)
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
    );
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
