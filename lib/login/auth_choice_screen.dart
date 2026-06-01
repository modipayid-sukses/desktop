import 'package:flutter/material.dart';
import 'package:gobank/utils/color.dart';
import 'package:gobank/login/login.dart';
import 'package:gobank/login/register.dart';
import 'package:google_fonts/google_fonts.dart';

class AuthChoiceScreen extends StatelessWidget {
  const AuthChoiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: width * 0.08,
            vertical: height * 0.04,
          ),
          child: Column(
            children: [
              const Spacer(flex: 1),
              SizedBox(
                height: height * 0.25,
                child: Image.asset(
                  'images/onboarding_notification.png',
                  fit: BoxFit.contain,
                ),
              ),
              SizedBox(height: height * 0.05),
              Text(
                'Yuk Lanjut Dikit Lagi!',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: grey900,
                  height: 1.3,
                ),
              ),
              SizedBox(height: height * 0.02),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: width * 0.08),
                child: Text(
                  'Login atau daftar dulu biar kamu bisa mulai transaksi tanpa ribet!',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: grey500,
                    height: 1.5,
                  ),
                ),
              ),
              const Spacer(flex: 2),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [primaryBlue500, primaryBlue600],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
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
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const Login()),
                      ),
                      borderRadius: BorderRadius.circular(12),
                      child: Center(
                        child: Text(
                          'Masuk',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: height * 0.02),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const Register()),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: primaryBlue500, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Belum punya akun? Daftar',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: primaryBlue500,
                    ),
                  ),
                ),
              ),
              SizedBox(height: height * 0.04),
              Text.rich(
                textAlign: TextAlign.center,
                TextSpan(
                  text: 'Dengan masuk atau mendaftar, kamu menyetujui\n',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: grey500,
                    height: 1.4,
                  ),
                  children: [
                    TextSpan(
                      text: 'Ketentuan Layanan',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        color: primaryBlue500,
                      ),
                    ),
                    TextSpan(
                      text: ' dan ',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w400,
                        color: grey500,
                      ),
                    ),
                    TextSpan(
                      text: 'Kebijakan Privasi',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        color: primaryBlue500,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
