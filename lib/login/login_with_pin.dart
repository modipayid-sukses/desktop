import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:modipay/bottombar/bottombar.dart';
import 'package:modipay/login/device_verification_screen.dart';
import 'package:modipay/login/setup_pin_screen.dart';
import 'package:modipay/providers/auth_provider.dart';
import 'package:modipay/services/api_service.dart';
import 'package:modipay/utils/color.dart';
import 'package:modipay/utils/responsive.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'desktop_auth_panel.dart';

class LoginWithPin extends StatefulWidget {
  const LoginWithPin({super.key, required this.phoneCandidates});

  final List<String> phoneCandidates;

  @override
  State<LoginWithPin> createState() => _LoginWithPinState();
}

class _LoginWithPinState extends State<LoginWithPin> {
  final _pinController = TextEditingController();
  final _pinFocusNode = FocusNode();
  bool _isLoading = false;
  bool _isPinValid = false;
  int _pinLength = 0;
  bool _hasAutoSubmitted = false;
  bool _hasPinError = false;
  String _pinErrorMessage = '';

  @override
  void initState() {
    super.initState();
    _pinController.addListener(_onPinChanged);
  }

  void _onPinChanged() {
    final digits = _pinController.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits != _pinController.text) {
      _pinController.value = TextEditingValue(
        text: digits,
        selection: TextSelection.collapsed(offset: digits.length),
      );
      return;
    }

    final valid = digits.length == 4;
    if (digits.length != _pinLength || valid != _isPinValid || _hasPinError) {
      setState(() {
        _pinLength = digits.length;
        _isPinValid = valid;
        _hasPinError = false;
        _pinErrorMessage = '';
      });
    }

    if (digits.length < 4) {
      _hasAutoSubmitted = false;
    }

    if (digits.length == 4 && !_isLoading && !_hasAutoSubmitted) {
      _hasAutoSubmitted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _loginWithPin();
        }
      });
    }
  }

  @override
  void dispose() {
    _pinController.dispose();
    _pinFocusNode.dispose();
    super.dispose();
  }

  bool _isLoginSuccess(Map<String, dynamic> response) {
    return response.containsKey('token');
  }

  String _mapPinErrorMessage(String message) {
    final text = message.toLowerCase();

    if (text.contains('pin salah')) {
      return 'PIN salah, coba lagi';
    }
    if (text.contains('belum memiliki pin') || text.contains('belum punya pin')) {
      return 'Akun ini belum punya PIN';
    }
    if (text.contains('tidak ditemukan') || text.contains('not found')) {
      return 'Nomor HP tidak terdaftar';
    }
    if (text.contains('koneksi internet')) {
      return 'Koneksi internet bermasalah';
    }
    if (text.contains('melebihi batas waktu')) {
      return 'Permintaan timeout, coba lagi';
    }

    return 'PIN tidak valid, coba lagi';
  }

  bool _isWrongPinMessage(String message) {
    final text = message.toLowerCase();
    return text.contains('pin salah') ||
        text.contains('pin tidak valid') ||
        text.contains('invalid pin');
  }

  bool _isNoPinMessage(String message) {
    final text = message.toLowerCase();
    return text.contains('belum memiliki pin') || text.contains('belum punya pin');
  }

  bool _isNotFoundMessage(String message) {
    final text = message.toLowerCase();
    return text.contains('tidak ditemukan') || text.contains('not found');
  }

  bool _isTimeoutMessage(String message) {
    final text = message.toLowerCase();
    return text.contains('melebihi batas waktu') || text.contains('timeout');
  }

  Future<void> _loginWithPin() async {
    final pin = _pinController.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (pin.length != 4) {
      setState(() {
        _hasPinError = true;
        _pinErrorMessage = 'PIN harus 4 digit';
      });
      return;
    }

    _pinFocusNode.unfocus();
    setState(() => _isLoading = true);
    try {
      Map<String, dynamic>? result;
      final candidates = <String>{
        ...widget.phoneCandidates,
      }.toList();
      String? lastErrorMessage;
      String? fallbackErrorMessage;
      String? deviceVerificationPendingToken;

      for (final candidate in candidates) {
        try {
          final response = await ApiService.loginWithPin(candidate, pin);
          if (_isLoginSuccess(response)) {
            result = response;
            break;
          }

          if (response['device_verification_required'] == true) {
            deviceVerificationPendingToken = response['pending_token']?.toString();
            break;
          }

          final message = (response['message'] ?? '').toString();
          if (message.isEmpty) {
            continue;
          }

          if (_isWrongPinMessage(message) || _isNoPinMessage(message)) {
            lastErrorMessage = message;
            break;
          }

          if (_isNotFoundMessage(message)) {
            fallbackErrorMessage ??= message;
            continue;
          }

          fallbackErrorMessage = message;
          lastErrorMessage = message;
        } catch (e) {
          final message = ApiService.userFriendlyMessage(
            e,
            fallback: 'Gagal login dengan PIN',
          );

          if (_isWrongPinMessage(message) || _isNoPinMessage(message)) {
            lastErrorMessage = message;
            break;
          }

          if (_isNotFoundMessage(message)) {
            fallbackErrorMessage ??= message;
            continue;
          }

          if (_isTimeoutMessage(message)) {
            fallbackErrorMessage ??= message;
            continue;
          }

          fallbackErrorMessage = message;
          lastErrorMessage = message;
          break;
        }
      }

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (deviceVerificationPendingToken != null &&
          deviceVerificationPendingToken.isNotEmpty) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DeviceVerificationScreen(
              pendingToken: deviceVerificationPendingToken!,
            ),
          ),
        );
        return;
      }

      if (result != null && _isLoginSuccess(result)) {
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
          _hasAutoSubmitted = false;
          setState(() {
            _hasPinError = true;
            _pinErrorMessage = _mapPinErrorMessage(auth.error ?? '');
          });
        }
      } else {
        _hasAutoSubmitted = false;
        setState(() {
          _hasPinError = true;
          _pinErrorMessage = _mapPinErrorMessage(lastErrorMessage ?? fallbackErrorMessage ?? '');
        });
      }
    } catch (e) {
      if (!mounted) return;
      final message = ApiService.userFriendlyMessage(
        e,
        fallback: 'Gagal login dengan PIN',
      );
      setState(() {
        _isLoading = false;
        _hasPinError = true;
        _pinErrorMessage = _mapPinErrorMessage(message);
      });
      _hasAutoSubmitted = false;
    }
  }

  void _focusPin() {
    FocusScope.of(context).requestFocus(_pinFocusNode);
  }

  Widget _pinBox({required int index}) {
    final hasValue = _pinLength > index;
    final isActive = _pinLength == index && !_isLoading;
    final borderColor = _hasPinError
      ? error500
      : (isActive ? primaryBlue500 : (hasValue ? grey300 : grey200));
    final shadowColor = _hasPinError
      ? error500.withValues(alpha: 0.16)
      : (isActive
        ? primaryBlue500.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.03));

    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      width: 58,
      height: 64,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: borderColor,
          width: (_hasPinError || isActive) ? 1.8 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 120),
        opacity: hasValue ? 1 : 0,
        child: Container(
          width: 12,
          height: 12,
          decoration: const BoxDecoration(
            color: grey900,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isDesktop(context)) {
      return DesktopAuthShell(child: _buildDesktopForm());
    }
    return _buildMobileLayout(context);
  }

  Widget _buildMobileLayout(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: screenWidth * 0.08,
            vertical: screenHeight * 0.02,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: () => Navigator.maybePop(context),
                  icon: const Icon(Icons.arrow_back, color: grey700, size: 28),
                  splashRadius: 24,
                ),
              ),
              SizedBox(height: screenHeight * 0.03),
              Container(
                width: screenHeight / 9,
                height: screenHeight / 9,
                decoration: BoxDecoration(
                  color: primaryBlue500.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_outline_rounded,
                  color: primaryBlue500,
                  size: 40,
                ),
              ),
              SizedBox(height: screenHeight * 0.03),
              Text(
                'Masukkan PIN',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Gilroy Bold',
                  fontSize: 28,
                  color: grey900,
                ),
              ),
              SizedBox(height: screenHeight * 0.01),
              Text(
                'Masukkan 4 digit PIN untuk melanjutkan login',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Gilroy Medium',
                  fontSize: 14,
                  color: grey500,
                  height: 1.4,
                ),
              ),
              SizedBox(height: screenHeight * 0.07),
              if (!_isLoading) ...[
                GestureDetector(
                  onTap: _focusPin,
                  behavior: HitTestBehavior.opaque,
                  child: Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          for (var i = 0; i < 4; i++) _pinBox(index: i),
                        ],
                      ),
                      Opacity(
                        opacity: 0,
                        child: SizedBox(
                          height: 64,
                          width: double.infinity,
                          child: TextField(
                            focusNode: _pinFocusNode,
                            controller: _pinController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(4),
                            ],
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              counterText: '',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: screenHeight * 0.03),
                if (!_isPinValid)
                  const Text(
                    'PIN harus 4 digit',
                    style: TextStyle(
                      fontFamily: 'Gilroy Medium',
                      fontSize: 12,
                      color: grey400,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                if (_hasPinError)
                  Padding(
                    padding: EdgeInsets.only(top: screenHeight * 0.01),
                    child: Text(
                      _pinErrorMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'Gilroy Medium',
                        fontSize: 12,
                        color: error500,
                      ),
                    ),
                  ),
              ],
              if (_isLoading)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Memverifikasi PIN...',
                      style: TextStyle(
                        fontFamily: 'Gilroy Medium',
                        fontSize: 12,
                        color: grey500,
                      ),
                    ),
                  ],
                ),
              SizedBox(height: screenHeight * 0.04),
              const Text(
                'PIN salah? Hubungi bantuan untuk reset PIN.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Gilroy Bold',
                  fontSize: 13,
                  color: primaryBlue500,
                ),
              ),
              SizedBox(height: screenHeight * 0.03),
            ],
          ),
        ),
      ),
    );
  }

  // ── Desktop layout (split-panel, gaya login.jpeg) ─────────────────────────

  Widget _buildDesktopForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: GestureDetector(
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
        ),
        const SizedBox(height: 16),
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: desktopPrimaryBtn.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.lock_outline_rounded, color: desktopPrimaryBtn, size: 32),
        ),
        const SizedBox(height: 20),
        Text(
          'Masukkan PIN',
          textAlign: TextAlign.center,
          style: GoogleFonts.hankenGrotesk(fontSize: 24, fontWeight: FontWeight.w700, color: desktopTextPrimary, letterSpacing: -0.3),
        ),
        const SizedBox(height: 8),
        Text(
          'Masukkan 4 digit PIN untuk melanjutkan login',
          textAlign: TextAlign.center,
          style: GoogleFonts.hankenGrotesk(fontSize: 14, color: desktopTextSecondary, height: 1.4),
        ),
        const SizedBox(height: 28),
        if (!_isLoading) ...[
          GestureDetector(
            onTap: _focusPin,
            behavior: HitTestBehavior.opaque,
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < 4; i++) ...[
                      if (i > 0) const SizedBox(width: 12),
                      _pinBox(index: i),
                    ],
                  ],
                ),
                Opacity(
                  opacity: 0,
                  child: SizedBox(
                    height: 64,
                    width: 280,
                    child: TextField(
                      focusNode: _pinFocusNode,
                      controller: _pinController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(4),
                      ],
                      decoration: const InputDecoration(border: InputBorder.none, counterText: ''),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (!_isPinValid)
            Text(
              'PIN harus 4 digit',
              style: GoogleFonts.hankenGrotesk(fontSize: 12, color: desktopTextSecondary, fontStyle: FontStyle.italic),
            ),
          if (_hasPinError)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _pinErrorMessage,
                textAlign: TextAlign.center,
                style: GoogleFonts.hankenGrotesk(fontSize: 12, color: desktopErrorRed),
              ),
            ),
        ],
        if (_isLoading)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2)),
              const SizedBox(width: 10),
              Text('Memverifikasi PIN...', style: GoogleFonts.hankenGrotesk(fontSize: 12, color: desktopTextSecondary)),
            ],
          ),
        const SizedBox(height: 24),
        Text(
          'PIN salah? Hubungi bantuan untuk reset PIN.',
          textAlign: TextAlign.center,
          style: GoogleFonts.hankenGrotesk(fontSize: 13, fontWeight: FontWeight.w700, color: desktopAccentBlue),
        ),
      ],
    );
  }
}
