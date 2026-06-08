import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class WilayahService {
  static const String _primaryBaseUrl = 'https://wilayah.id/api';
  static const String _fallbackBaseUrl = 'https://emsifa.github.io/api-wilayah-indonesia/api';

  // Ultimate fallback if all network calls fail
  static const List<Map<String, String>> _staticProvinces = [
    {'code': '11', 'name': 'Aceh'},
    {'code': '12', 'name': 'Sumatera Utara'},
    {'code': '13', 'name': 'Sumatera Barat'},
    {'code': '14', 'name': 'Riau'},
    {'code': '15', 'name': 'Jambi'},
    {'code': '16', 'name': 'Sumatera Selatan'},
    {'code': '17', 'name': 'Bengkulu'},
    {'code': '18', 'name': 'Lampung'},
    {'code': '19', 'name': 'Kepulauan Bangka Belitung'},
    {'code': '21', 'name': 'Kepulauan Riau'},
    {'code': '31', 'name': 'DKI Jakarta'},
    {'code': '32', 'name': 'Jawa Barat'},
    {'code': '33', 'name': 'Jawa Tengah'},
    {'code': '34', 'name': 'DI Yogyakarta'},
    {'code': '35', 'name': 'Jawa Timur'},
    {'code': '36', 'name': 'Banten'},
    {'code': '51', 'name': 'Bali'},
    {'code': '52', 'name': 'Nusa Tenggara Barat'},
    {'code': '53', 'name': 'Nusa Tenggara Timur'},
    {'code': '61', 'name': 'Kalimantan Barat'},
    {'code': '62', 'name': 'Kalimantan Tengah'},
    {'code': '63', 'name': 'Kalimantan Selatan'},
    {'code': '64', 'name': 'Kalimantan Timur'},
    {'code': '65', 'name': 'Kalimantan Utara'},
    {'code': '71', 'name': 'Sulawesi Utara'},
    {'code': '72', 'name': 'Sulawesi Tengah'},
    {'code': '73', 'name': 'Sulawesi Selatan'},
    {'code': '74', 'name': 'Sulawesi Tenggara'},
    {'code': '75', 'name': 'Gorontalo'},
    {'code': '76', 'name': 'Sulawesi Barat'},
    {'code': '81', 'name': 'Maluku'},
    {'code': '82', 'name': 'Maluku Utara'},
    {'code': '91', 'name': 'Papua Barat'},
    {'code': '94', 'name': 'Papua'},
  ];

  static List<Map<String, String>> _normalizeList(dynamic decoded) {
    try {
      List<dynamic> list;
      if (decoded is Map && decoded.containsKey('data')) {
        list = decoded['data'] as List? ?? [];
      } else if (decoded is List) {
        list = decoded;
      } else {
        return [];
      }

      return list.map((item) {
        if (item is Map) {
          final code = (item['code'] ?? item['id'] ?? '').toString();
          final name = (item['name'] ?? '').toString();
          return {
            'code': code,
            'name': name,
          };
        }
        return <String, String>{};
      }).where((item) => item.isNotEmpty && 
                         item['code'] != null && 
                         item['code']!.isNotEmpty && 
                         item['name'] != null && 
                         item['name']!.isNotEmpty).toList();
    } catch (e) {
      debugPrint('[WilayahService] Error normalizing list: $e');
      return [];
    }
  }

  static Future<List<Map<String, String>>> getProvinces() async {
    // Try primary
    try {
      debugPrint('[WilayahService] Fetching provinces from primary...');
      final response = await http.get(Uri.parse('$_primaryBaseUrl/provinces.json'))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final result = _normalizeList(decoded);
        if (result.isNotEmpty) {
          debugPrint('[WilayahService] Loaded ${result.length} provinces from primary.');
          return result;
        }
      }
    } catch (e) {
      debugPrint('[WilayahService] Primary getProvinces failed: $e');
    }

    // Try fallback
    try {
      debugPrint('[WilayahService] Fetching provinces from fallback...');
      final response = await http.get(Uri.parse('$_fallbackBaseUrl/provinces.json'))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final result = _normalizeList(decoded);
        if (result.isNotEmpty) {
          debugPrint('[WilayahService] Loaded ${result.length} provinces from fallback.');
          return result;
        }
      }
    } catch (e) {
      debugPrint('[WilayahService] Fallback getProvinces failed: $e');
    }

    debugPrint('[WilayahService] All network calls failed. Using static fallback.');
    return _staticProvinces;
  }

  static Future<List<Map<String, String>>> getRegencies(String provinceCode) async {
    // Try primary
    try {
      final response = await http.get(Uri.parse('$_primaryBaseUrl/regencies/$provinceCode.json'))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final result = _normalizeList(decoded);
        if (result.isNotEmpty) return result;
      }
    } catch (e) {
      debugPrint('[WilayahService] Primary getRegencies failed: $e');
    }

    // Try fallback
    try {
      final response = await http.get(Uri.parse('$_fallbackBaseUrl/regencies/$provinceCode.json'))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return _normalizeList(decoded);
      }
    } catch (e) {
      debugPrint('[WilayahService] Fallback getRegencies failed: $e');
    }

    return [];
  }

  static Future<List<Map<String, String>>> getDistricts(String regencyCode) async {
    // Try primary
    try {
      final response = await http.get(Uri.parse('$_primaryBaseUrl/districts/$regencyCode.json'))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final result = _normalizeList(decoded);
        if (result.isNotEmpty) return result;
      }
    } catch (e) {
      debugPrint('[WilayahService] Primary getDistricts failed: $e');
    }

    // Try fallback
    try {
      final response = await http.get(Uri.parse('$_fallbackBaseUrl/districts/$regencyCode.json'))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return _normalizeList(decoded);
      }
    } catch (e) {
      debugPrint('[WilayahService] Fallback getDistricts failed: $e');
    }

    return [];
  }

  static Future<List<Map<String, String>>> getVillages(String districtCode) async {
    // Try primary
    try {
      final response = await http.get(Uri.parse('$_primaryBaseUrl/villages/$districtCode.json'))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final result = _normalizeList(decoded);
        if (result.isNotEmpty) return result;
      }
    } catch (e) {
      debugPrint('[WilayahService] Primary getVillages failed: $e');
    }

    // Try fallback
    try {
      final response = await http.get(Uri.parse('$_fallbackBaseUrl/villages/$districtCode.json'))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return _normalizeList(decoded);
      }
    } catch (e) {
      debugPrint('[WilayahService] Fallback getVillages failed: $e');
    }

    return [];
  }
}


