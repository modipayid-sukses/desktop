import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class PlnPrepaidReceipt extends StatelessWidget {
  final Map<String, dynamic> data;
  final Map<String, String> receiptSettings;

  const PlnPrepaidReceipt({
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

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) {
      final normalized = value.replaceAll(',', '').trim();
      return double.tryParse(normalized) ?? 0.0;
    }
    return 0.0;
  }

  String _money(dynamic value) {
    final formatter = NumberFormat('#,###', 'id_ID');
    return 'Rp ${formatter.format(_toDouble(value).toInt())}';
  }

  String _date(DateTime dt) => DateFormat('yyyy-MM-dd').format(dt);
  String _time(DateTime dt) => DateFormat('HH:mm:ss').format(dt);

  String _pickFirst(List<dynamic> values, {String fallback = '-'}) {
    for (final v in values) {
      final s = (v ?? '').toString().trim();
      if (s.isNotEmpty && s != '-') return s;
    }
    return fallback;
  }

  String _formatTokenCode(String token) {
    final digits = token.replaceAll(RegExp(r'\s+'), '');
    if (digits.isEmpty) return '-';
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && i % 5 == 0) buf.write(' ');
      buf.write(digits[i]);
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    final note = _asMap(data['note']);
    final meta = _asMap(data['meta']);
    final joined = <String, dynamic>{
      ...note,
      ...meta,
      ...data,
    };

    final createdAt = DateTime.tryParse((data['created_at'] ?? '').toString()) ?? DateTime.now();
    final orderId = (data['order_id'] ?? data['id'] ?? '-').toString();

    final idpel = _pickFirst([
      joined['subscriber_id'],
      joined['customer_no'],
      joined['idpel'],
    ]);
    final meterNo = _pickFirst([joined['meter_no'], joined['msn']], fallback: '');
    final customerName = _pickFirst([joined['customer_name'], joined['nama']]);
    final tariffDaya = _pickFirst([joined['tariff_daya'], joined['tarif_daya']]);
    final productCode = _pickFirst([joined['product_code'], joined['kode_produk']]);
    final noRef = _pickFirst([
      joined['serial_number'],
      joined['reff'],
      joined['provider_ref'],
      joined['ref_id'],
    ]);
    final kwh = (joined['kwh'] ?? '').toString();
    final rawToken = (joined['token'] ?? '').toString();
    final info = (joined['info'] ?? '').toString();

    final nominal = _toDouble(joined['nominal']);
    final ppj = _toDouble(joined['ppj']);
    final admin = _toDouble(joined['admin']);
    final totalBayar = _toDouble(joined['total']) > 0
        ? _toDouble(joined['total'])
        : _toDouble(data['amount']);

    final storeName = (receiptSettings['storeName'] ?? '').trim();
    final storePhone = (receiptSettings['phone'] ?? '').trim();
    final addressParts = [
      receiptSettings['street'],
      receiptSettings['village'],
      receiptSettings['district'],
      receiptSettings['city'],
      receiptSettings['provinceName'],
      receiptSettings['address'],
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
    final tokenStyle = GoogleFonts.courierPrime(
      color: const Color(0xFF111111),
      fontSize: 16,
      fontWeight: FontWeight.bold,
      letterSpacing: 1.2,
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
                child: const Icon(Icons.bolt_rounded,
                    color: Color(0xFFFFA000), size: 38),
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
                  child: Text(storeAddress,
                      style: textStyle, textAlign: TextAlign.center),
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
                Text(
                  (receiptSettings['cashierName'] ?? '').toString().trim().isEmpty
                      ? 'kasir'
                      : receiptSettings['cashierName']!.trim(),
                  style: textStyle,
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(_time(createdAt), style: textStyle),
            const SizedBox(height: 2),
            Text('No. $orderId', style: textStyle),
            const SizedBox(height: 10),
            _dash(),
            const SizedBox(height: 8),
            Center(
              child: Text('STRUK PEMBELIAN TOKEN\nLISTRIK',
                  style: titleStyle, textAlign: TextAlign.center),
            ),
            const SizedBox(height: 4),
            Center(child: Text('#$orderId', style: titleStyle)),
            const SizedBox(height: 10),
            _kv('IDPEL', idpel, textStyle),
            _kv('Nama', customerName, textStyle),
            _kv('Tarif/Daya', tariffDaya, textStyle),
            if (meterNo.isNotEmpty && meterNo != idpel)
              _kv('No. Meter', meterNo, textStyle),
            if (productCode != '-') _kv('Kode Produk', productCode, textStyle),
            _kv('No. Ref', noRef, textStyle),
            if (kwh.isNotEmpty) _kv('kWh', '$kwh kWh', textStyle),
            const SizedBox(height: 4),
            if (nominal > 0) _kv('Nominal Token', _money(nominal), textStyle),
            if (ppj > 0) _kv('PPJ', _money(ppj), textStyle),
            if (admin > 0) _kv('Admin', _money(admin), textStyle),
            const SizedBox(height: 8),
            _dash(),
            const SizedBox(height: 8),
            _kv(
              'Total Bayar',
              _money(totalBayar),
              GoogleFonts.courierPrime(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF111111),
              ),
            ),
            const SizedBox(height: 12),
            _dash(),
            const SizedBox(height: 8),
            Text('KODE TOKEN', style: titleStyle),
            const SizedBox(height: 6),
            SelectableText(
              _formatTokenCode(rawToken),
              style: tokenStyle,
            ),
            const SizedBox(height: 12),
            if (info.trim().isNotEmpty) ...[
              _dash(),
              const SizedBox(height: 8),
              Text(info.trim(), style: textStyle),
              const SizedBox(height: 12),
            ],
            _dash(),
            const SizedBox(height: 14),
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

  Widget _dash() => Row(
        children: List.generate(
          50,
          (_) => const Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 1),
              child: Divider(color: Color(0xFF2B2B2B), thickness: 0.8, height: 1),
            ),
          ),
        ),
      );

  Widget _kv(String label, String value, TextStyle style) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: style),
          ),
          Text(': ', style: style),
          Expanded(child: Text(value, style: style)),
        ],
      ),
    );
  }
}
