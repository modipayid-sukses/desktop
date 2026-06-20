import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../utils/color.dart';

/// Shell desktop bergaya split-panel (navy kiri + form putih kanan) yang
/// dipakai di semua layar auth (login password, login OTP, verifikasi OTP,
/// input PIN), mengikuti design system "Vivid Enterprise"
/// (desktop_app_design_system/login_moditekh2h).
class DesktopAuthShell extends StatelessWidget {
  final Widget child;

  const DesktopAuthShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: desktopSurfacePage,
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: Container(
                margin: const EdgeInsets.all(24),
                constraints: const BoxConstraints(maxWidth: 1200, maxHeight: 760),
                decoration: BoxDecoration(
                  color: desktopSurfaceCard,
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 48,
                      offset: const Offset(0, 24),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Expanded(flex: 3, child: DesktopAuthBrandPanel()),
                    Expanded(
                      flex: 2,
                      child: Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 56, vertical: 32),
                          child: child,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              '© 2024 MODITEKH2H. All rights reserved.',
              style: GoogleFonts.hankenGrotesk(fontSize: 12, color: desktopTextSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

/// Panel navy kiri (brand, value-prop, ikon layanan, status banner) sesuai
/// design system "Vivid Enterprise".
class DesktopAuthBrandPanel extends StatelessWidget {
  const DesktopAuthBrandPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final services = [
      {'icon': Icons.smartphone_rounded, 'label': 'Pulsa', 'color': const Color(0xff2563eb)},
      {'icon': Icons.wifi_rounded, 'label': 'Paket Data', 'color': const Color(0xff22c55e)},
      {'icon': Icons.bolt_rounded, 'label': 'Token Listrik', 'color': const Color(0xfffbbf24)},
      {'icon': Icons.sports_esports_rounded, 'label': 'Game', 'color': const Color(0xffa855f7)},
      {'icon': Icons.account_balance_wallet_rounded, 'label': 'E-Wallet', 'color': const Color(0xff0ea5e9)},
    ];

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [desktopNavyStart, desktopNavyEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          // Decorative glow circle
          Positioned(
            top: -100,
            right: -100,
            width: 250,
            height: 250,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.08),
              ),
            ),
          ),
          // Main content column
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Logo
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.account_balance_wallet_rounded,
                        color: desktopPrimaryBtn,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'MODITEKH2H',
                          style: GoogleFonts.hankenGrotesk(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                            height: 1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'PPOB SOLUTION',
                          style: GoogleFonts.hankenGrotesk(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 48),
                // Headline
                Text.rich(
                  TextSpan(
                    style: GoogleFonts.hankenGrotesk(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.15,
                      letterSpacing: -0.64,
                    ),
                    children: [
                      const TextSpan(text: 'Solusi Transaksi PPOB Terlengkap & '),
                      TextSpan(
                        text: 'Terpercaya',
                        style: TextStyle(color: desktopNavyHighlight),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                // Subtitle
                Text(
                  'Top up lebih mudah, bayar tagihan lebih cepat, semua dalam satu platform yang aman dan handal untuk bisnis Anda.',
                  style: GoogleFonts.hankenGrotesk(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),
                // Service Grid
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: services.map((s) {
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Column(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: s['color'] as Color,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  s['icon'] as IconData,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                (s['label'] as String).toUpperCase(),
                                textAlign: TextAlign.center,
                                style: GoogleFonts.hankenGrotesk(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 20),
                // Status Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                          color: Color(0xff0e3cbc),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.verified_user_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Transaksi Sedang Lancar',
                              style: GoogleFonts.hankenGrotesk(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                height: 1,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Semua layanan tersedia dan normal.',
                              style: GoogleFonts.hankenGrotesk(
                                color: Colors.white.withOpacity(0.6),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: desktopSuccessFg.withOpacity(0.15),
                          border: Border.all(color: desktopSuccessFg.withOpacity(0.3)),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.circle, size: 6, color: desktopSuccessFg),
                            const SizedBox(width: 5),
                            Text(
                              'Normal',
                              style: GoogleFonts.hankenGrotesk(
                                color: desktopSuccessFg,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Illustration Mockup at bottom
          Positioned(
            bottom: -20,
            left: 0,
            right: 0,
            height: 240,
            child: Image.network(
              'https://lh3.googleusercontent.com/aida-public/AB6AXuBQdt6tQHKUwtPmQh5PrrpEx7tR5yH8v3FeH3rvgSRa4pFFaWLiyJB6eu8xIN253pbAwDYVInuj_U8GFqV9RrOME-Q9cXjqws82x4lDbE1TIKCXkquIulmvMzuEXTxgi__RBo0wC4R078i_ryLiU32dB8fHS7oF6CGNYrBlNlAq3wY8Gj8_gIz2fo_dzN7uAo9DGlolnPvuxs6qUxjcjL4ZPAFjHeauvI2MKfTAo6UHdAKxqqiRNZfIyN15bwMia3zVEbiT3YrmlZKC',
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
    );
  }
}

/// Input field bordered icon-prefixed yang dipakai di semua form auth desktop.
Widget desktopBorderedField({
  required IconData icon,
  required TextEditingController controller,
  required String hint,
  TextInputType? keyboardType,
  bool obscureText = false,
  Widget? suffix,
}) {
  return Container(
    height: 52,
    padding: const EdgeInsets.symmetric(horizontal: 16),
    decoration: BoxDecoration(
      border: Border.all(color: desktopBorder),
      borderRadius: BorderRadius.circular(12),
      color: desktopSurfaceCard,
    ),
    child: Row(
      children: [
        Icon(icon, color: desktopTextSecondary.withOpacity(0.6), size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            style: GoogleFonts.hankenGrotesk(fontSize: 14, fontWeight: FontWeight.w500, color: desktopTextPrimary),
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              hintText: hint,
              hintStyle: GoogleFonts.hankenGrotesk(fontSize: 14, color: desktopBorder),
            ),
          ),
        ),
        if (suffix != null) suffix,
      ],
    ),
  );
}
