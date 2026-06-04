import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class PlnPostpaidReceipt extends StatelessWidget {
  final Map<String, dynamic> data;
  final Map<String, String> receiptSettings;

  const PlnPostpaidReceipt({
    Key? key,
    required this.data,
    required this.receiptSettings,
  }) : super(key: key);

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is String) {
      final raw = value.trim();
      if (raw.isEmpty) return <String, dynamic>{};
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    return <String, dynamic>{};
  }

  List<Map<String, dynamic>> _asMapList(dynamic value) {
    if (value is! List) return <Map<String, dynamic>>[];
    return value
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) {
      final normalized = value.replaceAll(',', '').trim();
      return double.tryParse(normalized) ?? 0.0;
    }
    return 0.0;
  }

  double _sumDetail(List<Map<String, dynamic>> details, String key) {
    double total = 0;
    for (final item in details) {
      total += _toDouble(item[key]);
    }
    return total;
  }

  String _money(dynamic value) {
    final formatter = NumberFormat('#,###', 'id_ID');
    return 'Rp ${formatter.format(_toDouble(value).toInt())}';
  }

  String _date(DateTime dateTime) {
    return DateFormat('yyyy-MM-dd').format(dateTime);
  }

  String _time(DateTime dateTime) {
    return DateFormat('HH:mm:ss').format(dateTime);
  }

  String _period(dynamic value) {
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty) return '-';
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length == 6) {
      final a = digits.substring(0, 4);
      final b = digits.substring(4, 6);
      final c = digits.substring(0, 2);
      final d = digits.substring(2, 6);
      final bm = int.tryParse(b) ?? 0;
      if (bm >= 1 && bm <= 12) return '$b/$a';
      final cm = int.tryParse(c) ?? 0;
      if (cm >= 1 && cm <= 12) return '$c/$d';
    }
    return raw;
  }

  String _pickFirstNonEmpty(List<dynamic> values) {
    for (final v in values) {
      final s = (v ?? '').toString().trim();
      if (s.isNotEmpty && s != '-') return s;
    }
    return '-';
  }

  bool _isLikelyProductName(String value) {
    final lower = value.toLowerCase();
    return lower.contains('pln') ||
        lower.contains('pascabayar') ||
        lower.contains('tagihan') ||
        lower.contains('listrik') ||
        lower.contains('pembayaran');
  }

  @override
  Widget build(BuildContext context) {
    final payload = _asMap(data['payload']);
    final desc = _asMap(data['desc']);
    final description = _asMap(data['description']);
    final providerData = _asMap(data['provider_data']);
    final providerResponse = _asMap(data['provider_response']);

    final joined = <String, dynamic>{
      ...providerResponse,
      ...providerData,
      ...description,
      ...payload,
      ...desc,
      ...data,
    };

    final detailList = _asMapList(joined['detail'].toString() == '[]' ? null : joined['detail']);
    final firstDetail = detailList.isNotEmpty ? detailList.first : <String, dynamic>{};

    final createdAt = DateTime.tryParse((data['created_at'] ?? '').toString()) ?? DateTime.now();

    final idpel = _pickFirstNonEmpty([
      joined['customer_no'],
      joined['idpel'],
      joined['id_pel'],
      data['customer_no'],
    ]);
    final candidateName = _pickFirstNonEmpty([
      joined['customer_name'],
      joined['nama_pelanggan'],
      joined['nama'],
      joined['subscriber_name'],
      joined['subscriber'],
      joined['customer'],
      joined['pelanggan'],
      firstDetail['nama'],
      firstDetail['customer_name'],
      data['customer_name'],
      data['receiver_name'],
      data['name'],
    ]);
    final name = (candidateName != '-' && !_isLikelyProductName(candidateName))
        ? candidateName
        : '-';
    final rawTariffDaya = (joined['tariff_daya'] ?? firstDetail['tariff_daya'] ?? '').toString().trim();
    String tarif = (joined['tarif'] ?? firstDetail['tarif'] ?? '-').toString();
    String daya = (joined['daya'] ?? firstDetail['daya'] ?? '-').toString();
    if ((tarif == '-' || tarif.isEmpty) && (daya == '-' || daya.isEmpty) && rawTariffDaya.isNotEmpty && rawTariffDaya != '-') {
      final parts = rawTariffDaya.split('/');
      if (parts.length >= 2) {
        tarif = parts[0].trim();
        daya = parts[1].trim();
      } else {
        tarif = rawTariffDaya;
      }
    }
    final meterAwal = (firstDetail['meter_awal'] ?? '').toString();
    final meterAkhir = (firstDetail['meter_akhir'] ?? '').toString();
    final standMeter = (meterAwal.isNotEmpty || meterAkhir.isNotEmpty)
        ? '$meterAwal - $meterAkhir'
        : (joined['stand_meter'] ?? joined['standmeter'] ?? '-').toString();
    final periode = _period(joined['periode'] ?? firstDetail['periode']);
    final noRef = (joined['ref_id'] ?? joined['reference_id'] ?? joined['provider_ref'] ?? data['provider_ref'] ?? '-').toString();

    final totalNilaiTagihanDetail = _sumDetail(detailList, 'nilai_tagihan');
    final totalDendaDetail = _sumDetail(detailList, 'denda');
    final totalAdminDetail = _sumDetail(detailList, 'admin');
    final totalTagihan = _toDouble(firstDetail['nilai_tagihan']) > 0
        ? _toDouble(firstDetail['nilai_tagihan'])
        : _toDouble(joined['amount']);
    final denda = _toDouble(firstDetail['denda']) > 0
        ? _toDouble(firstDetail['denda'])
        : _toDouble(joined['denda']);
    final biayaAdmin = _toDouble(firstDetail['admin']) > 0
        ? _toDouble(firstDetail['admin'])
        : _toDouble(joined['admin']);
    final totalBayar = _toDouble(data['amount']);
    final biayaLayanan = (totalBayar - totalTagihan - denda - biayaAdmin).clamp(0, 999999999).toDouble();
    final totalLembarTagihan = _pickFirstNonEmpty([
      joined['lembar_tagihan'],
      detailList.isEmpty ? '' : detailList.length,
      '1',
    ]);

    final storeName = (receiptSettings['storeName'] ?? '').trim();
    final storePhone = (receiptSettings['phone'] ?? '').trim();
    final addressParts = [
      receiptSettings['street'],
      receiptSettings['village'],
      receiptSettings['district'],
      receiptSettings['city'],
      receiptSettings['provinceName'],
      receiptSettings['address'],
      receiptSettings['villageName'],
      receiptSettings['districtName'],
      receiptSettings['regencyName'],
    ].where((e) => (e ?? '').trim().isNotEmpty).map((e) => e!.trim()).toList();
    final storeAddress = addressParts.join(', ');
    final thanksMessage = (receiptSettings['thanksMessage'] ?? '').trim();

    final textStyle = GoogleFonts.courierPrime(
      color: const Color(0xFF2B2B2B),
      fontSize: 13,
      height: 1.2,
    );

    final titleStyle = GoogleFonts.courierPrime(
      color: const Color(0xFF2B2B2B),
      fontSize: 15,
      fontWeight: FontWeight.bold,
      height: 1.2,
    );

    return Container(
      width: double.infinity,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: CircleAvatar(
                radius: 34,
                backgroundColor: const Color(0xFFF0F0F0),
                child: const Icon(Icons.electrical_services, color: Color(0xFFFFA000), size: 38),
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: Text(
                storeName.isEmpty ? 'Toko PPOB' : storeName,
                style: titleStyle,
                textAlign: TextAlign.center,
              ),
            ),
            if (storeAddress.isNotEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(storeAddress, style: textStyle, textAlign: TextAlign.center),
                ),
              ),
            if (storePhone.isNotEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(storePhone, style: textStyle),
                ),
              ),
            const SizedBox(height: 10),
            _dash(),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_date(createdAt), style: textStyle),
                Text((receiptSettings['cashierName'] ?? '').toString().trim().isEmpty
                    ? 'kasir'
                    : receiptSettings['cashierName']!.trim(), style: textStyle),
              ],
            ),
            const SizedBox(height: 2),
            Text(_time(createdAt), style: textStyle),
            const SizedBox(height: 2),
            Text('No. ${data['order_id'] ?? data['id'] ?? '-'}', style: textStyle),
            const SizedBox(height: 10),
            _dash(),
            const SizedBox(height: 8),
            Center(
              child: Text('STRUK PEMBAYARAN TAGIHAN\nLISTRIK', style: titleStyle, textAlign: TextAlign.center),
            ),
            const SizedBox(height: 4),
            Center(
              child: Text('#${data['order_id'] ?? data['id'] ?? '-'}', style: titleStyle),
            ),
            const SizedBox(height: 10),
            _kv('IDPEL', idpel, textStyle),
            _kv('Nama', name, textStyle),
            _kv('Tarif/Daya', '$tarif/$daya', textStyle),
            _kv('BL/TH', periode, textStyle),
            _kv('Standmeter', standMeter, textStyle),
            _kv('No. Ref', noRef, textStyle),
            _kv('Total Lembar Tagihan', totalLembarTagihan, textStyle),
            const SizedBox(height: 4),
            _kv('Total Nilai Tagihan', _money(totalNilaiTagihanDetail > 0 ? totalNilaiTagihanDetail : totalTagihan), textStyle),
            _kv('Total Denda', _money(totalDendaDetail > 0 ? totalDendaDetail : denda), textStyle),
            _kv('Total Admin Periode', _money(totalAdminDetail > 0 ? totalAdminDetail : biayaAdmin), textStyle),
            _kv('Total Tagihan', _money(totalTagihan), textStyle),
            _kv('Denda', _money(denda), textStyle),
            _kv('Biaya Admin', _money(biayaAdmin), textStyle),
            _kv('Biaya Layanan Toko', _money(biayaLayanan), textStyle),
            _kv('Total Bayar', _money(totalBayar), textStyle),
            if (meterAwal.isNotEmpty) _kv('Meter Awal', meterAwal, textStyle),
            if (meterAkhir.isNotEmpty) _kv('Meter Akhir', meterAkhir, textStyle),
            const SizedBox(height: 8),
            _dash(),
            const SizedBox(height: 8),
            Text('1. PP_PLN - $idpel', style: GoogleFonts.courierPrime(fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('1 x ${_money(totalBayar)}', style: textStyle),
                Text(_money(totalBayar), style: textStyle),
              ],
            ),
            const SizedBox(height: 8),
            _dash(),
            const SizedBox(height: 8),
            Text('Total QTY : 1', style: textStyle),
            const SizedBox(height: 4),
            _kv('Total', _money(totalBayar), GoogleFonts.courierPrime(fontSize: 15, fontWeight: FontWeight.bold)),
            _kv('Bayar(Cash)', _money(totalBayar), textStyle),
            _kv('Kembali', _money(0), textStyle),
            const SizedBox(height: 18),
            Center(
              child: Text(
                thanksMessage.isEmpty
                    ? 'Terimakasih telah berbelanja di Toko Kami'
                    : thanksMessage,
                style: textStyle,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kv(String label, String value, TextStyle style) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 112, child: Text(label, style: style)),
          Text(': ', style: style),
          Expanded(child: Text(value, style: style, textAlign: TextAlign.left)),
        ],
      ),
    );
  }

  Widget _dash() {
    return const Text('--------------------------------------------', style: TextStyle(color: Color(0xFF4A4A4A), fontSize: 12));
  }
}
