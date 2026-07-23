# Implementation Plan - Priority 4: Desktop Features

**Status**: Not Started  
**Timeline**: 2-3 weeks  
**Dependencies**: Priority 1, 2, 3 (optional - can run parallel)  
**Target Platforms**: Windows, macOS, Linux

---

## Overview

Implement desktop-specific features to enable modiapps to run on desktop platforms with native experience. This includes responsive layouts, keyboard shortcuts, window management, and desktop-optimized UI patterns.

---

## 1. Desktop Auth Panel

**File**: `lib/login/desktop_auth_panel.dart`

### Requirements
- Side-by-side login form and branding
- Larger touch targets for desktop
- Keyboard navigation support
- Remember device option
- Biometric fallback
- Responsive to different window sizes

### Implementation

#### 1.1 Layout Structure

**Desktop Layout** (width > 1024px):
```
┌──────────────────────────────────────────────────────┐
│                                                      │
│  ┌──────────────────┐  ┌──────────────────────────┐ │
│  │                  │  │                          │ │
│  │  Branding        │  │  Login Form              │ │
│  │  & Promo         │  │  • Username/Email       │ │
│  │                  │  │  • Password             │ │
│  │  [Image]         │  │  • [ ] Remember Device  │ │
│  │                  │  │  • [Login] [Sign Up]    │ │
│  │                  │  │                          │ │
│  │                  │  │  Or login with:         │ │
│  │                  │  │  [Biometric] [OTP]      │ │
│  │                  │  │                          │ │
│  └──────────────────┘  └──────────────────────────┘ │
│                                                      │
└──────────────────────────────────────────────────────┘
```

**Tablet Layout** (768px < width ≤ 1024px):
```
┌────────────────────────────────────┐
│                                    │
│  ┌────────────────────────────┐   │
│  │  [Logo] Modipay            │   │
│  │                            │   │
│  │  Login Form                │   │
│  │  • Email: [______]         │   │
│  │  • Password: [______]      │   │
│  │  • [ ] Remember Device     │   │
│  │                            │   │
│  │  [Login] [Sign Up]         │   │
│  │                            │   │
│  │  Or: [Biometric] [OTP]     │   │
│  └────────────────────────────┘   │
│                                    │
└────────────────────────────────────┘
```

**Mobile Layout** (width ≤ 768px):
```
┌──────────────────┐
│  [Logo] Modipay  │
├──────────────────┤
│                  │
│  Email: [_____] │
│  Password: [__] │
│  [ ] Remember   │
│                  │
│  [Login] [Sign] │
│                  │
│  Or: [Bio] [OTP]│
│                  │
└──────────────────┘
```

#### 1.2 Desktop Auth Panel Widget

```dart
class DesktopAuthPanel extends StatefulWidget {
  final bool showBranding;
  final VoidCallback? onSignUp;
  final ValueChanged<LoginCredentials>? onLogin;

  const DesktopAuthPanel({
    this.showBranding = true,
    this.onSignUp,
    this.onLogin,
  });

  @override
  State<DesktopAuthPanel> createState() => _DesktopAuthPanelState();
}

class _DesktopAuthPanelState extends State<DesktopAuthPanel> {
  late TextEditingController _emailController;
  late TextEditingController _passwordController;
  bool _rememberDevice = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
    _loadRememberedDevice();
  }

  Future<void> _loadRememberedDevice() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('remembered_email');
    if (email != null) {
      setState(() {
        _emailController.text = email;
        _rememberDevice = true;
      });
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
        // Branding side
        Expanded(
          flex: 1,
          child: _buildBrandingSide(context),
        ),
        // Login side
        Expanded(
          flex: 1,
          child: _buildLoginSide(context),
        ),
      ],
    );
  }

  Widget _buildTabletLayout(BuildContext context) {
    return Column(
      children: [
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

  Widget _buildMobileLayout(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          SizedBox(height: 32),
          _buildCompactBranding(context),
          SizedBox(height: 32),
          _buildLoginSide(context),
          SizedBox(height: 32),
        ],
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
              // Logo
              Image.asset(
                'assets/logo_white.png',
                width: 120,
                height: 120,
              ),
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
        Image.asset(
          'assets/logo.png',
          width: 80,
          height: 80,
        ),
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
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: SizedBox(
            width: 400,
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
                  decoration: InputDecoration(
                    labelText: 'Email or Phone',
                    hintText: 'user@example.com',
                    prefixIcon: Icon(Icons.email),
                    border: OutlineInputBorder(),
                  ),
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => FocusScope.of(context).nextFocus(),
                ),
                SizedBox(height: 16),
                // Password field
                TextField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: Icon(Icons.lock),
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _handleLogin(),
                ),
                SizedBox(height: 16),
                // Remember device
                Row(
                  children: [
                    Checkbox(
                      value: _rememberDevice,
                      onChanged: (value) {
                        setState(() => _rememberDevice = value ?? false);
                      },
                    ),
                    Text('Remember this device'),
                    Spacer(),
                    TextButton(
                      onPressed: () {
                        // Navigate to forgot password
                      },
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
                      ),
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red[900]),
                      ),
                    ),
                  ),
                // Login button
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
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
      ),
    );
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

      // Perform login
      await Future.delayed(Duration(milliseconds: 500)); // Simulate API call

      // Remember device if checked
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
      final authenticated = await _authenticateWithBiometrics();
      if (authenticated) {
        // Proceed with biometric login
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    }
  }

  Future<bool> _authenticateWithBiometrics() async {
    // Implementation using local_auth package
    return false;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}

class LoginCredentials {
  final String email;
  final String password;

  LoginCredentials({required this.email, required this.password});
}
```

### Keyboard Navigation

```dart
// Add focus management
class DesktopAuthPanel extends StatefulWidget {
  @override
  State<DesktopAuthPanel> createState() => _DesktopAuthPanelState();
}

class _DesktopAuthPanelState extends State<DesktopAuthPanel> {
  late FocusNode _emailFocus;
  late FocusNode _passwordFocus;
  late FocusNode _rememberFocus;
  late FocusNode _loginFocus;

  @override
  void initState() {
    super.initState();
    _emailFocus = FocusNode();
    _passwordFocus = FocusNode();
    _rememberFocus = FocusNode();
    _loginFocus = FocusNode();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
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
      child: // ... rest of build
    );
  }

  @override
  void dispose() {
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _rememberFocus.dispose();
    _loginFocus.dispose();
    super.dispose();
  }
}
```

### Acceptance Criteria
- [ ] Side-by-side layout on desktop (width > 1024px)
- [ ] Stacked layout on tablet (768px < width ≤ 1024px)
- [ ] Mobile layout on small screens (width ≤ 768px)
- [ ] Keyboard navigation (Tab, Enter)
- [ ] Remember device functionality
- [ ] Biometric login option
- [ ] Error messages displayed
- [ ] Loading state during login
- [ ] Responsive to window resize
- [ ] Accessible (WCAG 2.1 AA)

### Testing
- Test on different screen sizes
- Test keyboard navigation
- Test remember device across sessions
- Test biometric fallback
- Test error scenarios
- Accessibility audit

---

## 2. Desktop Title Wrapper

**File**: `lib/widgets/desktop_title_wrapper.dart`

### Requirements
- Window title bar customization
- App title and branding
- Custom actions in title bar
- Responsive title bar
- Native look and feel

### Implementation

```dart
class DesktopTitleWrapper extends StatelessWidget {
  final Widget child;
  final String title;
  final List<Widget>? titleBarActions;
  final PreferredSizeWidget? appBar;
  final VoidCallback? onMinimize;
  final VoidCallback? onMaximize;
  final VoidCallback? onClose;

  const DesktopTitleWrapper({
    required this.child,
    required this.title,
    this.titleBarActions,
    this.appBar,
    this.onMinimize,
    this.onMaximize,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildCustomAppBar(context),
      body: child,
    );
  }

  PreferredSizeWidget _buildCustomAppBar(BuildContext context) {
    return PreferredSize(
      preferredSize: Size.fromHeight(60),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).appBarTheme.backgroundColor,
          border: Border(
            bottom: BorderSide(
              color: Theme.of(context).dividerColor,
            ),
          ),
        ),
        child: Row(
          children: [
            // Logo and title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Image.asset(
                    'assets/logo.png',
                    width: 32,
                    height: 32,
                  ),
                  SizedBox(width: 12),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ),
            // Spacer
            Expanded(
              child: SizedBox(),
            ),
            // Custom actions
            if (titleBarActions != null)
              Row(
                children: titleBarActions!,
              ),
            // Window controls (Windows/Linux only)
            if (defaultTargetPlatform != TargetPlatform.iOS &&
                defaultTargetPlatform != TargetPlatform.android)
              _buildWindowControls(context),
          ],
        ),
      ),
    );
  }

  Widget _buildWindowControls(BuildContext context) {
    return Row(
      children: [
        // Minimize button
        IconButton(
          icon: Icon(Icons.remove),
          tooltip: 'Minimize',
          onPressed: onMinimize,
        ),
        // Maximize button
        IconButton(
          icon: Icon(Icons.crop_square),
          tooltip: 'Maximize',
          onPressed: onMaximize,
        ),
        // Close button
        IconButton(
          icon: Icon(Icons.close),
          tooltip: 'Close',
          onPressed: onClose,
          hoverColor: Colors.red[100],
        ),
      ],
    );
  }
}
```

### Usage Example

```dart
DesktopTitleWrapper(
  title: 'Modipay',
  titleBarActions: [
    IconButton(
      icon: Icon(Icons.notifications),
      onPressed: () => showNotifications(context),
    ),
    IconButton(
      icon: Icon(Icons.settings),
      onPressed: () => navigateToSettings(context),
    ),
  ],
  onMinimize: () {
    // Platform-specific minimize
  },
  onMaximize: () {
    // Platform-specific maximize
  },
  onClose: () {
    // Confirm and close
  },
  child: MainContent(),
)
```

### Acceptance Criteria
- [ ] Custom title bar displays correctly
- [ ] Window controls (minimize, maximize, close)
- [ ] Custom actions in title bar
- [ ] Responds to window resize
- [ ] Respects system theme (light/dark)
- [ ] Works on Windows, macOS, Linux
- [ ] Keyboard shortcuts for window management
- [ ] Accessible window controls

---

## 3. Responsive Utilities

**File**: `lib/utils/responsive.dart`

### Requirements
- Breakpoint definitions
- Device type detection
- Responsive helpers
- Orientation detection
- Safe area handling

### Implementation

```dart
class ResponsiveHelper {
  static const double mobileBreakpoint = 480;
  static const double tabletBreakpoint = 768;
  static const double desktopBreakpoint = 1024;
  static const double largeDesktopBreakpoint = 1440;

  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < tabletBreakpoint;

  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= tabletBreakpoint &&
      MediaQuery.of(context).size.width < desktopBreakpoint;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= desktopBreakpoint;

  static bool isLargeDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= largeDesktopBreakpoint;

  static double getMaxWidth(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (isLargeDesktop(context)) return 1400;
    if (isDesktop(context)) return 1000;
    if (isTablet(context)) return 700;
    return width - 32;
  }

  static int getGridColumns(BuildContext context) {
    if (isLargeDesktop(context)) return 4;
    if (isDesktop(context)) return 3;
    if (isTablet(context)) return 2;
    return 1;
  }

  static EdgeInsets getPadding(BuildContext context) {
    if (isDesktop(context)) return EdgeInsets.all(32);
    if (isTablet(context)) return EdgeInsets.all(24);
    return EdgeInsets.all(16);
  }

  static double getIconSize(BuildContext context) {
    if (isDesktop(context)) return 32;
    if (isTablet(context)) return 28;
    return 24;
  }

  static Orientation getOrientation(BuildContext context) =>
      MediaQuery.of(context).orientation;

  static bool isPortrait(BuildContext context) =>
      getOrientation(context) == Orientation.portrait;

  static bool isLandscape(BuildContext context) =>
      getOrientation(context) == Orientation.landscape;

  static EdgeInsets getSafeAreaPadding(BuildContext context) {
    final padding = MediaQuery.of(context).padding;
    return padding;
  }

  static double getViewInsets(BuildContext context) {
    return MediaQuery.of(context).viewInsets.bottom;
  }
}

// Extension methods for convenience
extension ResponsiveExt on BuildContext {
  bool get isMobile => ResponsiveHelper.isMobile(this);
  bool get isTablet => ResponsiveHelper.isTablet(this);
  bool get isDesktop => ResponsiveHelper.isDesktop(this);
  bool get isLargeDesktop => ResponsiveHelper.isLargeDesktop(this);
  
  double get maxWidth => ResponsiveHelper.getMaxWidth(this);
  int get gridColumns => ResponsiveHelper.getGridColumns(this);
  EdgeInsets get padding => ResponsiveHelper.getPadding(this);
  double get iconSize => ResponsiveHelper.getIconSize(this);
  
  bool get isPortrait => ResponsiveHelper.isPortrait(this);
  bool get isLandscape => ResponsiveHelper.isLandscape(this);
}

// Responsive widget builder
class ResponsiveWidget extends StatelessWidget {
  final WidgetBuilder mobile;
  final WidgetBuilder? tablet;
  final WidgetBuilder? desktop;

  const ResponsiveWidget({
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    if (context.isLargeDesktop && desktop != null) {
      return desktop!(context);
    }
    if (context.isDesktop && desktop != null) {
      return desktop!(context);
    }
    if (context.isTablet && tablet != null) {
      return tablet!(context);
    }
    return mobile(context);
  }
}
```

### Usage Examples

```dart
// Simple responsive check
if (context.isDesktop) {
  // Desktop layout
} else if (context.isTablet) {
  // Tablet layout
} else {
  // Mobile layout
}

// Responsive padding
Padding(
  padding: context.padding,
  child: Text('Responsive content'),
)

// Responsive grid
GridView.count(
  crossAxisCount: context.gridColumns,
  children: items,
)

// Using ResponsiveWidget
ResponsiveWidget(
  mobile: (context) => MobileLayout(),
  tablet: (context) => TabletLayout(),
  desktop: (context) => DesktopLayout(),
)
```

### Acceptance Criteria
- [ ] Correct breakpoint detection
- [ ] Device type detection accurate
- [ ] Orientation detection working
- [ ] Safe area padding handled
- [ ] Extension methods accessible
- [ ] ResponsiveWidget builder works
- [ ] Responsive to window resize
- [ ] Performance: < 16ms evaluation

---

## Dependencies

### Packages Required

```yaml
dependencies:
  # Desktop support
  window_manager: ^0.4.0
  screen_retriever: ^0.2.0
  desktop_window: ^0.5.0
  
  # Platform detection
  platform: ^3.1.0
  
  # Shared preferences (already in Priority 1)
  shared_preferences: ^2.2.0
  
  # Local auth (already in Priority 1)
  local_auth: ^2.2.0
  
  # Existing dependencies
  flutter: sdk
```

### Permissions

**Desktop platforms**: No special permissions needed. Window management uses native APIs.

---

## Rollout Strategy

### Week 1: Auth Panel
- Day 1-2: Desktop auth panel layout
- Day 3: Keyboard navigation
- Day 4: Remember device feature
- Day 5: Testing

### Week 2: Title Bar & Responsive
- Day 1-2: Desktop title wrapper
- Day 3-4: Responsive utilities
- Day 5: Integration with existing screens

### Week 3: Polish & Deployment
- Day 1-2: Cross-platform testing (Windows, macOS, Linux)
- Day 3-4: Performance optimization
- Day 5: Documentation and deployment

---

## Success Metrics

| Metric | Target |
|--------|--------|
| Desktop login time | < 5 seconds |
| Window resize response | < 16ms |
| Keyboard navigation coverage | 100% |
| Cross-platform compatibility | All major platforms |
| User satisfaction (Desktop) | > 4.3/5 |
| App responsiveness | 60fps maintained |

---

## Platform-Specific Considerations

### Windows
- Use native window controls (minimize, maximize, close)
- Support snap layouts (Windows 11)
- Dark mode support
- Keyboard shortcuts: Win+D (minimize all), etc.

### macOS
- Use native title bar styling
- Support full-screen mode
- Trackpad gestures
- Use system colors and fonts

### Linux
- X11 and Wayland support
- GNOME/KDE/other DE compatibility
- Window manager integration
- System theme detection

---

## Risk Mitigation

| Risk | Impact | Mitigation |
|------|--------|-----------|
| Window management crashes | High | Wrap in try-catch, provide fallback |
| Keyboard conflicts | Medium | Document all shortcuts, allow customization |
| Platform inconsistencies | Medium | Extensive cross-platform testing |
| Performance regression | Medium | Profile on each platform, optimize |
| Responsive layout issues | Medium | Test on 10+ screen sizes |

---

## Notes

- Ensure all desktop features have mobile/tablet equivalents
- Test on actual hardware, not just emulators
- Consider accessibility for desktop users (larger touch targets, keyboard nav)
- Document all keyboard shortcuts for users
- Performance is critical on desktop - profile regularly
- Consider dark mode support from the start
