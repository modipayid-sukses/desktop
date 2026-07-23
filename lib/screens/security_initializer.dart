import 'package:flutter/material.dart';
import '../services/security_manager.dart';
import '../login/device_verification_screen.dart';
import '../widgets/update_dialog.dart';

class SecurityInitializer extends StatefulWidget {
  final Widget child;
  final VoidCallback? onSecurityCheckComplete;

  const SecurityInitializer({
    required this.child,
    this.onSecurityCheckComplete,
  });

  @override
  State<SecurityInitializer> createState() => _SecurityInitializerState();
}

class _SecurityInitializerState extends State<SecurityInitializer> {
  late SecurityManager _securityManager;
  bool _initialized = false;
  String? _initError;

  @override
  void initState() {
    super.initState();
    _securityManager = SecurityManager();
    _initializeSecurity();
  }

  Future<void> _initializeSecurity() async {
    try {
      // Initialize security services
      await _securityManager.initialize();

      if (!mounted) return;

      // Check for forced updates first
      final isUpdateRequired = await _securityManager.isUpdateRequired();
      if (isUpdateRequired) {
        _showForceUpdateDialog();
        return;
      }

      // Check for optional updates
      final updateAvailable = await _securityManager.isUpdateAvailable();
      if (updateAvailable) {
        final updateInfo = await _securityManager.checkForUpdates();
        if (updateInfo != null && mounted) {
          _showOptionalUpdateDialog(updateInfo);
        }
      }

      setState(() => _initialized = true);
      widget.onSecurityCheckComplete?.call();
    } catch (e) {
      setState(() => _initError = e.toString());
    }
  }

  void _showForceUpdateDialog() {
    Future.delayed(Duration(milliseconds: 500), () async {
      final updateInfo = await _securityManager.checkForUpdates();
      if (updateInfo != null && mounted) {
        showUpdateDialog(
          context,
          updateInfo: updateInfo,
          isForceUpdate: true,
          onUpdateNow: _handleForceUpdate,
        );
      }
    });
  }

  void _showOptionalUpdateDialog(UpdateInfo updateInfo) {
    showUpdateDialog(
      context,
      updateInfo: updateInfo,
      isForceUpdate: false,
      onUpdateNow: _handleOptionalUpdate,
      onUpdateLater: _handleUpdateLater,
      onSkip: _handleUpdateSkip,
    );
  }

  Future<void> _handleForceUpdate() async {
    try {
      await _securityManager.updateService.logUpdateAction(
        'accepted',
        await _securityManager.getAppVersion(),
      );
      // Platform-specific update handling would go here
    } catch (e) {
      _showErrorSnackbar('Update failed: $e');
    }
  }

  Future<void> _handleOptionalUpdate() async {
    try {
      await _securityManager.updateService.logUpdateAction(
        'accepted',
        await _securityManager.getAppVersion(),
      );
      _showSuccessSnackbar('Update initiated');
    } catch (e) {
      _showErrorSnackbar('Update failed: $e');
    }
  }

  Future<void> _handleUpdateLater() async {
    try {
      await _securityManager.updateService.logUpdateAction(
        'dismissed',
        await _securityManager.getAppVersion(),
      );
    } catch (e) {
      // Silently fail
    }
  }

  Future<void> _handleUpdateSkip() async {
    try {
      final version = await _securityManager.getAppVersion();
      await _securityManager.updateService.saveDismissedUpdateVersion(version);
      await _securityManager.updateService.logUpdateAction('skipped', version);
    } catch (e) {
      // Silently fail
    }
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_initError != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error, size: 64, color: Colors.red),
              SizedBox(height: 16),
              Text('Security initialization failed'),
              SizedBox(height: 8),
              Text(
                _initError!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  setState(() => _initError = null);
                  _initializeSecurity();
                },
                child: Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (!_initialized) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Initializing security...'),
            ],
          ),
        ),
      );
    }

    return widget.child;
  }

  @override
  void dispose() {
    _securityManager.dispose();
    super.dispose();
  }
}

/// Mixin for screens that need pre-login security checks
mixin PreLoginSecurityMixin {
  Future<bool> performPreLoginSecurityCheck(BuildContext context) async {
    final securityManager = SecurityManager();
    final result = await securityManager.preLoginSecurityCheck();

    if (!result.canProceed) {
      _showSecurityError(context, result);
      return false;
    }

    if (!result.deviceVerified) {
      _showDeviceVerificationPrompt(context);
    }

    return true;
  }

  void _showSecurityError(BuildContext context, SecurityCheckResult result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(Icons.security, color: Colors.red, size: 48),
        title: Text('Security Check Failed'),
        content: Text(result.reason ?? 'Unknown error'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showDeviceVerificationPrompt(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Verify Device'),
        content: Text('For security, please verify this device before proceeding.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Skip for now'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DeviceVerificationScreen(),
                ),
              );
            },
            child: Text('Verify'),
          ),
        ],
      ),
    );
  }
}

/// Mixin for screens that need pre-transaction security checks
mixin PreTransactionSecurityMixin {
  Future<bool> performPreTransactionSecurityCheck(
    BuildContext context,
    double amount,
  ) async {
    final securityManager = SecurityManager();
    final result = await securityManager.preTransactionSecurityCheck(amount);

    if (!result.canProceed) {
      _showSecurityError(context, result);
      return false;
    }

    if (result.requiresAdditionalVerification) {
      _showAdditionalVerificationPrompt(context);
    }

    return true;
  }

  void _showSecurityError(BuildContext context, SecurityCheckResult result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(Icons.security, color: Colors.red, size: 48),
        title: Text('Transaction Blocked'),
        content: Text(result.reason ?? 'Unknown error'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showAdditionalVerificationPrompt(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(Icons.warning, color: Colors.orange, size: 48),
        title: Text('Additional Verification Required'),
        content: Text('For security, we need additional verification for this transaction.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Show verification flow
            },
            child: Text('Continue'),
          ),
        ],
      ),
    );
  }
}
