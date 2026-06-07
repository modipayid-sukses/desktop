import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/api_service.dart';
import '../../utils/colornotifire.dart';
import 'bpjs_inquiry_screen.dart';
import 'components/saved_customers_bottom_sheet.dart';

// ── Tokens warna mengikuti style PPOB ────────────────────────────────────────
const Color _kHeaderBlue = Color(0xFF3F6FB4);
const Color _kPageBg = Color(0xFFFAFAFA);
const Color _kCardBorder = Color(0xFFE5E9EE);
const Color _kInputFill = Color(0xFFF3F4F6);
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
      Fluttertoast.showToast(
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
      Fluttertoast.showToast(msg: 'Sedang memuat daftar produk...');
      return;
    }
    if (_products.isEmpty) {
      Fluttertoast.showToast(msg: 'Produk BPJS belum tersedia');
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
      Fluttertoast.showToast(msg: 'Masukkan Nomor BPJS');
      _customerIdFocus.requestFocus();
      return;
    }
    if (_selectedProduct == null) {
      Fluttertoast.showToast(msg: 'Pilih jenis BPJS terlebih dahulu');
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
    if (_inquiryError != null) {
      setState(() => _inquiryError = null);
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
      });
    }
  }

  // ─── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    notifire = Provider.of<ColorNotifire>(context, listen: true);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: _kPageBg,
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: _kHeaderBlue,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarBrightness: Brightness.dark,
          statusBarIconBrightness: Brightness.light,
          statusBarColor: Colors.transparent,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'BPJS',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Gilroy Bold',
            fontSize: 18,
          ),
        ),
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Column(
          children: [
            // ── Kartu input ──────────────────────────────────────────────
            Container(
              color: _kHeaderBlue,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Field 1: Pilih Jenis BPJS
                    const Text(
                      'Jenis BPJS',
                      style: TextStyle(
                        color: _kTextPrimary,
                        fontFamily: 'Gilroy Bold',
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: _showProductPicker,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        height: 48,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: _kInputFill,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _kInputBorder),
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

                    const SizedBox(height: 14),

                    // Field 2: Nomor BPJS
                    const Text(
                      'Nomor BPJS',
                      style: TextStyle(
                        color: _kTextPrimary,
                        fontFamily: 'Gilroy Bold',
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: _kInputFill,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _kInputBorder),
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
                  ],
                ),
              ),
            ),

            // ── Tombol Cek Tagihan + hasil ─────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: 48,
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
                                  fontSize: 14,
                                ),
                              ),
                      ),
                    ),
                    if (_inquiryError != null && !_isInquiring) ...[
                      const SizedBox(height: 12),
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
            ),
          ],
        ),
      ),
    );
  }
}
