import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'app_exception.dart';
import 'device_identity_service.dart';

class ApiService {
  // Override with --dart-define=API_BASE_URL=http://<your-ip>:8000/api for local dev.
  static const String _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://desktop.modipay.biz.id/api',
  );

  static String get baseUrl => _baseUrl;

  static const bool _httpDebug = true;

  // HTTP client yang tidak follow redirect untuk POST — mencegah POST→GET
  // conversion saat ada 301/302 redirect (mis. dari Cloudflare atau server).
  static http.Client get _noRedirectClient => _NoRedirectClient();
  
  // Enable mock QRIS for testing when backend endpoints aren't ready
  static bool useMockQris = const bool.fromEnvironment('MOCK_QRIS', defaultValue: false);

  static String? _token;
  static const Duration _requestTimeout = Duration(seconds: 25);
  static void Function(String message, {String? errorCode})? unauthorizedHandler;

  static void setToken(String? token) {
    _token = token;
  }

  static String? getToken() => _token;

  static String avatarUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) return path;

    final base = _baseUrl.endsWith('/api')
        ? _baseUrl.substring(0, _baseUrl.length - 4)
        : _baseUrl;

    if (path.startsWith('/')) return '$base$path';
    return '$base/storage/$path';
  }

  // dart:io's HttpHeaders.set() only accepts Latin-1/ASCII bytes in header
  // values. Device names can contain smart quotes/emoji (e.g. macOS
  // "Work’s Mac mini"), which throws a FormatException before the request
  // is even sent — replace anything outside printable ASCII with '?'.
  static String _sanitizeHeaderValue(String value) {
    final buffer = StringBuffer();
    for (final codeUnit in value.codeUnits) {
      buffer.writeCharCode(codeUnit >= 0x20 && codeUnit <= 0x7E ? codeUnit : 0x3F);
    }
    return buffer.toString();
  }

  static Map<String, String> _headers({bool auth = false}) {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Cache-Control': 'no-cache',
    };
    if (auth && _token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }
    final deviceId = DeviceIdentityService.currentDeviceId;
    if (deviceId != null && deviceId.isNotEmpty) {
      headers['X-Device-Id'] = deviceId;
    }
    final deviceName = DeviceIdentityService.currentDeviceName;
    if (deviceName != null && deviceName.isNotEmpty) {
      headers['X-Device-Name'] = _sanitizeHeaderValue(deviceName);
    }
    final devicePlatform = DeviceIdentityService.currentDevicePlatform;
    if (devicePlatform != null && devicePlatform.isNotEmpty) {
      headers['X-Device-Platform'] = devicePlatform;
    }
    headers['X-App-Version'] = DeviceIdentityService.appVersion;
    return headers;
  }

  /// Attach device metadata to outgoing auth request bodies so the backend
  /// can persist what device the user logged in from.
  static Map<String, dynamic> _withDevicePayload(Map<String, dynamic> body) {
    final meta = DeviceIdentityService.metadata();
    body.putIfAbsent('device_id', () => meta['device_id']);
    body.putIfAbsent('device_name', () => meta['device_name']);
    body.putIfAbsent('device_platform', () => meta['device_platform']);
    body.putIfAbsent('app_version', () => meta['app_version']);
    return body;
  }

  static String _mask(String input, {int keepEnd = 4}) {
    final s = input.toString();
    if (s.isEmpty) return '';
    if (s.length <= keepEnd) return '***';
    return '${List.filled(s.length - keepEnd, '*').join()}${s.substring(s.length - keepEnd)}';
  }

  static Object? _redactBody(Object? body) {
    if (body == null) return null;
    dynamic decoded;
    if (body is String) {
      try {
        decoded = jsonDecode(body);
      } catch (_) {
        return '[non-json body length=${body.length}]';
      }
    } else {
      decoded = body;
    }

    dynamic redact(dynamic value) {
      if (value is Map) {
        final out = <String, dynamic>{};
        for (final entry in value.entries) {
          final key = entry.key.toString();
          final lower = key.toLowerCase();
          final v = entry.value;
          if (lower.contains('pin') ||
              lower.contains('password') ||
              lower.contains('token') ||
              lower.contains('sign') ||
              lower.contains('api_key') ||
              lower == 'apikey' ||
              lower == 'authorization') {
            out[key] = '[REDACTED]';
            continue;
          }
          if (lower.contains('customer_no') ||
              lower.contains('phone') ||
              lower.contains('account_number')) {
            out[key] = v == null ? null : _mask(v.toString());
            continue;
          }
          out[key] = redact(v);
        }
        return out;
      }
      if (value is List) return value.map(redact).toList();
      return value;
    }

    return redact(decoded);
  }

  static String userFriendlyMessage(
    Object error, {
    String fallback = 'Terjadi kesalahan. Silakan coba lagi.',
  }) {
    if (error is AppException) return error.message;
    if (error is TimeoutException) return 'Permintaan melebihi batas waktu.';
    if (error is SocketException || error is HttpException) {
      return 'Koneksi internet bermasalah.';
    }
    if (error is FormatException) return 'Respon server tidak valid.';
    return fallback;
  }

  static bool _isSafeUserMessage(String message) {
    final lower = message.toLowerCase();
    const blockedTerms = [
      'sqlstate',
      'exception',
      'stack trace',
      '<html',
      '<!doctype',
      'undefined',
      'syntax error',
      ' on line ',
      ' at ',
    ];

    if (message.trim().isEmpty || message.length > 180) return false;
    return !blockedTerms.any(lower.contains);
  }

  static String _messageForStatus(int statusCode) {
    if (statusCode == 400) return 'Permintaan tidak valid.';
    if (statusCode == 401) return 'Sesi Anda berakhir. Silakan login kembali.';
    if (statusCode == 403) return 'Anda tidak memiliki akses untuk aksi ini.';
    if (statusCode == 404) return 'Data tidak ditemukan.';
    if (statusCode == 422) return 'Data tidak valid. Periksa kembali input Anda.';
    if (statusCode == 429) return 'Terlalu banyak percobaan. Silakan tunggu sebentar lalu coba lagi.';
    if (statusCode >= 500) return 'Server sedang bermasalah. Coba lagi nanti.';
    return 'Terjadi kesalahan. Silakan coba lagi.';
  }

  static dynamic _decodeBody(String body) {
    if (body.trim().isEmpty) return <String, dynamic>{};
    try {
      return jsonDecode(body);
    } catch (_) {
      throw const AppException('Respon server tidak valid.');
    }
  }

  static String _extractMessage(dynamic decoded, int statusCode) {
    if (decoded is Map<String, dynamic>) {
      final errors = decoded['errors'];
      if (errors is Map) {
        for (final value in errors.values) {
          if (value is List && value.isNotEmpty) {
            final first = value.first?.toString().trim();
            if (first != null && first.isNotEmpty) {
              return first;
            }
          }
          final single = value?.toString().trim();
          if (single != null && single.isNotEmpty) {
            return single;
          }
        }
      }

      final message = decoded['message']?.toString();
      if (message != null && _isSafeUserMessage(message)) {
        return message;
      }
    }
    return _messageForStatus(statusCode);
  }

  static Never _throwMappedError(
    Object error, {
    String fallback = 'Terjadi kesalahan. Silakan coba lagi.',
  }) {
    if (error is AppException) throw error;
    if (error is TimeoutException) {
      throw const AppException('Permintaan melebihi batas waktu.');
    }
    if (error is SocketException || error is HttpException) {
      throw const AppException('Koneksi internet bermasalah.');
    }
    if (error is FormatException) {
      throw const AppException('Respon server tidak valid.');
    }
    throw AppException(fallback);
  }

  static Future<dynamic> _sendRequest(
    Future<http.Response> Function() request, {
    String fallbackMessage = 'Terjadi kesalahan. Silakan coba lagi.',
    String? debugLabel,
    Object? debugBody,
    void Function()? onDone,
  }) async {
    try {
      final stopwatch = Stopwatch()..start();
      final response = await request().timeout(_requestTimeout);
      stopwatch.stop();

      if (_httpDebug) {
        final label = debugLabel ?? 'HTTP';
        final redacted = _redactBody(debugBody);
        // ignore: avoid_print
        print('[API] $label status=${response.statusCode} ms=${stopwatch.elapsedMilliseconds}');
        if (redacted != null) {
          // ignore: avoid_print
          print('[API] $label body=$redacted');
        }
        // ignore: avoid_print
        print('[API] $label response=${response.body}');
      }

      final decoded = _decodeBody(response.body);

      if (_httpDebug && (response.statusCode < 200 || response.statusCode >= 300)) {
        final label = debugLabel ?? 'HTTP';
        // ignore: avoid_print
        print('[API] $label error=$decoded');
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return decoded;
      }

      if (response.statusCode == 401) {
        String? errorCode;
        if (decoded is Map && decoded['error_code'] is String) {
          errorCode = decoded['error_code'] as String;
        }
        unauthorizedHandler?.call(
          _extractMessage(decoded, response.statusCode),
          errorCode: errorCode,
        );
      }

      throw AppException(
        _extractMessage(decoded, response.statusCode),
        statusCode: response.statusCode,
        details: decoded,
      );
    } catch (error) {
      _throwMappedError(error, fallback: fallbackMessage);
    } finally {
      onDone?.call();
    }
  }

  static Future<Map<String, dynamic>> _getJson(
    String url, {
    bool auth = false,
    String fallbackMessage = 'Gagal memuat data.',
  }) async {
    final decoded = await _sendRequest(
      () => http.get(Uri.parse(url), headers: _headers(auth: auth)),
      fallbackMessage: fallbackMessage,
      debugLabel: 'GET $url',
    );
    if (decoded is List) return {'data': decoded};
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return <String, dynamic>{};
  }

  static Future<Map<String, dynamic>> _postJson(
    String url, {
    bool auth = false,
    Object? body,
    String fallbackMessage = 'Gagal mengirim permintaan.',
  }) async {
    final decoded = await _sendRequest(
      () async {
        final uri = Uri.parse(url);
        final ioClient = HttpClient();
        ioClient.autoUncompress = true;
        try {
          final ioReq = await ioClient.postUrl(uri);
          ioReq.followRedirects = false;
          // Set headers
          final headers = _headers(auth: auth);
          headers.forEach((key, value) {
            ioReq.headers.set(key, value);
          });
          // Write body
          final bodyStr = (body as String?) ?? '';
          if (bodyStr.isNotEmpty) {
            final bodyBytes = utf8.encode(bodyStr);
            ioReq.contentLength = bodyBytes.length;
            ioReq.add(bodyBytes);
          }
          final ioResp = await ioReq.close();
          // Read response body
          final responseBytes = <int>[];
          await for (final chunk in ioResp) {
            responseBytes.addAll(chunk);
          }
          // ignore: avoid_print
          print('[API][POST] $url status=${ioResp.statusCode} bytes=${responseBytes.length} '
              'contentEncoding=${ioResp.headers.value('content-encoding')} '
              'contentType=${ioResp.headers.value('content-type')} '
              'first32Hex=${responseBytes.take(32).map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
          String responseBody;
          try {
            responseBody = utf8.decode(responseBytes);
          } catch (decodeError) {
            // ignore: avoid_print
            print('[API][POST] $url utf8.decode FAILED: $decodeError');
            responseBody = utf8.decode(responseBytes, allowMalformed: true);
            // ignore: avoid_print
            print('[API][POST] $url malformed-decoded body=$responseBody');
          }
          // Debug: log status dan awal response
          if (ioResp.statusCode != 200 && ioResp.statusCode != 201) {
            // ignore: avoid_print
            print('[API][POST] $url status=${ioResp.statusCode} body=${responseBody.length > 200 ? responseBody.substring(0, 200) : responseBody}');
          }
          return http.Response(responseBody, ioResp.statusCode);
        } finally {
          ioClient.close();
        }
      },
      fallbackMessage: fallbackMessage,
      debugLabel: 'POST $url',
      debugBody: body,
    );
    if (decoded is List) return {'data': decoded};
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return <String, dynamic>{};
  }

  static Future<Map<String, dynamic>> _putJson(
    String url, {
    bool auth = false,
    Object? body,
    String fallbackMessage = 'Gagal memperbarui data.',
  }) async {
    final decoded = await _sendRequest(
      () => http.put(
        Uri.parse(url),
        headers: _headers(auth: auth),
        body: body,
      ),
      fallbackMessage: fallbackMessage,
      debugLabel: 'PUT $url',
      debugBody: body,
    );
    if (decoded is List) return {'data': decoded};
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return <String, dynamic>{};
  }

  static Future<void> _postWithoutBody(
    String url, {
    bool auth = false,
    String fallbackMessage = 'Gagal mengirim permintaan.',
  }) async {
    await _sendRequest(
      () => http.post(Uri.parse(url), headers: _headers(auth: auth)),
      fallbackMessage: fallbackMessage,
    );
  }

  static Future<Map<String, dynamic>> _sendMultipart(
    http.MultipartRequest request, {
    String fallbackMessage = 'Gagal mengunggah data.',
  }) async {
    try {
      final streamed = await request.send().timeout(_requestTimeout);
      final body = await streamed.stream.bytesToString();
      final decoded = _decodeBody(body);
      if (streamed.statusCode >= 200 && streamed.statusCode < 300) {
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
        return <String, dynamic>{};
      }
      throw AppException(
        _extractMessage(decoded, streamed.statusCode),
        statusCode: streamed.statusCode,
        details: decoded,
      );
    } catch (error) {
      _throwMappedError(error, fallback: fallbackMessage);
    }
  }

  // ==================== AUTH ====================

  /// Konfigurasi aplikasi dari setting panel (mis. `is_otp_required`).
  /// Dipanggil sebelum login, tidak butuh auth.
  static Future<Map<String, dynamic>> getAppConfig() async {
    return _getJson(
      '$_baseUrl/app-config',
      fallbackMessage: 'Gagal memuat konfigurasi aplikasi.',
    );
  }

  /// Cek setting `is_otp_required` dari `/api/app-config`.
  /// Default ke `false` (tanpa OTP) bila config gagal dimuat.
  static Future<bool> isOtpRequired() async {
    try {
      final config = await getAppConfig();
      final data = config['data'];
      final raw = config['is_otp_required'] ??
          (data is Map ? data['is_otp_required'] : null);
      return _parseConfigBool(raw, defaultValue: false);
    } catch (_) {
      return false;
    }
  }

  static bool _parseConfigBool(dynamic value, {required bool defaultValue}) {
    if (value == null) return defaultValue;
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final lower = value.toLowerCase();
      if (lower == 'true' || lower == '1') return true;
      if (lower == 'false' || lower == '0') return false;
    }
    return defaultValue;
  }

  static Future<Map<String, dynamic>> sendOtp(String phone, {String channel = 'wa-generic', String type = 'register'}) async {
    return _postJson(
      '$_baseUrl/send-otp',
      body: jsonEncode({'phone': phone, 'channel': channel, 'type': type}),
      fallbackMessage: 'Gagal mengirim OTP.',
    );
  }

  static Future<Map<String, dynamic>> verifyOtp(String phone, String otp, {String type = 'register'}) async {
    return _postJson(
      '$_baseUrl/verify-otp',
      body: jsonEncode(_withDevicePayload({
        'phone': phone,
        'otp': otp,
        'type': type,
      })),
      fallbackMessage: 'Gagal memverifikasi OTP.',
    );
  }

  static Future<Map<String, dynamic>> login(String login, String password) async {
    return _postJson(
      '$_baseUrl/login',
      body: jsonEncode(_withDevicePayload({
        'login': login,
        'password': password,
      })),
      fallbackMessage: 'Gagal login.',
    );
  }

  static Future<Map<String, dynamic>> loginWithPin(String login, String pin) async {
    return _postJson(
      '$_baseUrl/login-pin',
      body: jsonEncode(_withDevicePayload({
        'login': login,
        'pin': pin,
      })),
      fallbackMessage: 'Gagal login dengan PIN.',
    );
  }

  /// Poll status verifikasi perangkat baru pasca `login`/`login-pin` yang
  /// membalas `device_verification_required: true` + `pending_token`.
  static Future<Map<String, dynamic>> deviceVerificationStatus(
    String pendingToken,
  ) async {
    return _getJson(
      '$_baseUrl/device-verification/$pendingToken/status',
      fallbackMessage: 'Gagal memeriksa status verifikasi perangkat.',
    );
  }

  static Future<void> updateFcmToken(String fcmToken) async {
    await _postJson(
      '$_baseUrl/notifications/fcm-token',
      auth: true,
      body: jsonEncode({'fcm_token': fcmToken}),
      fallbackMessage: 'Gagal memperbarui token notifikasi.',
    );
  }

  static Future<Map<String, dynamic>> register({
    required String name,
    required String phone,
    String? password,
    String? passwordConfirmation,
    String? email,
    String? referralCode,
  }) async {
    return _postJson(
      '$_baseUrl/register',
      body: jsonEncode(_withDevicePayload({
        'name': name,
        'phone': phone,
        if (password != null && password.isNotEmpty) 'password': password,
        if (passwordConfirmation != null && passwordConfirmation.isNotEmpty)
          'password_confirmation': passwordConfirmation,
        if (email != null) 'email': email,
        if (referralCode != null && referralCode.isNotEmpty) 'referral_code': referralCode,
      })),
      fallbackMessage: 'Gagal mendaftar akun.',
    );
  }

  /// Poll status verifikasi akun pasca `/register` menggunakan `pendingToken`.
  /// `verified: false` selama link/OTP belum dituntaskan pengguna.
  static Future<Map<String, dynamic>> registerVerificationStatus(
    String pendingToken,
  ) async {
    return _getJson(
      '$_baseUrl/register-verification/$pendingToken/status',
      fallbackMessage: 'Gagal memeriksa status verifikasi.',
    );
  }

  /// Submit OTP untuk melengkapi verifikasi registrasi setelah link diklik.
  static Future<Map<String, dynamic>> registerVerifyOtp(
    String pendingToken,
    String otp,
  ) async {
    return _postJson(
      '$_baseUrl/register-verification/$pendingToken/verify-otp',
      body: jsonEncode({'otp': otp}),
      fallbackMessage: 'Gagal memverifikasi OTP.',
    );
  }

  static Future<Map<String, dynamic>> setPin(String pin) async {
    return _postJson(
      '$_baseUrl/set-pin',
      auth: true,
      body: jsonEncode({'pin': pin, 'pin_confirmation': pin}),
      fallbackMessage: 'Gagal menyimpan PIN.',
    );
  }

  static Future<Map<String, dynamic>> changePin(String oldPin, String newPin) async {
    return _postJson(
      '$_baseUrl/change-pin',
      auth: true,
      body: jsonEncode({'old_pin': oldPin, 'new_pin': newPin}),
      fallbackMessage: 'Gagal mengganti PIN.',
    );
  }

  static Future<Map<String, dynamic>> togglePinRequired(String pin, bool required) async {
    return _postJson(
      '$_baseUrl/toggle-pin-required',
      auth: true,
      body: jsonEncode({'pin': pin, 'pin_required': required}),
      fallbackMessage: 'Gagal memperbarui pengaturan PIN.',
    );
  }

  static Future<void> logout() async {
    await _postWithoutBody(
      '$_baseUrl/logout',
      auth: true,
      fallbackMessage: 'Gagal logout.',
    );
    _token = null;
  }

  // ==================== FORGOT PIN ====================

  /// Step 0 (UX): cek apakah `phone` sudah terdaftar sebelum kirim OTP.
  /// Backend rate-limit 10 cek/menit per IP.
  /// Returns `true` jika nomor terdaftar, `false` jika tidak.
  static Future<bool> forgotPinCheckPhone(String phone) async {
    final response = await _postJson(
      '$_baseUrl/auth/forgot-pin/check-phone',
      body: jsonEncode({'phone': phone}),
      fallbackMessage: 'Gagal memeriksa nomor.',
    );
    return response['registered'] == true;
  }

  /// Step 1: Kirim OTP 6 digit ke WhatsApp nomor `phone` untuk reset PIN.
  /// Backend rate-limit: 3x per 15 menit, min 60 detik antar request.
  static Future<Map<String, dynamic>> forgotPinSendOtp(String phone) async {
    return _postJson(
      '$_baseUrl/auth/forgot-pin/send-otp',
      body: jsonEncode({'phone': phone}),
      fallbackMessage: 'Gagal mengirim kode OTP.',
    );
  }

  /// Step 2: Verifikasi OTP. Return `reset_token` (5 menit) kalau cocok.
  static Future<Map<String, dynamic>> forgotPinVerifyOtp({
    required String phone,
    required String otp,
  }) async {
    return _postJson(
      '$_baseUrl/auth/forgot-pin/verify-otp',
      body: jsonEncode({'phone': phone, 'otp': otp}),
      fallbackMessage: 'Gagal memverifikasi kode OTP.',
    );
  }

  /// Step 3: Reset PIN dengan reset_token + pin baru (4 digit).
  static Future<Map<String, dynamic>> forgotPinReset({
    required String resetToken,
    required String pin,
  }) async {
    return _postJson(
      '$_baseUrl/auth/forgot-pin/reset',
      body: jsonEncode({
        'reset_token': resetToken,
        'pin': pin,
        'pin_confirmation': pin,
      }),
      fallbackMessage: 'Gagal mengubah PIN.',
    );
  }

  // ==================== FORGOT PASSWORD ====================

  /// Step 1: Mulai proses reset password berdasarkan `email`.
  /// Metode verifikasi ditentukan backend sesuai setting `is_otp_required`:
  ///  - true  -> OTP dikirim ke WhatsApp, `verification_method` = 'otp'.
  ///  - false -> tanpa OTP, `verification_method` = 'pin'.
  static Future<Map<String, dynamic>> forgotPassword(String email) async {
    return _postJson(
      '$_baseUrl/forgot-password',
      body: jsonEncode({'email': email}),
      fallbackMessage: 'Gagal memproses permintaan reset password.',
    );
  }

  /// Step 2: Reset password dengan kode verifikasi (OTP atau PIN sesuai
  /// `verificationMethod` dari [forgotPassword]) + password baru.
  static Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String code,
    required String password,
    required String passwordConfirmation,
    required String verificationMethod,
  }) async {
    final body = <String, dynamic>{
      'email': email,
      'password': password,
      'password_confirmation': passwordConfirmation,
    };
    if (verificationMethod == 'pin') {
      body['pin'] = code;
    } else {
      body['otp'] = code;
    }
    return _postJson(
      '$_baseUrl/reset-password',
      body: jsonEncode(body),
      fallbackMessage: 'Gagal mereset password.',
    );
  }

  // ==================== PROFILE ====================

  static Future<Map<String, dynamic>> getProfile() async {
    return _getJson(
      '$_baseUrl/profile',
      auth: true,
      fallbackMessage: 'Gagal memuat profil.',
    );
  }

  static Future<Map<String, dynamic>> getLevelDetail() async {
    return _getJson(
      '$_baseUrl/profile/level',
      auth: true,
      fallbackMessage: 'Gagal memuat detail level.',
    );
  }

  static Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) async {
    return _putJson(
      '$_baseUrl/profile',
      auth: true,
      body: jsonEncode(data),
      fallbackMessage: 'Gagal memperbarui profil.',
    );
  }

  static Future<Map<String, dynamic>> uploadAvatar(File avatarFile) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/profile/avatar'),
    );
    request.headers.addAll(_headers(auth: true));
    request.headers.remove('Content-Type');
    request.files.add(await http.MultipartFile.fromPath('avatar', avatarFile.path));

    return _sendMultipart(
      request,
      fallbackMessage: 'Gagal mengunggah foto profil.',
    );
  }

  static Future<Map<String, dynamic>> changePassword(String currentPassword, String newPassword, String confirmPassword) async {
    return _postJson(
      '$_baseUrl/profile/change-password',
      auth: true,
      body: jsonEncode({
        'current_password': currentPassword,
        'password': newPassword,
        'password_confirmation': confirmPassword,
      }),
      fallbackMessage: 'Gagal mengganti password.',
    );
  }

  static Future<Map<String, dynamic>> getReceiptSettings() async {
    return _getJson(
      '$_baseUrl/profile/receipt-settings',
      auth: true,
      fallbackMessage: 'Gagal memuat pengaturan struk.',
    );
  }

  static Future<Map<String, dynamic>> updateReceiptSettings(
      Map<String, dynamic> data) async {
    return _putJson(
      '$_baseUrl/profile/receipt-settings',
      auth: true,
      body: jsonEncode(data),
      fallbackMessage: 'Gagal menyimpan pengaturan struk.',
    );
  }

  // ==================== TRANSACTIONS ====================

  static Future<Map<String, dynamic>> getTransactions({String? type, int page = 1}) async {
    String url = '$_baseUrl/transactions?page=$page';
    if (type != null) url += '&type=$type';
    return _getJson(url, auth: true, fallbackMessage: 'Gagal memuat transaksi.');
  }

  static Future<Map<String, dynamic>> getTransactionDetail(String orderId) async {
    return _getJson(
      '$_baseUrl/transactions/$orderId',
      auth: true,
      fallbackMessage: 'Gagal memuat detail transaksi.',
    );
  }

  // ==================== CONTACTS ====================

  static Future<List<dynamic>> getContacts({String? category, bool? favorite, String? search}) async {
    final params = <String>[];
    if (category != null) params.add('category=${Uri.encodeComponent(category)}');
    if (favorite == true) params.add('favorite=1');
    if (search != null) params.add('search=${Uri.encodeComponent(search)}');
    
    String url = '$_baseUrl/contacts';
    if (params.isNotEmpty) url += '?${params.join('&')}';
    
    final response = await _getJson(url, auth: true, fallbackMessage: 'Gagal memuat kontak.');
    final data = response['data'] ?? response['contacts'] ?? response['items'] ?? response['results'] ?? response;
    return data is List ? data : <dynamic>[];
  }

  static Future<Map<String, dynamic>> createContact({
    required String name,
    String? phone,
    String? email,
    String? category,
    String? avatar,
  }) async {
    return _postJson(
      '$_baseUrl/contacts',
      auth: true,
      body: jsonEncode({
        'name': name,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        if (email != null && email.isNotEmpty) 'email': email,
        if (category != null && category.isNotEmpty) 'category': category,
        if (avatar != null && avatar.isNotEmpty) 'avatar': avatar,
      }),
      fallbackMessage: 'Gagal menambahkan kontak.',
    );
  }

  static Future<Map<String, dynamic>> toggleFavorite(int contactId) async {
    return _postWithoutBody('$_baseUrl/contacts/$contactId/toggle-favorite', auth: true)
        .then((_) => <String, dynamic>{'message': 'Favorit diperbarui'});
  }

  // ==================== TRANSFERS ====================

  static Future<Map<String, dynamic>> transfer(int receiverId, double amount, String pin, {String? notes, bool biometricAuth = false}) async {
    return _postJson(
      '$_baseUrl/transfers',
      auth: true,
      body: jsonEncode({
        'receiver_id': receiverId,
        'amount': amount,
        'pin': pin,
        if (notes != null) 'notes': notes,
        if (biometricAuth) 'biometric_auth': true,
      }),
      fallbackMessage: 'Gagal melakukan transfer.',
    );
  }

  static Future<Map<String, dynamic>> getTransfers() async {
    return _getJson('$_baseUrl/transfers', auth: true, fallbackMessage: 'Gagal memuat data transfer.');
  }

  static Future<Map<String, dynamic>> createWithdrawalRequest({
    required int contactId,
    required double amount,
    String? pin,
    bool biometricAuth = false,
  }) async {
    return _postJson(
      '$_baseUrl/withdrawals',
      auth: true,
      body: jsonEncode({
        'contact_id': contactId,
        'amount': amount,
        if (pin != null && pin.isNotEmpty) 'pin': pin,
        if (biometricAuth) 'biometric_auth': true,
      }),
      fallbackMessage: 'Gagal mengajukan penarikan.',
    );
  }

  // ==================== TOPUP ====================

  /// Create a QRIS top up via OnixPayz. Returns
  /// `{ status, message, data: { topup_id, reference_id, amount, qris_string,
  /// payment_url, expires_at, expires_in_seconds } }`.
  static Future<Map<String, dynamic>> createTopup(int amount) async {
    return _postJson(
      '$_baseUrl/topups',
      auth: true,
      body: jsonEncode({'amount': amount}),
      fallbackMessage: 'Gagal membuat top up.',
    );
  }

  /// Poll a topup transaction status. The webhook is the primary settlement
  /// path; this endpoint is a fallback for the foreground UI.
  static Future<Map<String, dynamic>> checkTopupStatus(int topupId) async {
    return _getJson(
      '$_baseUrl/topups/$topupId/status',
      auth: true,
      fallbackMessage: 'Gagal cek status pembayaran.',
    );
  }

  static Future<List<Map<String, dynamic>>> getRecentTopups() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/topups'),
        headers: _headers(auth: true),
      ).timeout(_requestTimeout);
      final body = _decodeBody(response.body);
      final data = body['data'] ?? body;
      if (data is List) {
        return List<Map<String, dynamic>>.from(data);
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  static Future<Map<String, dynamic>> getTopupStatus(int topupId) async {
    return _getJson('$_baseUrl/topups/$topupId', auth: true, fallbackMessage: 'Gagal memuat status top up.');
  }

  static Future<void> checkPendingTopups() async {
    try {
      await http.post(
        Uri.parse('$_baseUrl/topups/check-pending'),
        headers: _headers(auth: true),
      );
    } catch (_) {}
  }

  static Future<void> checkPendingPpob() async {
    try {
      await http.post(
        Uri.parse('$_baseUrl/ppob/check-pending'),
        headers: _headers(auth: true),
      );
    } catch (_) {}
  }

  static Future<Map<String, dynamic>> checkTransactionStatus({
    required String orderId,
  }) async {
    return _postJson(
      '$_baseUrl/ppob/check-status',
      auth: true,
      body: jsonEncode({'order_id': orderId}),
      fallbackMessage: 'Gagal cek status transaksi.',
    );
  }

  // ==================== NOTIFICATIONS ====================

  static Future<Map<String, dynamic>> getNotifications({int page = 1}) async {
    return _getJson('$_baseUrl/notifications?page=$page', auth: true, fallbackMessage: 'Gagal memuat notifikasi.');
  }

  static Future<void> markNotificationRead(int id) async {
    await _postWithoutBody(
      '$_baseUrl/notifications/$id/read',
      auth: true,
      fallbackMessage: 'Gagal memperbarui notifikasi.',
    );
  }

  // ==================== SERVICES ====================

  static Future<List<dynamic>> getServices({String? category}) async {
    String url = '$_baseUrl/services';
    if (category != null) url += '?category=$category';
    final response = await _getJson(url, auth: true, fallbackMessage: 'Gagal memuat layanan.');
    final data = response['data'] ?? response;
    return data is List ? data : <dynamic>[];
  }

  // ==================== ANALYTICS ====================

  static Future<Map<String, dynamic>> getAnalytics({String period = 'monthly'}) async {
    return _getJson('$_baseUrl/analytics?period=$period', auth: true, fallbackMessage: 'Gagal memuat analitik.');
  }

  // ==================== PAYMENT REQUESTS ====================

  static Future<Map<String, dynamic>> createPaymentRequest(int targetId, double amount, {String? notes}) async {
    return _postJson(
      '$_baseUrl/payment-requests',
      auth: true,
      body: jsonEncode({
        'target_id': targetId,
        'amount': amount,
        if (notes != null) 'notes': notes,
      }),
      fallbackMessage: 'Gagal membuat permintaan pembayaran.',
    );
  }

  // ==================== PPOB ====================

  static Future<List<dynamic>> getPpobCategories({String cmd = 'prepaid'}) async {
    final data = await _getJson(
      '$_baseUrl/ppob/categories?cmd=$cmd',
      fallbackMessage: 'Gagal memuat kategori PPOB.',
    );
    return data['data'] ?? [];
  }

  static Future<List<dynamic>> getPpobBrands({
    String cmd = 'prepaid',
    String? category,
    String? productTypeFilter,
  }) async {
    String url = '$_baseUrl/ppob/brands?cmd=$cmd';
    if (category != null) url += '&category=${Uri.encodeComponent(category)}';
    if (productTypeFilter != null) url += '&product_type=${Uri.encodeComponent(productTypeFilter)}';
    final data = await _getJson(url, fallbackMessage: 'Gagal memuat brand PPOB.');
    return data['data'] ?? [];
  }

  static Future<List<dynamic>> getPpobProducts({
    String cmd = 'prepaid',
    String? category,
    String? brand,
    String? productTypeFilter,
    String? search,
    bool tokenListrik = false,
  }) async {
    String url = '$_baseUrl/ppob/products?cmd=$cmd';
    if (category != null) url += '&category=${Uri.encodeComponent(category)}';
    if (brand != null) url += '&brand=${Uri.encodeComponent(brand)}';
    if (productTypeFilter != null) url += '&product_type=${Uri.encodeComponent(productTypeFilter)}';
    if (search != null) url += '&search=${Uri.encodeComponent(search)}';
    if (tokenListrik) url += '&token_listrik=1';
    final data = await _getJson(url, auth: true, fallbackMessage: 'Gagal memuat produk PPOB.');
    return data['data'] ?? [];
  }

  static Future<Map<String, dynamic>> purchasePpob({
    required String buyerSkuCode,
    required String customerNo,
    required String pin,
    bool biometricAuth = false,
    String? provider,
    String? category,
    String paymentSource = 'saldo',
    double? amount,
    // Identifies the desktop-app cashier who confirmed this sale. The
    // backend decides whether these are actually required (a store only
    // enforces kasir_code/kasir_pin once it has at least one Kasir
    // registered — see ValidatesKasir::validateKasirOrPin server-side), so
    // it's safe to always pass them alongside `pin`.
    String? kasirCode,
    String? kasirPin,
  }) async {
    return _postJson(
      '$_baseUrl/ppob/purchase',
      auth: true,
      body: jsonEncode({
        'buyer_sku_code': buyerSkuCode,
        'customer_no': customerNo,
        'pin': pin,
        if (biometricAuth) 'biometric_auth': true,
        if (provider != null && provider.isNotEmpty) 'provider': provider,
        if (category != null && category.isNotEmpty) 'category': category,
        'payment_source': paymentSource,
        if (amount != null) 'amount': amount,
        if (kasirCode != null) 'kasir_code': kasirCode,
        if (kasirPin != null) 'kasir_pin': kasirPin,
      }),
      fallbackMessage: 'Gagal melakukan pembelian.',
    );
  }

  /// Purchase e-wallet via Loket Bayar (Nominal Lainnya / custom amount).
  /// Requires refId from prior inquiry.
  static Future<Map<String, dynamic>> purchaseLoketbayar({
    required String kodeProduk,
    required String customerNo,
    required int nominal,
    required String refId,
    required String pin,
    bool biometricAuth = false,
    String paymentSource = 'saldo',
    String? productName,
    String? kasirCode,
    String? kasirPin,
  }) async {
    return _postJson(
      '$_baseUrl/loketbayar/purchase',
      auth: true,
      body: jsonEncode({
        'kode_produk': kodeProduk,
        'customer_no': customerNo,
        'nominal': nominal,
        'ref_id': refId,
        'pin': pin,
        if (biometricAuth) 'biometric_auth': true,
        'payment_source': paymentSource,
        if (productName != null) 'product_name': productName,
        if (kasirCode != null) 'kasir_code': kasirCode,
        if (kasirPin != null) 'kasir_pin': kasirPin,
      }),
      fallbackMessage: 'Gagal melakukan pembelian.',
    );
  }

  /// Cek status transaksi PPOB yang masih `pending` (dipanggil berulang oleh
  /// `PendingPpobService` sampai statusnya `completed`/`failed`). Backend
  /// meng-handle transaksi Digiflazz maupun Loketbayar lewat endpoint yang
  /// sama — lihat PpobController::checkStatus di backend.
  static Future<Map<String, dynamic>> checkPpobStatus({required String orderId}) async {
    return _postJson(
      '$_baseUrl/ppob/check-status',
      auth: true,
      body: jsonEncode({'order_id': orderId}),
      fallbackMessage: 'Gagal memeriksa status transaksi.',
    );
  }

  static Future<Map<String, dynamic>> checkGameUsername({
    required String gameCode,
    required String userId,
    String provider = 'apigames',
  }) async {
    return _postJson(
      '$_baseUrl/ppob/check-game-username',
      auth: true,
      body: jsonEncode({
        'game_code': gameCode,
        'user_id': userId,
        'provider': provider,
      }),
      fallbackMessage: 'Gagal memeriksa username game.',
    );
  }

  /// Inquiry tagihan PDAM via Loket Bayar.
  ///
  /// Endpoint khusus PDAM yang bypass tabel produk lokal — backend langsung
  /// panggil Loket Bayar pakai `kode_produk` (mis. `PDAM4400019`) dan idpel.
  /// Server akan summarize nominal/admin/total dari array `tagihan` provider.
  static Future<Map<String, dynamic>> pdamInquiry({
    required String kodeProduk,
    required String customerNo,
  }) async {
    return _postJson(
      '$_baseUrl/loketbayar/pdam/inquiry',
      auth: true,
      body: jsonEncode({
        'kode_produk': kodeProduk,
        'customer_no': customerNo,
      }),
      fallbackMessage: 'Gagal melakukan cek tagihan PDAM.',
    );
  }

  /// Endpoint khusus BPJS — sama seperti PDAM, backend langsung panggil
  /// Loket Bayar pakai `kode_produk` (mis. `BPJSKS`) dan nomor peserta.
  /// Server akan summarize nominal/admin/total dari array `tagihan` provider.
  static Future<Map<String, dynamic>> bpjsInquiry({
    required String kodeProduk,
    required String customerNo,
  }) async {
    return _postJson(
      '$_baseUrl/loketbayar/bpjs/inquiry',
      auth: true,
      body: jsonEncode({
        'kode_produk': kodeProduk,
        'customer_no': customerNo,
      }),
      fallbackMessage: 'Gagal melakukan cek tagihan BPJS.',
    );
  }

  static Future<Map<String, dynamic>> ppobInquiry({
    String? buyerSkuCode,
    required String customerNo,
    double? amount,
    String? provider,
    String? category,
    String? brand,
    String? selectedSkuCode,
  }) async {
    final body = <String, dynamic>{
      'customer_no': customerNo,
    };
    if (buyerSkuCode != null && buyerSkuCode.isNotEmpty) {
      body['buyer_sku_code'] = buyerSkuCode;
    }
    if (amount != null) {
      body['amount'] = amount;
    }
    if (provider != null) {
      body['provider'] = provider;
    }
    if (category != null && category.isNotEmpty) {
      body['category'] = category;
    }
    if (brand != null && brand.isNotEmpty) {
      body['brand'] = brand;
    }
    if (selectedSkuCode != null && selectedSkuCode.isNotEmpty) {
      body['selected_sku_code'] = selectedSkuCode;
    }
    return _postJson(
      '$_baseUrl/ppob/inquiry',
      auth: true,
      body: jsonEncode(body),
      fallbackMessage: 'Gagal melakukan pengecekan produk.',
    );
  }

  static Future<Map<String, dynamic>> ppobInquiryPln({
    required String customerNo,
  }) async {
    return _postJson(
      '$_baseUrl/ppob/inquiry-pln',
      auth: true,
      body: jsonEncode({
        'customer_no': customerNo,
      }),
      fallbackMessage: 'Gagal melakukan cek tagihan PLN.',
    );
  }

  static Future<Map<String, dynamic>> ppobInquiryPlnRaw({
    required String customerNo,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/ppob/inquiry-pln'),
            headers: _headers(auth: true),
            body: jsonEncode({'customer_no': customerNo}),
          )
          .timeout(_requestTimeout);

      final rawBody = response.body;
      dynamic parsed;
      try {
        parsed = _decodeBody(rawBody);
      } catch (_) {
        parsed = <String, dynamic>{};
      }

      return {
        'ok': response.statusCode >= 200 && response.statusCode < 300,
        'status_code': response.statusCode,
        'raw_body': rawBody,
        'parsed': parsed,
      };
    } catch (error) {
      return {
        'ok': false,
        'status_code': null,
        'raw_body': '',
        'parsed': <String, dynamic>{
          'status': 'error',
          'message': userFriendlyMessage(error, fallback: 'Cek tagihan gagal'),
          'customer_no': customerNo,
        },
      };
    }
  }

  static Future<Map<String, dynamic>> purchasePpobPostpaid({
    required String buyerSkuCode,
    required String customerNo,
    required String pin,
    required double amount,
    bool biometricAuth = false,
    String paymentSource = 'saldo',
  }) async {
    return _postJson(
      '$_baseUrl/ppob/purchase-postpaid',
      auth: true,
      body: jsonEncode({
        'buyer_sku_code': buyerSkuCode,
        'customer_no': customerNo,
        'pin': pin,
        'amount': amount,
        if (biometricAuth) 'biometric_auth': true,
        'payment_source': paymentSource,
      }),
      fallbackMessage: 'Gagal melakukan pembayaran.',
    );
  }

  // ==================== KYC ====================

  static Future<Map<String, dynamic>> uploadKyc({
    required File ktpFile,
    required File selfieFile,
  }) async {
    final uri = Uri.parse('$_baseUrl/profile/kyc');
    final request = http.MultipartRequest('POST', uri);
    // Pakai _headers() agar X-Device-Id ikut terkirim (wajib sejak backend
    // meng-enforce single-device login). Content-Type dihapus supaya multipart
    // bisa menetapkan boundary-nya sendiri.
    request.headers.addAll(_headers(auth: true));
    request.headers.remove('Content-Type');
    request.files.add(await http.MultipartFile.fromPath('kyc_ktp', ktpFile.path));
    request.files.add(await http.MultipartFile.fromPath('kyc_selfie', selfieFile.path));
    return _sendMultipart(request, fallbackMessage: 'Gagal mengunggah data KYC.');
  }

  static Future<Map<String, dynamic>> getKycStatus() async {
    return _getJson('$_baseUrl/profile/kyc-status', auth: true, fallbackMessage: 'Gagal memuat status KYC.');
  }

  // ==================== BANK TRANSFER ====================

  static Future<Map<String, dynamic>> getBanks() async {
    return _getJson('$_baseUrl/bank-transfers/banks', auth: true, fallbackMessage: 'Gagal memuat daftar bank.');
  }

  static Future<Map<String, dynamic>> bankInquiry({
    required String bankCode,
    required String accountNumber,
  }) async {
    return _postJson(
      '$_baseUrl/bank-transfers/inquiry',
      auth: true,
      body: jsonEncode({
        'bank_code': bankCode,
        'account_number': accountNumber,
      }),
      fallbackMessage: 'Gagal melakukan pengecekan rekening.',
    );
  }

  // ==================== MERCHANT KYC ====================

  static Future<Map<String, dynamic>> getMerchantKycStatus() async {
    return _getJson(
      '$_baseUrl/merchant-kyc/status',
      auth: true,
      fallbackMessage: 'Gagal memuat status KYC.',
    );
  }

  static Future<Map<String, dynamic>> getMerchantLimitDetail() async {
    return _getJson(
      '$_baseUrl/merchant-kyc/limit-detail',
      auth: true,
      fallbackMessage: 'Gagal memuat detail limit.',
    );
  }

  static Future<Map<String, dynamic>> getLimitHistory() async {
    return _getJson(
      '$_baseUrl/merchant-kyc/limit-history',
      auth: true,
      fallbackMessage: 'Gagal memuat riwayat limit.',
    );
  }

  static Future<Map<String, dynamic>> payLimitBill({
    required String method,
    String? pin,
    bool biometricAuth = false,
  }) async {
    return _postJson(
      '$_baseUrl/merchant-kyc/pay-bill',
      auth: true,
      body: jsonEncode({
        'method': method,
        if (pin != null && pin.isNotEmpty) 'pin': pin,
        if (biometricAuth) 'biometric_auth': true,
      }),
      fallbackMessage: 'Gagal membayar tagihan.',
    );
  }

  static Future<Map<String, dynamic>> submitMerchantKyc({
    required String storeName,
    required String ownerName,
    required String phone,
    required String accountNumber,
    required String bankName,
    required String address,
    required File ktpPhoto,
    required File selfiePhoto,
    required String businessType,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/merchant-kyc'),
    );
    request.headers.addAll(_headers(auth: true));
    request.headers.remove('Content-Type');
    request.fields['store_name'] = storeName;
    request.fields['owner_name'] = ownerName;
    request.fields['phone'] = phone;
    request.fields['account_number'] = accountNumber;
    request.fields['bank_name'] = bankName;
    request.fields['address'] = address;
    request.fields['business_type'] = businessType;
    request.files.add(await http.MultipartFile.fromPath('ktp_photo', ktpPhoto.path));
    request.files.add(await http.MultipartFile.fromPath('selfie_photo', selfiePhoto.path));

    return _sendMultipart(request, fallbackMessage: 'Gagal mengirim pengajuan KYC.');
  }

  static Future<Map<String, dynamic>> bankTransferStatus() async {
    return _getJson(
      '$_baseUrl/bank-transfers/status',
      auth: true,
      fallbackMessage: 'Gagal memuat status transfer.',
    );
  }

  static Future<Map<String, dynamic>> bankTransferInquiry({
    required String bankCode,
    required String accountNumber,
    required double amount,
  }) async {
    return _postJson(
      '$_baseUrl/bank-transfers/inquiry',
      auth: true,
      body: jsonEncode({
        'bank_code': bankCode,
        'account_number': accountNumber,
        'amount': amount,
      }),
      fallbackMessage: 'Gagal melakukan inquiry transfer.',
    );
  }

  static Future<Map<String, dynamic>> bankTransferPayment({
    required String kodeProduk,
    required String accountNumber,
    required String refId,
    required double nominal,
    required String bankName,
    required String accountName,
    required double amount,
    required double admin,
    required String pin,
    String? notes,
    bool biometricAuth = false,
    double? providerTotal,
  }) async {
    return _postJson(
      '$_baseUrl/bank-transfers/payment',
      auth: true,
      body: jsonEncode({
        'kode_produk': kodeProduk,
        'account_number': accountNumber,
        'ref_id': refId,
        'nominal': nominal,
        'bank_name': bankName,
        'account_name': accountName,
        'amount': amount,
        'admin': admin,
        if (providerTotal != null) 'provider_total': providerTotal,
        'pin': pin,
        if (notes != null) 'notes': notes,
        if (biometricAuth) 'biometric_auth': true,
      }),
      fallbackMessage: 'Gagal melakukan transfer bank.',
    );
  }

  static Future<Map<String, dynamic>> bankTransfer({
    required String bankCode,
    required String bankName,
    required String accountNumber,
    required String accountName,
    required double amount,
    required String pin,
    String? notes,
    bool biometricAuth = false,
  }) async {
    return _postJson(
      '$_baseUrl/bank-transfers',
      auth: true,
      body: jsonEncode({
        'bank_code': bankCode,
        'bank_name': bankName,
        'account_number': accountNumber,
        'account_name': accountName,
        'amount': amount,
        'pin': pin,
        if (notes != null) 'notes': notes,
        if (biometricAuth) 'biometric_auth': true,
      }),
      fallbackMessage: 'Gagal melakukan transfer bank.',
    );
  }

  // ==================== QRIS MERCHANT ====================

  static Future<Map<String, dynamic>> getQrisMerchantStatus() async {
    return _getJson('$_baseUrl/qris-merchant/status', auth: true, fallbackMessage: 'Gagal memuat status QRIS merchant.');
  }

  static Future<Map<String, dynamic>> registerQrisMerchant({
    required String businessName,
    required String businessType,
    required File photoProduct,
    required File photoPlace,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/qris-merchant/register'),
    );
    request.headers.addAll(_headers(auth: true));
    request.headers.remove('Content-Type');
    request.fields['business_name'] = businessName;
    request.fields['business_type'] = businessType;
    request.files.add(await http.MultipartFile.fromPath('photo_product', photoProduct.path));
    request.files.add(await http.MultipartFile.fromPath('photo_place', photoPlace.path));

    return _sendMultipart(request, fallbackMessage: 'Gagal mengirim pengajuan QRIS merchant.');
  }

  static Future<Map<String, dynamic>> createQrisPayment(int amount) async {
    return _postJson(
      '$_baseUrl/qris-merchant/create-payment',
      auth: true,
      body: jsonEncode({'amount': amount}),
      fallbackMessage: 'Gagal membuat pembayaran QRIS.',
    );
  }

  static Future<Map<String, dynamic>> getQrisTransactions() async {
    return _getJson('$_baseUrl/qris-merchant/transactions', auth: true, fallbackMessage: 'Gagal memuat transaksi QRIS.');
  }

  static Future<Map<String, dynamic>> withdrawQrisBalance({
    required double amount,
    required String pin,
  }) async {
    return _postJson(
      '$_baseUrl/qris-merchant/withdraw',
      auth: true,
      body: jsonEncode({'amount': amount, 'pin': pin}),
      fallbackMessage: 'Gagal melakukan penarikan saldo QRIS.',
    );
  }

  static Future<Map<String, dynamic>> updateQrisNote({
    required int transactionId,
    required String? note,
  }) async {
    return _putJson(
      '$_baseUrl/qris-merchant/transactions/$transactionId/note',
      auth: true,
      body: jsonEncode({'note': note}),
      fallbackMessage: 'Gagal memperbarui catatan QRIS.',
    );
  }

  // ==================== QRIS CUSTOMER PAYMENT ====================

  static Future<Map<String, dynamic>> getQrisPaymentDetails(String qrisCode) async {
    // Mock data for testing when backend endpoints aren't ready
    if (useMockQris) {
      await Future.delayed(const Duration(milliseconds: 500)); // Simulate network delay
      return {
        'status': 'success',
        'data': {
          'merchant_name': 'Toko Merpati Jaya',
          'merchant_location': 'Jl. Merdeka No. 123, Jakarta',
          'amount': 50000.0,
          'transaction_id': 'QRIS${DateTime.now().millisecondsSinceEpoch}',
        }
      };
    }
    
    return _postJson(
      '$_baseUrl/qris-payment/parse',
      auth: true,
      body: jsonEncode({'qris_code': qrisCode}),
      fallbackMessage: 'Gagal memproses kode QRIS.',
    );
  }

  static Future<Map<String, dynamic>> submitQrisPayment({
    required String qrisCode,
    required double amount,
    required String pin,
    String? notes,
  }) async {
    // Mock data for testing when backend endpoints aren't ready
    if (useMockQris) {
      await Future.delayed(const Duration(milliseconds: 800)); // Simulate network delay
      return {
        'status': 'success',
        'data': {
          'id': 'TXN${DateTime.now().millisecondsSinceEpoch}',
          'reference_id': 'QRIS${DateTime.now().millisecondsSinceEpoch}',
          'status': 'completed',
          'amount': amount,
          'created_at': DateTime.now().toIso8601String(),
          'merchant_name': 'Toko Merpati Jaya',
          'merchant_location': 'Jl. Merdeka No. 123, Jakarta',
        }
      };
    }
    
    return _postJson(
      '$_baseUrl/qris-payment/submit',
      auth: true,
      body: jsonEncode({
        'qris_code': qrisCode,
        'amount': amount,
        'pin': pin,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      }),
      fallbackMessage: 'Gagal melakukan pembayaran QRIS.',
    );
  }

  static Future<Map<String, dynamic>> updateTransactionNote({
    required int transactionId,
    required String? note,
  }) async {
    return _putJson(
      '$_baseUrl/transactions/$transactionId/note',
      auth: true,
      body: jsonEncode({'note': note}),
      fallbackMessage: 'Gagal memperbarui catatan transaksi.',
    );
  }

  // ── Banners ──
  static Future<List<Map<String, dynamic>>> getBanners() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/banners'),
        headers: _headers(),
      );
      final data = jsonDecode(response.body);
      if (data['status'] == 'success' && data['data'] != null) {
        return List<Map<String, dynamic>>.from(data['data']);
      }
    } catch (_) {}
    return [];
  }

  // ── PPOB Menu (ordered categories from admin) ──
  static Future<Map<String, dynamic>> getPpobMenu() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/ppob/menu'),
        headers: _headers(),
      );
      final data = jsonDecode(response.body);
      if (data['status'] == 'success' && data['data'] != null) {
        return Map<String, dynamic>.from(data['data']);
      }
    } catch (_) {}
    return {};
  }

  static Future<List<dynamic>> getPromoProducts() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/ppob/promo-products'),
        headers: _headers(auth: true),
      );
      final data = jsonDecode(response.body);
      if (data['status'] == 'success') {
        return data['data'] ?? [];
      }
    } catch (_) {}
    return [];
  }

  // ==================== PPOB SAVED CUSTOMERS ====================

  static Future<List<dynamic>> getSavedCustomers({String? category}) async {
    String url = '$_baseUrl/ppob/saved-customers';
    if (category != null) url += '?category=${Uri.encodeComponent(category)}';
    final response = await _getJson(url, auth: true, fallbackMessage: 'Gagal memuat daftar pelanggan.');
    final data = response['data'] ?? response['customers'] ?? response['items'] ?? response;
    return data is List ? data : <dynamic>[];
  }

  static Future<Map<String, dynamic>> saveCustomer({
    required String name,
    required String customerNumber,
    String? category,
    String? notes,
  }) async {
    return _postJson(
      '$_baseUrl/ppob/saved-customers',
      auth: true,
      body: jsonEncode({
        'name': name,
        'customer_number': customerNumber,
        if (category != null) 'category': category,
        if (notes != null) 'notes': notes,
      }),
      fallbackMessage: 'Gagal menyimpan pelanggan.',
    );
  }

  static Future<void> deleteSavedCustomer(int id) async {
    await _sendRequest(
      () => http.delete(Uri.parse('$_baseUrl/ppob/saved-customers/$id'), headers: _headers(auth: true)),
      fallbackMessage: 'Gagal menghapus pelanggan.',
    );
  }

  // ==================== COMPLAINTS ====================

  static Future<Map<String, dynamic>> createComplaint({
    required String category,
    required String subject,
    required String message,
    int? transactionId,
    String? transactionCode,
  }) async {
    return _postJson(
      '$_baseUrl/complaints',
      auth: true,
      body: jsonEncode({
        'category': category,
        'subject': subject,
        'message': message,
        if (transactionId != null) 'transaction_id': transactionId,
        if (transactionCode != null) 'transaction_code': transactionCode,
      }),
      fallbackMessage: 'Gagal mengirim pengaduan.',
    );
  }

  static Future<List<dynamic>> getComplaints() async {
    final response = await _getJson('$_baseUrl/complaints', auth: true, fallbackMessage: 'Gagal memuat pengaduan.');
    final data = response['data'] ?? response['complaints'] ?? response['items'] ?? response;
    return data is List ? data : <dynamic>[];
  }

  // ==================== TRANSFERS SEARCH ====================

  static Future<Map<String, dynamic>> searchUser(String phone) async {
    return _postJson(
      '$_baseUrl/transfers/search-user',
      auth: true,
      body: jsonEncode({'phone': phone}),
      fallbackMessage: 'Pengguna tidak ditemukan.',
    );
  }

  // ==================== AGENTS ====================

  static Future<Map<String, dynamic>> getAgens() async {
    return _getJson('$_baseUrl/hierarchy/agens', auth: true, fallbackMessage: 'Gagal memuat daftar agen.');
  }

  static Future<Map<String, dynamic>> updateMargin(double margin) async {
    return _putJson(
      '$_baseUrl/hierarchy/margin',
      auth: true,
      body: jsonEncode({'markup_margin': margin}),
      fallbackMessage: 'Gagal memperbarui margin.',
    );
  }

  /// Buat akun agen baru di bawah master yang sedang login.
  static Future<Map<String, dynamic>> addAgen({
    required String name,
    required String phone,
    required String password,
    String? email,
    String? referralCode,
  }) async {
    return _postJson(
      '$_baseUrl/hierarchy/agens',
      auth: true,
      body: jsonEncode({
        'name': name,
        'phone': phone,
        'password': password,
        if (email != null && email.isNotEmpty) 'email': email,
        if (referralCode != null && referralCode.isNotEmpty) 'referral_code': referralCode,
      }),
      fallbackMessage: 'Gagal menambah agen.',
    );
  }

  /// Tautkan akun existing (pernah daftar mandiri) ke hierarki master yang
  /// sedang login berdasarkan No. HP, tanpa membuat akun baru.
  static Future<Map<String, dynamic>> addExistingAgen({required String phone}) async {
    return _postJson(
      '$_baseUrl/hierarchy/agens/link',
      auth: true,
      body: jsonEncode({'phone': phone}),
      fallbackMessage: 'Gagal menambahkan agen.',
    );
  }

  /// Hapus agen dari hierarki user master.
  static Future<Map<String, dynamic>> deleteAgen(int agenId) async {
    final decoded = await _sendRequest(
      () => http.delete(
        Uri.parse('$_baseUrl/hierarchy/agens/$agenId'),
        headers: _headers(auth: true),
      ),
      fallbackMessage: 'Gagal menghapus agen.',
      debugLabel: 'DELETE $_baseUrl/hierarchy/agens/$agenId',
    );
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return <String, dynamic>{};
  }
}

/// HTTP client yang tidak follow redirect.
/// Saat server kirim 301/302, Dart default-nya convert POST→GET.
/// Client ini set followRedirects=false pada BaseRequest.
class _NoRedirectClient extends http.BaseClient {
  final http.Client _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.followRedirects = false;
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}
