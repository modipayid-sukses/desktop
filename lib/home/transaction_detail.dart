import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:modipay/bottombar/bottombar.dart';
import 'package:modipay/home/print_receipt_page.dart';
import 'package:modipay/services/api_service.dart' show ApiService;
import 'package:intl/intl.dart';
import 'package:modipay/utils/transaction_helpers.dart';

class TransactionDetail extends StatefulWidget {
  final Map<String, dynamic> data;
  const TransactionDetail({super.key, required this.data});

  @override
  State<TransactionDetail> createState() => _TransactionDetailState();
}

class _TransactionDetailState extends State<TransactionDetail> {
  Map<String, dynamic> _hydratedPlnData = const {};
  bool _isCheckingStatus = false;

  @override
  void initState() {
    super.initState();
    _hydratePlnData();
  }

  // ----------------- helpers -----------------

  Map<String, dynamic> get _data =>
      _hydratedPlnData.isNotEmpty ? _hydratedPlnData : widget.data;

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

  String _pickFirstNonEmpty(List<dynamic> values) {
    for (final v in values) {
      final s = (v ?? '').toString().trim();
      if (s.isNotEmpty && s != '-') return s;
    }
    return '';
  }

  String _cleanOrderId(String value) {
    if (value.startsWith('PPOB-')) return value.substring(5);
    return value;
  }

  String _formatTokenCode(String token) {
    final digits = token.replaceAll(RegExp(r'\s+'), '');
    if (digits.isEmpty) return '';
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && i % 5 == 0) buf.write(' ');
      buf.write(digits[i]);
    }
    return buf.toString();
  }

  /// Gabungkan semua sumber data PLN (note, meta, payload, provider_response,
  /// dll) jadi satu Map agar kunci spesifik bisa dipanggil langsung.
  Map<String, dynamic> _joinedPlnData(Map<String, dynamic> data) {
    return <String, dynamic>{
      ..._asMap(data['provider_response']),
      ..._asMap(data['provider_data']),
      ..._asMap(data['description']),
      ..._asMap(data['payload']),
      ..._asMap(data['desc']),
      ..._asMap(data['note']),
      ..._asMap(data['meta']),
      ...data,
    };
  }

  double _parseAmount(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) {
      final normalized = value.replaceAll(',', '').trim();
      return double.tryParse(normalized) ?? 0.0;
    }
    return 0.0;
  }

  String _normalizeStatus(String raw) {
    final s = raw.trim().toLowerCase();
    if (s.isEmpty) return s;
    if (s.contains('success') ||
        s.contains('completed') ||
        s.contains('berhasil') ||
        s.contains('sukses')) return 'success';
    if (s.contains('pending') ||
        s.contains('proses') ||
        s.contains('process')) return 'pending';
    if (s.contains('failed') ||
        s.contains('gagal') ||
        s.contains('expired') ||
        s.contains('cancel') ||
        s.contains('reject') ||
        s.contains('error')) return 'failed';
    return s;
  }

  bool _isPlnTransaction(Map<String, dynamic> data) {
    final category = (data['category'] ?? '').toString().toLowerCase();
    final name =
        (data['name'] ?? data['product_name'] ?? '').toString().toLowerCase();
    final source = '$category $name';
    return source.contains('pln') ||
        source.contains('listrik') ||
        source.contains('token') ||
        source.contains('prabayar') ||
        source.contains('pasca');
  }

  /// Apakah transaksi perlu di-hydrate dari endpoint detail untuk
  /// mendapatkan field-field tambahan (note JSON, dll). Selain PLN,
  /// transfer bank juga butuh karena list endpoint tidak kirim note.
  bool _shouldHydrateDetail(Map<String, dynamic> data) {
    final category = (data['category'] ?? '').toString().toLowerCase();
    if (category.contains('bank_transfer') || category == 'bank') return true;
    return _isPlnTransaction(data);
  }

  // ----------------- PLN hydration (prepaid + postpaid) -----------------

  /// Fetch detail transaksi penuh dari `/transactions/{orderId}` lalu merge
  /// field PLN (meter_no, customer_name, tariff_daya, subscriber_id, token,
  /// info, kwh, dll) yang tidak dikirim oleh list endpoint.
  Future<void> _hydratePlnData() async {
    final base = Map<String, dynamic>.from(widget.data);
    if (!_shouldHydrateDetail(base)) return;

    final orderId = (base['order_id'] ?? base['id'] ?? '').toString();
    if (orderId.isEmpty) return;

    // Step 1: parse data yang sudah ada di base — note bisa berupa JSON string
    // dari list endpoint, jadi _joinedPlnData men-decode-nya lebih dulu.
    final preMerged = <String, dynamic>{...base};
    _mergePlnFields(preMerged, _joinedPlnData(base));
    if (preMerged.length > base.length && mounted) {
      setState(() => _hydratedPlnData = preMerged);
    }

    try {
      final detailResponse = await ApiService.getTransactionDetail(orderId);

      // Backend mengembalikan {transaction: {...}, data: {..., meta: {...}}}
      // atau cuma {data: {...}} tergantung versi. Coba kedua sumber.
      final detailData = _asMap(detailResponse['data']).isNotEmpty
          ? _asMap(detailResponse['data'])
          : _asMap(detailResponse['transaction']).isNotEmpty
              ? _asMap(detailResponse['transaction'])
              : detailResponse;
      if (detailData.isEmpty) {
        if (mounted) setState(() => _hydratedPlnData = preMerged);
        return;
      }

      // base (data dari list) menang vs detailData supaya field umum
      // (status, amount, dll) tidak ter-overwrite oleh data lama.
      final merged = <String, dynamic>{...detailData, ...base};

      // Gabung semua sumber data PLN dari respon detail.
      _mergePlnFields(merged, _joinedPlnData(detailData));

      // Pastikan note/meta/description ikut ter-bawa kalau base tidak punya.
      if ((base['note'] == null || base['note'].toString().isEmpty) &&
          detailData['note'] != null) {
        merged['note'] = detailData['note'];
      }
      if ((base['meta'] == null || base['meta'].toString().isEmpty) &&
          detailData['meta'] != null) {
        merged['meta'] = detailData['meta'];
      }
      if ((base['description'] == null ||
              base['description'].toString().isEmpty) &&
          detailData['description'] != null) {
        merged['description'] = detailData['description'];
      }

      if (mounted) setState(() => _hydratedPlnData = merged);
    } catch (_) {
      // Diam saat gagal — UI tetap pakai base/preMerged.
      if (mounted) setState(() => _hydratedPlnData = preMerged);
    }
  }

  /// Salin field PLN dari [source] ke [target] kalau target belum punya.
  void _mergePlnFields(
      Map<String, dynamic> target, Map<String, dynamic> source) {
    const keys = <String>[
      // Prepaid (Token PLN)
      'meter_no',
      'customer_name',
      'tariff_daya',
      'subscriber_id',
      'token',
      'serial_number',
      'kwh',
      'info',
      'product_code',
      'admin',
      'total',
      // Postpaid
      'nama_pelanggan',
      'nama',
      'subscriber_name',
      'tarif',
      'daya',
      'periode',
      'detail',
      'denda',
      'ref_id',
      'reference_id',
      'provider_ref',
      'lembar_tagihan',
      'stand_meter',
      'standmeter',
      // Bank transfer
      'account_name',
      'account_number',
      'bank_name',
      'bank_code',
      'amount',
      'fee',
      'notes',
      'reff',
      'nama_penerima',
      'nomor_rekening',
      'bank',
    ];
    for (final key in keys) {
      final exists =
          target[key] != null && target[key].toString().trim().isNotEmpty;
      if (!exists && source[key] != null) {
        final v = source[key].toString().trim();
        if (v.isNotEmpty) target[key] = source[key];
      }
    }
  }

  // ----------------- print/download -----------------

  void _openPrintReceipt({bool autoDownload = false}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            PrintReceiptPage(data: _data, autoDownload: autoDownload),
      ),
    );
  }

  // ----------------- check status -----------------

  Future<void> _checkTransactionStatus() async {
    final orderId = (_data['order_id'] ?? _data['id'] ?? '').toString();
    if (orderId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order ID tidak ditemukan')),
      );
      return;
    }

    setState(() => _isCheckingStatus = true);
    try {
      final response = await ApiService.checkTransactionStatus(orderId: orderId);
      if (!mounted) return;
      final tx = response['data']?['transaction'];
      if (tx is Map) {
        final newStatus = (tx['status'] ?? '').toString();
        if (newStatus.isNotEmpty) {
          setState(() {
            _hydratedPlnData = Map<String, dynamic>.from({..._data, 'status': newStatus});
            if (tx['provider_ref'] != null) {
              _hydratedPlnData['provider_ref'] = tx['provider_ref'];
            }
            if (tx['note'] != null) {
              _hydratedPlnData['note'] = tx['note'];
              // Parse note JSON and merge token/SN fields into data
              try {
                final noteData = Map<String, dynamic>.from(
                    tx['note'] is String ? Map<String, dynamic>.from(
                        const JsonDecoder().convert(tx['note'] as String) as Map)
                    : (tx['note'] is Map ? tx['note'] as Map<String, dynamic> : {}));
                if (noteData['token'] != null && noteData['token'].toString().isNotEmpty) {
                  _hydratedPlnData['token'] = noteData['token'];
                }
                if (noteData['serial_number'] != null && noteData['serial_number'].toString().isNotEmpty) {
                  _hydratedPlnData['serial_number'] = noteData['serial_number'];
                  _hydratedPlnData['provider_ref'] ??= noteData['serial_number'];
                }
                if (noteData['customer_name'] != null) {
                  _hydratedPlnData['customer_name'] = noteData['customer_name'];
                }
                if (noteData['kwh'] != null) {
                  _hydratedPlnData['kwh'] = noteData['kwh'];
                }
              } catch (_) {}
            }
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Status: ${newStatus == 'completed' ? 'Sukses' : newStatus == 'failed' ? 'Gagal' : 'Pending'}')),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal cek status: ${ApiService.userFriendlyMessage(e)}')),
        );
      }
    }
    if (mounted) setState(() => _isCheckingStatus = false);
  }

  /// Tampilkan popup untuk custom harga admin sebelum print.
  /// Total Bayar asli ditampilkan, merchant bisa input Harga Admin,
  /// dan Total (Total Bayar + Harga Admin) dihitung realtime.
  /// Nilai ini bersifat sementara dan hanya mempengaruhi struk print.
  void _showPrintAdminPopup() {
    // Untuk produk yang note JSON-nya sudah berisi field final
    // (mis. e-wallet, bank transfer, PLN), pakai nominal & admin dari note.
    // Kalau tidak ada, fallback ke `_data['amount']` (legacy).
    //
    // Note key untuk nominal asli berbeda per kategori:
    //   - PLN, e-wallet : `nominal`
    //   - Transfer bank : `amount` (di-set BankTransferController)
    final note = _asMap(_data['note']);
    final notedNominal = _parseAmount(note['nominal']);
    final notedBankAmount = _parseAmount(note['amount']);
    final notedAdmin = _parseAmount(note['admin']);
    final dataAmount = _parseAmount(_data['amount']);

    final amount = notedNominal > 0
        ? notedNominal
        : (notedBankAmount > 0 ? notedBankAmount : dataAmount);
    final defaultAdmin = notedAdmin > 0 ? notedAdmin : 0;
    final adminController = TextEditingController(
      text: defaultAdmin.toInt().toString(),
    );
    final currencyFormat = NumberFormat('#,###', 'id_ID');

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final adminValue = double.tryParse(
                    adminController.text.replaceAll('.', '').replaceAll(',', '')) ??
                0;
            final total = amount + adminValue;

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              actionsPadding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              title: const Text(
                'Cetak Struk',
                style: TextStyle(
                  fontFamily: 'Gilroy Bold',
                  fontSize: 18,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Harga Admin (editable)
                  Row(
                    children: [
                      const Text(
                        'Harga Admin',
                        style: TextStyle(
                          fontFamily: 'Gilroy Medium',
                          fontSize: 14,
                          color: Color(0xFF555555),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: adminController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontFamily: 'Gilroy Bold',
                            fontSize: 14,
                            color: Color(0xFF333333),
                          ),
                          decoration: InputDecoration(
                            prefixText: 'Rp ',
                            prefixStyle: const TextStyle(
                              fontFamily: 'Gilroy Bold',
                              fontSize: 14,
                              color: Color(0xFF333333),
                            ),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                  color: Color(0xFFDDDDDD)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                  color: Color(0xFFDDDDDD)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                  color: Color(0xFF3C74BB), width: 1.5),
                            ),
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          onChanged: (_) => setDialogState(() {}),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Harga Produk (read-only, harga asli transaksi)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Harga Produk',
                        style: TextStyle(
                          fontFamily: 'Gilroy Medium',
                          fontSize: 14,
                          color: Color(0xFF555555),
                        ),
                      ),
                      Text(
                        'Rp ${currencyFormat.format(amount.toInt())}',
                        style: const TextStyle(
                          fontFamily: 'Gilroy Bold',
                          fontSize: 14,
                          color: Color(0xFF333333),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Divider(color: Color(0xFFE5E9EE), height: 1),
                  const SizedBox(height: 14),
                  // Total (auto-calculated: Harga Admin + Harga Produk)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total',
                        style: TextStyle(
                          fontFamily: 'Gilroy Bold',
                          fontSize: 16,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      Text(
                        'Rp ${currencyFormat.format(total.toInt())}',
                        style: const TextStyle(
                          fontFamily: 'Gilroy Bold',
                          fontSize: 16,
                          color: Color(0xFF3C74BB),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                                color: Color(0xFFCCCCCC), width: 1),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            'Batal',
                            style: TextStyle(
                              fontFamily: 'Gilroy Bold',
                              fontSize: 14,
                              color: Color(0xFF666666),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(dialogContext);
                            // Buat data sementara dengan admin custom
                            final printData =
                                Map<String, dynamic>.from(_data);
                            printData['admin'] = adminValue;
                            printData['amount'] = total;
                            printData['total'] = total;
                            // Simpan amount asli agar receipt bisa pakai
                            printData['original_amount'] = amount;
                            // Override juga di note/meta jika ada,
                            // agar UniversalReceipt joined map ikut terpengaruh
                            if (printData['note'] != null) {
                              try {
                                final noteMap = printData['note'] is Map
                                    ? Map<String, dynamic>.from(printData['note'] as Map)
                                    : (printData['note'] is String
                                        ? Map<String, dynamic>.from(
                                            jsonDecode(printData['note'] as String) as Map)
                                        : <String, dynamic>{});
                                if (noteMap.isNotEmpty) {
                                  noteMap['admin'] = adminValue;
                                  noteMap['total'] = total;
                                  printData['note'] = jsonEncode(noteMap);
                                }
                              } catch (_) {}
                            }
                            if (printData['meta'] != null) {
                              try {
                                final metaMap = printData['meta'] is Map
                                    ? Map<String, dynamic>.from(printData['meta'] as Map)
                                    : (printData['meta'] is String
                                        ? Map<String, dynamic>.from(
                                            jsonDecode(printData['meta'] as String) as Map)
                                        : <String, dynamic>{});
                                if (metaMap.isNotEmpty) {
                                  metaMap['admin'] = adminValue;
                                  metaMap['total'] = total;
                                  printData['meta'] = metaMap;
                                }
                              } catch (_) {}
                            }
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PrintReceiptPage(
                                  data: printData,
                                  autoDownload: false,
                                ),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF3C74BB),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            'Cetak',
                            style: TextStyle(
                              fontFamily: 'Gilroy Bold',
                              fontSize: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ----------------- transaction kind detection -----------------

  String _detectKind() {
    final c = (_data['category'] ?? '').toString().toLowerCase();
    final n = (_data['name'] ?? _data['product_name'] ?? '')
        .toString()
        .toLowerCase();
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
    if ((source.contains('pln') || source.contains('listrik')) &&
        (source.contains('prabayar') || source.contains('token'))) {
      return 'pln_prepaid';
    }
    if (source.contains('pulsa')) return 'pulsa';
    if (source.contains('paket') || source.contains('data')) return 'data';
    if (source.contains('e-money') ||
        source.contains('emoney') ||
        source.contains('e-wallet') ||
        source.contains('wallet')) {
      return 'emoney';
    }
    if (source.contains('voucher') ||
        source.contains('game') ||
        source.contains('epin')) {
      return 'voucher';
    }
    return 'generic';
  }

  String? _detectProviderLogo() {
    final source = [
      _data['name'],
      _data['product_name'],
      _data['category'],
    ].whereType<String>().join(' ').toLowerCase();
    if (source.contains('telkomsel') ||
        source.contains('simpati') ||
        source.contains('kartu as') ||
        source.contains('by.u')) return 'telkomsel';
    if (source.contains('im3') ||
        source.contains('indosat') ||
        source.contains('mentari')) return 'indosat';
    if (source.contains('smartfren')) return 'smartfren';
    if (source.contains('axis')) return 'axis';
    if (source.contains('tri') || source.contains('three')) return 'tri';
    if (source.contains('xl')) return 'xl';
    return null;
  }

  // ----------------- build -----------------

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final amount = _parseAmount(data['amount']);
    final orderId =
        (data['order_id'] ?? data['id'] ?? '-').toString();
    final productName =
        (data['name'] ?? data['product_name'] ?? '-').toString();
    final category = (data['category'] ?? '-').toString();
    final rawStatus = (data['status'] ??
            data['transaction_status'] ??
            data['payment_status'] ??
            'pending')
        .toString();
    final status = _normalizeStatus(rawStatus);
    final createdAt = parseDateTime(data['created_at']);
    final customerNo = _pickFirstNonEmpty([
      data['customer_no'],
      data['customer_id'],
      data['destination'],
      data['target'],
      data['phone_number'],
    ]);
    final paymentMethod =
        _pickFirstNonEmpty([data['payment_method'], data['bank_name']]);
    final adminFee = _parseAmount(data['admin'] ?? _asMap(data['note'])['admin']);

    final isPending = status == 'pending';
    final isSuccess = status == 'success';

    final statusColor = isSuccess
        ? const Color(0xFF2E7D32)
        : (isPending ? const Color(0xFFED9D00) : const Color(0xFFD32F2F));
    final statusBg = isSuccess
        ? const Color(0xFFE8F5E9)
        : (isPending ? const Color(0xFFFFF3E0) : const Color(0xFFFFEBEE));
    final statusIcon = isSuccess
        ? Icons.check_circle_outline_rounded
        : (isPending
            ? Icons.access_time_rounded
            : Icons.error_outline_rounded);
    final statusLabel = isSuccess
        ? 'Sukses'
        : (isPending ? 'Dalam Proses' : 'Gagal');
    final statusBanner = isSuccess
        ? 'Transaksi Berhasil'
        : (isPending ? 'Transaksi Dalam Proses' : 'Transaksi Gagal');

    final currencyFormat = NumberFormat('#,###', 'id_ID');
    final amountText = 'Rp ${currencyFormat.format(amount.toInt())}';
    final adminText =
        adminFee > 0 ? 'Rp ${currencyFormat.format(adminFee.toInt())}' : 'Gratis!';
    final headerDateFormat = DateFormat('d MMM yyyy • HH:mm', 'id_ID');
    final detailDateFormat = DateFormat('dd MMM yyyy, HH:mm:ss', 'id_ID');

    final providerLogo = _detectProviderLogo();
    final kind = _detectKind();

    const headerBlue = Color(0xFF3F75B7);
    const pageBg = Color(0xFFF5F5F7);

    return Scaffold(
      backgroundColor: pageBg,
      body: Stack(
        children: [
          Positioned.fill(
            child: Column(
              children: [
                Container(height: 170, color: headerBlue),
                Expanded(child: Container(color: pageBg)),
              ],
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Icon(Icons.close_rounded,
                            color: Colors.white, size: 30),
                      ),
                      const Expanded(
                        child: Text(
                          'Detail Transaksi',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Gilroy Bold',
                            fontSize: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 30),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 20),
                    child: Column(
                      children: [
                        Container(
                          width: double.infinity,
                          padding:
                              const EdgeInsets.fromLTRB(16, 8, 16, 14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (kind == 'pulsa') ...[
                                SizedBox(
                                  width: double.infinity,
                                  height: 100,
                                  child: Center(
                                    child: providerLogo != null
                                        ? Image.asset(
                                            'images/provider_logos/$providerLogo.webp',
                                            fit: BoxFit.contain,
                                            width: 220,
                                            height: 92,
                                            errorBuilder: (_, __, ___) =>
                                                Image.asset(
                                              'images/provider_logos/$providerLogo.png',
                                              fit: BoxFit.contain,
                                              width: 220,
                                              height: 92,
                                              errorBuilder: (_, __, ___) =>
                                                  _categoryIconFallback(kind),
                                            ),
                                          )
                                        : _categoryIconFallback(kind),
                                  ),
                                ),
                                const SizedBox(height: 4),
                              ] else
                                const SizedBox(height: 8),
                              Row(
                                children: [
                                  Flexible(
                                    flex: 7,
                                    child: Text(
                                      headerDateFormat.format(createdAt),
                                      style: const TextStyle(
                                        fontFamily: 'Gilroy Medium',
                                        fontSize: 13,
                                        color: Color(0xFF3A3A3A),
                                      ),
                                    ),
                                  ),
                                  Flexible(
                                    flex: 9,
                                    child: Text(
                                      'Id transaksi : $orderId',
                                      textAlign: TextAlign.right,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontFamily: 'Gilroy Medium',
                                        fontSize: 12,
                                        color: Color(0xFF3A3A3A),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              const Divider(
                                  color: Color(0xFFE6E9EE), height: 1),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Icon(statusIcon,
                                      size: 16, color: statusColor),
                                  const SizedBox(width: 6),
                                  Text(
                                    statusBanner,
                                    style: TextStyle(
                                      fontFamily: 'Gilroy Medium',
                                      fontSize: 13,
                                      color: statusColor,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                productName,
                                style: const TextStyle(
                                  fontFamily: 'Gilroy Bold',
                                  fontSize: 20,
                                  color: Color(0xFF161616),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF3F3F3),
                                      borderRadius:
                                          BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      category.toUpperCase(),
                                      style: const TextStyle(
                                        fontFamily: 'Gilroy Medium',
                                        fontSize: 12,
                                        color: Color(0xFF515151),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: statusBg,
                                      borderRadius:
                                          BorderRadius.circular(30),
                                      border: Border.all(
                                          color: statusColor.withValues(
                                              alpha: 0.6)),
                                    ),
                                    child: Text(
                                      statusLabel,
                                      style: TextStyle(
                                        fontFamily: 'Gilroy Medium',
                                        fontSize: 12,
                                        color: statusColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Detail Transaksi',
                                style: TextStyle(
                                  fontFamily: 'Gilroy Bold',
                                  fontSize: 17,
                                  color: Color(0xFF1A1A1A),
                                ),
                              ),
                              const SizedBox(height: 10),
                              _row('Id transaksi', _cleanOrderId(orderId),
                                  canCopy: true, onCopy: () async {
                                await Clipboard.setData(ClipboardData(
                                    text: _cleanOrderId(orderId)));
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content:
                                          Text('ID transaksi disalin')),
                                );
                              }),
                              _row('Nama Produk', productName),
                              ..._buildCategoryRows(
                                kind: kind,
                                data: data,
                                orderId: orderId,
                                amount: amount,
                                amountText: amountText,
                                adminText: adminText,
                                customerNo: customerNo,
                                paymentMethod: paymentMethod,
                                currencyFormat: currencyFormat,
                              ),
                              const Divider(
                                height: 14,
                                thickness: 1,
                                color: Color(0xFFE5E9EE),
                              ),
                              _row('Waktu',
                                  detailDateFormat.format(createdAt)),
                              _row(
                                'Sumber Dana',
                                (data['payment_source'] ?? 'saldo')
                                            .toString() ==
                                        'limit'
                                    ? 'Limit'
                                    : 'Saldo',
                              ),
                              _row('Status', statusLabel,
                                  valueColor: statusColor),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (!isPending)
                          Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 54,
                                  child: OutlinedButton(
                                    onPressed: () => _showPrintAdminPopup(),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(
                                        color: Color(0xFF3C74BB),
                                        width: 1.5,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(14),
                                      ),
                                    ),
                                    child: const Text(
                                      'PRINT',
                                      style: TextStyle(
                                        fontFamily: 'Gilroy Bold',
                                        fontSize: 16,
                                        color: Color(0xFF3C74BB),
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: SizedBox(
                                  height: 54,
                                  child: ElevatedButton(
                                    onPressed: _isCheckingStatus ? null : _checkTransactionStatus,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF3C74BB),
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(14),
                                      ),
                                    ),
                                    child: _isCheckingStatus
                                        ? const SizedBox(
                                            width: 20, height: 20,
                                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                          )
                                        : const Text(
                                            'CEK STATUS',
                                            style: TextStyle(
                                              fontFamily: 'Gilroy Bold',
                                              fontSize: 16,
                                              color: Colors.white,
                                              letterSpacing: 1,
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                            ],
                          )
                        else
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: ElevatedButton(
                              onPressed: _isCheckingStatus ? null : _checkTransactionStatus,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF3C74BB),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                              ),
                              child: _isCheckingStatus
                                  ? const SizedBox(
                                      width: 20, height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Text(
                                      'CEK STATUS',
                                      style: TextStyle(
                                        fontFamily: 'Gilroy Bold',
                                        fontSize: 16,
                                        color: Colors.white,
                                        letterSpacing: 1,
                                      ),
                                    ),
                            ),
                          ),
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: () => Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const Bottombar()),
                            (route) => false,
                          ),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 6),
                            child: Text(
                              'Kembali ke Beranda',
                              style: TextStyle(
                                fontFamily: 'Gilroy Bold',
                                fontSize: 16,
                                color: Color(0xFF3C86D6),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Bangun deretan baris detail sesuai kategori transaksi.
  ///
  /// Khusus PLN Prabayar mengikuti breakdown yang diminta user:
  /// IDPEL → meter_no, Nama → customer_name, Tarif/Daya → tariff_daya,
  /// Stand Meter → subscriber_id, No Ref → order_id (tanpa "PPOB-"),
  /// Biaya Admin → admin, Total Bayar → total, Info → info.
  List<Widget> _buildCategoryRows({
    required String kind,
    required Map<String, dynamic> data,
    required String orderId,
    required double amount,
    required String amountText,
    required String adminText,
    required String customerNo,
    required String paymentMethod,
    required NumberFormat currencyFormat,
  }) {
    if (kind == 'bank_transfer') {
      // Untuk bank_transfer, sumber yang benar adalah `note` JSON yang
      // disimpan saat purchase: amount=nominal asli, admin=biaya admin,
      // total=saldo dipotong. Kunci `amount` di Transaction root justru
      // sudah jadi total (saldo dipotong) — itu konflik. Jadi kita
      // baca dari note/meta dulu sebelum fallback ke joined map.
      final note = _asMap(data['note']);
      final meta = _asMap(data['meta']);
      // Order: data root (paling rendah prioritas) → note → meta (tertinggi).
      // Field bank yang konflik dengan Transaction root (`amount`) akan
      // di-overwrite oleh value dari note.
      final bankSrc = <String, dynamic>{...data, ...note, ...meta};

      String s(String key) => (bankSrc[key] ?? '').toString().trim();
      double n(String key) {
        final v = bankSrc[key];
        if (v is num) return v.toDouble();
        if (v is String) {
          return double.tryParse(v.replaceAll(',', '').trim()) ?? 0.0;
        }
        return 0.0;
      }

      final accountName = s('account_name').isNotEmpty
          ? s('account_name')
          : s('nama_penerima');
      final accountNumber = s('account_number').isNotEmpty
          ? s('account_number')
          : s('nomor_rekening').isNotEmpty
              ? s('nomor_rekening')
              : customerNo;
      final bankName = s('bank_name').isNotEmpty
          ? s('bank_name')
          : s('bank').isNotEmpty
              ? s('bank')
              : paymentMethod;
      final notes = s('notes');
      final providerReff = s('reff').isNotEmpty
          ? s('reff')
          : s('provider_ref');

      // amount = nominal yang user transfer (bukan total). Total dari
      // Transaction root dipakai sebagai fallback terakhir.
      final amountVal = n('amount') > 0 ? n('amount') : amount;
      final adminVal = n('admin') > 0 ? n('admin') : n('fee');
      final totalVal = n('total') > 0
          ? n('total')
          : (amountVal + adminVal > 0 ? amountVal + adminVal : amount);

      String money(double v) => 'Rp ${currencyFormat.format(v.toInt())}';

      return [
        if (bankName.isNotEmpty) _row('Bank Tujuan', bankName),
        if (accountNumber.isNotEmpty)
          _row(
            'No. Rekening',
            accountNumber,
            canCopy: true,
            onCopy: () async {
              await Clipboard.setData(ClipboardData(text: accountNumber));
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Nomor rekening disalin')),
              );
            },
          ),
        if (accountName.isNotEmpty) _row('Nama Penerima', accountName),
        _row('No. Ref', _cleanOrderId(orderId)),
        if (providerReff.isNotEmpty && providerReff != _cleanOrderId(orderId))
          _row('Reff', providerReff),
        _row('Nominal', money(amountVal)),
        _row('Biaya Admin',
            adminVal > 0 ? money(adminVal) : 'Gratis!'),
        if (notes.isNotEmpty) _row('Catatan', notes),
        const Divider(
          height: 14,
          thickness: 1,
          color: Color(0xFFE5E9EE),
        ),
        _row('Total Bayar', money(totalVal), large: true),
      ];
    }

    if (kind == 'pln_prepaid') {
      final joined = _joinedPlnData(data);
      String s(String key) => (joined[key] ?? '').toString().trim();
      double n(String key) {
        final v = joined[key];
        if (v is num) return v.toDouble();
        if (v is String) {
          return double.tryParse(v.replaceAll(',', '').trim()) ?? 0.0;
        }
        return 0.0;
      }

      final idpel = s('meter_no').isNotEmpty
          ? s('meter_no')
          : s('subscriber_id').isNotEmpty
              ? s('subscriber_id')
              : s('customer_no');
      final nama = s('customer_name');
      final tariffDaya = s('tariff_daya');
      final standMeter = s('subscriber_id') == s('meter_no')
          ? '' // hindari duplikat dengan IDPEL
          : s('subscriber_id');
      final noRef = _cleanOrderId(orderId);
      final adminVal = n('admin');
      final totalVal = n('total') > 0 ? n('total') : amount;
      final info = s('info');
      final rawToken = s('token');
      final formattedToken = _formatTokenCode(rawToken);

      String moneyOrDash(double v) =>
          v > 0 ? 'Rp ${currencyFormat.format(v.toInt())}' : 'Gratis!';

      return [
        if (idpel.isNotEmpty) _row('IDPEL', idpel),
        if (nama.isNotEmpty) _row('Nama', nama),
        if (tariffDaya.isNotEmpty) _row('Tarif/Daya', tariffDaya),
        if (standMeter.isNotEmpty) _row('Stand Meter', standMeter),
        _row('No. Ref', noRef),
        if (rawToken.isNotEmpty)
          _row(
            'Token',
            formattedToken,
            canCopy: true,
            onCopy: () async {
              await Clipboard.setData(ClipboardData(text: rawToken));
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Token disalin')),
              );
            },
          ),
        _row('Biaya Admin', moneyOrDash(adminVal)),
        const Divider(
          height: 14,
          thickness: 1,
          color: Color(0xFFE5E9EE),
        ),
        _row('Total Bayar',
            'Rp ${currencyFormat.format(totalVal.toInt())}',
            large: true),
        if (info.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Text(
            'Info',
            style: TextStyle(
              fontFamily: 'Gilroy Medium',
              fontSize: 13,
              color: Color(0xFF999999),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            info,
            style: const TextStyle(
              fontFamily: 'Gilroy Medium',
              fontSize: 12,
              color: Color(0xFF374151),
              height: 1.45,
            ),
          ),
        ],
      ];
    }

    // Default (Pulsa, Data, E-Money, Voucher, Generic)
    //
    // Untuk e-wallet & produk bebas nominal, `data.amount` adalah saldo yang
    // dipotong (= nominal + admin), sedangkan `note.nominal` adalah harga
    // produk asli yang sampai ke tujuan. Pakai itu sebagai `Harga`.
    final note = _asMap(data['note']);
    final meta = _asMap(data['meta']);
    // Note disimpan oleh backend dengan field final (admin panel, total user).
    // Meta kadang berisi response provider (admin Loketbayar 0). Note menang.
    final genSrc = <String, dynamic>{...meta, ...note};
    double parseNum(dynamic v) {
      if (v is num) return v.toDouble();
      if (v is String) {
        return double.tryParse(v.replaceAll(',', '').trim()) ?? 0.0;
      }
      return 0.0;
    }
    final notedNominal = parseNum(genSrc['nominal']);
    final notedAdmin = parseNum(genSrc['admin']);
    final rootAdmin = parseNum(data['admin']);
    final hargaVal = notedNominal > 0 ? notedNominal : amount;
    final hargaText = 'Rp ${currencyFormat.format(hargaVal.toInt())}';
    final adminVal = notedAdmin > 0 ? notedAdmin : rootAdmin;
    final adminTextLocal = adminVal > 0
        ? 'Rp ${currencyFormat.format(adminVal.toInt())}'
        : 'Gratis!';

    // Nama penerima dari note (mis. e-wallet bebas nominal). Untuk pulsa
    // umumnya kosong. Tampilkan kalau ada.
    final receiverName = (genSrc['customer_name'] ?? '').toString().trim();

    final serialNumber = _pickFirstNonEmpty([
      data['provider_ref'],
      data['serial_number'],
      data['sn'],
    ]);
    return [
      if (customerNo.isNotEmpty) _row(_destLabel(kind), customerNo),
      if (receiverName.isNotEmpty) _row('Nama Penerima', receiverName),
      _row('Metode Pembayaran',
          paymentMethod.isEmpty ? '-' : paymentMethod),
      _row('Kode Promosi', '-'),
      _row('Harga', hargaText),
      _row('Biaya Admin', adminTextLocal),
      if (serialNumber.isNotEmpty)
        _row(
          'Serial Number',
          serialNumber,
          canCopy: true,
          onCopy: () async {
            await Clipboard.setData(ClipboardData(text: serialNumber));
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Serial Number disalin')),
            );
          },
        ),
      const Divider(
        height: 14,
        thickness: 1,
        color: Color(0xFFE5E9EE),
      ),
      _row('Total', amountText, large: true),
      _row('No. Referensi', _cleanOrderId(orderId)),
    ];
  }

  String _destLabel(String kind) {
    switch (kind) {
      case 'pulsa':
      case 'data':
        return 'Nomor Handphone';
      case 'pln_prepaid':
      case 'pln_postpaid':
        return 'ID Pelanggan';
      case 'emoney':
      case 'voucher':
        return 'Tujuan';
      default:
        return 'Nomor';
    }
  }

  Widget _categoryIconFallback(String kind) {
    IconData icon;
    Color color;
    switch (kind) {
      case 'pln_prepaid':
      case 'pln_postpaid':
        icon = Icons.bolt_rounded;
        color = const Color(0xFFFFA000);
        break;
      case 'pulsa':
      case 'data':
        icon = Icons.sim_card_rounded;
        color = const Color(0xFF1E63C6);
        break;
      case 'emoney':
        icon = Icons.account_balance_wallet_rounded;
        color = const Color(0xFF1E63C6);
        break;
      case 'voucher':
        icon = Icons.confirmation_number_rounded;
        color = const Color(0xFF1E63C6);
        break;
      default:
        icon = Icons.receipt_long_rounded;
        color = const Color(0xFF1E63C6);
    }
    return Icon(icon, size: 74, color: color);
  }

  Widget _row(
    String label,
    String value, {
    Color? valueColor,
    bool large = false,
    bool canCopy = false,
    VoidCallback? onCopy,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 138,
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'Gilroy Medium',
                fontSize: large ? 16 : 13,
                color: const Color(0xFF999999),
              ),
            ),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    value,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontFamily: 'Gilroy Bold',
                      fontSize: large ? 17 : 13,
                      color: valueColor ?? const Color(0xFF333333),
                    ),
                  ),
                ),
                if (canCopy) ...[
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: onCopy,
                    child: const Icon(
                      Icons.copy_rounded,
                      size: 15,
                      color: Color(0xFF3C86D6),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
