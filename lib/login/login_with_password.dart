import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:modipay/bottombar/bottombar.dart';
import 'package:modipay/login/register.dart';
import 'package:modipay/login/setup_pin_screen.dart';
import 'package:modipay/providers/auth_provider.dart';
import 'package:modipay/services/api_service.dart';
import 'package:modipay/utils/color.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

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

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(_onPhoneChanged);
    _passwordController.addListener(_onPasswordChanged);
  }

  void _onPhoneChanged() {
    final text = _phoneController.text;
    
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
    super.dispose();
  }

  Future<void> _loginWithPassword() async {
    final rawPhone = _phoneController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final password = _passwordController.text.trim();

    if (rawPhone.isEmpty) {
      Fluttertoast.showToast(msg: 'Masukkan nomor HP');
      return;
    }
    if (password.isEmpty) {
      Fluttertoast.showToast(msg: 'Masukkan password');
      return;
    }

    final phoneCandidates = _phoneCandidates(rawPhone);

    setState(() => _isLoading = true);
    try {
      Map<String, dynamic> result = {};
      for (final candidate in phoneCandidates) {
        result = await ApiService.login(candidate, password);
        if (_isLoginSuccess(result)) {
          break;
        }
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
                      content: const Text('Jika ada pertanyaan, hubungi layanan pelanggan kami di support@Modipay.id'),
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
                  SizedBox(height: screenHeight * 0.04),
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
}
