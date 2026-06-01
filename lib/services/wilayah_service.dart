import 'dart:convert';

import 'package:http/http.dart' as http;

class WilayahService {
  static const String _baseUrl = 'https://wilayah.id/api';

  static List<Map<String, String>> _normalizeList(Map<String, dynamic> decoded) {
    final list = List<Map<String, dynamic>>.from(decoded['data'] ?? const []);
    return list
        .map(
          (item) => {
            'code': (item['code'] ?? '').toString(),
            'name': (item['name'] ?? '').toString(),
          },
        )
        .where((item) => item['code']!.isNotEmpty && item['name']!.isNotEmpty)
        .toList();
  }

  static Future<List<Map<String, String>>> getProvinces() async {
    final response = await http.get(Uri.parse('$_baseUrl/provinces.json'));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Gagal memuat daftar provinsi');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return _normalizeList(decoded);
  }

  static Future<List<Map<String, String>>> getRegencies(String provinceCode) async {
    final response = await http.get(Uri.parse('$_baseUrl/regencies/$provinceCode.json'));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Gagal memuat daftar kota/kabupaten');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return _normalizeList(decoded);
  }

  static Future<List<Map<String, String>>> getDistricts(String regencyCode) async {
    final response = await http.get(Uri.parse('$_baseUrl/districts/$regencyCode.json'));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Gagal memuat daftar kecamatan');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return _normalizeList(decoded);
  }

  static Future<List<Map<String, String>>> getVillages(String districtCode) async {
    final response = await http.get(Uri.parse('$_baseUrl/villages/$districtCode.json'));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Gagal memuat daftar kelurahan/desa');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return _normalizeList(decoded);
  }
}
