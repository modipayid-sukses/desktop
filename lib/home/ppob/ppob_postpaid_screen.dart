import 'dart:convert';
import 'package:modipay/widgets/desktop_title_wrapper.dart';


import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:modipay/providers/auth_provider.dart';
import 'package:intl/intl.dart';
import 'package:otp_text_field/otp_field.dart';
import 'package:otp_text_field/otp_field_style.dart';
import 'package:otp_text_field/style.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/api_service.dart';
import '../../services/biometric_service.dart';
import '../../utils/colornotifire.dart';
import '../../utils/color.dart';
import '../../utils/media.dart';
import '../../widgets/transaction_receipt.dart';
import 'components/saved_customers_bottom_sheet.dart';
import '../../utils/responsive.dart';
import '../../design/design.dart';

class PPOBPostpaidScreen extends StatefulWidget {
  final String brand;
  final String title;

  const PPOBPostpaidScreen({
    Key? key,
    required this.brand,
    required this.title,
  }) : super(key: key);

  @override
  State<PPOBPostpaidScreen> createState() => _PPOBPostpaidScreenState();
}

class _PPOBPostpaidScreenState extends State<PPOBPostpaidScreen> {
  static const String _historyStorageKey = 'postpaid_check_history_v1';

  late ColorNotifire notifire;
  bool _isLoading = false;
  bool _isInquiring = false;
  bool _isLoadingProviders = false;
  Map<String, dynamic>? _inquiryResult;
  List<Map<String, dynamic>> _historyItems = [];
  List<Map<String, dynamic>> _providerProducts = [];
  Map<String, dynamic>? _selectedProviderProduct;
  final TextEditingController _customerIdController = TextEditingController();
  final _currencyFormat = NumberFormat('#,###', 'id_ID');

  double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return double.tryParse(value.toString()) ?? 0;
  }

  @override
  void initState() {
    super.initState();
    // Ensure notifire is available for async callbacks like _loadDarkMode.
    notifire = Provider.of<ColorNotifire>(context, listen: false);
    _loadDarkMode();
    _loadHistory();
    _loadProviderProducts();
  }

  String? _buyerSkuCodeForBrand() {
    if (_selectedProviderProduct?['buyer_sku_code'] != null) {
      return _selectedProviderProduct!['buyer_sku_code'].toString();
    }

    final brand = widget.brand.toLowerCase();
    if (brand.contains('pln')) return 'PLNPASCA';
    if (brand.contains('pdam')) return 'pdam';
    if (brand.contains('bpjs')) return 'bpjs';
    if (brand.contains('internet')) return 'internet';
    if (brand.contains('multifinance') || brand.contains('finance')) return 'multifinance';
    if (brand.contains('gas') || brand.contains('pgn')) return 'pgas';
    if (brand.contains('tv')) return 'tv';
    if (brand.contains('hp') || brand.contains('telepon')) return 'hp';
    return null;
  }

  Future<void> _loadProviderProducts() async {
    setState(() => _isLoadingProviders = true);
    try {
      final products = await ApiService.getPpobProducts(cmd: 'pasca', brand: widget.brand);
      final uniqueBySku = <String, Map<String, dynamic>>{};
      for (final p in products) {
        if (p is Map) {
          final item = Map<String, dynamic>.from(p);
          final sku = (item['buyer_sku_code'] ?? '').toString();
          if (sku.isNotEmpty && !uniqueBySku.containsKey(sku)) {
            uniqueBySku[sku] = item;
          }
        }
      }

      final normalized = uniqueBySku.values.toList();
      normalized.sort((a, b) {
        final an = (a['product_name'] ?? '').toString();
        final bn = (b['product_name'] ?? '').toString();
        return an.compareTo(bn);
      });

      if (!mounted) return;
      setState(() {
        _providerProducts = normalized;
        _selectedProviderProduct = normalized.isNotEmpty ? normalized.first : null;
        _isLoadingProviders = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingProviders = false);
    }
  }

  @override
  void dispose() {
    _customerIdController.dispose();
    super.dispose();
  }

  Future<void> _loadDarkMode() async {
    final prefs = await SharedPreferences.getInstance();
    bool? previusstate = prefs.getBool("setIsDark");
    if (previusstate == null) {
      notifire.setIsDark = false;
    } else {
      notifire.setIsDark = previusstate;
    }
  }

  String _historyBrandKey() => widget.brand.trim().toLowerCase();

  Future<List<Map<String, dynamic>>> _readAllHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_historyStorageKey);
    if (raw == null || raw.isEmpty) return <Map<String, dynamic>>[];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <Map<String, dynamic>>[];
      return decoded
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  Future<void> _loadHistory() async {
    final all = await _readAllHistory();
    final currentKey = _historyBrandKey();
    final filtered = all
        .where((e) => (e['brand_key']?.toString() ?? '') == currentKey)
        .toList();

    filtered.sort((a, b) {
      final ad = DateTime.tryParse(a['updated_at']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bd = DateTime.tryParse(b['updated_at']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bd.compareTo(ad);
    });

    if (!mounted) return;
    setState(() {
      _historyItems = filtered.take(8).toList();
    });
  }

  Future<void> _saveHistoryEntry(Map<String, dynamic> inquiryData, {required String status}) async {
    final customerNo = (inquiryData['customer_no'] ?? _customerIdController.text.trim()).toString();
    if (customerNo.isEmpty) return;

    final all = await _readAllHistory();
    final brandKey = _historyBrandKey();
    final nowIso = DateTime.now().toIso8601String();

    final newEntry = <String, dynamic>{
      'id': '${brandKey}_$customerNo',
      'brand_key': brandKey,
      'brand': widget.brand,
      'title': widget.title,
      'status': status,
      'updated_at': nowIso,
      'data': inquiryData,
    };

    final idx = all.indexWhere((e) => (e['id']?.toString() ?? '') == newEntry['id']);
    if (idx >= 0) {
      all[idx] = {...all[idx], ...newEntry};
    } else {
      all.add(newEntry);
    }

    all.sort((a, b) {
      final ad = DateTime.tryParse(a['updated_at']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bd = DateTime.tryParse(b['updated_at']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bd.compareTo(ad);
    });

    final compact = all.take(40).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_historyStorageKey, jsonEncode(compact));
    await _loadHistory();
  }

  Future<void> _markHistoryAsPaid(Map<String, dynamic> tx) async {
    if (_inquiryResult == null) return;
    final merged = Map<String, dynamic>.from(_inquiryResult!);
    merged['last_transaction_status'] = tx['status'];
    merged['last_order_id'] = tx['order_id'];
    await _saveHistoryEntry(merged, status: 'paid');
  }

  String _formatPrice(dynamic price) {
    double p = 0;
    if (price is int) p = price.toDouble();
    else if (price is double) p = price;
    else if (price is String) p = double.tryParse(price) ?? 0;
    return 'Rp ${_currencyFormat.format(p.toInt())}';
  }

  String _formatNumber(dynamic value) {
    final number = _toDouble(value);
    return _currencyFormat.format(number.toInt());
  }

  String _formatPeriodDisplay(dynamic value) {
    if (value == null) return '-';
    final raw = value.toString().trim();
    if (raw.isEmpty) return '-';

    final digitsOnly = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.length == 6) {
      final yearFirst = digitsOnly.substring(0, 4);
      final monthFirst = digitsOnly.substring(4, 6);
      final yearLast = digitsOnly.substring(2, 6);
      final monthLast = digitsOnly.substring(0, 2);

      final monthFirstInt = int.tryParse(monthFirst) ?? 0;
      if (monthFirstInt >= 1 && monthFirstInt <= 12) {
        return '$monthFirst/$yearFirst';
      }

      final monthLastInt = int.tryParse(monthLast) ?? 0;
      if (monthLastInt >= 1 && monthLastInt <= 12) {
        return '$monthLast/$yearLast';
      }
    }

    return raw;
  }

  double _sumDetailField(List<dynamic> details, String key) {
    double total = 0;
    for (final item in details) {
      if (item is Map) {
        total += _toDouble(item[key]);
      }
    }
    return total;
  }

  Future<void> _doInquiry() async {
    final customerId = _customerIdController.text.trim();
    if (customerId.isEmpty) {
      Fluttertoast.showToast(msg: 'Masukkan nomor pelanggan');
      return;
    }

    setState(() {
      _isInquiring = true;
      _inquiryResult = null;
    });

    try {
      final sku = _buyerSkuCodeForBrand();
      if (sku == null) {
        if (mounted) setState(() => _isInquiring = false);
        Fluttertoast.showToast(msg: 'Layanan belum tersedia untuk brand ini');
        return;
      }

      final result = await ApiService.ppobInquiry(
        buyerSkuCode: sku,
        customerNo: customerId,
      );

      if (mounted) {
        setState(() => _isInquiring = false);
        if (result['status'] == 'success' && result['data'] != null) {
          final data = Map<String, dynamic>.from(result['data']);
          setState(() => _inquiryResult = data);
          await _saveHistoryEntry(data, status: 'checked');
        } else {
          final msg = result['message']?.toString() ?? 'Cek tagihan gagal';
          if (widget.brand.toLowerCase().contains('internet') && _providerProducts.length > 1) {
            Fluttertoast.showToast(msg: '$msg. Coba pilih provider lain.');
          } else {
            Fluttertoast.showToast(msg: msg);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isInquiring = false);
        Fluttertoast.showToast(
          msg: ApiService.userFriendlyMessage(e, fallback: 'Cek tagihan gagal'),
        );
      }
    }
  }

  void _payBill() {
    if (_inquiryResult == null) return;

    final amount = _toDouble(_inquiryResult!['selling_price']);
    final admin = _toDouble(_inquiryResult!['admin']);
    if (amount <= 0) {
      Fluttertoast.showToast(msg: 'Total tagihan tidak valid, silakan cek ulang');
      return;
    }

    final buyerSkuCode = _inquiryResult!['buyer_sku_code']?.toString() ?? _buyerSkuCodeForBrand();
    if (buyerSkuCode == null || buyerSkuCode.isEmpty) {
      Fluttertoast.showToast(msg: 'Kode produk tidak ditemukan, silakan cek tagihan ulang');
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _PostpaidPinScreen(
          buyerSkuCode: buyerSkuCode,
          customerNo: _customerIdController.text.trim(),
          productName: _inquiryResult!['product_name'] ?? widget.title,
          customerName: _inquiryResult!['customer_name'] ?? '-',
          amount: amount,
          admin: admin,
          onPaymentSuccess: _markHistoryAsPaid,
        ),
      ),
    );
  }

  String _getHintText() {
    final brand = widget.brand.toLowerCase();
    if (brand.contains('pln')) return 'Masukkan ID Pelanggan PLN';
    if (brand.contains('pdam')) return 'Masukkan ID Pelanggan PDAM';
    if (brand.contains('internet')) return 'Masukkan ID Pelanggan Internet';
    if (brand.contains('multifinance') || brand.contains('finance')) return 'Masukkan No. Kontrak';
    if (brand.contains('bpjs')) return 'Masukkan No. BPJS';
    if (brand.contains('tv')) return 'Masukkan No. Pelanggan TV';
    if (brand.contains('tol') || brand.contains('e-toll')) return 'Masukkan No. Kartu Tol';
    if (brand.contains('pbb')) return 'Masukkan NOP PBB';
    if (brand.contains('gas') || brand.contains('pgn')) return 'Masukkan ID Pelanggan Gas';
    if (brand.contains('hp')) return 'Masukkan No. HP Pascabayar';
    return 'Masukkan nomor pelanggan';
  }

  IconData _getInputIcon() {
    final brand = widget.brand.toLowerCase();
    if (brand.contains('pln')) return Icons.electric_bolt;
    if (brand.contains('pdam')) return Icons.water_drop;
    if (brand.contains('internet')) return Icons.wifi;
    if (brand.contains('multifinance') || brand.contains('finance')) return Icons.account_balance;
    if (brand.contains('bpjs')) return Icons.health_and_safety;
    if (brand.contains('tv')) return Icons.tv;
    if (brand.contains('tol')) return Icons.toll;
    if (brand.contains('pbb')) return Icons.home_work;
    if (brand.contains('gas') || brand.contains('pgn')) return Icons.local_fire_department;
    if (brand.contains('hp')) return Icons.phone_android;
    return Icons.numbers;
  }

  Widget _buildDescDetails() {
    final desc = _inquiryResult!['desc'];
    if (desc is! Map) return const SizedBox.shrink();

    final details = (desc['detail'] is List) ? List<dynamic>.from(desc['detail']) : <dynamic>[];
    final totalDenda = _sumDetailField(details, 'denda');
    final totalNilaiTagihan = _sumDetailField(details, 'nilai_tagihan');
    final totalAdminDetail = _sumDetailField(details, 'admin');

    return Container(
      margin: EdgeInsets.only(top: height / 70),
      padding: EdgeInsets.all(width / 25),
      decoration: BoxDecoration(
        color: notifire.getprimerycolor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: notifire.getIsDark ? grey600 : grey200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Rincian Tagihan',
            style: TextStyle(
              color: notifire.getdarkscolor,
              fontFamily: 'Gilroy Bold',
              fontSize: height / 52,
            ),
          ),
          SizedBox(height: height / 120),
          if (_inquiryResult!['periode'] != null)
            _billRow('Periode (BL/TH)', _formatPeriodDisplay(_inquiryResult!['periode'])),
          if (desc['tarif'] != null)
            _billRow('Tarif', desc['tarif'].toString()),
          if (desc['daya'] != null)
            _billRow('Daya', '${_formatNumber(desc['daya'])} VA'),
          if (desc['lembar_tagihan'] != null)
            _billRow('Total Lembar Tagihan', desc['lembar_tagihan'].toString()),
          if (details.isNotEmpty) ...[
            _billRow('Total Nilai Tagihan', _formatPrice(totalNilaiTagihan)),
            _billRow('Total Denda', _formatPrice(totalDenda)),
            if (totalAdminDetail > 0)
              _billRow('Total Admin Periode', _formatPrice(totalAdminDetail)),
            SizedBox(height: height / 120),
            ...details.asMap().entries.map((entry) {
              final index = entry.key + 1;
              final item = entry.value is Map<String, dynamic>
                  ? entry.value as Map<String, dynamic>
                  : Map<String, dynamic>.from(entry.value as Map);
              final periode = _formatPeriodDisplay(item['periode']);
              final nilai = _formatPrice(item['nilai_tagihan'] ?? 0);
              final admin = _formatPrice(item['admin'] ?? 0);
              final denda = _formatPrice(item['denda'] ?? 0);
              final meterAwal = item['meter_awal']?.toString();
              final meterAkhir = item['meter_akhir']?.toString();
              return Container(
                margin: EdgeInsets.only(top: height / 150),
                padding: EdgeInsets.all(width / 35),
                decoration: BoxDecoration(
                  color: notifire.gettabwhitecolor,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: notifire.getIsDark ? grey600 : grey200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lembar $index - Periode $periode',
                      style: TextStyle(
                        color: notifire.getdarkscolor,
                        fontFamily: 'Gilroy Bold',
                        fontSize: height / 60,
                      ),
                    ),
                    SizedBox(height: height / 180),
                    _billRow('Nilai Tagihan', nilai),
                    _billRow('Admin', admin),
                    _billRow('Denda', denda),
                    if (meterAwal != null) _billRow('Meter Awal', meterAwal),
                    if (meterAkhir != null) _billRow('Meter Akhir', meterAkhir),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildHistorySection() {
    if (_historyItems.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: width / 20),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Riwayat Cek / Bayar Terakhir',
              style: TextStyle(
                color: notifire.getdarkscolor,
                fontFamily: 'Gilroy Bold',
                fontSize: height / 52,
              ),
            ),
            SizedBox(height: height / 120),
            ..._historyItems.map((entry) {
              final data = entry['data'] is Map
                  ? Map<String, dynamic>.from(entry['data'])
                  : <String, dynamic>{};
              final status = (entry['status'] ?? 'checked').toString();
              final isPaid = status == 'paid';
              final customerNo = (data['customer_no'] ?? '-').toString();
              final customerName = (data['customer_name'] ?? data['name'] ?? '-').toString();
              final total = _formatPrice(data['selling_price'] ?? data['price'] ?? 0);
              final periode = _formatPeriodDisplay(data['periode']);

              return Container(
                margin: EdgeInsets.only(top: height / 150),
                padding: EdgeInsets.all(width / 35),
                decoration: BoxDecoration(
                  color: notifire.getprimerycolor.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: notifire.getIsDark ? grey600 : grey200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            customerName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: notifire.getdarkscolor,
                              fontFamily: 'Gilroy Bold',
                              fontSize: height / 60,
                            ),
                          ),
                        ),
                        AppBadge(
                          label: isPaid ? 'Dibayar' : 'Dicek',
                          tone: isPaid ? AppBadgeTone.success : AppBadgeTone.warning,
                        ),
                      ],
                    ),
                    SizedBox(height: height / 200),
                    Text(
                      '$customerNo • Periode: $periode • $total',
                      style: TextStyle(
                        color: notifire.getdarkgreycolor,
                        fontFamily: 'Gilroy Medium',
                        fontSize: height / 68,
                      ),
                    ),
                    SizedBox(height: height / 200),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          _customerIdController.text = customerNo;
                          setState(() {
                            _inquiryResult = data;
                          });
                          Fluttertoast.showToast(msg: 'Data tagihan dimuat dari riwayat lokal');
                          final sku = data['buyer_sku_code']?.toString();
                          if (sku != null) {
                            final match = _providerProducts.where((e) => e['buyer_sku_code']?.toString() == sku);
                            if (match.isNotEmpty) {
                              setState(() => _selectedProviderProduct = match.first);
                            }
                          }
                        },
                        child: const Text('Gunakan Lagi'),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  String _getCategory() {
    final b = widget.brand.toLowerCase();
    if (b.contains('pln')) return 'pln';
    if (b.contains('pdam')) return 'pdam';
    if (b.contains('bpjs')) return 'bpjs';
    if (b.contains('internet') || b.contains('indihome')) return 'internet';
    if (b.contains('tv')) return 'tv';
    if (b.contains('hp') || b.contains('pascabayar')) return 'pulsa';
    return b;
  }

  Future<void> _openSavedCustomers() async {
    final selectedNo = await SavedCustomersBottomSheet.show(
      context,
      category: _getCategory(),
      accentColor: notifire.getbluecolor,
    );
    if (selectedNo != null && selectedNo.isNotEmpty) {
      setState(() {
        _customerIdController.text = selectedNo;
        _inquiryResult = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    notifire = Provider.of<ColorNotifire>(context, listen: true);
    return Scaffold(
      backgroundColor: notifire.getprimerycolor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              if (!isDesktopPopup(context))
              Padding(
                padding: EdgeInsets.fromLTRB(width / 20, height / 120, width / 20, 0),
                child: Row(
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: height / 19,
                        height: height / 19,
                        decoration: BoxDecoration(
                          color: notifire.gettabwhitecolor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: notifire.getdarkgreycolor.withOpacity(0.15)),
                        ),
                        child: Icon(Icons.arrow_back, color: notifire.getdarkscolor, size: height / 36),
                      ),
                    ),
                    SizedBox(width: width / 35),
                    Expanded(
                      child: Text(
                        widget.title,
                        style: TextStyle(
                          color: notifire.getdarkscolor,
                          fontSize: height / 40,
                          fontFamily: 'Gilroy Bold',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (!isDesktopPopup(context))
              SizedBox(height: height / 60),

              Padding(
                padding: EdgeInsets.symmetric(horizontal: width / 20),
                child: AppCard(
                  child: Row(
                    children: [
                      Container(
                        width: height / 18,
                        height: height / 18,
                        decoration: BoxDecoration(
                          color: notifire.getbluecolor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Icon(_getInputIcon(), color: notifire.getbluecolor, size: height / 34),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Cek Tagihan Pelanggan',
                              style: TextStyle(
                                color: notifire.getdarkscolor,
                                fontFamily: 'Gilroy Bold',
                                fontSize: height / 54,
                              ),
                            ),
                            Text(
                              'Masukkan ID pelanggan untuk menampilkan detail tagihan.',
                              style: TextStyle(
                                color: notifire.getdarkgreycolor,
                                fontFamily: 'Gilroy Medium',
                                fontSize: height / 68,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: height / 70),

              Padding(
                padding: EdgeInsets.symmetric(horizontal: width / 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                        child: Text(
                          widget.title,
                          style: TextStyle(
                            color: notifire.getdarkscolor,
                            fontFamily: 'Gilroy Bold',
                            fontSize: 18,
                          ),
                        ),
                      ),
                      const Divider(height: 0, color: Color(0xFFECEEF2)),
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F6F8),
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                          ),
                          child: TextField(
                            controller: _customerIdController,
                            style: TextStyle(
                              color: notifire.getdarkscolor,
                              fontFamily: 'Gilroy Medium',
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (_) {
                              if (_inquiryResult != null) {
                                setState(() => _inquiryResult = null);
                              }
                            },
                            decoration: InputDecoration(
                              hintText: _getHintText(),
                              hintStyle: TextStyle(
                                color: notifire.getdarkgreycolor.withOpacity(0.6),
                                fontFamily: 'Gilroy Medium',
                              ),
                              prefixIcon: Icon(_getInputIcon(), color: notifire.getbluecolor),
                              suffixIcon: IconButton(
                                icon: Icon(Icons.contact_page_outlined, color: notifire.getbluecolor),
                                onPressed: _openSavedCustomers,
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: width / 30,
                                vertical: height / 60,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (_isLoadingProviders)
                Padding(
                  padding: EdgeInsets.only(top: height / 90),
                  child: SizedBox(
                    height: height / 50,
                    width: height / 50,
                    child: const CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),

              if (_providerProducts.length > 1) ...[
                SizedBox(height: height / 80),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: width / 20),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Pilih Provider',
                      style: TextStyle(
                        color: notifire.getdarkgreycolor,
                        fontFamily: 'Gilroy Medium',
                        fontSize: height / 62,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: height / 120),
                SizedBox(
                  height: height / 22,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.symmetric(horizontal: width / 20),
                    itemCount: _providerProducts.length,
                    itemBuilder: (context, index) {
                      final p = _providerProducts[index];
                      final selected = _selectedProviderProduct?['buyer_sku_code'] == p['buyer_sku_code'];
                      final label = (p['product_name'] ?? p['buyer_sku_code'] ?? '-').toString();
                      return Padding(
                        padding: EdgeInsets.only(right: width / 50),
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedProviderProduct = p;
                              _inquiryResult = null;
                            });
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: width / 30),
                            decoration: BoxDecoration(
                              color: selected ? notifire.getbluecolor : notifire.gettabwhitecolor,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: selected ? notifire.getbluecolor : notifire.getdarkgreycolor.withOpacity(0.2),
                              ),
                            ),
                            child: Center(
                              child: Text(
                                label,
                                style: TextStyle(
                                  color: selected ? Colors.white : notifire.getdarkscolor,
                                  fontFamily: 'Gilroy Medium',
                                  fontSize: height / 68,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],

              SizedBox(height: height / 55),

              _buildHistorySection(),

              if (_historyItems.isNotEmpty) SizedBox(height: height / 55),

            // Cek Tagihan button
            if (_inquiryResult == null)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: width / 20),
                child: AppButton.primary(
                  expand: true,
                  loading: _isInquiring,
                  label: 'Cek Tagihan',
                  onPressed: (_isInquiring || _isLoading) ? null : _doInquiry,
                ),
              ),

            // Inquiry result
            if (_inquiryResult != null) ...[
              SizedBox(height: height / 50),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: width / 20),
                child: AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.receipt_long, color: notifire.getbluecolor, size: height / 30),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            'Detail Tagihan',
                            style: TextStyle(
                              color: notifire.getdarkscolor,
                              fontFamily: 'Gilroy Bold',
                              fontSize: height / 42,
                            ),
                          ),
                        ],
                      ),
                      Divider(color: notifire.getIsDark ? grey600 : grey200, height: AppSpacing.xxl),
                      _billRow('Nama Pelanggan', (_inquiryResult!['customer_name'] ?? '-').toString()),
                      _billRow('No. Pelanggan', (_inquiryResult!['customer_no'] ?? '-').toString()),
                      _billRow('Produk', (_inquiryResult!['product_name'] ?? '-').toString()),
                      if (_inquiryResult!['admin'] != null && (num.tryParse(_inquiryResult!['admin'].toString()) ?? 0) > 0)
                        _billRow('Biaya Admin', _formatPrice(_inquiryResult!['admin'])),
                      _billRow('Total Tagihan', _formatPrice(_inquiryResult!['selling_price'] ?? 0),
                          isBold: true, isBlue: true),
                      if (_inquiryResult!['desc'] != null) _buildDescDetails(),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              // Bayar button
              Padding(
                padding: EdgeInsets.symmetric(horizontal: width / 20),
                child: AppButton.success(
                  expand: true,
                  label: 'Bayar Sekarang',
                  onPressed: _payBill,
                ),
              ),
            ],

            SizedBox(height: height / 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _billRow(String label, String value, {bool isBold = false, bool isBlue = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: height / 150),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: notifire.getdarkgreycolor,
              fontFamily: 'Gilroy Medium',
              fontSize: height / 55,
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: isBlue ? notifire.getbluecolor : notifire.getdarkscolor,
                fontFamily: isBold ? 'Gilroy Bold' : 'Gilroy Medium',
                fontSize: isBold ? height / 45 : height / 55,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// PIN Screen for postpaid payment
class _PostpaidPinScreen extends StatefulWidget {
  final String buyerSkuCode;
  final String customerNo;
  final String productName;
  final String customerName;
  final double amount;
  final double admin;
  final Future<void> Function(Map<String, dynamic> transaction)? onPaymentSuccess;

  const _PostpaidPinScreen({
    Key? key,
    required this.buyerSkuCode,
    required this.customerNo,
    required this.productName,
    required this.customerName,
    required this.amount,
    required this.admin,
    this.onPaymentSuccess,
  }) : super(key: key);

  @override
  State<_PostpaidPinScreen> createState() => _PostpaidPinScreenState();
}

class _PostpaidPinScreenState extends State<_PostpaidPinScreen> {
  late ColorNotifire notifire;
  bool _isLoading = false;
  String _pin = '';
  bool _biometricAvailable = false;
  bool _showPin = false;
  bool _usedBiometric = false;
  final _currencyFormat = NumberFormat('#,###', 'id_ID');

  String _formatPrice(double price) {
    return 'Rp ${_currencyFormat.format(price.toInt())}';
  }

  @override
  void initState() {
    super.initState();
    _checkBiometric();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.pinRequired) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _handlePay());
    }
  }

  Future<void> _checkBiometric() async {
    final available = await BiometricService.isAvailable();
    final enabled = await BiometricService.isEnabled();
    if (mounted) setState(() => _biometricAvailable = available && enabled);
  }

  Future<void> _handleBiometric() async {
    final success = await BiometricService.authenticate(
      reason: 'Konfirmasi pembayaran ${widget.productName}',
    );
    print('[BIOMETRIC] postpaid: success=$success, mounted=$mounted');
    if (success && mounted) {
      _usedBiometric = true;
      _handlePay(bypassPin: true);
    }
  }

  Future<void> _handlePay({bool bypassPin = false}) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!bypassPin && auth.pinRequired && _pin.length != 4) {
      Fluttertoast.showToast(msg: 'Masukkan PIN 4 digit');
      return;
    }

    setState(() => _isLoading = true);
    final stopwatch = Stopwatch()..start();

    try {
      final response = await ApiService.purchasePpobPostpaid(
        buyerSkuCode: widget.buyerSkuCode,
        customerNo: widget.customerNo,
        pin: _pin,
        amount: widget.amount,
        biometricAuth: _usedBiometric,
      );
      print('[BIOMETRIC] postpaid API response: $response');

      stopwatch.stop();
      if (!mounted) return;
      setState(() => _isLoading = false);

      if (response.containsKey('transaction')) {
        Provider.of<AuthProvider>(context, listen: false).updateBalance();
        final tx = response['transaction'] as Map<String, dynamic>? ?? {};
        if (widget.onPaymentSuccess != null) {
          await widget.onPaymentSuccess!(tx);
        }
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => TransactionReceipt(
              title: 'Pembayaran ${widget.productName}',
              status: tx['status'] ?? 'completed',
              amount: widget.amount,
              productName: widget.productName,
              customerNo: widget.customerNo,
              receiverName: widget.customerName,
              orderId: tx['order_id']?.toString(),
              providerRef: tx['provider_ref'],
              category: 'Pascabayar',
              transactionTime: DateTime.now(),
              processingMs: stopwatch.elapsedMilliseconds,
            ),
          ),
        );
      } else {
        Fluttertoast.showToast(msg: response['message'] ?? 'Pembayaran gagal');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        Fluttertoast.showToast(
          msg: ApiService.userFriendlyMessage(e, fallback: 'Pembayaran gagal'),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    notifire = Provider.of<ColorNotifire>(context, listen: true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final needPin = auth.pinRequired;

    return Scaffold(
      backgroundColor: const Color(0xFF0D47A1),
      appBar: isDesktopPopup(context) ? null : AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: DesktopTitleWrapper(child: Text(
          'Konfirmasi Pembayaran',
          style: TextStyle(
            fontFamily: 'Gilroy Bold',
            fontSize: height / 40,
            color: Colors.white,
          ),
        ))
      ),
      body: needPin
          ? Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Bill summary card
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: width / 20),
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(width / 20),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            Text(
                              widget.productName,
                              style: TextStyle(
                                color: Colors.white,
                                fontFamily: 'Gilroy Bold',
                                fontSize: height / 45,
                              ),
                            ),
                            SizedBox(height: height / 80),
                            Text(
                              widget.customerName,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontFamily: 'Gilroy Medium',
                                fontSize: height / 55,
                              ),
                            ),
                            SizedBox(height: height / 60),
                            Text(
                              _formatPrice(widget.amount),
                              style: TextStyle(
                                color: Colors.white,
                                fontFamily: 'Gilroy Bold',
                                fontSize: height / 30,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: height / 20),
                    if (_biometricAvailable && !_showPin) ...[
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.fingerprint, color: Colors.white, size: 44),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Gunakan sidik jari atau Face ID',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontFamily: 'Gilroy Medium',
                          fontSize: height / 60,
                        ),
                      ),
                      const SizedBox(height: 36),
                      GestureDetector(
                        onTap: _isLoading ? null : _handleBiometric,
                        child: Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withOpacity(0.4), width: 2),
                          ),
                          child: const Icon(Icons.fingerprint, color: Colors.white, size: 40),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Tekan untuk verifikasi',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontFamily: 'Gilroy Medium',
                          fontSize: 12,
                        ),
                      ),
                      if (_isLoading) ...[
                        const SizedBox(height: 24),
                        const CircularProgressIndicator(color: Colors.white),
                      ],
                      const SizedBox(height: 32),
                      GestureDetector(
                        onTap: () => setState(() => _showPin = true),
                        child: Text(
                          'Gunakan PIN',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontFamily: 'Gilroy Medium',
                            fontSize: 13,
                            decoration: TextDecoration.underline,
                            decorationColor: Colors.white.withOpacity(0.5),
                          ),
                        ),
                      ),
                    ] else ...[
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.lock_outline_rounded, color: Colors.white, size: 34),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Masukkan PIN',
                        style: TextStyle(
                          fontFamily: 'Gilroy Bold',
                          fontSize: height / 35,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: height / 80),
                      Text(
                        'Masukkan PIN untuk konfirmasi pembayaran',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontFamily: 'Gilroy Medium',
                          fontSize: height / 60,
                        ),
                      ),
                      SizedBox(height: height / 30),
                      OTPTextField(
                        length: 4,
                        width: width / 1.5,
                        fieldWidth: width / 7,
                        style: TextStyle(
                          fontSize: height / 30,
                          fontFamily: 'Gilroy Bold',
                          color: Colors.white,
                        ),
                        textFieldAlignment: MainAxisAlignment.spaceAround,
                        fieldStyle: FieldStyle.box,
                        otpFieldStyle: OtpFieldStyle(
                          backgroundColor: Colors.white.withOpacity(0.1),
                          borderColor: Colors.white.withOpacity(0.5),
                          enabledBorderColor: Colors.white.withOpacity(0.3),
                          focusBorderColor: Colors.white,
                        ),
                        obscureText: true,
                        onCompleted: (pin) {
                          _pin = pin;
                        },
                        onChanged: (pin) {
                          _pin = pin;
                        },
                      ),
                      SizedBox(height: height / 10),
                      GestureDetector(
                        onTap: _isLoading ? null : _handlePay,
                        child: _isLoading
                            ? SizedBox(
                                height: height / 15,
                                child: const Center(
                                  child: CircularProgressIndicator(color: Colors.white),
                                ),
                              )
                            : Container(
                                height: height / 15,
                                width: width / 1.1,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.white.withOpacity(0.4)),
                                ),
                                child: Center(
                                  child: Text(
                                    'Konfirmasi Pembayaran',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontFamily: 'Gilroy Bold',
                                      fontSize: height / 45,
                                    ),
                                  ),
                                ),
                              ),
                      ),
                      if (_biometricAvailable && _showPin) ...[
                        const SizedBox(height: 24),
                        GestureDetector(
                          onTap: () => setState(() => _showPin = false),
                          child: Text(
                            'Gunakan Sidik Jari / Face ID',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontFamily: 'Gilroy Medium',
                              fontSize: 13,
                              decoration: TextDecoration.underline,
                              decorationColor: Colors.white.withOpacity(0.5),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            )
          : Center(
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle_outline, size: 60, color: Colors.white),
                        const SizedBox(height: 16),
                        const Text('Memproses...', style: TextStyle(fontFamily: 'Gilroy Medium', color: Colors.white)),
                      ],
                    ),
            ),
    );
  }
}
