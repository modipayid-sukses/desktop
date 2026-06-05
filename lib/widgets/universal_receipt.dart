import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

/// Template struk universal bergaya thermal-printer untuk semua kategori
/// transaksi (Pulsa, Data, PLN Prabayar/Pascabayar, E-Money, Voucher, dll).
///
/// Layout meniru struk PLN Prabayar (Toko Devon) yang dipakai sebagai
/// referensi: kop toko, tanggal/kasir/no, judul kategori, daftar detail,
/// total bayar, blok kode token (jika ada), info, lalu pesan terimakasih.
class UniversalReceipt extends StatelessWidget {
  final Map<String, dynamic> data;
  final Map<String, String> receiptSettings;

  const UniversalReceipt({
    Key? key,
    required this.data,
    required this.receiptSettings,
  }) : super(key: key);

  // ------------------------- helpers -------------------------

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

  // ------------------------- category detection -------------------------

  String _detectKind() {
    final c = (data['category'] ?? '').toString().toLowerCase();
    final n = (data['name'] ?? data['product_name'] ?? '').toString().toLowerCase();
    final note = (data['note'] ?? '').toString();
    final source = '$c $n';

    if (c.contains('bank_transfer') ||
        c == 'bank' ||
        (source.contains('transfer') && source.contains('bank'))) {
      return 'bank_transfer';
    }
    if (source.contains('pasca') &&
        (source.contains('pln') || source.contains('listrik'))) {
      return 'pln_postpaid';
    }
    if ((source.contains('pln') ||
            source.contains('listrik') ||
            source.contains('token')) &&
        (source.contains('prabayar') ||
            source.contains('token') ||
            note.contains('"token"'))) {
      return 'pln_prepaid';
    }
    if (source.contains('pulsa')) return 'pulsa';
    if (source.contains('paket') && source.contains('data')) return 'data';
    if (source.contains('data')) return 'data';
    if (source.contains('e-money') || source.contains('emoney') ||
        source.contains('e-wallet') || source.contains('wallet')) {
      return 'emoney';
    }
    if (source.contains('voucher') || source.contains('game') ||
        source.contains('epin')) {
      return 'voucher';
    }
    return 'generic';
  }

  String _titleForKind(String kind) {
    switch (kind) {
      case 'pln_prepaid':
        return 'STRUK PEMBELIAN TOKEN\nLISTRIK';
      case 'pln_postpaid':
        return 'STRUK PEMBAYARAN TAGIHAN\nLISTRIK';
      case 'bank_transfer':
        return 'STRUK TRANSFER BANK';
      case 'pulsa':
        return 'STRUK PEMBELIAN PULSA';
      case 'data':
        return 'STRUK PEMBELIAN PAKET DATA';
      case 'emoney':
        return 'STRUK TOP UP E-MONEY';
      case 'voucher':
        return 'STRUK PEMBELIAN VOUCHER';
      default:
        return 'STRUK TRANSAKSI';
    }
  }

  // ------------------------- build -------------------------

  @override
  Widget build(BuildContext context) {
    final kind = _detectKind();

    final note = _asMap(data['note']);
    final meta = _asMap(data['meta']);
    final desc = _asMap(data['desc']);
    final description = _asMap(data['description']);
    final providerData = _asMap(data['provider_data']);
    final providerResponse = _asMap(data['provider_response']);
    final payload = _asMap(data['payload']);

    final joined = <String, dynamic>{
      ...providerResponse,
      ...providerData,
      ...description,
      ...payload,
      ...desc,
      // meta sering berisi response provider (admin = 0 dari Loketbayar).
      // note disimpan oleh backend dengan field final (admin panel, total user).
      // Note menang vs meta.
      ...meta,
      ...note,
      ...data,
    };

    DateTime _parseDateTime(dynamic val) {
      if (val == null) return DateTime.now();
      String raw = val.toString().trim();
      if (raw.isEmpty) return DateTime.now();
      if (!raw.endsWith('Z') &&
          !raw.contains(RegExp(r'[+-]\d{2}:?\d{2}$')) &&
          !raw.contains(RegExp(r'[+-]\d{4}$'))) {
        if (!raw.contains('T')) {
          raw = raw.replaceAll(' ', 'T');
        }
        raw = '${raw}Z';
      }
      return DateTime.tryParse(raw)?.toLocal() ?? DateTime.now();
    }
    final createdAt = _parseDateTime(data['created_at']);
    final orderId =
        (data['order_id'] ?? data['id'] ?? '-').toString();
    final amount = _toDouble(data['amount']);

    // Header toko
    final storeName = (receiptSettings['storeName'] ?? '').trim();
    final storePhone = (receiptSettings['phone'] ?? '').trim();
    final addressParts = [
      receiptSettings['street'],
      receiptSettings['village'],
      receiptSettings['district'],
      receiptSettings['city'],
      receiptSettings['provinceName'],
    ].where((e) => (e ?? '').trim().isNotEmpty).map((e) => e!.trim()).toList();
    final storeAddress = addressParts.join(', ');
    final thanksMessage = (receiptSettings['thanksMessage'] ?? '').trim();
    final cashierName =
        (receiptSettings['cashierName'] ?? '').toString().trim();

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

    final detailRows = <Widget>[];
    final List<Widget> footerExtras = [];

    if (kind == 'pln_prepaid') {
      // Mapping field mengikuti breakdown user:
      //   IDPEL       -> meter_no (fallback ke subscriber_id / customer_no)
      //   Nama        -> customer_name
      //   Tarif/Daya  -> tariff_daya
      //   Stand Meter -> subscriber_id
      //   No. Ref     -> order_id (tanpa prefix PPOB-)
      //   Biaya Admin -> admin
      //   Total Bayar -> total
      //   Info        -> info
      final idpel = _pickFirst([
        joined['meter_no'],
        joined['subscriber_id'],
        joined['idpel'],
        data['customer_no'],
        joined['customer_no'],
      ]);
      final customerName = _pickFirst([joined['customer_name']]);
      final tariffDaya = _pickFirst([joined['tariff_daya']]);
      final standMeterRaw = _pickFirst([joined['subscriber_id']]);
      // Hindari duplikat: kalau Stand Meter sama dengan IDPEL, kosongkan.
      final standMeter = standMeterRaw == idpel ? '-' : standMeterRaw;
      final noRef = orderId.startsWith('PPOB-') ? orderId.substring(5) : orderId;
      final rawToken = (joined['token'] ?? '').toString();
      final info = (joined['info'] ?? '').toString();

      final admin = _toDouble(joined['admin']);
      final totalBayar = _toDouble(joined['total']) > 0
          ? _toDouble(joined['total'])
          : amount;

      detailRows.addAll([
        _kv('IDPEL', idpel, textStyle),
        _kv('Nama', customerName, textStyle),
        _kv('Tarif/Daya', tariffDaya, textStyle),
        if (standMeter != '-') _kv('Stand Meter', standMeter, textStyle),
        _kv('No. Ref', noRef, textStyle),
        const SizedBox(height: 4),
        _kv('Biaya Admin', admin > 0 ? _money(admin) : 'Gratis!', textStyle),
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
      ]);

      if (rawToken.trim().isNotEmpty) {
        footerExtras.addAll([
          const SizedBox(height: 12),
          _dash(),
          const SizedBox(height: 8),
          Text('KODE TOKEN', style: titleStyle),
          const SizedBox(height: 6),
          SelectableText(_formatTokenCode(rawToken), style: tokenStyle),
        ]);
      }
      if (info.trim().isNotEmpty) {
        footerExtras.addAll([
          const SizedBox(height: 12),
          _dash(),
          const SizedBox(height: 8),
          Text('Info', style: titleStyle),
          const SizedBox(height: 4),
          Text(info.trim(), style: textStyle),
        ]);
      }
    } else if (kind == 'pln_postpaid') {
      final detailList = _asMapList(
          joined['detail'].toString() == '[]' ? null : joined['detail']);
      final firstDetail =
          detailList.isNotEmpty ? detailList.first : <String, dynamic>{};

      final idpel = _pickFirst([
        joined['customer_no'],
        joined['idpel'],
        joined['id_pel'],
      ]);
      final name = _pickFirst([
        joined['customer_name'],
        joined['nama_pelanggan'],
        joined['nama'],
      ]);
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
      final noRef = (joined['ref_id'] ??
              joined['reference_id'] ??
              joined['provider_ref'] ??
              data['provider_ref'] ??
              '-')
          .toString();

      final totalNilaiTagihan = _sumDetail(detailList, 'nilai_tagihan');
      final totalDenda = _sumDetail(detailList, 'denda');
      final totalAdmin = _sumDetail(detailList, 'admin');
      final totalTagihan = _toDouble(firstDetail['nilai_tagihan']) > 0
          ? _toDouble(firstDetail['nilai_tagihan'])
          : (_toDouble(joined['nominal']) > 0
              ? _toDouble(joined['nominal'])
              : amount);
      final denda = _toDouble(firstDetail['denda']) > 0
          ? _toDouble(firstDetail['denda'])
          : _toDouble(joined['denda']);
      final biayaAdmin = _toDouble(firstDetail['admin']) > 0
          ? _toDouble(firstDetail['admin'])
          : _toDouble(joined['admin']);
      final lembar = _pickFirst([
        joined['lembar_tagihan'],
        detailList.isEmpty ? '' : detailList.length,
        '1',
      ]);

      detailRows.addAll([
        _kv('IDPEL', idpel, textStyle),
        _kv('Nama', name, textStyle),
        _kv('Tarif/Daya', '$tarif/$daya', textStyle),
        _kv('BL/TH', periode, textStyle),
        _kv('Standmeter', standMeter, textStyle),
        _kv('No. Ref', noRef, textStyle),
        _kv('Lembar Tagihan', lembar, textStyle),
        const SizedBox(height: 4),
        if (totalNilaiTagihan > 0)
          _kv('Total Nilai Tagihan', _money(totalNilaiTagihan), textStyle),
        if (totalDenda > 0) _kv('Total Denda', _money(totalDenda), textStyle),
        if (totalAdmin > 0) _kv('Total Admin', _money(totalAdmin), textStyle),
        _kv('Tagihan', _money(totalTagihan), textStyle),
        if (denda > 0) _kv('Denda', _money(denda), textStyle),
        if (biayaAdmin > 0) _kv('Biaya Admin', _money(biayaAdmin), textStyle),
        const SizedBox(height: 8),
        _dash(),
        const SizedBox(height: 8),
        _kv(
          'Total Bayar',
          _money(amount),
          GoogleFonts.courierPrime(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF111111),
          ),
        ),
      ]);
    } else if (kind == 'bank_transfer') {
      // Untuk bank_transfer, sumber data harus dari `note` JSON yang
      // disimpan saat purchase: amount=nominal asli, admin=biaya admin
      // panel, total=saldo dipotong. Kunci `amount` di Transaction root
      // sudah jadi total (saldo dipotong) — itu konflik. Jadi note menang.
      final bankSrc = <String, dynamic>{...data, ...meta, ...note};
      final bankName = _pickFirst([
        bankSrc['bank_name'],
        bankSrc['bank'],
      ]);
      final accountNumber = _pickFirst([
        bankSrc['account_number'],
        bankSrc['nomor_rekening'],
        data['customer_no'],
      ]);
      final accountName = _pickFirst([
        bankSrc['account_name'],
        bankSrc['nama_penerima'],
      ]);
      final providerReff = _pickFirst([
        bankSrc['reff'],
        data['provider_ref'],
        bankSrc['provider_ref'],
      ]);
      final notes = (bankSrc['notes'] ?? '').toString().trim();
      final noRef = orderId;

      // amount di note = nominal asli yang sampai ke tujuan.
      final amountVal = _toDouble(bankSrc['amount']) > 0
          ? _toDouble(bankSrc['amount'])
          : amount;
      final adminVal = _toDouble(bankSrc['admin']) > 0
          ? _toDouble(bankSrc['admin'])
          : _toDouble(bankSrc['fee']);
      final totalVal = _toDouble(bankSrc['total']) > 0
          ? _toDouble(bankSrc['total'])
          : (amountVal + adminVal);

      detailRows.addAll([
        if (bankName != '-') _kv('Bank Tujuan', bankName, textStyle),
        if (accountNumber != '-') _kv('No. Rekening', accountNumber, textStyle),
        if (accountName != '-') _kv('Nama Penerima', accountName, textStyle),
        _kv('No. Ref', noRef, textStyle),
        if (providerReff != '-' && providerReff != noRef)
          _kv('Reff', providerReff, textStyle),
        const SizedBox(height: 4),
        _kv('Nominal', _money(amountVal), textStyle),
        _kv('Biaya Admin',
            adminVal > 0 ? _money(adminVal) : 'Gratis!', textStyle),
        if (notes.isNotEmpty) _kv('Catatan', notes, textStyle),
        const SizedBox(height: 8),
        _dash(),
        const SizedBox(height: 8),
        _kv(
          'Total Bayar',
          _money(totalVal),
          GoogleFonts.courierPrime(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF111111),
          ),
        ),
      ]);
    } else {
      // Generic / Pulsa / Data / E-Money / Voucher
      final productName = _pickFirst([
        data['name'],
        data['product_name'],
        joined['product_name'],
      ]);
      final customerNo = _pickFirst([
        data['customer_no'],
        data['customer_id'],
        data['destination'],
        data['target'],
        data['phone_number'],
        joined['customer_no'],
      ], fallback: '');
      final providerRef = _pickFirst([
        data['provider_ref'],
        data['provider_reference'],
        joined['serial_number'],
        joined['reff'],
      ], fallback: '');
      // Nama penerima dari note (e-wallet bebas nominal punya field ini).
      final customerName = _pickFirst([
        joined['customer_name'],
        joined['nama_penerima'],
        joined['nama'],
      ], fallback: '');
      final admin = _toDouble(joined['admin']);
      // `nominal` = jumlah yang sampai ke tujuan (dari note).
      // `amount` = saldo dipotong (= nominal + admin panel) dari Transaction root.
      final nominal =
          _toDouble(joined['nominal']) > 0 ? _toDouble(joined['nominal']) : amount;

      detailRows.addAll([
        _kv('Produk', productName, textStyle),
        if (customerNo.isNotEmpty)
          _kv(_destinationLabel(kind), customerNo, textStyle),
        if (customerName.isNotEmpty && customerName != '-')
          _kv('Nama Penerima', customerName, textStyle),
        if (providerRef.isNotEmpty) _kv('No. Ref', providerRef, textStyle),
        const SizedBox(height: 4),
        _kv('Nominal', _money(nominal), textStyle),
        _kv('Admin', admin > 0 ? _money(admin) : 'Gratis!', textStyle),
        const SizedBox(height: 8),
        _dash(),
        const SizedBox(height: 8),
        _kv(
          'Total Bayar',
          _money(amount),
          GoogleFonts.courierPrime(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF111111),
          ),
        ),
      ]);
    }

    return Container(
      width: double.infinity,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                Text(cashierName.isEmpty ? 'kasir' : cashierName,
                    style: textStyle),
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
              child: Text(_titleForKind(kind),
                  style: titleStyle, textAlign: TextAlign.center),
            ),
            const SizedBox(height: 4),
            Center(child: Text('#$orderId', style: titleStyle)),
            const SizedBox(height: 10),
            ...detailRows,
            ...footerExtras,
            const SizedBox(height: 14),
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

  String _destinationLabel(String kind) {
    switch (kind) {
      case 'pulsa':
      case 'data':
        return 'Nomor HP';
      case 'emoney':
        return 'Tujuan';
      case 'voucher':
        return 'Tujuan';
      default:
        return 'Nomor';
    }
  }

  Widget _dash() => Row(
        children: List.generate(
          50,
          (_) => const Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 1),
              child: Divider(
                  color: Color(0xFF2B2B2B), thickness: 0.8, height: 1),
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
          SizedBox(width: 120, child: Text(label, style: style)),
          Text(': ', style: style),
          Expanded(child: Text(value, style: style)),
        ],
      ),
    );
  }
}
