import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';

import '../bottombar/bottombar.dart';
import '../home/purchase_transaction_detail.dart';
import '../services/api_service.dart';

class TransactionReceipt extends StatefulWidget {
  final String title;
  final String status;
  final double amount;
  final String? productName;
  final String? customerNo;
  final String? receiverName;
  final String? bankName;
  final String? accountNumber;
  final String? orderId;
  final String? providerRef;
  final String? notes;
  final String? category;
  final DateTime? transactionTime;
  final int? processingMs;
  final Map<String, dynamic>? plnMeta;

  const TransactionReceipt({
    super.key,
    required this.title,
    required this.status,
    required this.amount,
    this.productName,
    this.customerNo,
    this.receiverName,
    this.bankName,
    this.accountNumber,
    this.orderId,
    this.providerRef,
    this.notes,
    this.category,
    this.transactionTime,
    this.processingMs,
    this.plnMeta,
  });

  @override
  State<TransactionReceipt> createState() => _TransactionReceiptState();
}

class _TransactionReceiptState extends State<TransactionReceipt> {
  String _currentStatus = '';
  String? _updatedProviderRef;
  Map<String, dynamic>? _updatedPlnMeta;
  bool _isRefreshing = false;
  final GlobalKey _receiptKey = GlobalKey();

  String? get _effectiveProviderRef => _updatedProviderRef ?? widget.providerRef;
  Map<String, dynamic>? get _effectivePlnMeta {
    if (_updatedPlnMeta != null && _updatedPlnMeta!.isNotEmpty) return _updatedPlnMeta;
    return widget.plnMeta;
  }
  bool _isSavingReceipt = false;

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

  Future<Uint8List?> _captureReceiptBytes() async {
    try {
      final boundary =
          _receiptKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.status;
  }

  Future<void> _refreshTransactionStatus() async {
    if (_isRefreshing) return;
    
    if (widget.orderId == null || widget.orderId!.isEmpty) {
      debugPrint('[RECEIPT] Warning: orderId is null/empty, will use getTransactions only');
    }

    setState(() => _isRefreshing = true);
    try {
      // First, trigger backend to check status with provider (advice for LB)
      if (widget.orderId != null && widget.orderId!.isNotEmpty && _isPending) {
        try {
          final checkResp = await ApiService.checkTransactionStatus(orderId: widget.orderId!);
          // Parse transaction data from check response to extract token/SN
          final tx = checkResp['data']?['transaction'];
          if (tx is Map) {
            if (tx['provider_ref'] != null) {
              _updatedProviderRef = tx['provider_ref'].toString();
            }
            if (tx['note'] != null) {
              try {
                final raw = tx['note'];
                final noteMap = raw is String
                    ? Map<String, dynamic>.from(jsonDecode(raw) as Map)
                    : (raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{});
                if (noteMap.isNotEmpty) {
                  _updatedPlnMeta = noteMap;
                }
              } catch (_) {}
            }
          }
        } catch (e) {
          debugPrint('[RECEIPT] checkTransactionStatus failed: $e');
        }
      }

      final List<Map<String, dynamic>> responses = [];
      String? detailStatus;
      String? listStatus;

      // Try to get transaction detail if orderId available
      if (widget.orderId != null && widget.orderId!.isNotEmpty) {
        try {
          final detailResponse = await ApiService.getTransactionDetail(widget.orderId!);
          responses.add(detailResponse);
          detailStatus = _extractTransactionStatus(detailResponse);
          debugPrint('[RECEIPT] Detail response status: $detailStatus');
        } catch (e) {
          debugPrint('[RECEIPT] Warning: getTransactionDetail failed: $e');
        }
      }

      // Always try to get transaction list
      try {
        final listResponse = await ApiService.getTransactions(page: 1);
        responses.add(listResponse);
        listStatus = _extractTransactionListStatus(
          listResponse,
          widget.orderId ?? '',
          widget.providerRef,
        );
        debugPrint('[RECEIPT] List response status: $listStatus');
      } catch (e) {
        debugPrint('[RECEIPT] Warning: getTransactions failed: $e');
      }

      if (!mounted) return;

      // Pick best status from what we got
      final nextStatus = _pickBestStatus([detailStatus, listStatus]);
      debugPrint('[RECEIPT] Picked best status: $nextStatus');

      if (nextStatus != null && nextStatus.isNotEmpty) {
        final previousStatus = _currentStatus;
        setState(() => _currentStatus = nextStatus);

        // Log status change
        if (previousStatus != nextStatus) {
          debugPrint('[RECEIPT] Status updated: $previousStatus → $nextStatus');
        }
      } else {
        debugPrint('[RECEIPT] No valid status found in responses');
      }
    } catch (e) {
      debugPrint('[RECEIPT] Unexpected error during refresh: $e');
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  String? _extractTransactionStatus(Map<String, dynamic> response) {
    return _pickBestStatus(_collectStatuses(response));
  }

  String? _extractTransactionListStatus(
    Map<String, dynamic> response,
    String orderId,
    String? providerRef,
  ) {
    final data = response['data'];
    if (data is! List) return null;

    final normalizedOrderId = orderId.trim().toLowerCase();
    final normalizedProviderRef = (providerRef ?? '').trim().toLowerCase();

    for (final item in data) {
      final candidate = item is Map
          ? Map<String, dynamic>.from(item)
          : null;
      if (candidate == null) continue;

      final itemOrderId = _firstNonEmptyString([
        candidate['order_id'],
        candidate['reference_id'],
        candidate['id'],
      ]).toLowerCase();
      final itemProviderRef = _firstNonEmptyString([
        candidate['provider_ref'],
        candidate['provider_reference'],
      ]).toLowerCase();

      final matchesOrder = itemOrderId.isNotEmpty && itemOrderId == normalizedOrderId;
      final matchesProvider = normalizedProviderRef.isNotEmpty && itemProviderRef == normalizedProviderRef;
      if (!matchesOrder && !matchesProvider) continue;

      final status = _pickBestStatus(_collectStatuses(candidate));
      if (status != null && status.isNotEmpty) return status;
    }

    return null;
  }

  List<String> _collectStatuses(dynamic value) {
    final collected = <String>[];
    final visited = <int>{};

    void walk(dynamic node) {
      if (node == null) return;
      final identity = identityHashCode(node);
      if (node is Map || node is List) {
        if (!visited.add(identity)) return;
      }

      if (node is Map) {
        final map = Map<dynamic, dynamic>.from(node);
        for (final key in const [
          'status',
          'transaction_status',
          'payment_status',
          'trx_status',
          'state',
        ]) {
          final raw = map[key];
          if (raw is String && raw.trim().isNotEmpty) {
            collected.add(_normalizeStatus(raw));
          }
        }
        for (final entry in map.entries) {
          walk(entry.value);
        }
      } else if (node is List) {
        for (final item in node) {
          walk(item);
        }
      }
    }

    walk(value);
    return collected;
  }

  String _normalizeStatus(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) return normalized;
    if (normalized.contains('success') || normalized.contains('completed') || normalized.contains('berhasil')) {
      return 'success';
    }
    if (normalized.contains('pending') || normalized.contains('proses') || normalized.contains('process')) {
      return 'pending';
    }
    if (normalized.contains('failed') ||
        normalized.contains('gagal') ||
        normalized.contains('expired') ||
        normalized.contains('cancel') ||
        normalized.contains('reject') ||
        normalized.contains('error')) {
      return 'failed';
    }
    return normalized;
  }

  String _firstNonEmptyString(List<dynamic> values) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty && text != '-') return text;
    }
    return '';
  }

  String? _pickBestStatus(List<String?> statuses) {
    String? pending;
    for (final status in statuses) {
      final normalized = status == null ? null : _normalizeStatus(status);
      if (normalized == null || normalized.isEmpty) continue;
      if (normalized == 'pending') {
        pending ??= normalized;
        continue;
      }
      if (normalized == 'failed') {
        return normalized;
      }
      if (normalized == 'success') {
        return normalized;
      }
    }
    return pending;
  }

  bool get _isSuccess => _normalizeStatus(_currentStatus) == 'success';
  bool get _isPending => _normalizeStatus(_currentStatus) == 'pending';
  String get _statusLabel {
    if (_isSuccess) return 'Sukses';
    if (_isPending) return 'Dalam Proses';
    return 'Gagal';
  }

  Color get _statusColor {
    if (_isSuccess) return const Color(0xFF2E7D32);
    if (_isPending) return const Color(0xFFED9D00);
    return const Color(0xFFD32F2F);
  }

  Color get _statusBgColor {
    if (_isSuccess) return const Color(0xFFE8F5E9);
    if (_isPending) return const Color(0xFFFFF3E0);
    return const Color(0xFFFFEBEE);
  }

  IconData get _statusIcon {
    if (_isSuccess) return Icons.check_circle_outline_rounded;
    if (_isPending) return Icons.access_time_rounded;
    return Icons.error_outline_rounded;
  }

  String get _displayMethod {
    if (widget.bankName != null && widget.bankName!.trim().isNotEmpty) return widget.bankName!.trim();
    final c = (widget.category ?? '').toLowerCase();
    if (c.contains('topup')) return 'QRIS';
    return '-';
  }

  String _cleanTransactionId(String value) {
    if (value.startsWith('PPOB-')) {
      return value.substring(5);
    }
    return value;
  }

  bool _isPlnTokenReceipt() {
    if (_effectivePlnMeta != null && _effectivePlnMeta!.isNotEmpty) return true;
    final source = [widget.category, widget.title, widget.productName]
        .whereType<String>()
        .map((e) => e.toLowerCase())
        .join(' ');
    return source.contains('token pln') ||
        source.contains('token listrik') ||
        source.contains('pln prabayar') ||
        source.contains('pln prepaid');
  }

  String _formatTokenCode(String token) {
    final digits = token.replaceAll(RegExp(r'\s+'), '');
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && i % 5 == 0) buf.write(' ');
      buf.write(digits[i]);
    }
    return buf.toString();
  }

  String _plnMetaValue(String key) {
    final v = _effectivePlnMeta?[key];
    if (v == null) return '';
    return v.toString();
  }

  String? _detectProviderKey() {
    final source = [
      widget.title,
      widget.productName,
      widget.category,
      widget.providerRef,
      widget.notes,
      widget.bankName,
    ].whereType<String>().join(' ').toLowerCase();

    if (source.contains('telkomsel') ||
        source.contains('simpati') ||
        source.contains('kartu as') ||
        source.contains('by.u')) {
      return 'telkomsel';
    }
    if (source.contains('im3') || source.contains(' m3') || source.contains('m3 ')) {
      return 'im3';
    }
    if (source.contains('indosat') || source.contains('mentari')) {
      return 'indosat';
    }
    if (source.contains('smartfren')) return 'smartfren';
    if (source.contains('axis')) return 'axis';
    if (source.contains('tri') || source.contains('three')) return 'tri';
    if (source.contains('xl')) return 'xl';
    return null;
  }

  List<String> _providerLogoAssets(String? providerKey) {
    if (providerKey == null) return const [];
    return [
      'images/provider_logos/$providerKey.webp',
      'images/provider_logos/$providerKey.png',
    ];
  }

  Widget _buildProviderLogoByCandidates(List<String> candidates, int index) {
    if (index >= candidates.length) {
      return const Icon(
        Icons.sim_card_rounded,
        size: 74,
        color: Color(0xFF1E63C6),
      );
    }

    return Image.asset(
      candidates[index],
      fit: BoxFit.contain,
      width: 220,
      height: 92,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, __, ___) {
        return _buildProviderLogoByCandidates(candidates, index + 1);
      },
    );
  }

  Future<void> _openPrintTemplate() async {
    if (!mounted) return;
    _showPrintAdminPopup();
  }

  void _showPrintAdminPopup() {
    final amount = widget.amount;
    final adminController = TextEditingController(text: '0');
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              actionsPadding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              title: const Text('Cetak Struk',
                  style: TextStyle(fontFamily: 'Gilroy Bold', fontSize: 18, color: Color(0xFF1A1A1A))),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Text('Harga Admin',
                          style: TextStyle(fontFamily: 'Gilroy Medium', fontSize: 14, color: Color(0xFF555555))),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: adminController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontFamily: 'Gilroy Bold', fontSize: 14, color: Color(0xFF333333)),
                          decoration: InputDecoration(
                            prefixText: 'Rp ',
                            prefixStyle: const TextStyle(fontFamily: 'Gilroy Bold', fontSize: 14, color: Color(0xFF333333)),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFDDDDDD))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFDDDDDD))),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF3C74BB), width: 1.5)),
                          ),
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          onChanged: (_) => setDialogState(() {}),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Harga Produk', style: TextStyle(fontFamily: 'Gilroy Medium', fontSize: 14, color: Color(0xFF555555))),
                      Text('Rp ${currencyFormat.format(amount.toInt())}',
                          style: const TextStyle(fontFamily: 'Gilroy Bold', fontSize: 14, color: Color(0xFF333333))),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Divider(color: Color(0xFFE5E9EE), height: 1),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total', style: TextStyle(fontFamily: 'Gilroy Bold', fontSize: 16, color: Color(0xFF1A1A1A))),
                      Text('Rp ${currencyFormat.format(total.toInt())}',
                          style: const TextStyle(fontFamily: 'Gilroy Bold', fontSize: 16, color: Color(0xFF3C74BB))),
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
                            side: const BorderSide(color: Color(0xFFCCCCCC), width: 1),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('Batal',
                              style: TextStyle(fontFamily: 'Gilroy Bold', fontSize: 14, color: Color(0xFF666666))),
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
                            final purchaseData = <String, dynamic>{
                              'amount': total,
                              'original_amount': amount,
                              'admin': adminValue,
                              'total': total,
                              'customer_no': widget.customerNo,
                              'phone_number': widget.customerNo,
                              'order_id': widget.orderId,
                              'id': widget.orderId,
                              'name': widget.productName,
                              'product_name': widget.productName,
                              'provider_ref': _effectiveProviderRef,
                              'created_at': (widget.transactionTime ?? DateTime.now()).toIso8601String(),
                              'category': widget.category,
                              if (_effectivePlnMeta != null && _effectivePlnMeta!.isNotEmpty)
                                'meta': {..._effectivePlnMeta!, 'admin': adminValue, 'total': total},
                              if (_effectivePlnMeta != null && _effectivePlnMeta!.isNotEmpty)
                                'note': jsonEncode({..._effectivePlnMeta!, 'admin': adminValue, 'total': total}),
                            };
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PurchaseTransactionDetail(data: purchaseData),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF3C74BB),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('Cetak',
                              style: TextStyle(fontFamily: 'Gilroy Bold', fontSize: 14, color: Colors.white)),
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

  Future<void> _downloadReceiptToGallery() async {
    if (_isSavingReceipt) return;
    setState(() => _isSavingReceipt = true);
    try {
      final granted = await _requestGalleryPermission();
      if (!granted) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Izin penyimpanan ditolak')),
        );
        return;
      }

      final bytes = await _captureReceiptBytes();
      if (bytes == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal menyimpan struk')),
        );
        return;
      }

      final result = await ImageGallerySaverPlus.saveImage(
        Uint8List.fromList(bytes),
        name: 'STRUK_${(widget.orderId ?? DateTime.now().millisecondsSinceEpoch).toString()}',
      );

      if (!mounted) return;
      if (result['isSuccess'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Struk berhasil disimpan ke galeri')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal menyimpan struk')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal menyimpan struk')),
      );
    } finally {
      if (mounted) setState(() => _isSavingReceipt = false);
    }
  }

  Future<void> _shareReceiptImage() async {
    if (_isSavingReceipt) return;
    setState(() => _isSavingReceipt = true);
    try {
      final bytes = await _captureReceiptBytes();
      if (bytes == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal membagikan struk')),
        );
        return;
      }

      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/receipt_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Struk transaksi',
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal membagikan struk')),
      );
    } finally {
      if (mounted) setState(() => _isSavingReceipt = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat('#,###', 'id_ID');
    final headerDateFormat = DateFormat('d MMM yyyy • HH:mm', 'id_ID');
    final detailDateFormat = DateFormat('dd MMM yyyy, HH:mm:ss', 'id_ID');
    final now = (widget.transactionTime ?? DateTime.now()).toLocal();

    const headerBlue = Color(0xFF3F75B7);
    const pageBg = Color(0xFFF5F5F7);
    final amountText = 'Rp ${currencyFormat.format(widget.amount.toInt())}';
    final product = widget.productName ?? widget.title;
    final orderReference = _cleanTransactionId(widget.orderId ?? '-');
    final isPlnToken = _isPlnTokenReceipt();
    final providerLogoAssets =
        isPlnToken ? const <String>[] : _providerLogoAssets(_detectProviderKey());
    final processing = widget.processingMs == null
        ? '-'
        : '${(widget.processingMs! / 1000).toStringAsFixed(2)} detik';

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
                        onTap: () => Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (_) => const Bottombar()),
                          (route) => false,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 30,
                        ),
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
                  child: RefreshIndicator(
                    color: const Color(0xFF3F75B7),
                    onRefresh: _refreshTransactionStatus,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 20),
                      child: Column(
                      children: [
                        RepaintBoundary(
                          key: _receiptKey,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
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
                              if (!isPlnToken)
                                SizedBox(
                                  width: double.infinity,
                                  height: 100,
                                  child: Center(
                                    child: providerLogoAssets.isEmpty
                                        ? const Icon(
                                            Icons.sim_card_rounded,
                                            size: 74,
                                            color: Color(0xFF1E63C6),
                                          )
                                        : _buildProviderLogoByCandidates(
                                            providerLogoAssets,
                                            0,
                                          ),
                                  ),
                                ),
                              if (!isPlnToken) const SizedBox(height: 3),
                              Row(
                                children: [
                                  Flexible(
                                    flex: 7,
                                    child: Text(
                                      headerDateFormat.format(now),
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
                                      'Id transaksi : $orderReference',
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
                              const Divider(color: Color(0xFFE6E9EE), height: 1),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Icon(_statusIcon, size: 16, color: _statusColor),
                                  const SizedBox(width: 6),
                                  Text(
                                    _isPending
                                        ? 'Transaksi Dalam Proses'
                                        : _isSuccess
                                            ? 'Transaksi Berhasil'
                                            : 'Transaksi Gagal',
                                    style: TextStyle(
                                      fontFamily: 'Gilroy Medium',
                                      fontSize: 13,
                                      color: _statusColor,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                product,
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
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      (widget.category ?? '-').toUpperCase(),
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
                                      color: _statusBgColor,
                                      borderRadius: BorderRadius.circular(30),
                                      border: Border.all(
                                        color: _statusColor.withValues(alpha: 0.6),
                                      ),
                                    ),
                                    child: Text(
                                      _statusLabel,
                                      style: TextStyle(
                                        fontFamily: 'Gilroy Medium',
                                        fontSize: 12,
                                        color: _statusColor,
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
                              _buildDetailRow(
                                'Id transaksi',
                                orderReference,
                                canCopy: true,
                                onCopy: () async {
                                  await Clipboard.setData(
                                    ClipboardData(text: orderReference),
                                  );
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('ID transaksi disalin'),
                                    ),
                                  );
                                },
                              ),
                              _buildDetailRow('Nama Produk', product),
                              if (isPlnToken) ...[
                                if (_plnMetaValue('customer_name').isNotEmpty)
                                  _buildDetailRow(
                                      'Nama Pelanggan',
                                      _plnMetaValue('customer_name')),
                                if ((widget.customerNo ?? '').trim().isNotEmpty)
                                  _buildDetailRow(
                                      'ID Pelanggan', widget.customerNo!),
                                if (_plnMetaValue('meter_no').isNotEmpty &&
                                    _plnMetaValue('meter_no') !=
                                        widget.customerNo)
                                  _buildDetailRow(
                                      'No. Meter', _plnMetaValue('meter_no')),
                                if (_plnMetaValue('tariff_daya').isNotEmpty)
                                  _buildDetailRow(
                                      'Tarif/Daya', _plnMetaValue('tariff_daya')),
                                if (_plnMetaValue('product_code').isNotEmpty)
                                  _buildDetailRow('Kode Produk',
                                      _plnMetaValue('product_code')),
                                if (_plnMetaValue('kwh').isNotEmpty)
                                  _buildDetailRow(
                                      'kWh', '${_plnMetaValue('kwh')} kWh'),
                                _buildDetailRow('Harga', amountText),
                                if (_plnMetaValue('admin').isNotEmpty &&
                                    double.tryParse(
                                            _plnMetaValue('admin')) !=
                                        null &&
                                    double.parse(_plnMetaValue('admin')) > 0)
                                  _buildDetailRow(
                                      'Biaya Admin',
                                      'Rp ${currencyFormat.format(double.parse(_plnMetaValue('admin')).toInt())}')
                                else
                                  _buildDetailRow('Biaya Admin', 'Gratis!'),
                              ] else ...[
                                if (widget.customerNo != null &&
                                    widget.customerNo!.trim().isNotEmpty)
                                  _buildDetailRow(
                                      'Nomor Handphone', widget.customerNo!),
                                _buildDetailRow('Metode Pembayaran', _displayMethod),
                                _buildDetailRow('Kode Promosi', '-'),
                                _buildDetailRow('Harga', amountText),
                                _buildDetailRow('Biaya Admin', 'Gratis!'),
                              ],
                              const Divider(
                                height: 12,
                                thickness: 1,
                                color: Color(0xFFE5E9EE),
                              ),
                              _buildDetailRow('Total', amountText, large: true),
                              _buildDetailRow('Waktu', detailDateFormat.format(now)),
                              _buildDetailRow('No. Referensi', orderReference),
                              if (_effectiveProviderRef != null && _effectiveProviderRef!.isNotEmpty && _isSuccess)
                                _buildDetailRow('SN', _effectiveProviderRef!),
                              if (widget.processingMs != null)
                                _buildDetailRow('Waktu Proses', processing),
                              _buildDetailRow(
                                'Status',
                                _statusLabel,
                                valueColor: _statusColor,
                              ),
                              if (isPlnToken &&
                                  _plnMetaValue('token').isNotEmpty) ...[
                                const SizedBox(height: 12),
                                const Divider(
                                  height: 12,
                                  thickness: 1,
                                  color: Color(0xFFE5E9EE),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Kode Token',
                                  style: TextStyle(
                                    fontFamily: 'Gilroy Medium',
                                    fontSize: 13,
                                    color: Color(0xFF6B7280),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Builder(builder: (ctx) {
                                  final raw = _plnMetaValue('token');
                                  final formatted = _formatTokenCode(raw);
                                  return Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.fromLTRB(
                                        12, 10, 12, 10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF3F6FA),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                          color: const Color(0xFFD9E1EC)),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: SelectableText(
                                            formatted,
                                            style: const TextStyle(
                                              fontFamily: 'Gilroy Bold',
                                              fontSize: 16,
                                              letterSpacing: 1.2,
                                              color: Color(0xFF1A1A1A),
                                            ),
                                          ),
                                        ),
                                        InkWell(
                                          borderRadius:
                                              BorderRadius.circular(6),
                                          onTap: () async {
                                            await Clipboard.setData(
                                                ClipboardData(text: raw));
                                            if (!ctx.mounted) return;
                                            ScaffoldMessenger.of(ctx)
                                                .showSnackBar(
                                              const SnackBar(
                                                content:
                                                    Text('Token disalin'),
                                              ),
                                            );
                                          },
                                          child: const Padding(
                                            padding: EdgeInsets.all(6),
                                            child: Icon(
                                              Icons.copy_rounded,
                                              size: 20,
                                              color: Color(0xFF3C74BB),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                              if (isPlnToken &&
                                  _plnMetaValue('info').isNotEmpty) ...[
                                const SizedBox(height: 12),
                                const Text(
                                  'Info',
                                  style: TextStyle(
                                    fontFamily: 'Gilroy Medium',
                                    fontSize: 13,
                                    color: Color(0xFF6B7280),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _plnMetaValue('info'),
                                  style: const TextStyle(
                                    fontFamily: 'Gilroy Medium',
                                    fontSize: 12,
                                    color: Color(0xFF374151),
                                    height: 1.45,
                                  ),
                                ),
                              ],
                            ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (!_isPending)
                          Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 54,
                                  child: OutlinedButton(
                                    onPressed: _openPrintTemplate,
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(
                                        color: Color(0xFF3C74BB),
                                        width: 1.5,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
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
                                    onPressed: _isRefreshing ? null : _refreshTransactionStatus,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF3C74BB),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    child: _isRefreshing
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
                              onPressed: _isRefreshing ? null : _refreshTransactionStatus,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF3C74BB),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: _isRefreshing
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
                            MaterialPageRoute(builder: (_) => const Bottombar()),
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
              ),
            ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
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
