import 'package:flutter/material.dart';
import 'package:modipay/widgets/desktop_title_wrapper.dart';

import 'package:flutter/services.dart';
import 'package:modipay/utils/toast.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../utils/responsive.dart';
import '../../services/api_service.dart';
import '../../services/app_exception.dart';
import '../../utils/colornotifire.dart';
import '../../utils/color.dart';
import '../../providers/auth_provider.dart';
import '../../design/design.dart';
import '../../services/pending_ppob_service.dart';
import 'bpjs_inquiry_screen.dart';
import 'components/saved_customers_bottom_sheet.dart';

// ── Tokens warna mengikuti style PPOB ────────────────────────────────────────
const Color _kHeaderBlue = Color(0xFF3F6FB4);
const Color _kPageBg = Color(0xFFF8F9FD);
const Color _kCardBorder = Color(0xFFE5E9EE);
const Color _kInputFill = Color(0xFFF5F6F8);
const Color _kInputBorder = Color(0xFFD4D8DF);
const Color _kTextPrimary = Color(0xFF1D1D1D);
const Color _kTextSecondary = Color(0xFF6B7280);
const Color _kErrorBg = Color(0xFFFFF4F4);
const Color _kErrorBorder = Color(0xFFF5C2C2);
const Color _kErrorText = Color(0xFFB00020);

class BpjsScreen extends StatefulWidget {
  const BpjsScreen({super.key});

  @override
  State<BpjsScreen> createState() => _BpjsScreenState();
}

class _BpjsScreenState extends State<BpjsScreen> {
  late ColorNotifire notifire;
  final TextEditingController _customerIdController = TextEditingController();
  final FocusNode _customerIdFocus = FocusNode();

  // Product list dari admin panel
  bool _isLoadingProducts = false;
  List<Map<String, dynamic>> _products = [];
  Map<String, dynamic>? _selectedProduct;

  // Inquiry state
  bool _isInquiring = false;
  String? _inquiryError;

  // Desktop: hasil inquiry ditampilkan inline di halaman yang sama (bukan
  // navigasi ke BpjsInquiryResultScreen seperti alur mobile), meniru
  // referensi desain dua-kolom.
  Map<String, dynamic>? _inquiryData;
  bool _isPaying = false;

  // Search di bottom-sheet
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _filteredProducts = [];

  @override
  void initState() {
    super.initState();
    notifire = Provider.of<ColorNotifire>(context, listen: false);
    _loadDarkMode();
    _loadProducts();
  }

  @override
  void dispose() {
    _customerIdController.dispose();
    _customerIdFocus.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDarkMode() async {
    final prefs = await SharedPreferences.getInstance();
    bool? previusstate = prefs.getBool('setIsDark');
    if (previusstate == null) {
      notifire.setIsDark = false;
    } else {
      notifire.setIsDark = previusstate;
    }
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoadingProducts = true);
    try {
      final products = await ApiService.getPpobProducts(
        cmd: 'pasca',
        brand: 'BPJS',
      );

      final unique = <String, Map<String, dynamic>>{};
      for (final p in products) {
        if (p is! Map) continue;
        final item = Map<String, dynamic>.from(p);
        final sku = (item['buyer_sku_code'] ?? item['product_code'] ?? '')
            .toString()
            .trim();
        if (sku.isEmpty) continue;
        unique.putIfAbsent(sku, () => item);
      }

      final list = unique.values.toList()
        ..sort((a, b) {
          final an = (a['product_name'] ?? '').toString().toLowerCase();
          final bn = (b['product_name'] ?? '').toString().toLowerCase();
          return an.compareTo(bn);
        });

      if (!mounted) return;
      setState(() {
        _products = list;
        _filteredProducts = List.from(list);
        _isLoadingProducts = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingProducts = false);
      showToast(
        msg: ApiService.userFriendlyMessage(e,
            fallback: 'Gagal memuat daftar produk BPJS'),
      );
    }
  }

  String _productNameOf(Map<String, dynamic> product) {
    final name = (product['product_name'] ?? product['product_code'] ?? '')
        .toString()
        .trim();
    return name.isEmpty ? '-' : name;
  }

  String _productSkuOf(Map<String, dynamic> product) {
    return (product['buyer_sku_code'] ?? product['product_code'] ?? '')
        .toString()
        .trim();
  }

  void _showProductPicker() {
    if (_isLoadingProducts) {
      showToast(msg: 'Sedang memuat daftar produk...');
      return;
    }
    if (_products.isEmpty) {
      showToast(msg: 'Produk BPJS belum tersedia');
      _loadProducts();
      return;
    }

    _searchController.clear();
    _filteredProducts = List.from(_products);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Container(
              height: MediaQuery.of(ctx).size.height * 0.75,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  // Handle bar
                  Container(
                    margin: const EdgeInsets.only(top: 10),
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD4D8DF),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 12),
                    child: Row(
                      children: [
                        Icon(Icons.health_and_safety,
                            color: _kHeaderBlue, size: 22),
                        SizedBox(width: 10),
                        Text(
                          'Pilih Jenis BPJS',
                          style: TextStyle(
                            color: _kTextPrimary,
                            fontFamily: 'Gilroy Bold',
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Search
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      height: 46,
                      decoration: BoxDecoration(
                        color: _kInputFill,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _kInputBorder),
                      ),
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(
                          color: _kTextPrimary,
                          fontFamily: 'Gilroy Medium',
                          fontSize: 14,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Cari produk BPJS...',
                          hintStyle: TextStyle(
                            color: _kTextSecondary,
                            fontFamily: 'Gilroy Medium',
                            fontSize: 14,
                          ),
                          prefixIcon: Icon(Icons.search,
                              color: _kTextSecondary, size: 20),
                          border: InputBorder.none,
                          contentPadding:
                              EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                        ),
                        onChanged: (value) {
                          final q = value.toLowerCase();
                          setModalState(() {
                            _filteredProducts = _products
                                .where((product) =>
                                    _productNameOf(product)
                                        .toLowerCase()
                                        .contains(q) ||
                                    _productSkuOf(product)
                                        .toLowerCase()
                                        .contains(q))
                                .toList();
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: _filteredProducts.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.search_off,
                                    size: 56, color: Color(0xFFD4D8DF)),
                                SizedBox(height: 8),
                                Text(
                                  'Tidak ada produk ditemukan',
                                  style: TextStyle(
                                    color: _kTextSecondary,
                                    fontFamily: 'Gilroy Medium',
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                            itemCount: _filteredProducts.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (ctx, index) {
                              final product = _filteredProducts[index];
                              final productName = _productNameOf(product);
                              final productSku = _productSkuOf(product);
                              final isSelected = _selectedProduct != null &&
                                  _productSkuOf(_selectedProduct!) ==
                                      productSku;
                              return InkWell(
                                onTap: () {
                                  setState(() {
                                    _selectedProduct = product;
                                    _inquiryError = null;
                                    _inquiryData = null;
                                  });
                                  Navigator.pop(ctx);
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(0xFFEAF1FB)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected
                                          ? _kHeaderBlue
                                          : _kCardBorder,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? _kHeaderBlue
                                                  .withValues(alpha: 0.16)
                                              : const Color(0xFFF3F4F6),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: const Icon(
                                          Icons.health_and_safety,
                                          color: _kHeaderBlue,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              productName,
                                              style: const TextStyle(
                                                color: _kTextPrimary,
                                                fontFamily: 'Gilroy Bold',
                                                fontSize: 14,
                                              ),
                                            ),
                                            if (productSku.isNotEmpty)
                                              Padding(
                                                padding: const EdgeInsets
                                                    .only(top: 2),
                                                child: Text(
                                                  productSku,
                                                  style: const TextStyle(
                                                    color: _kTextSecondary,
                                                    fontFamily: 'Gilroy Medium',
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      if (isSelected)
                                        const Icon(Icons.check_circle,
                                            color: _kHeaderBlue, size: 22),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _doInquiry() async {
    final customerId = _customerIdController.text.trim();
    if (customerId.isEmpty) {
      showToast(msg: 'Masukkan Nomor BPJS');
      _customerIdFocus.requestFocus();
      return;
    }
    if (_selectedProduct == null) {
      showToast(msg: 'Pilih jenis BPJS terlebih dahulu');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isInquiring = true;
      _inquiryError = null;
    });

    try {
      final sku = _productSkuOf(_selectedProduct!);
      final result = await ApiService.bpjsInquiry(
        kodeProduk: sku,
        customerNo: customerId,
      );

      final status = (result['status'] ?? '').toString().toLowerCase();
      final isSuccess = status == 'success' || status == 'sukses';

      if (!mounted) return;
      setState(() => _isInquiring = false);

      if (isSuccess && result['data'] is Map) {
        final data = Map<String, dynamic>.from(result['data'] as Map);
        if (isDesktop(context)) {
          setState(() => _inquiryData = data);
          return;
        }
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BpjsInquiryResultScreen(
              inquiryData: data,
              customerId: customerId,
              productName: _productNameOf(_selectedProduct!),
            ),
          ),
        );
      } else {
        setState(() {
          _inquiryError =
              (result['message'] ?? 'Cek tagihan gagal').toString();
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _inquiryError =
            ApiService.userFriendlyMessage(e, fallback: 'Cek tagihan gagal');
        _isInquiring = false;
      });
    }
  }

  void _clearError() {
    if (_inquiryError != null || _inquiryData != null) {
      setState(() {
        _inquiryError = null;
        _inquiryData = null;
      });
    }
  }

  Future<void> _openSavedCustomers() async {
    final selectedNo = await SavedCustomersBottomSheet.show(
      context,
      category: 'bpjs',
      accentColor: _kHeaderBlue,
    );
    if (selectedNo != null && selectedNo.isNotEmpty) {
      setState(() {
        _customerIdController.text = selectedNo;
        _inquiryError = null;
        _inquiryData = null;
      });
    }
  }

  // ─── Desktop: helpers & pembayaran inline ───────────────────────────────

  double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    final clean = value.toString().replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(clean) ?? 0;
  }

  double _firstAmount(List<dynamic> candidates) {
    for (final c in candidates) {
      if (c is List) continue;
      final n = _toDouble(c);
      if (n > 0) return n;
    }
    return 0;
  }

  String _firstText(List<dynamic> candidates) {
    for (final c in candidates) {
      final s = (c ?? '').toString().trim();
      if (s.isNotEmpty) return s;
    }
    return '';
  }

  String _money(dynamic v) {
    final n = _toDouble(v);
    return 'Rp ${NumberFormat('#,###', 'id_ID').format(n.toInt())}';
  }

  List<Map<String, dynamic>> get _tagihanList {
    final data = _inquiryData;
    if (data == null || data['tagihan'] is! List) return [];
    return List<Map<String, dynamic>>.from(
      (data['tagihan'] as List).whereType<Map>().map(Map<String, dynamic>.from),
    );
  }

  /// Alur bayar desktop: dialog PIN kasir (sama seperti flow PPOB desktop
  /// lain) lalu `ApiService.purchaseLoketbayar` — API yang sama persis
  /// dengan yang dipakai `_BpjsPayPinScreenState._pay` di alur mobile,
  /// hanya menambahkan kasirCode/kasirPin sesuai pola `TransactionPinAuthDialog`.
  Future<void> _payDesktop() async {
    final data = _inquiryData;
    if (data == null) return;
    double total = _firstAmount([data['total'], data['selling_price']]);
    if (total <= 0) {
      total = _toDouble(data['tagihan']) + _toDouble(data['admin']) + _toDouble(data['denda']);
    }
    if (total <= 0) {
      showToast(msg: 'Total tagihan tidak valid');
      return;
    }
    final refId = _firstText([data['ref_id'], data['refID']]);
    if (refId.isEmpty) {
      showToast(msg: 'Ref ID tidak ditemukan, silakan cek tagihan ulang');
      return;
    }
    final kodeProduk = _firstText([
      data['kode_produk'],
      data['kodeProduk'],
      _selectedProduct != null ? _productSkuOf(_selectedProduct!) : '',
    ]);
    final customerNo =
        (data['idpel'] ?? data['customer_no'] ?? data['noVA'] ?? _customerIdController.text.trim()).toString();
    final customerName = (data['nama'] ?? data['customer_name'] ?? '-').toString();
    final productName = _selectedProduct != null ? _productNameOf(_selectedProduct!) : 'BPJS';

    await TransactionPinAuthDialog.show(
      context: context,
      onConfirm: (kasirCode, kasirPin) async {
        setState(() => _isPaying = true);
        final stopwatch = Stopwatch()..start();
        try {
          final response = await ApiService.purchaseLoketbayar(
            kodeProduk: kodeProduk,
            customerNo: customerNo,
            nominal: total.toInt(),
            refId: refId,
            pin: kasirPin,
            kasirCode: kasirCode,
            kasirPin: kasirPin,
            productName: productName,
          );
          stopwatch.stop();
          if (!mounted) return;
          setState(() => _isPaying = false);

          if (response.containsKey('transaction')) {
            Provider.of<AuthProvider>(context, listen: false).updateBalance();
            final tx = response['transaction'] as Map<String, dynamic>? ?? {};
            Navigator.of(context, rootNavigator: true).pop();

            final orderId = (tx['order_id'] ?? '-').toString();
            void showSuccess(Map<String, dynamic> finalTx) {
              TransactionSuccessDialog.show(
                context: context,
                subtitle: 'Tagihan $productName berhasil dibayar',
                orderId: (finalTx['order_id'] ?? orderId).toString(),
                rows: [
                  MapEntry('Nomor Peserta', customerNo),
                  MapEntry('Nama Peserta', customerName),
                  MapEntry('Jenis', productName),
                ],
                totalLabel: _money(total),
              );
            }

            // Backend PPOB/Loketbayar memproses transaksi secara async — respons
            // ini cuma tanda transaksi diterima (status 'pending'), belum tentu
            // sukses. Lihat ppob_pending_timeout_frontend_prompt.md di repo
            // modiback: harus polling /ppob/check-status sampai final, TANPA
            // membuat transaksi baru untuk customer_no yang sama selama masih
            // pending.
            if ((tx['status'] ?? '').toString() == 'pending') {
              PendingPpobService.instance.track(orderId, initialTransaction: tx);
              TransactionPendingDialog.show(
                context: context,
                orderId: orderId,
                description: 'Tagihan $productName untuk $customerNo',
                onCompleted: (finalTx) {
                  PendingPpobService.instance.dismiss(orderId);
                  showSuccess(finalTx);
                },
                onFailed: (finalTx) {
                  PendingPpobService.instance.dismiss(orderId);
                  TransactionFailedDialog.show(
                    context: context,
                    orderId: orderId,
                    reason: TransactionFailedDialog.reasonFromTransaction(finalTx),
                  );
                },
              );
            } else {
              showSuccess(tx);
            }
          } else {
            throw AppException(response['message']?.toString() ?? 'Pembayaran gagal');
          }
        } catch (e) {
          if (mounted) setState(() => _isPaying = false);
          if (e is AppException) rethrow;
          throw AppException(ApiService.userFriendlyMessage(e, fallback: 'Pembayaran gagal'));
        }
      },
    );
  }

  Widget _desktopHeader() {
    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(color: desktopPrimaryBtn.withValues(alpha: 0.08), shape: BoxShape.circle),
          alignment: Alignment.center,
          child: const Icon(Icons.health_and_safety_rounded, color: desktopPrimaryBtn, size: 24),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pembayaran BPJS', style: GoogleFonts.hankenGrotesk(fontSize: 20, fontWeight: FontWeight.w800, color: desktopTextPrimary)),
            Text('Bayar tagihan BPJS Kesehatan & BPJS Ketenagakerjaan dengan mudah', style: GoogleFonts.hankenGrotesk(fontSize: 13, color: desktopTextSecondary)),
          ],
        ),
      ],
    );
  }

  Widget _desktopProductCard(Map<String, dynamic> product) {
    final name = _productNameOf(product);
    final sku = _productSkuOf(product);
    final selected = _selectedProduct != null && _productSkuOf(_selectedProduct!) == sku;
    final isKesehatan = name.toLowerCase().contains('kesehatan');
    final color = isKesehatan ? const Color(0xFF16A34A) : const Color(0xFF2563EB);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() {
          _selectedProduct = product;
          _inquiryError = null;
          _inquiryData = null;
        }),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: desktopSurfaceCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? desktopAccentBlue : desktopBorder, width: selected ? 1.5 : 1),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                alignment: Alignment.center,
                child: Icon(isKesehatan ? Icons.health_and_safety_rounded : Icons.engineering_rounded, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(name, style: GoogleFonts.hankenGrotesk(fontSize: 13.5, fontWeight: FontWeight.w800, color: desktopTextPrimary), maxLines: 2, overflow: TextOverflow.ellipsis),
                    if (isKesehatan)
                      Text(
                        'Badan Penyelenggara Jaminan Sosial',
                        style: GoogleFonts.hankenGrotesk(fontSize: 10.5, color: desktopTextSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              if (selected)
                Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(color: desktopAccentBlue, shape: BoxShape.circle),
                  child: const Icon(Icons.check_rounded, size: 13, color: Colors.white),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _desktopTrustBadge(IconData icon, String title, String subtitle) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 18, color: desktopAccentBlue),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: GoogleFonts.hankenGrotesk(fontSize: 12, fontWeight: FontWeight.w700, color: desktopTextPrimary)),
                Text(subtitle, style: GoogleFonts.hankenGrotesk(fontSize: 10.5, color: desktopTextSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoPair(String label, Widget value) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: GoogleFonts.hankenGrotesk(fontSize: 11.5, color: desktopTextSecondary)),
            const SizedBox(height: 3),
            value,
          ],
        ),
      ),
    );
  }

  Widget _infoPairText(String label, String value) {
    return _infoPair(
      label,
      Text(value, style: GoogleFonts.hankenGrotesk(fontSize: 12.5, fontWeight: FontWeight.w700, color: desktopTextPrimary)),
    );
  }

  Widget _statusBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: desktopSuccessBg, borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: GoogleFonts.hankenGrotesk(fontSize: 11, fontWeight: FontWeight.w700, color: desktopSuccessFg)),
    );
  }

  Widget _rincianRow(String label, String value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.hankenGrotesk(
                fontSize: highlight ? 13.5 : 12.5,
                fontWeight: highlight ? FontWeight.w800 : FontWeight.w500,
                color: highlight ? desktopTextPrimary : desktopTextSecondary,
              ),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.hankenGrotesk(
              fontSize: highlight ? 16 : 12.5,
              fontWeight: FontWeight.w800,
              color: highlight ? desktopAccentBlue : desktopTextPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopBillInfo() {
    final data = _inquiryData;
    if (data == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 40),
        decoration: BoxDecoration(
          color: desktopSurfacePage,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: desktopBorder.withValues(alpha: 0.6)),
        ),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(color: desktopSurfaceCard, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: const Icon(Icons.receipt_long_outlined, size: 26, color: desktopTextSecondary),
            ),
            const SizedBox(height: 14),
            Text('Informasi tagihan akan muncul di sini', style: GoogleFonts.hankenGrotesk(fontSize: 13.5, fontWeight: FontWeight.w700, color: desktopTextPrimary)),
            const SizedBox(height: 4),
            Text(
              'Lengkapi langkah 1 dan 2, lalu klik "Cek Tagihan" untuk melihat detail tagihan.',
              textAlign: TextAlign.center,
              style: GoogleFonts.hankenGrotesk(fontSize: 12, color: desktopTextSecondary),
            ),
          ],
        ),
      );
    }

    final customerId = _customerIdController.text.trim();
    final isKesehatan = _selectedProduct != null && _productNameOf(_selectedProduct!).toLowerCase().contains('kesehatan');
    final iconColor = isKesehatan ? const Color(0xFF16A34A) : const Color(0xFF2563EB);
    final periode = _firstText([data['periode'], _tagihanList.isNotEmpty ? _tagihanList.first['periode'] : null]);
    final jatuhTempo = _firstText([data['jatuh_tempo'], data['due_date'], data['tgl_jatuh_tempo']]);
    final faskes = _firstText([data['faskes'], data['foskes'], data['faskes_tk1']]);
    final tagihanAmount = _firstAmount([data['nominal'], data['tagihan']]);
    final admin = _toDouble(data['admin']);
    final denda = _toDouble(data['denda']);
    final total = _firstAmount([data['total'], data['selling_price']]);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: desktopSurfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: desktopBorder.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                alignment: Alignment.center,
                child: Icon(isKesehatan ? Icons.health_and_safety_rounded : Icons.engineering_rounded, color: iconColor, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _infoPairText('Nama Peserta', (data['nama'] ?? data['customer_name'] ?? '-').toString()),
                        _infoPairText('Tipe Peserta', (data['segmen'] ?? '-').toString()),
                      ],
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _infoPairText('Nomor Peserta', (data['idpel'] ?? data['customer_no'] ?? customerId).toString()),
                        _infoPairText('Periode', periode.isEmpty ? '-' : periode),
                      ],
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _infoPairText('Faskes Tingkat 1', faskes.isEmpty ? '-' : faskes),
                        _infoPairText('Jatuh Tempo', jatuhTempo.isEmpty ? '-' : jatuhTempo),
                      ],
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Expanded(child: SizedBox.shrink()),
                        _infoPair('Status', _statusBadge('Aktif')),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Rincian Tagihan', style: GoogleFonts.hankenGrotesk(fontSize: 13, fontWeight: FontWeight.w700, color: desktopAccentBlue)),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(color: desktopSurfacePage, borderRadius: BorderRadius.circular(10)),
            child: Column(
              children: [
                _rincianRow('Tagihan Iuran${periode.isNotEmpty ? ' ($periode)' : ''}', _money(tagihanAmount)),
                if (denda > 0) _rincianRow('Denda Keterlambatan', _money(denda)),
                _rincianRow('Biaya Admin', _money(admin)),
                const SizedBox(height: 6),
                Divider(color: desktopBorder.withValues(alpha: 0.6), height: 1),
                const SizedBox(height: 6),
                _rincianRow('Total Tagihan', _money(total), highlight: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Layout desktop dua-kolom khusus BPJS: kiri = pilih jenis BPJS + nomor
  // peserta + tombol "Cek Tagihan" + informasi tagihan inline, kanan =
  // ringkasan transaksi sticky. Tombol "Bayar Sekarang" memanggil
  // _payDesktop (dialog PIN kasir lalu ApiService.purchaseLoketbayar).
  Widget _buildDesktopLayout() {
    final data = _inquiryData;
    final customerId = _customerIdController.text.trim();
    final productName = _selectedProduct != null ? _productNameOf(_selectedProduct!) : null;
    final total = data != null ? _firstAmount([data['total'], data['selling_price']]) : 0.0;
    final tagihanAmount = data != null ? _firstAmount([data['nominal'], data['tagihan']]) : 0.0;
    final admin = data != null ? _toDouble(data['admin']) : 0.0;
    final denda = data != null ? _toDouble(data['denda']) : 0.0;
    final periode = data != null
        ? _firstText([data['periode'], _tagihanList.isNotEmpty ? _tagihanList.first['periode'] : null])
        : '-';
    final canConfirm = data != null && !_isPaying;

    return Scaffold(
      backgroundColor: desktopSurfacePage,
      body: PpobDesktopTwoColumnLayout(
        left: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _desktopHeader(),
            const SizedBox(height: 28),
            const PpobStepHeader(step: 1, title: 'Pilih Jenis BPJS'),
            const SizedBox(height: 14),
            if (_isLoadingProducts)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_products.isEmpty)
              Text('Produk BPJS belum tersedia', style: GoogleFonts.hankenGrotesk(fontSize: 13, color: desktopTextSecondary))
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _products.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  mainAxisExtent: 104,
                ),
                itemBuilder: (_, i) => _desktopProductCard(_products[i]),
              ),
            const SizedBox(height: 28),
            const PpobStepHeader(
              step: 2,
              title: 'Masukkan Nomor Peserta / Virtual Account',
              subtitle: 'Nomor Peserta / Virtual Account',
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: desktopBorderedField(
                    icon: Icons.person_outline_rounded,
                    controller: _customerIdController,
                    focusNode: _customerIdFocus,
                    keyboardType: TextInputType.number,
                    hint: 'Contoh: 0001234567890',
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (_) => _clearError(),
                    onSubmitted: (_) => _isInquiring ? null : _doInquiry(),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _isInquiring ? null : _doInquiry,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: desktopPrimaryBtn,
                      disabledBackgroundColor: desktopPrimaryBtn.withValues(alpha: 0.5),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: _isInquiring
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2.2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                          )
                        : const Icon(Icons.search_rounded, size: 18, color: Colors.white),
                    label: Text('Cek Tagihan', style: GoogleFonts.hankenGrotesk(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                ),
              ],
            ),
            if (_inquiryError != null && !_isInquiring) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: _kErrorBg,
                  border: Border.all(color: _kErrorBorder),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(_inquiryError!, style: GoogleFonts.hankenGrotesk(fontSize: 12.5, color: _kErrorText)),
              ),
            ] else ...[
              const SizedBox(height: 12),
              const PpobDesktopBanner(
                icon: Icons.info_outline_rounded,
                title: 'Pastikan nomor peserta / virtual account sudah benar.',
                tone: PpobBannerTone.info,
              ),
            ],
            const SizedBox(height: 28),
            const PpobStepHeader(step: 3, title: 'Informasi Tagihan'),
            const SizedBox(height: 12),
            _buildDesktopBillInfo(),
            if (_inquiryData != null) ...[
              const SizedBox(height: 12),
              const PpobDesktopBanner(
                icon: Icons.info_outline_rounded,
                title: 'Pembayaran akan diproses secara real-time dan langsung tercatat.',
                tone: PpobBannerTone.info,
              ),
            ],
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: desktopBorder.withValues(alpha: 0.5)))),
              child: Row(
                children: [
                  _desktopTrustBadge(Icons.bolt_rounded, 'Proses Instan', 'Pembayaran langsung diproses'),
                  _desktopTrustBadge(Icons.shield_outlined, 'Aman & Terpercaya', 'Data terenkripsi & aman'),
                  _desktopTrustBadge(Icons.sync_rounded, 'Update Real-time', 'Tagihan selalu terupdate'),
                  _desktopTrustBadge(Icons.support_agent_rounded, '24/7 Support', 'Kami siap membantu'),
                ],
              ),
            ),
          ],
        ),
        right: PpobDesktopSummaryPanel(
          rows: [
            const PpobDetailRow(icon: Icons.health_and_safety_outlined, label: 'Penyedia', value: 'BPJS'),
            PpobDetailRow(icon: Icons.badge_outlined, label: 'Nomor Peserta', value: data != null ? (data['idpel'] ?? data['customer_no'] ?? customerId).toString() : '-'),
            PpobDetailRow(icon: Icons.person_outline, label: 'Nama Peserta', value: data != null ? (data['nama'] ?? data['customer_name'] ?? '-').toString() : '-'),
            PpobDetailRow(icon: Icons.calendar_month_outlined, label: 'Periode', value: data != null ? periode : '-'),
            PpobDetailRow(icon: Icons.groups_outlined, label: 'Jenis Peserta', value: productName ?? '-'),
            if ((data?['faskes'] ?? data?['foskes']) != null)
              PpobDetailRow(icon: Icons.local_hospital_outlined, label: 'Foskes Tingkat 1', value: (data!['faskes'] ?? data['foskes']).toString()),
            PpobDetailRow(icon: Icons.description_outlined, label: 'Tagihan', value: data != null ? _money(tagihanAmount) : '-'),
            if (data != null && denda > 0) PpobDetailRow(icon: Icons.report_gmailerrorred_outlined, label: 'Denda', value: _money(denda)),
            PpobDetailRow(icon: Icons.receipt_long_outlined, label: 'Admin', value: data != null ? _money(admin) : '-'),
          ],
          totalLabel: data != null ? _money(total) : 'Rp 0',
          confirmLabel: 'Bayar Sekarang',
          loading: _isPaying,
          onConfirm: canConfirm ? _payDesktop : null,
        ),
      ),
    );
  }

  // ─── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    notifire = Provider.of<ColorNotifire>(context, listen: true);

    if (isDesktop(context)) {
      return _buildDesktopLayout();
    }

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: _kPageBg,
      appBar: isDesktopPopup(context) ? null : AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        backgroundColor: _kPageBg,
        leading: DesktopLeadingWrapper(
          child: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: _kTextPrimary),
          ),
        ),
        iconTheme: const IconThemeData(color: _kTextPrimary),
        title: DesktopTitleWrapper(child: const Text(
          'BPJS',
          style: TextStyle(
            color: _kTextPrimary,
            fontFamily: 'Gilroy Bold',
            fontSize: 18,
          ),
        ))
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF16215C).withValues(alpha: 0.06),
                            blurRadius: 20,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'BPJS',
                              style: TextStyle(
                                color: _kTextPrimary,
                                fontFamily: 'Gilroy Bold',
                                fontSize: 22,
                              ),
                            ),
                          ),
                          const Divider(height: 0, color: Color(0xFFECEEF2)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Jenis BPJS',
                                  style: TextStyle(
                                    color: _kTextPrimary,
                                    fontFamily: 'Gilroy Bold',
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                InkWell(
                                  onTap: _showProductPicker,
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    height: 48,
                                    padding: const EdgeInsets.symmetric(horizontal: 14),
                                    decoration: BoxDecoration(
                                      color: _kInputFill,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            _selectedProduct != null
                                                ? _productNameOf(_selectedProduct!)
                                                : (_isLoadingProducts
                                                    ? 'Memuat daftar produk...'
                                                    : 'Pilih jenis BPJS'),
                                            style: TextStyle(
                                              color: _selectedProduct != null
                                                  ? _kTextPrimary
                                                  : _kTextSecondary,
                                              fontFamily: _selectedProduct != null
                                                  ? 'Gilroy Bold'
                                                  : 'Gilroy Medium',
                                              fontSize: 14,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        if (_isLoadingProducts)
                                          const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.4,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                      _kHeaderBlue),
                                            ),
                                          )
                                        else
                                          const Icon(Icons.keyboard_arrow_down_rounded,
                                              color: _kTextSecondary),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                const Text(
                                  'Nomor BPJS',
                                  style: TextStyle(
                                    color: _kTextPrimary,
                                    fontFamily: 'Gilroy Bold',
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: _kInputFill,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: _customerIdController,
                                          focusNode: _customerIdFocus,
                                          keyboardType: TextInputType.number,
                                          inputFormatters: [
                                            FilteringTextInputFormatter.digitsOnly,
                                          ],
                                          style: const TextStyle(
                                            color: _kTextPrimary,
                                            fontFamily: 'Gilroy Medium',
                                            fontSize: 14,
                                          ),
                                          onChanged: (_) => _clearError(),
                                          decoration: const InputDecoration(
                                            hintText: 'Masukkan Nomor BPJS',
                                            hintStyle: TextStyle(
                                              color: _kTextSecondary,
                                              fontFamily: 'Gilroy Medium',
                                              fontSize: 14,
                                            ),
                                            border: InputBorder.none,
                                            contentPadding: EdgeInsets.symmetric(
                                                horizontal: 14, vertical: 12),
                                          ),
                                        ),
                                      ),
                                      InkWell(
                                        onTap: _openSavedCustomers,
                                        borderRadius: BorderRadius.circular(8),
                                        child: const Padding(
                                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          child: Icon(
                                            Icons.contact_page_outlined,
                                            color: _kHeaderBlue,
                                            size: 24,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (_inquiryError != null && !_isInquiring) ...[
                                  const SizedBox(height: 16),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: _kErrorBg,
                                      border: Border.all(color: _kErrorBorder),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      _inquiryError!,
                                      style: const TextStyle(
                                        color: _kErrorText,
                                        fontFamily: 'Gilroy Medium',
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: const BoxDecoration(
                              color: Color(0xFFF2F4F8),
                              borderRadius: BorderRadius.only(
                                bottomLeft: Radius.circular(16),
                                bottomRight: Radius.circular(16),
                              ),
                            ),
                            child: SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton(
                                onPressed: _isInquiring ? null : _doInquiry,
                                style: ElevatedButton.styleFrom(
                                  elevation: 0,
                                  backgroundColor: _kHeaderBlue,
                                  disabledBackgroundColor: const Color(0xFF8AA8D6),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: _isInquiring
                                    ? const Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.4,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                      Colors.white),
                                            ),
                                          ),
                                          SizedBox(width: 10),
                                          Text(
                                            'Memeriksa tagihan…',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontFamily: 'Gilroy Bold',
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      )
                                    : const Text(
                                        'Cek Tagihan',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontFamily: 'Gilroy Bold',
                                          fontSize: 15,
                                        ),
                                      ),
                              ),
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
        ),
      )
    );
  }
}
