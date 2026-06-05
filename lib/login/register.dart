import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:modipay/login/setup_pin_screen.dart';
import 'package:modipay/providers/auth_provider.dart';
import 'package:modipay/services/api_service.dart';
import 'package:modipay/utils/color.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:sms_autofill/sms_autofill.dart';

class Register extends StatefulWidget {
  const Register({super.key});

  @override
  State<Register> createState() => _RegisterState();
}

class _RegisterState extends State<Register> {
  final _phoneController = TextEditingController();
  bool _isPhoneValid = false;
  bool _isLoading = false;
  bool _phoneAlreadyRegistered = false;

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(_onPhoneChanged);
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
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

  Future<String?> _showChannelPicker() {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Kirim OTP lewat',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: grey900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Pilih metode pengiriman kode OTP.',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: grey500,
              ),
            ),
            const SizedBox(height: 16),
            _channelTile(
              ctx: ctx,
              icon: Icons.chat_rounded,
              iconColor: const Color(0xff25D366),
              title: 'WhatsApp',
              subtitle: 'wa-generic',
            ),
            const SizedBox(height: 10),
            _channelTile(
              ctx: ctx,
              icon: Icons.sms_rounded,
              iconColor: const Color(0xffFF9800),
              title: 'SMS',
              subtitle: 'sms-generic',
            ),
          ],
        ),
      ),
    );
  }

  Widget _channelTile({
    required BuildContext ctx,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    return Material(
      color: primaryBlue50,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.pop(ctx, subtitle),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Icon(icon, color: iconColor, size: 22),
              const SizedBox(width: 10),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: grey900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _continueRegister() async {
    final rawPhone = _phoneController.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (rawPhone.isEmpty) {
      Fluttertoast.showToast(msg: 'Masukkan nomor HP');
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

    final channel = await _showChannelPicker();
    if (!mounted) return;
    if (channel == null) {
      setState(() => _isLoading = false);
      return;
    }

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
          Fluttertoast.showToast(msg: msg);
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
          Fluttertoast.showToast(msg: msg);
          break;
        }
      }
    }

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (activePhone == null) {
      final message = lastErrorMessage ?? 'Gagal mengirim OTP';
      Fluttertoast.showToast(msg: message);
      return;
    }

    final verified = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _RegisterOtpScreen(phone: activePhone!, channel: channel),
      ),
    );

    if (verified == true && mounted) {
      setState(() => _isLoading = true);
      try {
        final registerResult = await ApiService.register(
          name: _generatedNameFromPhone(activePhone),
          phone: activePhone,
        );

        if (!mounted) return;
        setState(() => _isLoading = false);

        if (registerResult.containsKey('token')) {
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
            Fluttertoast.showToast(msg: auth.error ?? 'Gagal menyiapkan akun');
          }
        } else {
          Fluttertoast.showToast(
            msg: registerResult['message'] ?? 'Gagal mendaftarkan akun',
          );
        }
      } catch (e) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        Fluttertoast.showToast(
          msg: ApiService.userFriendlyMessage(e, fallback: 'Gagal mendaftarkan akun'),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEnabled = _isPhoneValid && !_isLoading;
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
                    'Masukkan nomor HP yang sudah terdaftar untuk verifikasi OTP.',
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
      Fluttertoast.showToast(msg: 'Masukkan 6 digit kode OTP');
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
        Fluttertoast.showToast(msg: result['message'] ?? 'Kode OTP salah');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
      Fluttertoast.showToast(
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
        Fluttertoast.showToast(msg: 'OTP berhasil dikirim ulang');
      } else {
        Fluttertoast.showToast(msg: result['message'] ?? 'Gagal mengirim OTP');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isResending = false);
      Fluttertoast.showToast(
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
