import 'dart:async';
import 'package:modipay/widgets/desktop_title_wrapper.dart';


import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/api_service.dart';
import '../utils/color.dart';
import '../utils/responsive.dart';
import 'desktop_auth_panel.dart';
import 'login_with_pin.dart';

/// Halaman OTP saat login. User wajib verifikasi OTP yang dikirim ke
/// WhatsApp (via Whapify) sebelum lanjut ke input PIN.
///
/// Flow:
///   1. initState → otomatis kirim OTP (`/send-otp type=login`)
///   2. User input 6 digit OTP
///   3. Verify (`/verify-otp type=login`)
///   4. Navigate ke `LoginWithPin`
class LoginOtpScreen extends StatefulWidget {
  /// Phone yang sudah terverifikasi terdaftar (format normalized).
  final String phone;

  const LoginOtpScreen({super.key, required this.phone});

  @override
  State<LoginOtpScreen> createState() => _LoginOtpScreenState();
}

class _LoginOtpScreenState extends State<LoginOtpScreen> {
  final _otpController = TextEditingController();
  bool _busy = false;
  bool _sending = false;
  String? _errorMessage;
  int _otpRemaining = 0;
  Timer? _otpTimer;
  bool _isOtpValid = false;

  @override
  void initState() {
    super.initState();
    _otpController.addListener(_onOtpChanged);
    // Otomatis kirim OTP saat halaman dibuka.
    WidgetsBinding.instance.addPostFrameCallback((_) => _sendOtp(initial: true));
  }

  @override
  void dispose() {
    _otpController.dispose();
    _otpTimer?.cancel();
    super.dispose();
  }

  void _onOtpChanged() {
    final valid = _otpController.text.trim().length == 6;
    if (valid != _isOtpValid) setState(() => _isOtpValid = valid);
    if (_errorMessage != null) setState(() => _errorMessage = null);
  }

  void _startCountdown(int seconds) {
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

  Future<void> _sendOtp({bool initial = false}) async {
    setState(() {
      _sending = true;
      _errorMessage = null;
    });
    try {
      await ApiService.sendOtp(
        widget.phone,
        channel: 'wa-generic',
        type: 'login',
      );
      if (!mounted) return;
      _startCountdown(300); // 5 menit
      if (!initial) {
        Fluttertoast.showToast(msg: 'Kode OTP baru sudah dikirim ke WhatsApp.');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = ApiService.userFriendlyMessage(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _verifyOtp() async {
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
      await ApiService.verifyOtp(widget.phone, otp, type: 'login');
      if (!mounted) return;
      _otpTimer?.cancel();

      // Setelah OTP terverifikasi, lanjut ke input PIN.
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => LoginWithPin(phoneCandidates: [widget.phone]),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = ApiService.userFriendlyMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canVerify = _isOtpValid && !_busy && !_sending;
    if (isDesktop(context)) {
      return DesktopAuthShell(child: _buildDesktopForm(canVerify));
    }
    return _buildMobileLayout(context, canVerify);
  }

  Widget _buildMobileLayout(BuildContext context, bool canVerify) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: grey700),
        title: DesktopTitleWrapper(child: Text(
          'Verifikasi OTP',
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
                  SizedBox(height: screenHeight * 0.02),
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
                    'Kami telah mengirim kode 6 digit ke WhatsApp +62${widget.phone}.',
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
                    autofocus: true,
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
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 18),
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
                        borderSide:
                            const BorderSide(color: primaryBlue500, width: 1.5),
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
                        onTap: (_busy || _sending || _otpRemaining > 0)
                            ? null
                            : () => _sendOtp(),
                        child: Text(
                          _sending ? 'Mengirim...' : 'Kirim ulang',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: (_otpRemaining > 0 || _sending)
                                ? grey300
                                : primaryBlue500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_errorMessage != null) ...[
                    SizedBox(height: screenHeight * 0.02),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFEBEE),
                        borderRadius: BorderRadius.circular(10),
                        border:
                            Border.all(color: error500.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded,
                              color: error500, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
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
            child: Container(
              width: double.infinity,
              height: 52,
              decoration: BoxDecoration(
                gradient: canVerify
                    ? const LinearGradient(
                        colors: [primaryBlue500, primaryBlue600],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : LinearGradient(colors: [grey200, grey200]),
                borderRadius: BorderRadius.circular(14),
                boxShadow: canVerify
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
                  onTap: canVerify ? _verifyOtp : null,
                  borderRadius: BorderRadius.circular(14),
                  child: Center(
                    child: Text(
                      _busy ? 'Memverifikasi...' : 'Verifikasi & Lanjutkan',
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

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  // ── Desktop layout (split-panel, gaya login.jpeg) ─────────────────────────

  Widget _buildDesktopForm(bool canVerify) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () => Navigator.maybePop(context),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.arrow_back, size: 16, color: desktopTextSecondary),
              const SizedBox(width: 4),
              Text('Kembali', style: GoogleFonts.hankenGrotesk(fontSize: 12, color: desktopTextSecondary)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Masukkan Kode OTP',
          style: GoogleFonts.hankenGrotesk(fontSize: 28, fontWeight: FontWeight.w700, color: desktopTextPrimary, letterSpacing: -0.3),
        ),
        const SizedBox(height: 8),
        Text(
          'Kami telah mengirim kode 6 digit ke WhatsApp +62${widget.phone}.',
          style: GoogleFonts.hankenGrotesk(fontSize: 14, color: desktopTextSecondary, height: 1.4),
        ),
        const SizedBox(height: 28),
        TextField(
          controller: _otpController,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          textAlign: TextAlign.center,
          autofocus: true,
          style: GoogleFonts.hankenGrotesk(fontSize: 24, fontWeight: FontWeight.w700, color: desktopTextPrimary, letterSpacing: 8),
          decoration: InputDecoration(
            hintText: '······',
            hintStyle: GoogleFonts.hankenGrotesk(fontSize: 24, fontWeight: FontWeight.w700, color: desktopBorder, letterSpacing: 8),
            filled: true,
            fillColor: desktopSurfacePage,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: desktopBorder)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: desktopBorder)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: desktopAccentBlue, width: 1.5)),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _otpRemaining > 0 ? 'Kode berlaku ${_formatDuration(_otpRemaining)}' : 'Kode kedaluwarsa',
              style: GoogleFonts.hankenGrotesk(fontSize: 12, fontWeight: FontWeight.w500, color: _otpRemaining > 0 ? desktopTextSecondary : desktopErrorRed),
            ),
            GestureDetector(
              onTap: (_busy || _sending || _otpRemaining > 0) ? null : () => _sendOtp(),
              child: Text(
                _sending ? 'Mengirim...' : 'Kirim ulang',
                style: GoogleFonts.hankenGrotesk(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: (_otpRemaining > 0 || _sending) ? desktopBorder : desktopAccentBlue,
                ),
              ),
            ),
          ],
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: desktopErrorRed.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: desktopErrorRed.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: desktopErrorRed, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: GoogleFonts.hankenGrotesk(fontSize: 12, fontWeight: FontWeight.w500, color: desktopErrorRed),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: canVerify ? _verifyOtp : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: desktopPrimaryBtn,
              disabledBackgroundColor: desktopPrimaryBtn.withOpacity(0.4),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                  )
                : Text('Verifikasi & Lanjutkan', style: GoogleFonts.hankenGrotesk(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
          ),
        ),
      ],
    );
  }
}
