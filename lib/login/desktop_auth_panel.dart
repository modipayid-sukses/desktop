import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:modipay/utils/color.dart';

class _FeatureIconData {
  final IconData icon;
  final String label;
  final Color color;

  const _FeatureIconData(this.icon, this.label, this.color);
}

const List<_FeatureIconData> _authFeatureIcons = [
  _FeatureIconData(Icons.smartphone_rounded, 'PULSA', Color(0xff2f6fed)),
  _FeatureIconData(Icons.wifi_rounded, 'PAKET DATA', Color(0xff22b573)),
  _FeatureIconData(Icons.bolt_rounded, 'TOKEN LISTRIK', desktopWarningAmber),
  _FeatureIconData(Icons.sports_esports_rounded, 'GAME', Color(0xff9b59f6)),
  _FeatureIconData(Icons.account_balance_wallet_rounded, 'E-WALLET', Color(0xff22c1e0)),
];

class DesktopAuthShell extends StatelessWidget {
  final Widget child;

  const DesktopAuthShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: desktopSurfacePage,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 1180),
                  margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: desktopSurfaceCard,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.10),
                        blurRadius: 40,
                        offset: const Offset(0, 20),
                      ),
                    ],
                  ),
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(flex: 5, child: _buildBrandingPanel()),
                        Expanded(
                          flex: 6,
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 32),
                            child: Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 420),
                                child: child,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Text(
                '© ${DateTime.now().year} MODITEKH2H. All rights reserved.',
                style: GoogleFonts.hankenGrotesk(fontSize: 12, color: desktopTextSecondary.withValues(alpha: 0.8)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBrandingPanel() {
    return ClipRRect(
      borderRadius: const BorderRadius.horizontal(left: Radius.circular(28)),
      child: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [desktopNavyStart, desktopNavyEnd],
              ),
            ),
          ),
          Positioned(
            top: -70,
            right: -70,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(44, 44, 40, 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
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
                      child: const Icon(Icons.account_balance_wallet_rounded, color: desktopPrimaryBtn, size: 26),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'MODITEKH2H',
                          style: GoogleFonts.hankenGrotesk(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.3),
                        ),
                        Text(
                          'PPOB SOLUTION',
                          style: GoogleFonts.hankenGrotesk(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white.withValues(alpha: 0.6),
                            letterSpacing: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 40),
                Text.rich(
                  TextSpan(
                    style: GoogleFonts.hankenGrotesk(fontSize: 32, fontWeight: FontWeight.w800, height: 1.25, color: Colors.white),
                    children: const [
                      TextSpan(text: 'Solusi Transaksi PPOB\nTerlengkap & '),
                      TextSpan(text: 'Terpercaya', style: TextStyle(color: desktopNavyHighlight)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Top up lebih mudah, bayar tagihan lebih cepat, semua dalam satu platform yang aman dan handal untuk bisnis Anda.',
                  style: GoogleFonts.hankenGrotesk(fontSize: 14, color: Colors.white.withValues(alpha: 0.7), height: 1.5),
                ),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      for (final feature in _authFeatureIcons)
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(color: feature.color, borderRadius: BorderRadius.circular(14)),
                              alignment: Alignment.center,
                              child: Icon(feature.icon, color: Colors.white, size: 22),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              feature.label,
                              style: GoogleFonts.hankenGrotesk(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.white.withValues(alpha: 0.85),
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(color: desktopPrimaryBtn, shape: BoxShape.circle),
                        alignment: Alignment.center,
                        child: const Icon(Icons.shield_rounded, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Transaksi Sedang Lancar',
                              style: GoogleFonts.hankenGrotesk(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Semua layanan tersedia dan normal.',
                              style: GoogleFonts.hankenGrotesk(fontSize: 12, color: Colors.white.withValues(alpha: 0.6)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: desktopSuccessFg.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(color: Color(0xff4ade80), shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Normal',
                              style: GoogleFonts.hankenGrotesk(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xff4ade80)),
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
        ],
      ),
    );
  }
}

class DesktopAuthPanel extends StatefulWidget {
  final bool showBranding;
  final VoidCallback? onSignUp;
  final ValueChanged<LoginCredentials>? onLogin;
  final VoidCallback? onForgotPassword;

  const DesktopAuthPanel({
    this.showBranding = true,
    this.onSignUp,
    this.onLogin,
    this.onForgotPassword,
  });

  @override
  State<DesktopAuthPanel> createState() => _DesktopAuthPanelState();
}

class LoginCredentials {
  final String email;
  final String password;

  LoginCredentials({required this.email, required this.password});
}

class _DesktopAuthPanelState extends State<DesktopAuthPanel> {
  late TextEditingController _emailController;
  late TextEditingController _passwordController;
  late FocusNode _emailFocus;
  late FocusNode _passwordFocus;
  late FocusNode _rememberFocus;
  late FocusNode _loginFocus;

  bool _rememberDevice = false;
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;
  final LocalAuthentication _localAuth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
    _emailFocus = FocusNode();
    _passwordFocus = FocusNode();
    _rememberFocus = FocusNode();
    _loginFocus = FocusNode();
    _loadRememberedDevice();
  }

  Future<void> _loadRememberedDevice() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString('remembered_email');
      if (email != null) {
        setState(() {
          _emailController.text = email;
          _rememberDevice = true;
        });
      }
    } catch (e) {
      // Silently fail
    }
  }

  Future<void> _handleLogin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Validate inputs
      if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
        throw Exception('Email and password are required');
      }

      // Simulate API call
      await Future.delayed(Duration(milliseconds: 500));

      // Save email if remember device is checked
      if (_rememberDevice) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('remembered_email', _emailController.text);
      }

      // Call callback
      widget.onLogin?.call(LoginCredentials(
        email: _emailController.text,
        password: _passwordController.text,
      ));
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleBiometricLogin() async {
    try {
      final canCheckBiometrics = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();

      if (!canCheckBiometrics || !isDeviceSupported) {
        throw Exception('Biometric authentication not available');
      }

      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Authenticate to log in',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      if (authenticated) {
        // Biometric successful, trigger login with stored credentials
        widget.onLogin?.call(LoginCredentials(
          email: _emailController.text,
          password: 'biometric_auth',
        ));
      }
    } catch (e) {
      setState(() => _errorMessage = 'Biometric authentication failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 1024) {
          return _buildWideLayout(context);
        } else if (constraints.maxWidth > 768) {
          return _buildTabletLayout(context);
        } else {
          return _buildMobileLayout(context);
        }
      },
    );
  }

  Widget _buildWideLayout(BuildContext context) {
    return Row(
      children: [
        if (widget.showBranding)
          Expanded(
            flex: 1,
            child: _buildBrandingSide(context),
          ),
        Expanded(
          flex: 1,
          child: _buildLoginSide(context),
        ),
      ],
    );
  }

  Widget _buildTabletLayout(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          if (widget.showBranding) _buildCompactBranding(context),
          SizedBox(height: 32),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: _buildLoginSide(context),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            SizedBox(height: 32),
            _buildCompactBranding(context),
            SizedBox(height: 32),
            _buildLoginSide(context),
            SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildBrandingSide(BuildContext context) {
    return Container(
      color: Theme.of(context).primaryColor,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.payment, size: 120, color: Colors.white),
              SizedBox(height: 32),
              Text(
                'Modipay',
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              SizedBox(height: 16),
              Text(
                'Digital Payment Platform',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white70,
                    ),
              ),
              SizedBox(height: 48),
              Text(
                'Fast, secure, and easy payments for everyone',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.white70,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactBranding(BuildContext context) {
    return Column(
      children: [
        Icon(Icons.payment, size: 80, color: Theme.of(context).primaryColor),
        SizedBox(height: 16),
        Text(
          'Modipay',
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
    );
  }

  Widget _buildLoginSide(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 400,
        child: Focus(
          onKey: (node, event) {
            // Tab navigation
            if (event.isKeyPressed(LogicalKeyboardKey.tab)) {
              if (_emailFocus.hasFocus) {
                FocusScope.of(context).requestFocus(_passwordFocus);
              } else if (_passwordFocus.hasFocus) {
                FocusScope.of(context).requestFocus(_rememberFocus);
              } else if (_rememberFocus.hasFocus) {
                FocusScope.of(context).requestFocus(_loginFocus);
              } else {
                FocusScope.of(context).requestFocus(_emailFocus);
              }
              return KeyEventResult.handled;
            }
            // Enter to login
            if (event.isKeyPressed(LogicalKeyboardKey.enter)) {
              _handleLogin();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Sign In',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              SizedBox(height: 32),

              // Email field
              TextField(
                controller: _emailController,
                focusNode: _emailFocus,
                decoration: InputDecoration(
                  labelText: 'Email or Phone',
                  hintText: 'user@example.com',
                  prefixIcon: Icon(Icons.email),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => FocusScope.of(context).requestFocus(_passwordFocus),
              ),
              SizedBox(height: 16),

              // Password field
              TextField(
                controller: _passwordController,
                focusNode: _passwordFocus,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() => _obscurePassword = !_obscurePassword);
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _handleLogin(),
              ),
              SizedBox(height: 16),

              // Remember device
              Row(
                children: [
                  Checkbox(
                    focusNode: _rememberFocus,
                    value: _rememberDevice,
                    onChanged: (value) {
                      setState(() => _rememberDevice = value ?? false);
                    },
                  ),
                  Text('Remember this device'),
                  Spacer(),
                  TextButton(
                    onPressed: widget.onForgotPassword,
                    child: Text('Forgot password?'),
                  ),
                ],
              ),
              SizedBox(height: 24),

              // Error message
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red[300]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error, color: Colors.red, size: 20),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(color: Colors.red[900], fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Login button
              ElevatedButton(
                focusNode: _loginFocus,
                onPressed: _isLoading ? null : _handleLogin,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text('Sign In'),
              ),
              SizedBox(height: 16),

              // Sign up
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Don\'t have an account? '),
                  TextButton(
                    onPressed: widget.onSignUp,
                    child: Text('Sign Up'),
                  ),
                ],
              ),
              SizedBox(height: 32),

              // Divider
              Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('Or'),
                  ),
                  Expanded(child: Divider()),
                ],
              ),
              SizedBox(height: 16),

              // Alternative login methods
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  OutlinedButton.icon(
                    onPressed: _handleBiometricLogin,
                    icon: Icon(Icons.fingerprint),
                    label: Text('Biometric'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      // Show OTP dialog
                    },
                    icon: Icon(Icons.sms),
                    label: Text('OTP'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _rememberFocus.dispose();
    _loginFocus.dispose();
    super.dispose();
  }
}
