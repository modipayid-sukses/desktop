import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/app_exception.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';

class AuthProvider extends ChangeNotifier {
  Map<String, dynamic>? _user;
  bool _isLoading = false;
  String? _error;
  bool _kickedByOtherDevice = false;

  AuthProvider() {
    ApiService.unauthorizedHandler = _handleUnauthorizedSession;
  }

  Map<String, dynamic>? get user => _user;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _user != null && ApiService.getToken() != null;
  bool get hasPin => _user?['has_pin'] == true;
  bool get pinRequired => _user?['pin_required'] != false;
  String? get error => _error;

  /// True when the most recent forced logout was caused by the same account
  /// signing in on a different device. UI can read this once and then call
  /// [consumeKickedByOtherDevice] to reset the flag.
  bool get kickedByOtherDevice => _kickedByOtherDevice;

  void consumeKickedByOtherDevice() {
    if (!_kickedByOtherDevice) return;
    _kickedByOtherDevice = false;
    notifyListeners();
  }

  String get userName => _user?['name'] ?? 'User';
  String get userEmail => _user?['email'] ?? '';
  String get userPhone => _user?['phone'] ?? '';
  String get userAddress => _user?['address'] ?? '';
  String get userBalance => _user?['balance'] ?? '0.00';
  String? get userAvatar => _user?['avatar'];
  String get userLevel => _user?['level'] ?? 'bronze';
  int get userCoins => _user?['coins'] ?? 0;
  String get kycStatus => _user?['kyc_status'] ?? 'none';
  String get qrisBalance => _user?['qris_balance'] ?? '0.00';
  bool get qrisMerchantActive => _user?['qris_merchant_active'] == true || _user?['qris_merchant_active'] == 1;
  bool get kreditVerified => _user?['kredit_verified'] == true || _user?['kredit_verified'] == 1;
  double get kreditLimit => double.tryParse(_user?['kredit_limit']?.toString() ?? '0') ?? 0;
  /// Batas transfer P2P harian dari setting backend (`daily_transfer_limit`),
  /// default Rp 2.000.000 bila belum tersedia di profil.
  double get dailyTransferLimit => double.tryParse(_user?['daily_transfer_limit']?.toString() ?? '') ?? 2000000;
  /// Fitur transfer ke rekening bank hanya aktif bila admin sudah mengaktifkan
  /// `transfer_verified` di akun user (default false / harus pengajuan).
  bool get transferVerified => _user?['transfer_verified'] == true || _user?['transfer_verified'] == 1;
  /// Hierarchy level dari backend (kolom enum): 'supermaster', 'master',
  /// 'agen', atau null jika user biasa.
  String? get hierarchyLevel => _user?['hierarchy_level']?.toString();
  bool get isMasterAgent => hierarchyLevel == 'master';
  // Catatan: nilai backend adalah 'agen' (ejaan Indonesia), bukan 'agent'.
  bool get isAgent => hierarchyLevel == 'agen';
  /// Kode referral milik user yang sedang login, dibagikan ke agen baru
  /// agar terhubung ke hierarki user ini saat mendaftar.
  String? get referralCode => _user?['referral_code']?.toString();

  Future<void> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token != null) {
      ApiService.setToken(token);
      final ok = await fetchProfile();
      if (!ok) return;
      try { await NotificationService.instance.syncTokenWithServer(); } catch (_) {}
    }
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await ApiService.login(email, password);
      if (response.containsKey('token')) {
        final token = response['token'];
        ApiService.setToken(token);
        _user = response['user'];

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', token);
        try { await NotificationService.instance.syncTokenWithServer(); } catch (_) {}

        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = response['message'] ?? 'Login failed';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = ApiService.userFriendlyMessage(e, fallback: 'Login gagal.');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> loginWithOtpResult(Map<String, dynamic> response) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (response.containsKey('token')) {
        final token = response['token'];
        ApiService.setToken(token);
        _user = response['user'];

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', token);
        try { await NotificationService.instance.syncTokenWithServer(); } catch (_) {}

        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = response['message'] ?? 'Login gagal';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = ApiService.userFriendlyMessage(e, fallback: 'Login gagal.');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<Map<String, dynamic>> register({
    required String name,
    required String phone,
    required String password,
    required String passwordConfirmation,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await ApiService.register(
        name: name,
        phone: phone,
        password: password,
        passwordConfirmation: passwordConfirmation,
      );
      _isLoading = false;
      if (response.containsKey('token')) {
        final token = response['token'];
        ApiService.setToken(token);
        _user = response['user'];

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', token);
        try { await NotificationService.instance.syncTokenWithServer(); } catch (_) {}
      } else if (response.containsKey('errors')) {
        _error = (response['errors'] as Map).values.first[0];
      } else {
        _error = response['message'];
      }
      notifyListeners();
      return response;
    } catch (e) {
      _error = ApiService.userFriendlyMessage(e, fallback: 'Pendaftaran gagal.');
      _isLoading = false;
      notifyListeners();
      return {'message': _error};
    }
  }

  Future<bool> fetchProfile() async {
    try {
      final response = await ApiService.getProfile();
      if (response.containsKey('user')) {
        _user = response['user'];
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      if (e is AppException && e.statusCode == 401) {
        await _clearLocalSession('Sesi Anda berakhir. Silakan login kembali.');
      }
      return false;
    }
  }

  Future<void> _handleUnauthorizedSession(String message, {String? errorCode}) async {
    if (errorCode == 'device_mismatch') {
      _kickedByOtherDevice = true;
    }
    await _clearLocalSession(message);
  }

  Future<void> _clearLocalSession(String message) async {
    _user = null;
    _error = message;
    ApiService.setToken(null);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    notifyListeners();
  }

  Future<void> updateBalance() async {
    await fetchProfile();
  }

  Future<bool> setPin(String pin) async {
    try {
      final response = await ApiService.setPin(pin);
      if (response.containsKey('message')) {
        _user?['has_pin'] = true;
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>> changePin(String oldPin, String newPin) async {
    try {
      final response = await ApiService.changePin(oldPin, newPin);
      return response;
    } catch (e) {
      return {'message': ApiService.userFriendlyMessage(e, fallback: 'Gagal mengganti PIN.')};
    }
  }

  Future<Map<String, dynamic>> togglePinRequired(String pin, bool required) async {
    try {
      final response = await ApiService.togglePinRequired(pin, required);
      if (response.containsKey('pin_required')) {
        _user?['pin_required'] = response['pin_required'];
        notifyListeners();
      }
      return response;
    } catch (e) {
      return {'message': ApiService.userFriendlyMessage(e, fallback: 'Gagal memperbarui pengaturan PIN.')};
    }
  }

  Future<void> logout() async {
    try {
      await ApiService.logout();
    } catch (_) {}
    _user = null;
    ApiService.setToken(null);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<bool> loginWithPasswordResult(Map<String, dynamic> response) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (response.containsKey('token')) {
        final token = response['token'];
        ApiService.setToken(token);
        _user = response['user'];

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', token);
        try { await NotificationService.instance.syncTokenWithServer(); } catch (_) {}

        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = response['message'] ?? 'Login gagal';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = ApiService.userFriendlyMessage(e, fallback: 'Login gagal.');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}
