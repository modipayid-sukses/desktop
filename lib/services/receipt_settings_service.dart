import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';

class ReceiptSettingsService {
  static const String _keyStoreName = 'receipt_store_name';
  static const String _keyPhone = 'receipt_store_phone';
  static const String _keyProvinceCode = 'receipt_province_code';
  static const String _keyProvinceName = 'receipt_province_name';
  static const String _keyRegencyCode = 'receipt_regency_code';
  static const String _keyCity = 'receipt_city';
  static const String _keyDistrictCode = 'receipt_district_code';
  static const String _keyDistrict = 'receipt_district';
  static const String _keyVillageCode = 'receipt_village_code';
  static const String _keyVillage = 'receipt_village';
  static const String _keyStreet = 'receipt_street';
  static const String _keyThanks = 'receipt_thanks_message';

  static Map<String, String> _localCacheToMap(SharedPreferences prefs) {
    return {
      'storeName': prefs.getString(_keyStoreName) ?? '',
      'phone': prefs.getString(_keyPhone) ?? '',
      'provinceCode': prefs.getString(_keyProvinceCode) ?? '',
      'provinceName': prefs.getString(_keyProvinceName) ?? '',
      'regencyCode': prefs.getString(_keyRegencyCode) ?? '',
      'city': prefs.getString(_keyCity) ?? '',
      'districtCode': prefs.getString(_keyDistrictCode) ?? '',
      'district': prefs.getString(_keyDistrict) ?? '',
      'villageCode': prefs.getString(_keyVillageCode) ?? '',
      'village': prefs.getString(_keyVillage) ?? '',
      'street': prefs.getString(_keyStreet) ?? '',
      'thanksMessage':
          prefs.getString(_keyThanks) ?? 'Terimakasih telah berbelanja',
    };
  }

  static Map<String, String> _serverDataToMap(Map<String, dynamic> data) {
    String s(String key) => (data[key] ?? '').toString();
    final thanks = s('thanks_message');
    return {
      'storeName': s('store_name'),
      'phone': s('phone'),
      'provinceCode': s('province_code'),
      'provinceName': s('province_name'),
      'regencyCode': s('regency_code'),
      'city': s('city'),
      'districtCode': s('district_code'),
      'district': s('district'),
      'villageCode': s('village_code'),
      'village': s('village'),
      'street': s('street'),
      'thanksMessage':
          thanks.isEmpty ? 'Terimakasih telah berbelanja' : thanks,
    };
  }

  static Future<void> _writeLocalCache(
    SharedPreferences prefs,
    Map<String, String> data,
  ) async {
    await prefs.setString(_keyStoreName, (data['storeName'] ?? '').trim());
    await prefs.setString(_keyPhone, (data['phone'] ?? '').trim());
    await prefs.setString(
        _keyProvinceCode, (data['provinceCode'] ?? '').trim());
    await prefs.setString(
        _keyProvinceName, (data['provinceName'] ?? '').trim());
    await prefs.setString(
        _keyRegencyCode, (data['regencyCode'] ?? '').trim());
    await prefs.setString(_keyCity, (data['city'] ?? '').trim());
    await prefs.setString(
        _keyDistrictCode, (data['districtCode'] ?? '').trim());
    await prefs.setString(_keyDistrict, (data['district'] ?? '').trim());
    await prefs.setString(
        _keyVillageCode, (data['villageCode'] ?? '').trim());
    await prefs.setString(_keyVillage, (data['village'] ?? '').trim());
    await prefs.setString(_keyStreet, (data['street'] ?? '').trim());
    await prefs.setString(_keyThanks, (data['thanksMessage'] ?? '').trim());
  }

  /// Ambil pengaturan struk dari server. Jika gagal (offline / error),
  /// fallback ke cache lokal (SharedPreferences).
  static Future<Map<String, String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final response = await ApiService.getReceiptSettings();
      final raw = response['data'];
      if (raw is Map) {
        final data = _serverDataToMap(Map<String, dynamic>.from(raw));
        await _writeLocalCache(prefs, data);
        return data;
      }
    } catch (_) {
      // Fall through ke cache lokal.
    }
    return _localCacheToMap(prefs);
  }

  /// Simpan pengaturan struk ke server. Cache lokal di-update setelah server
  /// menerima. Jika server gagal, exception dilempar agar UI bisa menampilkan
  /// pesan error dan tidak mem-pop screen.
  static Future<void> save({
    required String storeName,
    required String phone,
    required String provinceCode,
    required String provinceName,
    required String regencyCode,
    required String city,
    required String districtCode,
    required String district,
    required String villageCode,
    required String village,
    required String street,
    required String thanksMessage,
  }) async {
    final payload = <String, dynamic>{
      'store_name': storeName.trim(),
      'phone': phone.trim(),
      'province_code': provinceCode.trim(),
      'province_name': provinceName.trim(),
      'regency_code': regencyCode.trim(),
      'city': city.trim(),
      'district_code': districtCode.trim(),
      'district': district.trim(),
      'village_code': villageCode.trim(),
      'village': village.trim(),
      'street': street.trim(),
      'thanks_message': thanksMessage.trim(),
    };

    final response = await ApiService.updateReceiptSettings(payload);

    final prefs = await SharedPreferences.getInstance();
    final raw = response['data'];
    final data = raw is Map
        ? _serverDataToMap(Map<String, dynamic>.from(raw))
        : <String, String>{
            'storeName': storeName.trim(),
            'phone': phone.trim(),
            'provinceCode': provinceCode.trim(),
            'provinceName': provinceName.trim(),
            'regencyCode': regencyCode.trim(),
            'city': city.trim(),
            'districtCode': districtCode.trim(),
            'district': district.trim(),
            'villageCode': villageCode.trim(),
            'village': village.trim(),
            'street': street.trim(),
            'thanksMessage': thanksMessage.trim(),
          };
    await _writeLocalCache(prefs, data);
  }

  static String composeAddress(Map<String, String> data) {
    final parts = <String>[];
    final street = (data['street'] ?? '').trim();
    final village = (data['village'] ?? '').trim();
    final district = (data['district'] ?? '').trim();
    final city = (data['city'] ?? '').trim();
    final province = (data['provinceName'] ?? '').trim();

    if (street.isNotEmpty) parts.add(street);
    if (village.isNotEmpty) parts.add(village);
    if (district.isNotEmpty) parts.add(district);
    if (city.isNotEmpty) parts.add(city);
    if (province.isNotEmpty) parts.add(province);

    return parts.join(', ');
  }
}
