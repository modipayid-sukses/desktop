import 'dart:async';
import 'package:modipay/widgets/desktop_title_wrapper.dart';


import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/api_service.dart';
import '../utils/color.dart';

/// Halaman lupa PIN (3 step):
///
///   Step 1 — input nomor HP (tanpa awalan 0, prefix +62 implicit),
///            kirim OTP via WhatsApp.
///   Step 2 — input OTP 6 digit, verify, dapatkan reset_token.
///   Step 3 — input PIN baru 4 digit + konfirmasi, submit reset.
///
/// Style mengikuti halaman Login (Poppins, gradient primaryBlue, palet grey).
class ForgotPinScreen extends StatefulWidget {
  const ForgotPinScreen({super.key});

  @override
  State<ForgotPinScreen> createState() => _ForgotPinScreenState();
}

enum _Step { phone, otp, newPin }

class _ForgotPinScreenState extends State<ForgotPinScreen> {
  _Step _step = _Step.phone;

  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _pinController = TextEditingController();
  final _pinConfirmController = TextEditingController();

  bool _busy = false;
  String? _errorMessage;
  String _phone = '';
  String _resetToken = '';
  int _otpRemaining = 0;
  Timer? _otpTimer;
  bool _isPhoneValid = false;
  bool _isOtpValid = false;
  bool _isPinValid = false;

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(_onPhoneChanged);
    _otpController.addListener(_onOtpChanged);
    _pinController.addListener(_onPinChanged);
    _pinConfirmController.addListener(_onPinChanged);
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _pinController.dispose();
    _pinConfirmController.dispose();
    _otpTimer?.cancel();
    super.dispose();
  }

  void _onPhoneChanged() {
    final text = _phoneController.text;
    // Sama dengan halaman Login: paksa user input tanpa awalan '0'.
    if (text.startsWith('0') && text.length > 1) {
      _phoneController.text = text.substring(1);
      _phoneController.selection = TextSelection.fromPosition(
        TextPosition(offset: _phoneController.text.length),
      );
    }
    final digits = _phoneController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final valid = digits.length >= 7;
    if (valid != _isPhoneValid) setState(() => _isPhoneValid = valid);
    if (_errorMessage != null) setState(() => _errorMessage = null);
  }

  void _onOtpChanged() {
    final valid = _otpController.text.trim().length == 6;
    if (valid != _isOtpValid) setState(() => _isOtpValid = valid);
    if (_errorMessage != null) setState(() => _errorMessage = null);
  }

  void _onPinChanged() {
    final pin = _pinController.text.trim();
    final confirm = _pinConfirmController.text.trim();
    final valid = pin.length == 4 && pin == confirm;
    if (valid != _isPinValid) setState(() => _isPinValid = valid);
    if (_errorMessage != null) setState(() => _errorMessage = null);
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

  Future<void> _onSendOtp() async {
    final phone = _phoneController.text.trim();
    if (phone.length < 7) {
      setState(() => _errorMessage = 'Nomor HP tidak valid.');
      return;
    }
    setState(() {
      _busy = true;
      _errorMessage = null;
    });
    try {
      // Pre-check: pastikan nomor terdaftar dulu sebelum kirim OTP. Ini
      // mencegah user menunggu OTP yang tidak akan datang kalau nomornya
      // memang belum terdaftar di ModiPay.
      final isRegistered = await ApiService.forgotPinCheckPhone(phone);
      if (!mounted) return;
      if (!isRegistered) {
        setState(() => _errorMessage =
            'Nomor tidak terdaftar. Silakan periksa kembali atau daftar akun terlebih dahulu.');
        return;
      }

      // Backend menerima format apapun (akan di-normalize). Kita kirim apa
      // adanya (tanpa '0' karena UI sudah strip auto).
      final response = await ApiService.forgotPinSendOtp(phone);
      if (!mounted) return;
      _phone = phone;
      final expiresIn = (response['expires_in'] as num?)?.toInt() ?? 300;
      _startOtpCountdown(expiresIn);
      setState(() {
        _step = _Step.otp;
        _otpController.clear();
        _isOtpValid = false;
      });
      Fluttertoast.showToast(
        msg: response['message']?.toString() ??
            'Kode OTP telah dikirim ke WhatsApp.',
      );
    } catch (e) {
      setState(() => _errorMessage = ApiService.userFriendlyMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _onVerifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      setState(() => _errorMessage = 'OTP harus 6 digit.');
      return;
    }
    setState(() {
      _busy = true;
      _errorMessage = null;
    });
    try {
      final response = await ApiService.forgotPinVerifyOtp(
        phone: _phone,
        otp: otp,
      );
      if (!mounted) return;
      _resetToken = (response['reset_token'] ?? '').toString();
      if (_resetToken.isEmpty) {
        setState(() => _errorMessage = 'Token reset tidak diterima.');
        return;
      }
      _otpTimer?.cancel();
      setState(() {
        _step = _Step.newPin;
        _pinController.clear();
        _pinConfirmController.clear();
        _isPinValid = false;
      });
    } catch (e) {
      setState(() => _errorMessage = ApiService.userFriendlyMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _onResetPin() async {
    final pin = _pinController.text.trim();
    final confirm = _pinConfirmController.text.trim();
    if (pin.length != 4) {
      setState(() => _errorMessage = 'PIN harus 4 digit.');
      return;
    }
    if (pin != confirm) {
      setState(() => _errorMessage = 'Konfirmasi PIN tidak cocok.');
      return;
    }
    setState(() {
      _busy = true;
      _errorMessage = null;
    });
    try {
      final response = await ApiService.forgotPinReset(
        resetToken: _resetToken,
        pin: pin,
      );
      if (!mounted) return;
      Fluttertoast.showToast(
        msg: response['message']?.toString() ?? 'PIN berhasil diubah.',
      );
      Navigator.pop(context);
    } catch (e) {
      setState(() => _errorMessage = ApiService.userFriendlyMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _goBackOrPop() {
    if (_step == _Step.otp) {
      _otpTimer?.cancel();
      setState(() {
        _step = _Step.phone;
        _otpController.clear();
        _errorMessage = null;
      });
    } else if (_step == _Step.newPin) {
      setState(() {
        _step = _Step.otp;
        _pinController.clear();
        _pinConfirmController.clear();
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
          'Lupa PIN',
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
                  if (_step == _Step.phone) _buildPhoneStep(screenHeight),
                  if (_step == _Step.otp) _buildOtpStep(screenHeight),
                  if (_step == _Step.newPin) _buildPinStep(screenHeight),
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
        seg(_step != _Step.phone),
        seg(_step == _Step.newPin),
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
      case _Step.phone:
        label = _busy ? 'Mengirim...' : 'Kirim OTP';
        enabled = _isPhoneValid && !_busy;
        onTap = _onSendOtp;
        break;
      case _Step.otp:
        label = _busy ? 'Memverifikasi...' : 'Verifikasi OTP';
        enabled = _isOtpValid && !_busy;
        onTap = _onVerifyOtp;
        break;
      case _Step.newPin:
        label = _busy ? 'Menyimpan...' : 'Reset PIN';
        enabled = _isPinValid && !_busy;
        onTap = _onResetPin;
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
            : LinearGradient(colors: [grey200, grey200]),
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

  // ─────────────────── STEP 1: PHONE ───────────────────

  Widget _buildPhoneStep(double screenHeight) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Reset PIN Akun',
          style: GoogleFonts.poppins(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: grey900,
            height: 1.3,
          ),
        ),
        SizedBox(height: screenHeight * 0.015),
        Text(
          'Masukkan nomor HP yang terdaftar. Kami akan kirim kode OTP ke WhatsApp Anda.',
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
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
    );
  }

  // ─────────────────── STEP 2: OTP ───────────────────

  Widget _buildOtpStep(double screenHeight) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Masukkan Kode OTP',
          style: GoogleFonts.poppins(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: grey900,
            height: 1.3,
          ),
        ),
        SizedBox(height: screenHeight * 0.015),
        Text(
          'Kode 6 digit telah dikirim ke WhatsApp +62$_phone.',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: grey500,
            height: 1.4,
          ),
        ),
        SizedBox(height: screenHeight * 0.06),
        TextField(
          controller: _otpController,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: grey900,
            letterSpacing: 8,
          ),
          decoration: InputDecoration(
            hintText: '······',
            hintStyle: GoogleFonts.poppins(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: grey200,
              letterSpacing: 8,
            ),
            filled: true,
            fillColor: grey50,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: grey200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: grey200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: primaryBlue500, width: 1.5),
            ),
          ),
        ),
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
              onTap: (_busy || _otpRemaining > 0) ? null : _onSendOtp,
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
    );
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  // ─────────────────── STEP 3: PIN BARU ───────────────────

  Widget _buildPinStep(double screenHeight) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Buat PIN Baru',
          style: GoogleFonts.poppins(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: grey900,
            height: 1.3,
          ),
        ),
        SizedBox(height: screenHeight * 0.015),
        Text(
          'Buat 4 digit PIN baru untuk akun Anda.',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: grey500,
            height: 1.4,
          ),
        ),
        SizedBox(height: screenHeight * 0.05),
        Text(
          'PIN Baru',
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: grey700,
          ),
        ),
        SizedBox(height: screenHeight * 0.012),
        _pinField(_pinController),
        SizedBox(height: screenHeight * 0.025),
        Text(
          'Konfirmasi PIN',
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: grey700,
          ),
        ),
        SizedBox(height: screenHeight * 0.012),
        _pinField(_pinConfirmController),
        SizedBox(height: screenHeight * 0.025),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8E1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFFFE082)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline_rounded,
                  color: Color(0xFFF57C00), size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Untuk keamanan, transfer & penarikan akan dibatasi 24 jam setelah PIN diubah.',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF6D4C41),
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _pinField(TextEditingController controller) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      obscureText: true,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(4),
      ],
      textAlign: TextAlign.center,
      style: GoogleFonts.poppins(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        color: grey900,
        letterSpacing: 12,
      ),
      decoration: InputDecoration(
        hintText: '····',
        hintStyle: GoogleFonts.poppins(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          color: grey200,
          letterSpacing: 12,
        ),
        filled: true,
        fillColor: grey50,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: grey200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: grey200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryBlue500, width: 1.5),
        ),
      ),
    );
  }
}
