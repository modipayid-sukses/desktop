import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:modipay/bottombar/bottombar.dart';
import 'package:modipay/home/print_receipt_page.dart';
import 'package:modipay/services/api_service.dart' show ApiService;
import 'package:intl/intl.dart';
import 'package:modipay/utils/color.dart';
import 'package:modipay/utils/responsive.dart';
import 'package:modipay/utils/transaction_helpers.dart';
import 'package:modipay/profile/complaint_form_screen.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';

class TransactionDetail extends StatefulWidget {
  final Map<String, dynamic> data;
  const TransactionDetail({super.key, required this.data});

  @override
  State<TransactionDetail> createState() => _TransactionDetailState();
}

class _TransactionDetailState extends State<TransactionDetail> {
  Map<String, dynamic> _hydratedPlnData = const {};
  bool _isCheckingStatus = false;
  final GlobalKey _desktopReceiptKey = GlobalKey();
  bool _isCapturingReceipt = false;

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

  /// Beberapa provider (PLN sandbox/dummy) mengembalikan `customer_name`
  /// yang sudah dibungkus label sendiri, mis. "NAMA: TEST USER" — buang
  /// prefix itu supaya tidak dobel dengan label "Nama"/"Nama Penerima"
  /// yang sudah kita render di UI.
  String _stripNamePrefix(String value) {
    return value.replaceFirst(RegExp(r'^\s*nama\s*:\s*', caseSensitive: false), '').trim();
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
    if (s.contains('expired') ||
        s.contains('kadalursa') ||
        s.contains('kedaluwarsa')) return 'expired';
    if (s.contains('failed') ||
        s.contains('gagal') ||
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

  // ----------------- desktop receipt capture (Bukti Transaksi) -----------------

  Future<Uint8List?> _captureDesktopReceipt() async {
    try {
      final boundary = _desktopReceiptKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  Future<bool> _requestGalleryPermission() async {
    if (Platform.isIOS) {
      final status = await Permission.photos.request();
      return status.isGranted || status.isLimited;
    }
    if (Platform.isAndroid) {
      final photoStatus = await Permission.photos.request();
      if (photoStatus.isGranted || photoStatus.isLimited) return true;
      final storageStatus = await Permission.storage.request();
      return storageStatus.isGranted;
    }
    return true;
  }

  Future<void> _downloadDesktopReceipt() async {
    if (_isCapturingReceipt) return;
    setState(() => _isCapturingReceipt = true);
    try {
      final granted = await _requestGalleryPermission();
      if (!granted) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Izin penyimpanan ditolak')),
        );
        return;
      }
      final bytes = await _captureDesktopReceipt();
      if (bytes == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal menyimpan bukti transaksi')),
        );
        return;
      }
      final orderId = (_data['order_id'] ?? _data['id'] ??
              DateTime.now().millisecondsSinceEpoch)
          .toString();
      final result = await ImageGallerySaverPlus.saveImage(
        bytes,
        name: 'BUKTI_TRANSAKSI_$orderId',
      );
      if (!mounted) return;
      final ok = result is Map ? result['isSuccess'] == true : false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok
              ? 'Bukti transaksi berhasil disimpan'
              : 'Gagal menyimpan bukti transaksi'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal menyimpan bukti transaksi')),
      );
    } finally {
      if (mounted) setState(() => _isCapturingReceipt = false);
    }
  }

  Future<void> _shareDesktopReceipt() async {
    if (_isCapturingReceipt) return;
    setState(() => _isCapturingReceipt = true);
    try {
      final bytes = await _captureDesktopReceipt();
      if (bytes == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal membagikan bukti transaksi')),
        );
        return;
      }
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/bukti_transaksi_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path)], text: 'Bukti transaksi');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal membagikan bukti transaksi')),
      );
    } finally {
      if (mounted) setState(() => _isCapturingReceipt = false);
    }
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
    if (isDesktop(context)) {
      return _buildDesktopLayout(context);
    }

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
    final isExpired = status == 'expired';

    final statusColor = isSuccess
        ? const Color(0xFF2E7D32)
        : (isPending 
            ? const Color(0xFFED9D00) 
            : (isExpired ? Colors.grey : const Color(0xFFD32F2F)));
    final statusBg = isSuccess
        ? const Color(0xFFE8F5E9)
        : (isPending 
            ? const Color(0xFFFFF3E0) 
            : (isExpired ? const Color(0xFFEEEEEE) : const Color(0xFFFFEBEE)));
    final statusIcon = isSuccess
        ? Icons.check_circle_outline_rounded
        : (isPending
            ? Icons.access_time_rounded
            : (isExpired ? Icons.timer_off_outlined : Icons.error_outline_rounded));
    final statusLabel = isSuccess
        ? 'Sukses'
        : (isPending 
            ? 'Dalam Proses' 
            : (isExpired ? 'Kedaluwarsa' : 'Gagal'));
    final statusBanner = isSuccess
        ? 'Transaksi Berhasil'
        : (isPending 
            ? 'Transaksi Dalam Proses' 
            : (isExpired ? 'Transaksi Kedaluwarsa' : 'Transaksi Gagal'));

    final currencyFormat = NumberFormat('#,###', 'id_ID');
    final amountText = 'Rp ${currencyFormat.format(amount.toInt())}';
    final adminText =
        adminFee > 0 ? 'Rp ${currencyFormat.format(adminFee.toInt())}' : 'Gratis!';
    final headerDateFormat = DateFormat('d MMM yyyy • HH:mm', 'id_ID');
    final detailDateFormat = DateFormat('dd MMM yyyy, HH:mm:ss', 'id_ID');

    final providerLogo = _detectProviderLogo();
    final kind = _detectKind();

    const pageBg = Color(0xFFF5F5F7);

    return Scaffold(
      backgroundColor: pageBg,
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(color: pageBg),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 10, 14, 8),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A1A)),
                      ),
                      const Expanded(
                        child: Text(
                          'Detail Transaksi',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Gilroy Bold',
                            fontSize: 17,
                            color: Color(0xFF1A1A1A),
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
                        if (status == 'pending' || status == 'failed') ...[
                          const SizedBox(height: 12),
                          GestureDetector(
                            onTap: () {
                              final txId = data['id'] is int 
                                  ? data['id'] as int 
                                  : int.tryParse(data['id']?.toString() ?? '');
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ComplaintFormScreen(
                                    transactionId: txId,
                                    transactionCode: orderId,
                                  ),
                                ),
                              );
                            },
                            child: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 6),
                              child: Text(
                                'Laporkan Masalah',
                                style: TextStyle(
                                  fontFamily: 'Gilroy Bold',
                                  fontSize: 16,
                                  color: Colors.red,
                                ),
                              ),
                            ),
                          ),
                        ],
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

  // ================= Desktop layout ("Detail Transaksi" two-column) =======
  //
  // Wide/desktop-only redesign matching the "Vivid Enterprise" reference:
  // left card = full transaction breakdown, right card = printable "Bukti
  // Transaksi" receipt with download/share actions, bottom = PRINT/CEK
  // STATUS. Mobile layout above is untouched. Reuses the same data-parsing
  // helpers as the mobile branch (`_buildCategoryRows`) via
  // `_desktopCategoryData` so both stay in sync with backend field names.

  Widget _buildDesktopLayout(BuildContext context) {
    final data = _data;
    final amount = _parseAmount(data['amount']);
    final orderId = (data['order_id'] ?? data['id'] ?? '-').toString();
    final cleanOrderId = _cleanOrderId(orderId);
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

    final isPending = status == 'pending';
    final isSuccess = status == 'success';
    final isExpired = status == 'expired';

    final statusColor = isSuccess
        ? desktopSuccessFg
        : (isPending
            ? desktopWarningAmber
            : (isExpired ? desktopTextSecondary : desktopErrorRed));
    final statusBg = isSuccess
        ? desktopSuccessBg
        : (isPending
            ? desktopWarningAmber.withValues(alpha: 0.12)
            : (isExpired
                ? desktopTextSecondary.withValues(alpha: 0.1)
                : desktopErrorRed.withValues(alpha: 0.1)));
    final statusIcon = isSuccess
        ? Icons.check_circle_rounded
        : (isPending
            ? Icons.access_time_rounded
            : (isExpired ? Icons.timer_off_outlined : Icons.error_rounded));
    final statusLabel = isSuccess
        ? 'Sukses'
        : (isPending
            ? 'Dalam Proses'
            : (isExpired ? 'Kedaluwarsa' : 'Gagal'));
    final statusBanner = isSuccess
        ? 'Transaksi Berhasil'
        : (isPending
            ? 'Transaksi Dalam Proses'
            : (isExpired ? 'Transaksi Kedaluwarsa' : 'Transaksi Gagal'));
    final statusSubtitle = isSuccess
        ? 'Terima kasih, transaksi Anda berhasil diproses.'
        : (isPending
            ? 'Transaksi Anda sedang diproses, mohon tunggu.'
            : (isExpired
                ? 'Transaksi ini sudah tidak berlaku.'
                : 'Transaksi tidak dapat diproses.'));

    final currencyFormat = NumberFormat('#,###', 'id_ID');
    final headerDateFormat = DateFormat('d MMM yyyy • HH:mm', 'id_ID');
    final detailDateFormat = DateFormat('dd MMM yyyy, HH:mm:ss', 'id_ID');
    final kind = _detectKind();

    final catData = _desktopCategoryData(
      kind: kind,
      data: data,
      orderId: orderId,
      amount: amount,
      customerNo: customerNo,
      paymentMethod: paymentMethod,
      currencyFormat: currencyFormat,
    );

    final leftRows = <_KV>[
      _KV('Id transaksi', cleanOrderId, copyable: true),
      _KV('Nama Produk', productName),
      ...catData.rows,
    ];

    final receiptRows = <_KV>[
      _KV('Produk', productName),
      // "No. Ref"/"No. Referensi" selalu ditambahkan ulang di bawah dengan
      // label baku "No. Referensi" — buang dulu biar tidak dobel di struk.
      ...catData.rows.where((e) => e.label != 'No. Referensi' && e.label != 'No. Ref'),
      _KV('ID Transaksi', cleanOrderId, copyable: true, dividerBefore: true),
      _KV('No. Referensi', cleanOrderId),
    ];

    // Everything (title bar, both cards, PRINT/CEK STATUS) lives inside one
    // shared max-width panel so the header always lines up with the content
    // beneath it — previously the title bar spanned the full window while
    // the cards were centered in a narrower column, so on wide windows the
    // title drifted away from what it was labeling.
    const panelMaxWidth = 1080.0;

    return Scaffold(
      backgroundColor: const Color(0xFFE8EAEF),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight - 48),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: panelMaxWidth),
                    child: Container(
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: desktopSurfacePage,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: desktopBorder.withValues(alpha: 0.35)),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.07), blurRadius: 28, offset: const Offset(0, 14)),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            decoration: BoxDecoration(
                              color: desktopSurfaceCard,
                              border: Border(
                                bottom: BorderSide(color: desktopBorder.withValues(alpha: 0.3)),
                              ),
                            ),
                            child: Row(
                              children: [
                                InkWell(
                                  onTap: () => Navigator.pop(context),
                                  borderRadius: BorderRadius.circular(20),
                                  child: const Padding(
                                    padding: EdgeInsets.all(6),
                                    child: Icon(Icons.close_rounded, size: 22, color: desktopTextPrimary),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    'Detail Transaksi',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.hankenGrotesk(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      color: desktopTextPrimary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 34),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: _desktopLeftCard(
                                        statusColor: statusColor,
                                        statusBg: statusBg,
                                        statusIcon: statusIcon,
                                        statusBanner: statusBanner,
                                        statusSubtitle: statusSubtitle,
                                        statusLabel: statusLabel,
                                        headerDateLabel: headerDateFormat.format(createdAt),
                                        orderId: cleanOrderId,
                                        productName: productName,
                                        category: category,
                                        kind: kind,
                                        rows: leftRows,
                                        infoText: catData.infoText,
                                        footerRows: [
                                          _KV('Waktu', detailDateFormat.format(createdAt)),
                                          _KV(
                                            'Sumber Dana',
                                            (data['payment_source'] ?? 'saldo').toString() == 'limit'
                                                ? 'Limit'
                                                : 'Saldo',
                                          ),
                                        ],
                                        statusRowColor: statusColor,
                                      ),
                                    ),
                                    const SizedBox(width: 24),
                                    SizedBox(
                                      width: 340,
                                      child: _desktopReceiptCard(
                                        statusColor: statusColor,
                                        statusBg: statusBg,
                                        statusIcon: statusIcon,
                                        statusBanner: statusBanner,
                                        dateLabel: detailDateFormat.format(createdAt),
                                        rows: receiptRows,
                                        infoText: catData.infoText,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 24),
                                _desktopActionRow(isPending: isPending),
                                if (status == 'pending' || status == 'failed') ...[
                                  const SizedBox(height: 14),
                                  Center(
                                    child: TextButton(
                                      onPressed: () {
                                        final txId = data['id'] is int
                                            ? data['id'] as int
                                            : int.tryParse(data['id']?.toString() ?? '');
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => ComplaintFormScreen(
                                              transactionId: txId,
                                              transactionCode: orderId,
                                            ),
                                          ),
                                        );
                                      },
                                      child: Text(
                                        'Laporkan Masalah',
                                        style: GoogleFonts.hankenGrotesk(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: desktopErrorRed,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _desktopLeftCard({
    required Color statusColor,
    required Color statusBg,
    required IconData statusIcon,
    required String statusBanner,
    required String statusSubtitle,
    required String statusLabel,
    required String headerDateLabel,
    required String orderId,
    required String productName,
    required String category,
    required String kind,
    required List<_KV> rows,
    required String infoText,
    required List<_KV> footerRows,
    required Color statusRowColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: desktopSurfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: desktopBorder.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: statusBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(statusIcon, size: 20, color: statusColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        statusBanner,
                        style: GoogleFonts.hankenGrotesk(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: statusColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        statusSubtitle,
                        style: GoogleFonts.hankenGrotesk(fontSize: 12.5, color: desktopTextSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                headerDateLabel,
                style: GoogleFonts.hankenGrotesk(fontSize: 13, color: desktopTextSecondary),
              ),
              Text(
                '  •  ID Transaksi: ',
                style: GoogleFonts.hankenGrotesk(fontSize: 13, color: desktopTextSecondary),
              ),
              Flexible(
                child: Text(
                  orderId,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: desktopAccentBlue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(color: desktopBorder.withValues(alpha: 0.5)),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: desktopAccentBlue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(11),
                ),
                alignment: Alignment.center,
                child: _categoryIconFallback(kind, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      productName,
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: desktopTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: desktopSurfacePage,
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Text(
                            category.toUpperCase(),
                            style: GoogleFonts.hankenGrotesk(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: desktopTextSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusBg,
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(color: statusColor.withValues(alpha: 0.5)),
                          ),
                          child: Text(
                            statusLabel,
                            style: GoogleFonts.hankenGrotesk(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Divider(color: desktopBorder.withValues(alpha: 0.5)),
          const SizedBox(height: 14),
          Text(
            'Detail Transaksi',
            style: GoogleFonts.hankenGrotesk(fontSize: 15, fontWeight: FontWeight.w800, color: desktopTextPrimary),
          ),
          const SizedBox(height: 10),
          for (final kv in rows) _desktopRowOrTotal(kv, statusRowColor: statusRowColor),
          if (infoText.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Info',
              style: GoogleFonts.hankenGrotesk(fontSize: 13, fontWeight: FontWeight.w700, color: desktopTextSecondary),
            ),
            const SizedBox(height: 4),
            Text(
              infoText,
              style: GoogleFonts.hankenGrotesk(fontSize: 12.5, color: desktopTextSecondary, height: 1.45),
            ),
          ],
          const SizedBox(height: 4),
          Divider(color: desktopBorder.withValues(alpha: 0.5)),
          const SizedBox(height: 4),
          for (final kv in footerRows) _desktopDetailRow(kv),
          _desktopDetailRow(_KV('Status', statusLabel), valueColor: statusRowColor, isBadge: true, badgeBg: statusBg),
        ],
      ),
    );
  }

  Widget _desktopRowOrTotal(_KV kv, {required Color statusRowColor}) {
    if (kv.isTotal) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: desktopAccentBlue.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(kv.label, style: GoogleFonts.hankenGrotesk(fontSize: 14, fontWeight: FontWeight.w700, color: desktopTextPrimary)),
              Text(
                kv.value,
                style: GoogleFonts.hankenGrotesk(fontSize: 18, fontWeight: FontWeight.w800, color: desktopAccentBlue),
              ),
            ],
          ),
        ),
      );
    }
    return _desktopDetailRow(kv);
  }

  Widget _desktopDetailRow(
    _KV kv, {
    Color? valueColor,
    bool isBadge = false,
    Color? badgeBg,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              kv.label,
              style: GoogleFonts.hankenGrotesk(fontSize: 13, color: desktopTextSecondary),
            ),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: isBadge
                      ? Align(
                          alignment: Alignment.centerRight,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: badgeBg,
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Text(
                              kv.value,
                              style: GoogleFonts.hankenGrotesk(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: valueColor ?? desktopTextPrimary,
                              ),
                            ),
                          ),
                        )
                      : Text(
                          kv.value,
                          textAlign: TextAlign.right,
                          style: GoogleFonts.hankenGrotesk(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: valueColor ?? desktopTextPrimary,
                          ),
                        ),
                ),
                if (kv.copyable) ...[
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: () async {
                      await Clipboard.setData(ClipboardData(text: kv.copyValue ?? kv.value));
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('${kv.label} disalin')),
                      );
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: const Padding(
                      padding: EdgeInsets.all(2),
                      child: Icon(Icons.copy_rounded, size: 14, color: desktopAccentBlue),
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

  Widget _desktopReceiptCard({
    required Color statusColor,
    required Color statusBg,
    required IconData statusIcon,
    required String statusBanner,
    required String dateLabel,
    required List<_KV> rows,
    required String infoText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Bukti Transaksi',
          style: GoogleFonts.hankenGrotesk(fontSize: 15, fontWeight: FontWeight.w800, color: desktopTextPrimary),
        ),
        const SizedBox(height: 14),
        ClipPath(
          clipper: const _ReceiptScallopClipper(),
          child: RepaintBoundary(
            key: _desktopReceiptKey,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              decoration: BoxDecoration(
                color: desktopSurfaceCard,
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 18, offset: const Offset(0, 8)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: const BoxDecoration(color: desktopAccentBlue, shape: BoxShape.circle),
                        alignment: Alignment.center,
                        child: Text('m', style: GoogleFonts.hankenGrotesk(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'modipay',
                        style: GoogleFonts.hankenGrotesk(fontSize: 17, fontWeight: FontWeight.w800, color: desktopAccentBlue),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(20)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, size: 13, color: statusColor),
                          const SizedBox(width: 5),
                          Text(
                            statusBanner,
                            style: GoogleFonts.hankenGrotesk(fontSize: 11.5, fontWeight: FontWeight.w800, color: statusColor),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: Text(
                      dateLabel,
                      style: GoogleFonts.hankenGrotesk(fontSize: 11.5, color: desktopTextSecondary),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Divider(color: desktopBorder.withValues(alpha: 0.5), height: 1),
                  const SizedBox(height: 8),
                  for (final kv in rows) ...[
                    if (kv.dividerBefore || kv.isTotal) ...[
                      const SizedBox(height: 4),
                      Divider(color: desktopBorder.withValues(alpha: 0.4), height: 1),
                      const SizedBox(height: 8),
                    ],
                    kv.isTotal
                        ? Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Text(kv.label, style: GoogleFonts.hankenGrotesk(fontSize: 13, fontWeight: FontWeight.w700, color: desktopTextPrimary)),
                                const Spacer(),
                                Text(
                                  kv.value,
                                  style: GoogleFonts.hankenGrotesk(fontSize: 17, fontWeight: FontWeight.w800, color: desktopAccentBlue),
                                ),
                              ],
                            ),
                          )
                        : _receiptRow(kv.label, kv.value),
                  ],
                  if (infoText.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Divider(color: desktopBorder.withValues(alpha: 0.4), height: 1),
                    const SizedBox(height: 8),
                    Text(
                      'Info',
                      style: GoogleFonts.hankenGrotesk(fontSize: 11.5, fontWeight: FontWeight.w700, color: desktopTextSecondary),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      infoText,
                      style: GoogleFonts.hankenGrotesk(fontSize: 11.5, color: desktopTextSecondary, height: 1.4),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: desktopAccentBlue.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_rounded, size: 15, color: desktopAccentBlue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Simpan bukti transaksi ini sebagai referensi Anda.',
                            style: GoogleFonts.hankenGrotesk(fontSize: 11.5, color: desktopTextSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 44,
                child: OutlinedButton.icon(
                  onPressed: _isCapturingReceipt ? null : _downloadDesktopReceipt,
                  icon: const Icon(Icons.download_rounded, size: 16, color: desktopAccentBlue),
                  label: Text('Download', style: GoogleFonts.hankenGrotesk(fontSize: 13, fontWeight: FontWeight.w700, color: desktopAccentBlue)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: desktopBorder),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SizedBox(
                height: 44,
                child: OutlinedButton.icon(
                  onPressed: _isCapturingReceipt ? null : _shareDesktopReceipt,
                  icon: const Icon(Icons.ios_share_rounded, size: 16, color: desktopAccentBlue),
                  label: Text('Bagikan', style: GoogleFonts.hankenGrotesk(fontSize: 13, fontWeight: FontWeight.w700, color: desktopAccentBlue)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: desktopBorder),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Struk (kartu "Bukti Transaksi") cuma ~300px lebar bersih. Nilai pendek
  // (mis. "Gratis!", "R1M/900") tetap sebaris dengan labelnya, tapi nilai
  // panjang (nomor order, token PLN berspasi, nama produk+nominal) diukur
  // dulu — kalau tidak muat sebaris, baru dipindah ke baris sendiri di
  // bawah label supaya tidak patah di tengah kata/nomor secara acak
  // (mis. "LB-" kepisah sendirian dari "FOPZNDGJAEXF").
  static const double _kReceiptContentWidth = 300;

  Widget _receiptRow(String label, String value, {double maxWidth = _kReceiptContentWidth}) {
    final labelStyle = GoogleFonts.hankenGrotesk(fontSize: 12.5, color: desktopTextSecondary);
    final valueStyle = GoogleFonts.hankenGrotesk(fontSize: 12.5, fontWeight: FontWeight.w700, color: desktopTextPrimary);

    final labelWidth = (TextPainter(
      text: TextSpan(text: label, style: labelStyle),
      textDirection: ui.TextDirection.ltr,
    )..layout())
        .width;
    final valueWidth = (TextPainter(
      text: TextSpan(text: value, style: valueStyle),
      textDirection: ui.TextDirection.ltr,
    )..layout())
        .width;
    final fitsInline = valueWidth <= (maxWidth - labelWidth - 12);

    if (fitsInline) {
      // `Spacer()` + `Flexible()` both default to flex:1, so they'd split
      // the remaining width 50/50 — but `Flexible` is loose-fit and only
      // claims as much of its half as the text needs, leaving the other
      // half as dead space nothing pushes into. Short values then land
      // well short of the shared right edge instead of flush against it.
      // `Expanded` + `Align` instead always claims the *entire* remaining
      // width and aligns the text to its right edge, so every row's value
      // lines up on the same right margin regardless of its own length.
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: labelStyle),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(value, textAlign: TextAlign.right, style: valueStyle),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: labelStyle),
          const SizedBox(height: 3),
          SizedBox(
            width: double.infinity,
            child: Text(value, textAlign: TextAlign.right, style: valueStyle),
          ),
        ],
      ),
    );
  }

  Widget _desktopActionRow({required bool isPending}) {
    if (isPending) {
      return SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: _isCheckingStatus ? null : _checkTransactionStatus,
          style: ElevatedButton.styleFrom(
            backgroundColor: desktopPrimaryBtn,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _isCheckingStatus
              ? const SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text('CEK STATUS', style: GoogleFonts.hankenGrotesk(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.6)),
        ),
      );
    }
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 52,
            child: OutlinedButton.icon(
              onPressed: () => _showPrintAdminPopup(),
              icon: const Icon(Icons.print_outlined, size: 18, color: desktopAccentBlue),
              label: Text('PRINT', style: GoogleFonts.hankenGrotesk(fontSize: 14, fontWeight: FontWeight.w800, color: desktopAccentBlue, letterSpacing: 0.6)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: desktopAccentBlue, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _isCheckingStatus ? null : _checkTransactionStatus,
              style: ElevatedButton.styleFrom(
                backgroundColor: desktopPrimaryBtn,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isCheckingStatus
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text('CEK STATUS', style: GoogleFonts.hankenGrotesk(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.6)),
            ),
          ),
        ),
      ],
    );
  }

  /// Data breakdown per kategori transaksi untuk layout desktop — sumber
  /// logika sama dengan `_buildCategoryRows` (mobile) supaya field backend
  /// yang dibaca tetap konsisten, hanya representasinya (`_KV`) yang beda.
  ({List<_KV> rows, String infoText}) _desktopCategoryData({
    required String kind,
    required Map<String, dynamic> data,
    required String orderId,
    required double amount,
    required String customerNo,
    required String paymentMethod,
    required NumberFormat currencyFormat,
  }) {
    if (kind == 'bank_transfer') {
      final note = _asMap(data['note']);
      final meta = _asMap(data['meta']);
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

      final accountName = s('account_name').isNotEmpty ? s('account_name') : s('nama_penerima');
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
      final providerReff = s('reff').isNotEmpty ? s('reff') : s('provider_ref');

      final amountVal = n('amount') > 0 ? n('amount') : amount;
      final adminVal = n('admin') > 0 ? n('admin') : n('fee');
      final totalVal = n('total') > 0 ? n('total') : (amountVal + adminVal > 0 ? amountVal + adminVal : amount);

      String money(double v) => 'Rp ${currencyFormat.format(v.toInt())}';

      return (
        rows: <_KV>[
          if (bankName.isNotEmpty) _KV('Bank Tujuan', bankName),
          if (accountNumber.isNotEmpty) _KV('No. Rekening', accountNumber, copyable: true),
          if (accountName.isNotEmpty) _KV('Nama Penerima', accountName),
          _KV('No. Ref', _cleanOrderId(orderId)),
          if (providerReff.isNotEmpty && providerReff != _cleanOrderId(orderId)) _KV('Reff', providerReff),
          _KV('Nominal', money(amountVal)),
          _KV('Biaya Admin', adminVal > 0 ? money(adminVal) : 'Gratis!'),
          if (notes.isNotEmpty) _KV('Catatan', notes),
          _KV('Total Bayar', money(totalVal), isTotal: true),
        ],
        infoText: '',
      );
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
      final nama = _stripNamePrefix(s('customer_name'));
      final tariffDaya = s('tariff_daya');
      final standMeter = s('subscriber_id') == s('meter_no') ? '' : s('subscriber_id');
      final adminVal = n('admin');
      final totalVal = n('total') > 0 ? n('total') : amount;
      final info = s('info');
      final rawToken = s('token');
      final formattedToken = _formatTokenCode(rawToken);

      String moneyOrDash(double v) => v > 0 ? 'Rp ${currencyFormat.format(v.toInt())}' : 'Gratis!';

      return (
        rows: <_KV>[
          if (idpel.isNotEmpty) _KV('IDPEL', idpel),
          if (nama.isNotEmpty) _KV('Nama', nama),
          if (tariffDaya.isNotEmpty) _KV('Tarif/Daya', tariffDaya),
          if (standMeter.isNotEmpty) _KV('Stand Meter', standMeter),
          _KV('No. Ref', _cleanOrderId(orderId)),
          if (rawToken.isNotEmpty) _KV('Token', formattedToken, copyable: true, copyValue: rawToken),
          _KV('Biaya Admin', moneyOrDash(adminVal)),
          _KV('Total Bayar', 'Rp ${currencyFormat.format(totalVal.toInt())}', isTotal: true),
        ],
        infoText: info,
      );
    }

    // Default (Pulsa, Data, E-Money, Voucher, PLN Pascabayar, Generic)
    final note = _asMap(data['note']);
    final meta = _asMap(data['meta']);
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
    final adminVal = notedAdmin > 0 ? notedAdmin : rootAdmin;
    // E-wallet: `nominal` mentah dari provider (mis. Loketbayar) bisa beda
    // dari harga retail yang sebenarnya kita jual — harga retail yang benar
    // didapat dari total dipotong dikurangi biaya admin (retail + admin =
    // total charge), bukan nominal provider.
    final hargaVal = kind == 'emoney' && amount > adminVal
        ? amount - adminVal
        : (notedNominal > 0 ? notedNominal : amount);
    final hargaText = 'Rp ${currencyFormat.format(hargaVal.toInt())}';
    final adminText = adminVal > 0 ? 'Rp ${currencyFormat.format(adminVal.toInt())}' : 'Gratis!';
    final receiverName = _stripNamePrefix((genSrc['customer_name'] ?? '').toString());
    final serialNumber = _pickFirstNonEmpty([
      data['provider_ref'],
      data['serial_number'],
      data['sn'],
    ]);

    return (
      rows: <_KV>[
        if (customerNo.isNotEmpty) _KV(_destLabel(kind), customerNo),
        if (receiverName.isNotEmpty) _KV('Nama Penerima', receiverName),
        _KV('Metode Pembayaran', paymentMethod.isEmpty ? '-' : paymentMethod),
        _KV('Kode Promosi', '-'),
        _KV('Harga', hargaText),
        _KV('Biaya Admin', adminText),
        if (serialNumber.isNotEmpty) _KV('Serial Number', serialNumber, copyable: true),
        _KV('Total', 'Rp ${currencyFormat.format(amount.toInt())}', isTotal: true),
        _KV('No. Referensi', _cleanOrderId(orderId)),
      ],
      infoText: '',
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
      final nama = _stripNamePrefix(s('customer_name'));
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
    final adminVal = notedAdmin > 0 ? notedAdmin : rootAdmin;
    // E-wallet: `nominal` mentah dari provider (mis. Loketbayar) bisa beda
    // dari harga retail yang sebenarnya kita jual — harga retail yang benar
    // didapat dari total dipotong dikurangi biaya admin (retail + admin =
    // total charge), bukan nominal provider.
    final hargaVal = kind == 'emoney' && amount > adminVal
        ? amount - adminVal
        : (notedNominal > 0 ? notedNominal : amount);
    final hargaText = 'Rp ${currencyFormat.format(hargaVal.toInt())}';
    final adminTextLocal = adminVal > 0
        ? 'Rp ${currencyFormat.format(adminVal.toInt())}'
        : 'Gratis!';

    // Nama penerima dari note (mis. e-wallet bebas nominal). Untuk pulsa
    // umumnya kosong. Tampilkan kalau ada.
    final receiverName = _stripNamePrefix((genSrc['customer_name'] ?? '').toString());

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

  Widget _categoryIconFallback(String kind, {double size = 74}) {
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
    return Icon(icon, size: size, color: color);
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

/// Label/value pair for the desktop "Detail Transaksi" and "Bukti
/// Transaksi" rows. `isTotal` renders as a highlighted total box instead of
/// a plain row; `copyable` adds a copy-to-clipboard icon.
class _KV {
  final String label;
  final String value;
  final bool copyable;
  final String? copyValue;
  final bool isTotal;
  final bool dividerBefore;

  const _KV(
    this.label,
    this.value, {
    this.copyable = false,
    this.copyValue,
    this.isTotal = false,
    this.dividerBefore = false,
  });
}

/// Clips a scalloped ("torn receipt paper") top edge for the desktop
/// "Bukti Transaksi" card, punching half-circle notches out of a
/// rounded-rect using [Path.combine] so the geometry stays simple and
/// artifact-free at any card width.
class _ReceiptScallopClipper extends CustomClipper<Path> {
  const _ReceiptScallopClipper({this.notchRadius = 6, this.cornerRadius = 16});

  final double notchRadius;
  final double cornerRadius;

  @override
  Path getClip(Size size) {
    final base = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Offset.zero & size,
        Radius.circular(cornerRadius),
      ));
    if (size.width <= 0) return base;

    final count = (size.width / (notchRadius * 2.4)).floor().clamp(4, 60);
    final gap = size.width / count;
    final notches = Path();
    for (var i = 0; i <= count; i++) {
      notches.addOval(Rect.fromCircle(center: Offset(i * gap, 0), radius: notchRadius));
    }
    return Path.combine(PathOperation.difference, base, notches);
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
