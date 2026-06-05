import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_native_contact_picker/flutter_native_contact_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../providers/auth_provider.dart';
import '../../services/app_exception.dart';
import '../../services/api_service.dart';
import '../../services/biometric_service.dart';
import '../../utils/colornotifire.dart';
import '../../widgets/transaction_receipt.dart';
import '../topup/topupcard/confirmpayment.dart';

class PPOBProductScreen extends StatefulWidget {
  final String category;
  final String title;
  final String cmd;
  final String? inquiryType;
  final String? initialBrand;
  final String? productTypeFilter;
  // Filter produk berdasarkan substring (case-insensitive) di product_name.
  // Dipakai untuk halaman TopUp Game per provider (mis. hanya tampilkan
  // produk dengan nama mengandung "free fire").
  final String? productNameFilter;
  // Paksa halaman ini langsung pakai panel "Cek Tagihan" (BPJS-style),
  // tidak peduli keyword kategori. Dipakai oleh hub (Tagihan Internet,
  // Multifinance, dll) saat user pilih brand.
  final bool inquiryOnly;

  // ─── UI config override (dari admin panel via /api/ppob/menu) ───
  // Kalau di-set, override heuristik internal (mis. _isTopupGameFiltered,
  // _isPln) untuk decision rendering. Kalau null, fallback ke heuristik
  // existing supaya kategori lama tetap jalan.
  final String? configInputLabel;
  final String? configInputHint;
  final String? configInputKeyboard; // 'number' | 'text'
  final int? configInputMinLength;
  final int? configInputMaxLength;
  final String? configProductLayout; // 'grid' | 'list'
  final int? configProductColumns; // 1..3
  final bool? configShowBrandTabs;
  final bool? configAutoDetectBrand;
  // Override SKU & provider untuk panggilan inquiry (cek nama pelanggan).
  // Kalau di-set, dipakai pengganti buyer_sku_code/provider produk yang
  // user pilih. Dipakai a.l. untuk Token PLN: admin set 1 SKU murah
  // sebagai SKU inquiry, supaya cek nama tidak tergantung produk yg dipilih.
  final String? configInquirySku;
  final String? configInquiryProvider;

  const PPOBProductScreen({
    super.key,
    required this.category,
    required this.title,
    this.cmd = 'prepaid',
    this.inquiryType,
    this.initialBrand,
    this.productTypeFilter,
    this.productNameFilter,
    this.inquiryOnly = false,
    this.configInputLabel,
    this.configInputHint,
    this.configInputKeyboard,
    this.configInputMinLength,
    this.configInputMaxLength,
    this.configProductLayout,
    this.configProductColumns,
    this.configShowBrandTabs,
    this.configAutoDetectBrand,
    this.configInquirySku,
    this.configInquiryProvider,
  });

  @override
  State<PPOBProductScreen> createState() => _PPOBProductScreenState();
}

class _PPOBProductScreenState extends State<PPOBProductScreen> {
  static const String _verifiedWithoutNameToken = '__VERIFIED_WITHOUT_NAME__';
  static const Duration _brandsCacheTtl = Duration(minutes: 30);
  static const Duration _productsCacheTtl = Duration(minutes: 10);
  static const bool _enableCustomNumpad = false;

  late ColorNotifire notifire;
  final FlutterNativeContactPicker _contactPicker =
      FlutterNativeContactPicker();
  final TextEditingController _customerIdController = TextEditingController();
  final FocusNode _customerIdFocusNode = FocusNode();
  final _currencyFormat = NumberFormat('#,###', 'id_ID');

  List<dynamic> _brands = [];
  List<dynamic> _products = [];
  String? _selectedBrand;
  Map<String, dynamic>? _selectedProduct;
  Map<String, dynamic>? _inquiryResult;

  /// Stores the ref_id from Loket Bayar inquiry for use during purchase.
  String? _lastInquiryRefId;

  /// Stores the nominal (total) from Loket Bayar inquiry for payment.
  int? _lastInquiryNominal;

  /// Stores the kode_produk (inquiry_sku) from Loket Bayar inquiry for payment.
  String? _lastInquiryKodeProduk;
  Map<String, dynamic>? _plnPostpaidInquiryResult;

  bool _isLoadingBrands = true;
  bool _isLoadingProducts = false;
  bool _isInquiring = false;
  bool _isValidatingRecipient = false;
  bool _isAutoSwitchingBrand = false;
  bool _showCustomNumpad = false;
  int _pulsaTabIndex = 0;
  int _plnTabIndex = 0;
  String? _lastDetectedPrefix;
  bool _isPulsaPrefixDetected = false;
  bool _isBrandsCacheFresh = false;
  bool _isProductsCacheFresh = false;
  bool _isPlnPostpaidInquiring = false;
  bool _ewalletBrandPicked = false;
  String _lastPlnRawResponse = '';
  int? _lastPlnRawStatusCode;
  // Pesan error inline untuk panel cek tagihan (mengganti dialog/toast).
  String? _plnPostpaidError;

  // ── E-Wallet: Nominal custom (produk dinamis Loket Bayar) ──────────
  final TextEditingController _customAmountController = TextEditingController();
  bool _isCustomAmountMode = true; // true = user memilih input nominal custom

  bool get _isPln => widget.inquiryType == 'pln';
  // True khusus untuk halaman PLN Pasca (cmd=pasca atau kategori PLN Pasca).
  // Halaman Token PLN tetap memakai tampilan asli (Prabayar/Pascabayar tab).
  bool get _isPlnPostpaidOnly =>
      _isPln &&
      (widget.cmd.toLowerCase() == 'pasca' ||
          widget.category.toLowerCase().contains('pasca'));
  bool get _isEmoney => widget.inquiryType == 'emoney';
  bool get _isInject {
    final cat = widget.category.toLowerCase();
    final title = widget.title.toLowerCase();
    final filter = widget.productTypeFilter?.toLowerCase() ?? '';
    return cat.contains('inject') ||
        cat.contains('voucher') ||
        title.contains('inject') ||
        title.contains('voucher') ||
        filter.contains('inject') ||
        filter.contains('voucher');
  }
  // Mode TopUp Game: dipakai untuk override label input ("ID Player") dan
  // menyembunyikan tab brand (karena brand sudah dipilih dari list provider
  // di layar sebelumnya).
  bool get _isTopupGameFiltered {
    final cat = widget.category.trim().toLowerCase();
    return cat == 'topup game' || cat == 'top up game' || cat == 'topupgame';
  }
  bool get _isPulsaCategory =>
      widget.category.toString().toLowerCase().contains('pulsa');
  // Kategori berbasis nomor HP (Pulsa & Paket Data & Paket Telfon) yang otomatis filter
  // brand berdasarkan prefix MSISDN.
  bool get _isCellularCategory {
    final cat = widget.category.toString().toLowerCase();
    return cat.contains('pulsa') ||
        cat.contains('data') ||
        cat.contains('paket tel') ||
        cat.contains('sms') ||
        cat.contains('aktif');
  }
  // Kategori postpaid yang inquiry SKU-nya disimpan di ppob_categories
  // (dipakai panel cek-tagihan generic: BPJS, Indihome, PDAM, dll).
  static const List<String> _categoryInquiryKeywords = [
    'bpjs',
    'indihome',
    'pdam',
    'telkom',
    'gas negara',
    'pgn',
    'internet',
    // Internet ISP brands (hub Tagihan Internet)
    'biznet',
    'cbn',
    'first media',
    'firstmedia',
    'myrepublic',
    'xl home',
  ];
  bool get _isCategoryInquiry {
    if (_isInternetHub || _isMultifinanceHub) return false;
    if (widget.inquiryOnly) return true;
    final hay =
        '${widget.category.toLowerCase()} ${widget.title.toLowerCase()}';
    for (final kw in _categoryInquiryKeywords) {
      if (hay.contains(kw)) return true;
    }
    return false;
  }

  // Halaman hub "Tagihan Internet": menampilkan grid provider (Indihome, Biznet, …)
  // alih-alih input + Cek Tagihan, karena tiap provider beda inquiry_sku.
  bool get _isInternetHub {
    final hay =
        '${widget.category.toLowerCase()} ${widget.title.toLowerCase()}';
    return hay.contains('tagihan internet');
  }

  static const List<Map<String, String>> _internetProviders = [
    {'name': 'Indihome', 'logo': 'images/provider_logos/indihome.png'},
    {'name': 'Biznet', 'logo': 'images/provider_logos/biznet.png'},
    {'name': 'CBN', 'logo': 'images/provider_logos/cbn.png'},
    {'name': 'First Media', 'logo': 'images/provider_logos/first.png'},
    {'name': 'MyRepublic', 'logo': 'images/provider_logos/myrep.png'},
    {'name': 'XL Home', 'logo': 'images/provider_logos/xl.png'},
  ];

  // Hub Multifinance: list brand cicilan/kredit
  bool get _isMultifinanceHub {
    final hay =
        '${widget.category.toLowerCase()} ${widget.title.toLowerCase()}';
    // Hanya halaman induk "Multifinance" (bukan brand spesifik di bawahnya).
    final isExact = hay.trim() == 'multifinance multifinance' ||
        widget.category.toLowerCase() == 'multifinance' ||
        widget.title.toLowerCase() == 'multifinance';
    return isExact;
  }

  static const List<String> _multifinanceBrands = [
    'SMS FINANCE',
    'WOM Finance',
    'BCA Multifinance',
    'AEON CICILAN',
    'ANGSURAN ITC MULTI FINANCE',
    'ANGSURAN KREDIT PLUS (FINANSIA)',
    'ANGSURAN MANDALA FINANCE',
    'ANGSURAN MEGA FINANCE',
    'ARTHA PRIMA FINANCE',
    'BIMA FINANCE',
    'CAPELLA MULTIDANA',
    'Clipan Finance',
    'GE MASTER CARD CLASSIC Bank Permata',
    'HEKSA INSURANCE PREMI LANJUTAN',
    'Home Credit Indonesia',
    'INDOMOBIL FINANCE INDONESIA',
    'JACCS MPM FINANCE Indonesia',
    'MEGA AUTO CENTRAL FINANCE',
    'MNC Finance',
    'MULTINDO AUTO FINANCE',
    'Nissan Finance',
    'NSC FINANCE',
    'PRO CAR INTERNATIONAL FINANCE',
    'PRO MITRA FINANCE',
    'PT ARTHAASIA FINANCE',
    'PT AEON CREDIT SERVICE INDONESIA',
    'RADANA FINANCE / HD FINANCE',
    'SMART MULTI FINANCE',
    'ADIRA FINANCE',
    'FIF FINANCE',
    'BUSSAN AUTO FINANCE (BAF)',
    'MPM FINANCE',
    'MEGA AUTO FINANCE',
    'MEGA CENTRAL FINANCE',
  ];

  String _categoryInquiryHint() {
    final hay =
        '${widget.category.toLowerCase()} ${widget.title.toLowerCase()}';
    if (hay.contains('bpjs')) return 'Contoh : 0001xxxxxxxxx';
    if (hay.contains('indihome') || hay.contains('telkom')) {
      return 'Contoh : 12xxxxxxxxxx';
    }
    if (hay.contains('pdam')) return 'Contoh : 1234567';
    if (hay.contains('gas') || hay.contains('pgn')) {
      return 'Contoh : 1xxxxxxxxx';
    }
    if (hay.contains('internet')) return 'Contoh : 12xxxxxxxxxx';
    return 'Masukkan ID Pelanggan';
  }

  // ── State panel cek-tagihan generic ────────────────────────
  bool _isBpjsInquiring = false;
  Map<String, dynamic>? _bpjsInquiryResult;
  String? _bpjsInquiryError;

  // Pencarian di halaman hub (Multifinance/Internet)
  final TextEditingController _hubSearchCtrl = TextEditingController();
  String _hubSearchQuery = '';

  void _hideCustomNumpad() {
    if (!_showCustomNumpad) return;
    setState(() => _showCustomNumpad = false);
  }

  void _showCustomNumpadSafely() {
    if (!_enableCustomNumpad) return;
    if (_showCustomNumpad) return;
    setState(() => _showCustomNumpad = true);
  }

  void _dismissInputAndNumpad() {
    if (_customerIdFocusNode.hasFocus) {
      _customerIdFocusNode.unfocus();
    }
    _hideCustomNumpad();
  }

  @override
  void initState() {
    super.initState();
    _selectedBrand = widget.initialBrand;
    if (_isEmoney &&
        widget.initialBrand != null &&
        widget.initialBrand!.trim().isNotEmpty) {
      _selectedBrand = widget.initialBrand;
    }
    // Hanya screen "PLN Pasca" yang otomatis pasca (tanpa tab).
    // Token PLN (prabayar) tetap memakai tab default-nya.
    if (_isPln && _isPlnPostpaidOnly) {
      _plnTabIndex = 1;
    }
    _bootstrap();
    // Fetch daftar produk promo aktif untuk diberi badge & disortir paling atas.
    unawaited(_refreshPromoIndex());
  }

  @override
  void dispose() {
    _customerIdController.dispose();
    _customerIdFocusNode.dispose();
    _hubSearchCtrl.dispose();
    _customAmountController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      await _loadCachedData();
      if (!mounted) return;
      setState(() => _isLoadingBrands = _brands.isEmpty);

      // Saat halaman dibuka dengan initialBrand eksplisit (mis. user tap
      // operator HoK dari layar TopUp Game), paksa cache brand & produk
      // untuk dianggap stale supaya benar-benar refetch sesuai initialBrand.
      // Tanpa ini, cache lama dari brand lain (mis. FREE FIRE) bisa membuat
      // halaman tampil kosong / produk salah.
      final hasExplicitInitialBrand =
          widget.initialBrand != null && widget.initialBrand!.trim().isNotEmpty;
      if (hasExplicitInitialBrand) {
        _isBrandsCacheFresh = false;
        _isProductsCacheFresh = false;
      }

      if (!_isBrandsCacheFresh || _brands.isEmpty) {
        unawaited(_loadBrands());
      }
      if (_isPln || _selectedBrand != null) {
        // PLN prabayar: selalu refresh agar filter token_listrik baru
        // tidak terhalang cache lama yang sempat berisi list kosong.
        if (!_isProductsCacheFresh || (_isPln && _plnTabIndex == 0)) {
          unawaited(_loadProducts(showLoading: _products.isEmpty));
        }
      }
    } finally {
      // no-op: cache-first rendering happens above
    }
  }

  String get _brandsCacheKey =>
      'ppob_brands_v6_${widget.cmd}_${widget.category}';

  String _productsCacheKey(String? brand) {
    final brandKey = (brand ?? 'all').replaceAll(' ', '_');
    final suffix = (_isPln && _plnTabIndex == 0) ? '_tl' : '';
    return 'ppob_products_v6_${widget.cmd}_${widget.category}_$brandKey$suffix';
  }

  String get _selectedBrandCacheKey =>
      'ppob_selected_brand_${widget.cmd}_${widget.category}';

  String _cacheTsKey(String baseKey) => '${baseKey}_ts';

  bool _isCacheFresh(
    SharedPreferences prefs,
    String baseKey,
    Duration ttl,
  ) {
    final ts = prefs.getInt(_cacheTsKey(baseKey));
    if (ts == null) return false;
    final cachedAt = DateTime.fromMillisecondsSinceEpoch(ts);
    return DateTime.now().difference(cachedAt) <= ttl;
  }

  Future<void> _saveCache(
    SharedPreferences prefs,
    String baseKey,
    String payload,
  ) async {
    await prefs.setString(baseKey, payload);
    await prefs.setInt(
      _cacheTsKey(baseKey),
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<void> _loadCachedData() async {
    final prefs = await SharedPreferences.getInstance();

    final cachedBrandsJson = prefs.getString(_brandsCacheKey);
    _isBrandsCacheFresh =
        _isCacheFresh(prefs, _brandsCacheKey, _brandsCacheTtl);
    if (cachedBrandsJson != null) {
      try {
        final cachedBrands =
            List<dynamic>.from(jsonDecode(cachedBrandsJson) as List);
        if (mounted && cachedBrands.isNotEmpty) {
          var orderedCachedBrands = _reorderTelkomselFirst(cachedBrands);
          if (_isInject) {
            const cellBrands = {
              'telkomsel', 'indosat', 'indosat ooredoo', 'indosat ooredoo hutchison',
              'xl', 'xl axiata', 'axis', 'three', 'tri', 'tri indonesia',
              'smartfren', 'smart', 'byu', 'by.u'
            };
            orderedCachedBrands = orderedCachedBrands.where((b) {
              final name = b.toString().toLowerCase().trim();
              return cellBrands.any((c) => name == c || name.contains(c) || c.contains(name));
            }).toList();
          }
          final brandStrings =
              orderedCachedBrands.map((b) => b.toString()).toList();
          final cachedBrand = prefs.getString(_selectedBrandCacheKey);
          final validCachedBrand =
              (cachedBrand != null && brandStrings.contains(cachedBrand))
                  ? cachedBrand
                  : null;
          // Hormati initialBrand (mis. user pilih HoK dari TopUp Game list)
          // di atas cached brand. Kalau tidak, cache brand yang dipilih
          // sebelumnya pada kategori yang sama (mis. FREE FIRE) bisa
          // override pilihan user yang baru.
          final initialBrandTrim = widget.initialBrand?.trim();
          String? matchedInitial;
          if (initialBrandTrim != null && initialBrandTrim.isNotEmpty) {
            final m = brandStrings.firstWhere(
              (b) => b.toLowerCase() == initialBrandTrim.toLowerCase(),
              orElse: () => '',
            );
            if (m.isNotEmpty) matchedInitial = m;
          }
          setState(() {
            _brands = orderedCachedBrands;
            // Saat initialBrand diberikan, abaikan total validCachedBrand
            // untuk mencegah cache lama (mis. 'TOPUP GAME') meracuni
            // pilihan brand baru dari user.
            if (initialBrandTrim != null && initialBrandTrim.isNotEmpty) {
              _selectedBrand = matchedInitial ??
                  widget.initialBrand ??
                  orderedCachedBrands.first.toString();
            } else {
              _selectedBrand = validCachedBrand ??
                  orderedCachedBrands.first.toString();
            }
            _isLoadingBrands = false;
          });
        }
      } catch (_) {}
    }

    final targetBrand = _selectedBrand ?? widget.initialBrand;
    _isProductsCacheFresh = _isCacheFresh(
      prefs,
      _productsCacheKey(targetBrand),
      _productsCacheTtl,
    );
    final cachedProductsJson = prefs.getString(_productsCacheKey(targetBrand));
    if (cachedProductsJson != null) {
      try {
        var cachedProducts =
            List<dynamic>.from(jsonDecode(cachedProductsJson) as List);
        if (_isEmoney) {
          cachedProducts = _sanitizeEmoneyProducts(cachedProducts);
        }
        cachedProducts = _prepareProductsForDisplay(cachedProducts);
        if (mounted && cachedProducts.isNotEmpty) {
          setState(() {
            _products = cachedProducts;
            _isLoadingProducts = false;
          });
        }
      } catch (_) {}
    }
  }

  Future<void> _loadBrands() async {
    try {
      final brands = await ApiService.getPpobBrands(
        cmd: widget.cmd,
        category: widget.category,
        productTypeFilter: widget.productTypeFilter,
      );
      if (!mounted) return;

      var orderedBrands = _reorderTelkomselFirst(brands);
      if (_isInject) {
        const cellBrands = {
          'telkomsel', 'indosat', 'indosat ooredoo', 'indosat ooredoo hutchison',
          'xl', 'xl axiata', 'axis', 'three', 'tri', 'tri indonesia',
          'smartfren', 'smart', 'byu', 'by.u'
        };
        orderedBrands = orderedBrands.where((b) {
          final name = b.toString().toLowerCase().trim();
          return cellBrands.any((c) => name == c || name.contains(c) || c.contains(name));
        }).toList();
      }

      setState(() {
        _brands = orderedBrands;
        final brandStrings = orderedBrands.map((b) => b.toString()).toList();
        final initialBrand = widget.initialBrand?.trim();
        // Hormati initialBrand kalau ada di list (mis. dari promo card,
        // brand-selection screen, atau e-money). Case-insensitive match.
        if (initialBrand != null && initialBrand.isNotEmpty) {
          final match = brandStrings.firstWhere(
            (b) => b.toLowerCase() == initialBrand.toLowerCase(),
            orElse: () => '',
          );
          if (match.isNotEmpty) {
            _selectedBrand = match;
          } else if (_isEmoney) {
            // E-money tetap pakai initialBrand walau tidak ada di list.
            _selectedBrand = initialBrand;
          } else if (brandStrings.isNotEmpty &&
              (_selectedBrand == null ||
                  !brandStrings.contains(_selectedBrand))) {
            _selectedBrand = brandStrings.first;
          }
        } else if (brandStrings.isNotEmpty) {
          if (_selectedBrand == null || !brandStrings.contains(_selectedBrand)) {
            _selectedBrand = brandStrings.first;
          }
        }
        _isLoadingBrands = false;
      });

      final prefs = await SharedPreferences.getInstance();
      await _saveCache(prefs, _brandsCacheKey, jsonEncode(orderedBrands));
      if (_selectedBrand != null) {
        await prefs.setString(_selectedBrandCacheKey, _selectedBrand!);
      }

      if ((!_isPln && _selectedBrand != null) &&
          !_isLoadingProducts &&
          _products.isEmpty) {
        await _loadProducts(showLoading: true);
      }
      if (_isCellularCategory && _customerIdController.text.isNotEmpty && !_isInject) {
        unawaited(_handlePulsaPrefixAutoSwitch(_customerIdController.text));
      }
    } catch (_) {
      if (mounted) {
        Fluttertoast.showToast(msg: 'Gagal memuat brand');
        setState(() => _isLoadingBrands = false);
      }
    }
  }

  List<dynamic> _reorderTelkomselFirst(List<dynamic> brands) {
    if (brands.isEmpty) return brands;
    final telkomsel = <dynamic>[];
    final others = <dynamic>[];
    for (final b in brands) {
      final name = b.toString().toLowerCase();
      if (name.contains('telkomsel')) {
        telkomsel.add(b);
      } else {
        others.add(b);
      }
    }
    return [...telkomsel, ...others];
  }

  String _normalizeBrandToken(String value) {
    return value.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  }

  bool _emoneyProductMatchesSelectedBrand(Map<String, dynamic> product) {
    if (!_isEmoney) return true;

    final selected =
        (_selectedBrand ?? widget.initialBrand ?? widget.title).toString();
    final selectedNorm = _normalizeBrandToken(selected);
    if (selectedNorm.isEmpty) return true;

    final haystack = [
      product['brand'],
      product['operator'],
      product['provider'],
      product['product_name'],
      product['category'],
    ].map((e) => _normalizeBrandToken((e ?? '').toString())).join(' ');

    if (haystack.contains(selectedNorm)) return true;
    if (selectedNorm == 'GOPAY' &&
        (haystack.contains('GOJEK') || haystack.contains('GOPAY'))) {
      return true;
    }
    if (selectedNorm == 'SHOPEEPAY' &&
        (haystack.contains('SHOPEE') || haystack.contains('SHOPEEPAY'))) {
      return true;
    }
    if (selectedNorm == 'DANA' && haystack.contains('DANA')) {
      return true;
    }
    if (selectedNorm == 'OVO' && haystack.contains('OVO')) {
      return true;
    }
    if (selectedNorm == 'LINKAJA' &&
        (haystack.contains('LINKAJA') || haystack.contains('LINK'))) {
      return true;
    }

    return false;
  }

  List<dynamic> _sanitizeEmoneyProducts(List<dynamic> source) {
    final result = <dynamic>[];

    for (final item in source) {
      final p = Map<String, dynamic>.from(item);
      if (!_emoneyProductMatchesSelectedBrand(p)) continue;

      final name = (p['product_name'] ?? '').toString().toLowerCase();
      final isCheckName =
          name.contains('cek nama') || name.contains('nama pengguna');
      if (isCheckName) continue;

      result.add(p);
    }

    return result;
  }

  Future<void> _loadProducts({bool showLoading = true}) async {
    if (!_isPln && _selectedBrand == null) {
      setState(() => _isLoadingProducts = false);
      return;
    }
    if (showLoading) {
      setState(() => _isLoadingProducts = true);
    }
    try {
      final isPlnPrabayar = _isPln && _plnTabIndex == 0;
      // Untuk E-Wallet (baik generic maupun dengan initialBrand): JANGAN
      // kirim filter brand ke backend, karena backend/Digiflazz tidak selalu
      // memetakan brand dengan presisi (mis. "DANA" vs "Dana" vs kosong).
      // Fetch SEMUA produk pada category yang sama dan filter per-provider
      // dilakukan client-side di `_sanitizeEmoneyProducts`.
      var products = await ApiService.getPpobProducts(
        cmd: widget.cmd,
        category: isPlnPrabayar ? null : widget.category,
        brand: (_isPln || _isEmoney) ? null : _selectedBrand,
        productTypeFilter: widget.productTypeFilter,
        tokenListrik: isPlnPrabayar,
      );
      debugPrint(
          '[PPOB] fetched ${products.length} products (isEmoney=$_isEmoney, selectedBrand=$_selectedBrand, category=${widget.category}, cmd=${widget.cmd})');
      if (products.isNotEmpty) {
        final sample = Map<String, dynamic>.from(products.first);
        debugPrint(
            '[PPOB] sample product keys=${sample.keys.toList()} brand=${sample['brand']} operator=${sample['operator']} provider=${sample['provider']} category=${sample['category']} name=${sample['product_name']}');
      }
      // DEBUG: cek keberadaan SKU tertentu (misal TSEL10B) di payload backend.
      final debugSkus = ['TSEL10B', 'TSEL10', 'DNA1', 'dna1'];
      for (final item in products) {
        final p = Map<String, dynamic>.from(item);
        final sku = (p['buyer_sku_code'] ?? p['sku'] ?? p['code'] ?? '').toString();
        if (debugSkus.any((s) => sku.toLowerCase() == s.toLowerCase())) {
          debugPrint(
              '[PPOB][DEBUG] FOUND sku=$sku name=${p['product_name']} brand=${p['brand']} category=${p['category']} desc=${p['desc'] ?? p['description']}');
        }
      }

      if (_isEmoney) {
        final beforeFilter = products.length;
        products = _sanitizeEmoneyProducts(products);
        debugPrint(
            '[PPOB] after sanitizeEmoney: ${products.length} (was $beforeFilter, selectedBrand=$_selectedBrand)');
      }

      final prefs = await SharedPreferences.getInstance();
      await _saveCache(
        prefs,
        _productsCacheKey(_isPln ? null : _selectedBrand),
        jsonEncode(products),
      );

      products = _prepareProductsForDisplay(products);

      if (!mounted) return;
      setState(() => _products = products);
    } catch (_) {
      if (mounted) {
        Fluttertoast.showToast(msg: 'Gagal memuat produk');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingProducts = false);
      }
    }
  }

  bool _isPulsaTransferProduct(Map<String, dynamic> product) {
    final text = [
      product['product_name'],
      product['brand'],
      product['desc'],
      product['description'],
    ].map((e) => (e ?? '').toString().toLowerCase()).join(' ');

    return text.contains('transfer');
  }

  List<dynamic> _filterPulsaProducts(List<dynamic> source) {
    if (!_isPulsaCategory) return source;

    final isTransferTab = _pulsaTabIndex == 1;
    return source.where((item) {
      final product = Map<String, dynamic>.from(item);
      final isTransferProduct = _isPulsaTransferProduct(product);
      return isTransferTab ? isTransferProduct : !isTransferProduct;
    }).toList();
  }

  Map<String, Map<String, dynamic>> _promoIndex = {};

  String _skuKey(Map<String, dynamic> p) {
    final raw = (p['buyer_sku_code'] ??
            p['sku'] ??
            p['code'] ??
            p['product_code'] ??
            '')
        .toString()
        .trim()
        .toUpperCase();
    return raw;
  }

  Future<void> _refreshPromoIndex() async {
    try {
      final promos = await ApiService.getPromoProducts();
      final map = <String, Map<String, dynamic>>{};
      for (final item in promos) {
        if (item is! Map) continue;
        final p = Map<String, dynamic>.from(item);
        final key = _skuKey(p);
        if (key.isEmpty) continue;
        map[key] = p;
      }
      if (!mounted) return;
      _promoIndex = map;
      if (_products.isNotEmpty) {
        setState(() {
          _products = _prepareProductsForDisplay(
            _products.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
          );
        });
      }
    } catch (_) {}
  }

  List<dynamic> _enrichWithPromo(List<dynamic> source) {
    if (_promoIndex.isEmpty) return source;
    return source.map((item) {
      final p = Map<String, dynamic>.from(item as Map);
      final key = _skuKey(p);
      if (key.isEmpty) return p;
      final promo = _promoIndex[key];
      if (promo == null) return p;
      // Promo endpoint: `price` = promo price, `original_price` = harga normal,
      // `promo_end` = waktu berakhir, juga ada flag `is_promo`.
      final promoPrice = promo['promo_price'] ?? promo['price'];
      final originalPrice = promo['original_price'] ?? p['price'];
      p['is_promo'] = true;
      if (promoPrice != null) p['promo_price'] = promoPrice;
      if (originalPrice != null) p['original_price'] = originalPrice;
      if (promo['promo_end'] != null) p['promo_end'] = promo['promo_end'];
      if (promo['promo_end_at'] != null) {
        p['promo_end_at'] = promo['promo_end_at'];
      }
      return p;
    }).toList();
  }

  List<dynamic> _sortProductsByPromoFirst(List<dynamic> source) {
    final sorted = List<dynamic>.from(source);
    sorted.sort((a, b) {
      final pa = Map<String, dynamic>.from(a);
      final pb = Map<String, dynamic>.from(b);
      final aPromo = _isPromoProduct(pa);
      final bPromo = _isPromoProduct(pb);
      if (aPromo != bPromo) {
        return aPromo ? -1 : 1;
      }
      final aPrice = _promoPrice(pa);
      final bPrice = _promoPrice(pb);
      return aPrice.compareTo(bPrice);
    });
    return sorted;
  }

  List<dynamic> _prepareProductsForDisplay(List<dynamic> source) {
    var prepared = _enrichWithPromo(source);
    if (_isPulsaCategory) {
      prepared = _filterPulsaProducts(prepared);
    }
    return _sortProductsByPromoFirst(prepared);
  }

  Future<void> _selectBrand(String brand) async {
    if (_selectedBrand == brand) return;
    setState(() {
      _selectedBrand = brand;
      _products = [];
      _selectedProduct = null;
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedBrandCacheKey, brand);

    final cachedProductsJson = prefs.getString(_productsCacheKey(brand));
    final isProductsCacheFresh = _isCacheFresh(
      prefs,
      _productsCacheKey(brand),
      _productsCacheTtl,
    );
    if (cachedProductsJson != null) {
      try {
        final cachedProducts =
            List<dynamic>.from(jsonDecode(cachedProductsJson) as List);
        if (mounted && cachedProducts.isNotEmpty) {
          setState(
              () => _products = _prepareProductsForDisplay(cachedProducts));
        }
      } catch (_) {}
    }

    if (isProductsCacheFresh) {
      return;
    }

    await _loadProducts(showLoading: _products.isEmpty);
  }

  String? _brandByPulsaPrefix(String msisdn) {
    if (msisdn.length < 4) return null;
    final prefix4 = msisdn.substring(0, 4);

    const prefixToBrand = <String, String>{
      // Telkomsel
      '0811': 'TELKOMSEL',
      '0812': 'TELKOMSEL',
      '0813': 'TELKOMSEL',
      '0821': 'TELKOMSEL',
      '0822': 'TELKOMSEL',
      '0823': 'TELKOMSEL',
      '0851': 'TELKOMSEL',
      '0852': 'TELKOMSEL',
      '0853': 'TELKOMSEL',

      // Tri
      '0895': 'TRI',
      '0896': 'TRI',
      '0897': 'TRI',
      '0898': 'TRI',
      '0899': 'TRI',

      // XL
      '0817': 'XL',
      '0818': 'XL',
      '0819': 'XL',
      '0859': 'XL',
      '0877': 'XL',
      '0878': 'XL',

      // Indosat Ooredoo Hutchison
      '0814': 'INDOSAT',
      '0815': 'INDOSAT',
      '0816': 'INDOSAT',
      '0855': 'INDOSAT',
      '0856': 'INDOSAT',
      '0857': 'INDOSAT',
      '0858': 'INDOSAT',

      // AXIS
      '0831': 'AXIS',
      '0832': 'AXIS',
      '0833': 'AXIS',
      '0838': 'AXIS',

      // Smartfren
      '0881': 'SMARTFREN',
      '0882': 'SMARTFREN',
      '0883': 'SMARTFREN',
      '0884': 'SMARTFREN',
      '0885': 'SMARTFREN',
      '0886': 'SMARTFREN',
      '0887': 'SMARTFREN',
      '0888': 'SMARTFREN',
      '0889': 'SMARTFREN',
    };

    return prefixToBrand[prefix4];
  }

  String? _resolveBrandNameFromKeyword(String keyword) {
    final upperKeyword = keyword.toUpperCase();
    for (final b in _brands) {
      final brand = b.toString();
      final upperBrand = brand.toUpperCase();
      if (upperBrand.contains(upperKeyword)) {
        return brand;
      }
    }
    for (final b in _brands) {
      final brand = b.toString();
      final upperBrand = brand.toUpperCase();
      if (upperKeyword == 'TRI' &&
          (upperBrand.contains('THREE') || upperBrand == '3')) {
        return brand;
      }
      if (upperKeyword == 'AXIS' &&
          (upperBrand.contains('XL') || upperBrand == 'XL AXIATA')) {
        return brand;
      }
    }
    return null;
  }

  Future<void> _handlePulsaPrefixAutoSwitch(String input) async {
    if (!_isCellularCategory) return;
    if (_isAutoSwitchingBrand) return;

    var digits = input.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('62') && digits.length >= 4) {
      digits = '0${digits.substring(2)}';
    } else if (digits.startsWith('8') && digits.length >= 4) {
      digits = '0$digits';
    }

    if (digits.length < 4) {
      if (mounted && _isPulsaPrefixDetected) {
        setState(() => _isPulsaPrefixDetected = false);
      }
      _lastDetectedPrefix = null;
      return;
    }

    final detectedKeyword = _brandByPulsaPrefix(digits);

    // Mark prefix as detected for any 4+ digit recognized Indonesian prefix.
    // Detection state must be set BEFORE the brands-empty check so that products
    // appear once brands finish loading (re-trigger from _loadBrands handles that).
    if (detectedKeyword != null) {
      if (!_isPulsaPrefixDetected && mounted) {
        setState(() => _isPulsaPrefixDetected = true);
      }
    } else {
      if (mounted && _isPulsaPrefixDetected) {
        setState(() => _isPulsaPrefixDetected = false);
      }
      _lastDetectedPrefix = null;
      return;
    }

    if (_brands.isEmpty) return;
    if (_lastDetectedPrefix == detectedKeyword) return;

    final targetBrand = _resolveBrandNameFromKeyword(detectedKeyword);
    if (targetBrand == null || _selectedBrand == targetBrand) {
      _lastDetectedPrefix = detectedKeyword;
      return;
    }

    _lastDetectedPrefix = detectedKeyword;
    _isAutoSwitchingBrand = true;
    try {
      await _selectBrand(targetBrand);
    } finally {
      _isAutoSwitchingBrand = false;
    }
  }

  String _normalizeMsisdn(String raw) {
    var digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('62')) {
      digits = '0${digits.substring(2)}';
    } else if (digits.startsWith('8')) {
      digits = '0$digits';
    }
    return digits;
  }

  String _pulsaProviderLogoAsset(Map<String, dynamic> product) {
    final rawBrand =
        (product['brand'] ?? product['operator'] ?? _selectedBrand ?? '')
            .toString()
            .toLowerCase()
            .trim();

    if (rawBrand.contains('telkomsel'))
      return 'images/provider_logos/telkomsel.png';
    if (rawBrand.contains('smartfren'))
      return 'images/provider_logos/smartfren.png';
    if (rawBrand.contains('axis')) return 'images/provider_logos/axis.png';
    if (rawBrand.contains('tri') || rawBrand.contains('3'))
      return 'images/provider_logos/tri.png';
    if (rawBrand.contains('im3')) return 'images/provider_logos/im3.png';
    if (rawBrand.contains('indosat') ||
        rawBrand.contains('isat') ||
        rawBrand.contains('mentari')) {
      return 'images/provider_logos/indosat.png';
    }
    if (rawBrand.contains('xl') || rawBrand.contains('xl axiata'))
      return 'images/provider_logos/xl.png';

    return '';
  }

  void _onCustomerInputChanged() {
    if (!mounted) return;

    setState(() {
      if (_isPln) {
        _inquiryResult = null;
      }
    });

    if (_isInject) return;

    if (_isCellularCategory && (_isPulsaCategory ? _pulsaTabIndex == 0 : true)) {
      unawaited(_handlePulsaPrefixAutoSwitch(_customerIdController.text));
    }
  }

  void _setCustomerId(String value) {
    final digitsOnly = value.replaceAll(RegExp(r'[^0-9]'), '');
    _customerIdController.text = digitsOnly;
    _customerIdController.selection = TextSelection.fromPosition(
      TextPosition(offset: digitsOnly.length),
    );
    _onCustomerInputChanged();
  }

  void _appendDigit(String digit) {
    final current = _customerIdController.text;
    if (current.length >= 15) return;
    _setCustomerId('$current$digit');
  }

  void _deleteDigit() {
    final current = _customerIdController.text;
    if (current.isEmpty) return;
    _setCustomerId(current.substring(0, current.length - 1));
  }

  Future<void> _triggerNumpadHaptic() async {
    try {
      await HapticFeedback.selectionClick();
    } catch (_) {
      // Ignore if haptics are unavailable on the current device.
    }
  }

  Widget _buildNumpadButton({
    required VoidCallback onTap,
    String? label,
    IconData? icon,
    required Color accent,
    required Color textPrimary,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          unawaited(_triggerNumpadHaptic());
          onTap();
        },
        child: Ink(
          decoration: BoxDecoration(
            color: const Color(0xFFF6F9FF),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFEAF1FF)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: icon != null
                ? Icon(icon, color: accent, size: 22)
                : Text(
                    label ?? '',
                    style: TextStyle(
                      color: textPrimary,
                      fontFamily: 'Gilroy Bold',
                      fontSize: 24,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomNumpad(
      Color accent, Color textPrimary, Color textSecondary) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(
                  'Numpad',
                  style: TextStyle(
                    color: textSecondary,
                    fontFamily: 'Gilroy Bold',
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => setState(() => _showCustomNumpad = false),
                  icon: Icon(Icons.keyboard_hide_rounded, color: accent),
                  splashRadius: 20,
                ),
              ],
            ),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.9,
              children: [
                _buildNumpadButton(
                    onTap: () => _appendDigit('1'),
                    label: '1',
                    accent: accent,
                    textPrimary: textPrimary),
                _buildNumpadButton(
                    onTap: () => _appendDigit('2'),
                    label: '2',
                    accent: accent,
                    textPrimary: textPrimary),
                _buildNumpadButton(
                    onTap: () => _appendDigit('3'),
                    label: '3',
                    accent: accent,
                    textPrimary: textPrimary),
                _buildNumpadButton(
                    onTap: () => _appendDigit('4'),
                    label: '4',
                    accent: accent,
                    textPrimary: textPrimary),
                _buildNumpadButton(
                    onTap: () => _appendDigit('5'),
                    label: '5',
                    accent: accent,
                    textPrimary: textPrimary),
                _buildNumpadButton(
                    onTap: () => _appendDigit('6'),
                    label: '6',
                    accent: accent,
                    textPrimary: textPrimary),
                _buildNumpadButton(
                    onTap: () => _appendDigit('7'),
                    label: '7',
                    accent: accent,
                    textPrimary: textPrimary),
                _buildNumpadButton(
                    onTap: () => _appendDigit('8'),
                    label: '8',
                    accent: accent,
                    textPrimary: textPrimary),
                _buildNumpadButton(
                    onTap: () => _appendDigit('9'),
                    label: '9',
                    accent: accent,
                    textPrimary: textPrimary),
                _buildNumpadButton(
                    onTap: () => _setCustomerId(''),
                    icon: Icons.close_rounded,
                    accent: accent,
                    textPrimary: textPrimary),
                _buildNumpadButton(
                    onTap: () => _appendDigit('0'),
                    label: '0',
                    accent: accent,
                    textPrimary: textPrimary),
                _buildNumpadButton(
                    onTap: _deleteDigit,
                    icon: Icons.backspace_outlined,
                    accent: accent,
                    textPrimary: textPrimary),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickNumberFromContact() async {
    try {
      final contact = await _contactPicker.selectPhoneNumber();
      final selected = contact?.selectedPhoneNumber?.trim() ?? '';
      final fromList =
          (contact?.phoneNumbers != null && contact!.phoneNumbers!.isNotEmpty)
              ? contact.phoneNumbers!.first.trim()
              : '';
      final raw = selected.isNotEmpty ? selected : fromList;
      if (raw.isEmpty) {
        Fluttertoast.showToast(msg: 'Kontak tidak memiliki nomor telepon');
        return;
      }

      final normalized = _normalizeMsisdn(raw);
      if (normalized.isEmpty) {
        Fluttertoast.showToast(msg: 'Nomor dari kontak tidak valid');
        return;
      }

      if (!mounted) return;
      _setCustomerId(normalized);
    } catch (_) {
      Fluttertoast.showToast(msg: 'Gagal mengambil kontak');
    }
  }

  Widget _buildShimmerProducts() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 6,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          mainAxisExtent: 148,
        ),
        itemBuilder: (_, __) => Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                  height: 14, width: double.infinity, color: Colors.white),
              const SizedBox(height: 6),
              Container(
                  height: 11, width: double.infinity, color: Colors.white),
              const SizedBox(height: 4),
              Container(height: 11, width: 92, color: Colors.white),
              const Spacer(),
              Container(height: 24, width: 92, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Input field placeholder
            Container(
              height: 60,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            const SizedBox(height: 12),
            // Info text placeholder
            Container(
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 16),
            // Brand tabs placeholder
            Row(
              children: List.generate(
                  4,
                  (_) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Container(
                          height: 32,
                          width: 80,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      )),
            ),
            const SizedBox(height: 16),
            // Product list placeholder (4 items)
            ...List.generate(
                4,
                (_) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Container(
                              height: 38,
                              width: 38,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                      height: 14,
                                      width: 160,
                                      color: Colors.white),
                                  const SizedBox(height: 6),
                                  Container(
                                      height: 12,
                                      width: 80,
                                      color: Colors.white),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right,
                                color: Colors.white),
                          ],
                        ),
                      ),
                    )),
          ],
        ),
      ),
    );
  }

  String _formatPrice(dynamic price) {
    double p = 0;
    if (price is int) {
      p = price.toDouble();
    } else if (price is double) {
      p = price;
    } else if (price is String) {
      p = double.tryParse(price) ?? 0;
    }
    return 'Rp ${_currencyFormat.format(p.toInt())}';
  }

  double _asDouble(dynamic value) {
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value == null) return 0;
    return double.tryParse(value.toString().replaceAll(',', '').trim()) ?? 0;
  }

  double _promoPrice(Map<String, dynamic> product) {
    final candidates = [
      product['promo_price'],
      product['price_promo'],
      product['promoPrice'],
      product['discount_price'],
      product['price'],
    ];
    for (final c in candidates) {
      final val = _asDouble(c);
      if (val > 0) return val;
    }
    return _asDouble(product['price']);
  }

  double _originalPrice(Map<String, dynamic> product) {
    final candidates = [
      product['original_price'],
      product['price_before_discount'],
      product['normal_price'],
      product['base_price'],
      product['price'],
    ];
    for (final c in candidates) {
      final val = _asDouble(c);
      if (val > 0) return val;
    }
    return _asDouble(product['price']);
  }

  bool _isPromoProduct(Map<String, dynamic> product) {
    final promoFlag = product['is_promo'] == true;
    final promo = _promoPrice(product);
    final original = _originalPrice(product);
    return promoFlag || (promo > 0 && original > promo);
  }

  DateTime? _promoEndDate(Map<String, dynamic> product) {
    final candidates = [
      product['promo_end'],
      product['promo_end_at'],
      product['promo_until'],
      product['promo_expired_at'],
      product['expired_at'],
    ];
    for (final c in candidates) {
      if (c == null) continue;
      final raw = c.toString().trim();
      if (raw.isEmpty) continue;
      final dt = DateTime.tryParse(raw);
      if (dt != null) return dt.toLocal();
    }
    return null;
  }

  String _promoRemainingLabel(Map<String, dynamic> product) {
    final endAt = _promoEndDate(product);
    if (endAt == null) return 'Promo aktif';
    final now = DateTime.now();
    final diff = endAt.difference(now);
    if (diff.inSeconds <= 0) return 'Promo berakhir';
    if (diff.inDays >= 1) {
      final hours = diff.inHours % 24;
      return 'Sisa ${diff.inDays}h ${hours}j';
    }
    if (diff.inHours >= 1) {
      final minutes = diff.inMinutes % 60;
      return 'Sisa ${diff.inHours}j ${minutes}m';
    }
    return 'Sisa ${diff.inMinutes}m';
  }

  String _productDescription(Map<String, dynamic> product) {
    final candidates = [
      product['desc'],
      product['description'],
      product['product_description'],
      product['product_desc'],
      product['note'],
      product['details'],
    ];
    for (final c in candidates) {
      final text = c?.toString().trim();
      if (text != null && text.isNotEmpty && text != '-') {
        return text;
      }
    }
    return '';
  }

  int? _extractRewardCoins(Map<String, dynamic> product) {
    final candidates = [
      product['coin'],
      product['coins'],
      product['coin_amount'],
      product['coins_amount'],
      product['coin_value'],
      product['coins_value'],
      product['koin'],
      product['jumlah_koin'],
      product['koin_didapat'],
      product['reward_coin'],
      product['reward_coins'],
      product['reward_coin_amount'],
      product['reward_coins_amount'],
      product['coin_reward'],
      product['coin_earned'],
      product['coins_earned'],
      product['earned_coin'],
      product['earned_coins'],
      product['bonus_coin'],
      product['bonus_coins'],
      product['cashback_coin'],
      product['cashback_coins'],
      product['point'],
      product['points'],
      product['poin'],
    ];

    int? parseCoinValue(dynamic value) {
      if (value == null) return null;
      if (value is int && value > 0) return value;
      if (value is num && value > 0) return value.round();

      final text = value.toString().trim();
      if (text.isEmpty) return null;

      final direct = int.tryParse(text);
      if (direct != null && direct > 0) return direct;

      final digitOnly = text.replaceAll(RegExp(r'[^0-9]'), '');
      final extracted = int.tryParse(digitOnly);
      if (extracted != null && extracted > 0) return extracted;

      return null;
    }

    bool isCoinLikeKey(String key) {
      final k = key.toLowerCase();
      return k.contains('coin') ||
          k.contains('koin') ||
          k.contains('point') ||
          k.contains('poin');
    }

    int? scanCoinLikeValues(dynamic source) {
      if (source == null) return null;

      if (source is Map) {
        for (final entry in source.entries) {
          final key = entry.key.toString();
          final value = entry.value;

          if (isCoinLikeKey(key)) {
            final parsed = parseCoinValue(value);
            if (parsed != null) return parsed;
          }

          final nested = scanCoinLikeValues(value);
          if (nested != null) return nested;
        }
        return null;
      }

      if (source is Iterable) {
        for (final item in source) {
          final nested = scanCoinLikeValues(item);
          if (nested != null) return nested;
        }
      }

      return null;
    }

    for (final value in candidates) {
      final parsed = parseCoinValue(value);
      if (parsed != null) return parsed;
    }

    final rewardObj = product['reward'];
    if (rewardObj is Map) {
      final reward = Map<String, dynamic>.from(rewardObj);
      final nestedCandidates = [
        reward['coin'],
        reward['coins'],
        reward['amount'],
        reward['value'],
      ];
      for (final value in nestedCandidates) {
        final parsed = parseCoinValue(value);
        if (parsed != null) return parsed;
      }
    }

    final dynamicParsed = scanCoinLikeValues(product);
    if (dynamicParsed != null) return dynamicParsed;

    final textSources = [
      _productDescription(product),
      (product['product_name'] ?? '').toString(),
      (product['note'] ?? '').toString(),
    ];
    final rewardPattern =
        RegExp(r'(\d+)\s*(coin|koin|poin|points?)', caseSensitive: false);
    for (final text in textSources) {
      final match = rewardPattern.firstMatch(text);
      if (match != null) {
        final parsed = int.tryParse(match.group(1) ?? '');
        if (parsed != null && parsed > 0) return parsed;
      }
    }

    return null;
  }

  Future<void> _doPlnInquiry() async {
    final customerId = _customerIdController.text.trim();
    if (customerId.isEmpty) {
      Fluttertoast.showToast(msg: 'Masukkan ID pelanggan / No meter');
      return;
    }

    setState(() {
      _isInquiring = true;
      _inquiryResult = null;
    });

    try {
      final result = await ApiService.ppobInquiryPln(customerNo: customerId);
      if (!mounted) return;

      final status = (result['status'] ?? '').toString().toLowerCase();
      final message = (result['message'] ?? '').toString().toLowerCase();
      final isSuccess = status == 'success' ||
          status == 'sukses' ||
          message.contains('sukses');

      if (isSuccess && result['data'] != null) {
        setState(() {
          _inquiryResult = Map<String, dynamic>.from(result['data']);
        });
        await _loadBrands();
        await _loadProducts();
      } else {
        Fluttertoast.showToast(msg: result['message'] ?? 'Cek pelanggan gagal');
      }
    } catch (_) {
      if (mounted) {
        Fluttertoast.showToast(msg: 'Kesalahan koneksi');
      }
    } finally {
      if (mounted) {
        setState(() => _isInquiring = false);
      }
    }
  }

  Future<void> _doPlnPostpaidInquiry() async {
    final customerId = _customerIdController.text.trim();
    if (customerId.isEmpty) {
      Fluttertoast.showToast(msg: 'Masukkan nomor pelanggan');
      return;
    }

    setState(() {
      _isPlnPostpaidInquiring = true;
      _plnPostpaidInquiryResult = null;
      _plnPostpaidError = null;
      _lastPlnRawResponse = '';
      _lastPlnRawStatusCode = null;
    });

    try {
      final candidateSkus = <String>{};
      final prioritizedSkus = <String>{};

      bool isLikelyPrepaidSku(String sku) {
        final s = sku.toLowerCase();
        return s.startsWith('token') ||
            s.contains('prepaid') ||
            s.contains('prabayar');
      }

      bool isStrictPlnPostpaidProduct(Map<String, dynamic> p) {
        final sku = (p['buyer_sku_code'] ?? '').toString().trim();
        if (sku.isEmpty || isLikelyPrepaidSku(sku)) return false;

        final brandText = (p['brand'] ?? '').toString().toLowerCase();
        final categoryText = (p['category'] ?? '').toString().toLowerCase();
        final nameText = (p['product_name'] ?? '').toString().toLowerCase();
        final operatorText = (p['operator'] ?? '').toString().toLowerCase();
        final label = '$brandText $categoryText $nameText $operatorText $sku'
            .toLowerCase();

        final hasPln = label.contains('pln') || label.contains('listrik');
        final hasPostpaid =
            label.contains('pasca') || label.contains('postpaid');
        return hasPln && hasPostpaid;
      }

      Future<void> collectSkus({String? brand, String? category}) async {
        final products = await ApiService.getPpobProducts(
          cmd: 'pasca',
          brand: brand,
          category: category,
        );

        for (final item in products) {
          if (item is! Map) continue;
          final p = Map<String, dynamic>.from(item);
          final buyerStatus = p['buyer_product_status'];
          final sellerStatus = p['seller_product_status'];
          final isBuyerActive =
              buyerStatus == null || buyerStatus == true || buyerStatus == 1;
          final isSellerActive =
              sellerStatus == null || sellerStatus == true || sellerStatus == 1;
          if (!isBuyerActive || !isSellerActive) continue;

          final sku = (p['buyer_sku_code'] ?? '').toString().trim();
          if (sku.isEmpty || isLikelyPrepaidSku(sku)) continue;

          candidateSkus.add(sku);

          if (isStrictPlnPostpaidProduct(p)) {
            prioritizedSkus.add(sku);
          }
        }
      }

      await collectSkus(brand: 'PLN PASCABAYAR');
      await collectSkus(brand: 'PLN');
      await collectSkus(category: 'Listrik');
      await collectSkus();

      for (final item in _products) {
        if (item is! Map) continue;
        final p = Map<String, dynamic>.from(item);
        final buyerStatus = p['buyer_product_status'];
        final sellerStatus = p['seller_product_status'];
        final isBuyerActive =
            buyerStatus == null || buyerStatus == true || buyerStatus == 1;
        final isSellerActive =
            sellerStatus == null || sellerStatus == true || sellerStatus == 1;
        if (!isBuyerActive || !isSellerActive) continue;

        final sku = (p['buyer_sku_code'] ?? '').toString().trim();
        if (sku.isEmpty || isLikelyPrepaidSku(sku)) continue;

        if (isStrictPlnPostpaidProduct(p)) {
          prioritizedSkus.add(sku);
        }
      }

      if (prioritizedSkus.isNotEmpty) {
        candidateSkus
          ..clear()
          ..addAll(prioritizedSkus);
      }

      if (candidateSkus.isEmpty) {
        candidateSkus
            .addAll(const {'PLNPASCA', 'plnpasca', 'PLNPOSTPAID', 'PLNPOST'});
      }

      final attempts = <Map<String, dynamic>>[];
      Map<String, dynamic>? selectedData;
      String? selectedSku;

      // Prefer backend endpoint khusus PLN pascabayar agar sesuai kontrak cek-tagihan.
      try {
        final directResult =
            await ApiService.ppobInquiryPln(customerNo: customerId);
        attempts
            .add({'sku': null, 'result': directResult, 'mode': 'inquiry-pln'});

        final directStatus =
            (directResult['status'] ?? '').toString().toLowerCase();
        final directMessage =
            (directResult['message'] ?? '').toString().toLowerCase();
        final directIsSuccess = directStatus == 'success' ||
            directStatus == 'sukses' ||
            directMessage.contains('sukses');

        if (directIsSuccess && directResult['data'] is Map) {
          final directData =
              Map<String, dynamic>.from(directResult['data'] as Map);
          final directSku =
              (directData['buyer_sku_code'] ?? '').toString().trim();
          final hasBillingAmount =
              _asDouble(directData['selling_price'] ?? directData['price']) > 0;
          final hasPostpaidIdentity = directSku.isNotEmpty &&
              !isLikelyPrepaidSku(directSku) &&
              (directSku.toLowerCase().contains('pln') ||
                  directSku.toLowerCase().contains('pasca'));

          // Jika endpoint ini ternyata mengembalikan shape inquiry PLN prabayar,
          // abaikan dan lanjutkan ke inq-pasca berbasis buyer_sku_code.
          if (hasBillingAmount || hasPostpaidIdentity) {
            selectedData = directData;
            selectedSku = directSku;
          }
        }
      } catch (error) {
        attempts.add({
          'sku': null,
          'mode': 'inquiry-pln',
          'error': ApiService.userFriendlyMessage(error,
              fallback: 'Cek tagihan PLN gagal'),
        });
      }

      for (final sku in candidateSkus) {
        if (selectedData != null) break;
        try {
          final result = await ApiService.ppobInquiry(
            buyerSkuCode: sku,
            customerNo: customerId,
            category: widget.category.isEmpty ? widget.title : widget.category,
          );
          attempts.add({'sku': sku, 'result': result});

          final status = (result['status'] ?? '').toString().toLowerCase();
          final message = (result['message'] ?? '').toString().toLowerCase();
          final isSuccess = status == 'success' ||
              status == 'sukses' ||
              message.contains('sukses');

          if (isSuccess && result['data'] != null) {
            selectedData = Map<String, dynamic>.from(result['data'] as Map);
            selectedSku = sku;
            break;
          }
        } catch (error) {
          attempts.add({
            'sku': sku,
            'error': ApiService.userFriendlyMessage(error,
                fallback: 'Cek tagihan gagal'),
          });
        }
      }

      final rawPayload = {
        'customer_no': customerId,
        'candidate_skus': candidateSkus.toList(),
        'selected_sku': selectedSku,
        'attempts': attempts,
      };
      final rawJson = const JsonEncoder.withIndent('  ').convert(rawPayload);

      if (mounted) {
        setState(() {
          _lastPlnRawStatusCode = selectedData != null ? 200 : 422;
          _lastPlnRawResponse = rawJson;
        });
      }

      if (!mounted) return;
      if (selectedData != null) {
        selectedData['buyer_sku_code'] =
            (selectedData['buyer_sku_code'] ?? selectedSku ?? 'PLNPASCA')
                .toString();
        setState(() {
          _plnPostpaidInquiryResult = selectedData;
        });
      } else {
        // Cari pesan paling informatif dari hasil percobaan agar provider
        // message (mis. "Tagihan sudah dibayar", "ID pelanggan tidak ditemukan")
        // tampil ke pengguna alih-alih pesan generik.
        String? providerMessage;
        for (final attempt in attempts.reversed) {
          final err = (attempt['error'] ?? '').toString().trim();
          if (err.isNotEmpty &&
              !err.toLowerCase().contains('produk tidak ditemukan') &&
              !err.toLowerCase().contains('gagal melakukan')) {
            providerMessage = err;
            break;
          }
          final res = attempt['result'];
          if (res is Map) {
            final msg = (res['message'] ?? res['keterangan'] ?? '')
                .toString()
                .trim();
            final status = (res['status'] ?? '').toString().toLowerCase();
            if (msg.isNotEmpty &&
                status != 'success' &&
                status != 'sukses' &&
                !msg.toLowerCase().contains('sukses')) {
              providerMessage = msg;
              break;
            }
          }
        }
        // Fallback ke error pertama jika tidak ada yg lebih spesifik.
        providerMessage ??= attempts
            .map((a) => (a['error'] ?? '').toString().trim())
            .firstWhere((s) => s.isNotEmpty, orElse: () => '');

        final body = (providerMessage.isNotEmpty)
            ? providerMessage
            : 'Tidak ada respon dari penyedia layanan. Coba beberapa saat lagi.';
        if (mounted) setState(() => _plnPostpaidError = body);
      }
    } catch (e) {
      if (!mounted) return;
      final message =
          ApiService.userFriendlyMessage(e, fallback: 'Cek tagihan gagal');
      setState(() => _plnPostpaidError = message);
    } finally {
      if (mounted) {
        setState(() => _isPlnPostpaidInquiring = false);
      }
    }
  }

  Future<void> _showPostpaidNotification(String title, String message) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _doBpjsInquiry() async {
    final customerId = _customerIdController.text.trim();
    if (customerId.isEmpty) {
      Fluttertoast.showToast(msg: 'Masukkan ID Pelanggan');
      return;
    }

    setState(() {
      _isBpjsInquiring = true;
      _bpjsInquiryResult = null;
      _bpjsInquiryError = null;
    });

    try {
      final categoryQuery =
          widget.category.isEmpty ? widget.title : widget.category;
      final result = await ApiService.ppobInquiry(
        customerNo: customerId,
        category: categoryQuery,
      );
      if (!mounted) return;
      final status = (result['status'] ?? '').toString().toLowerCase();
      final isSuccess = status == 'success' || status == 'sukses';
      if (isSuccess && result['data'] is Map) {
        setState(() {
          _bpjsInquiryResult =
              Map<String, dynamic>.from(result['data'] as Map);
        });
      } else {
        final msg = (result['message'] ?? 'Cek tagihan gagal').toString();
        setState(() => _bpjsInquiryError = msg);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _bpjsInquiryError =
          ApiService.userFriendlyMessage(e, fallback: 'Cek tagihan gagal'));
    } finally {
      if (mounted) setState(() => _isBpjsInquiring = false);
    }
  }

  void _payBpjsBill() {
    if (_bpjsInquiryResult == null) return;
    final amount = _asDouble(_bpjsInquiryResult!['selling_price']);
    if (amount <= 0) {
      Fluttertoast.showToast(
          msg: 'Total tagihan tidak valid, silakan cek ulang');
      return;
    }
    final buyerSkuCode =
        (_bpjsInquiryResult!['buyer_sku_code'] ?? _bpjsInquiryResult!['inquiry_sku'] ?? '')
            .toString();
    final customerNo = (_bpjsInquiryResult!['customer_no'] ??
            _customerIdController.text.trim())
        .toString();
    final productName =
        (_bpjsInquiryResult!['product_name'] ?? widget.title).toString();
    final customerName =
        (_bpjsInquiryResult!['customer_name'] ?? '-').toString();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _PlnPostpaidInlinePinScreen(
          buyerSkuCode: buyerSkuCode,
          customerNo: customerNo,
          productName: productName,
          customerName: customerName,
          amount: amount,
        ),
      ),
    );
  }

  void _payPlnPostpaidBill() {
    if (_plnPostpaidInquiryResult == null) return;

    final plnData = _plnPostpaidInquiryResult!;
    final desc = plnData['desc'] is Map
        ? Map<String, dynamic>.from(plnData['desc'] as Map)
        : <String, dynamic>{};
    Map<String, dynamic> firstBill = {};
    final tagihan = plnData['tagihan'];
    if (tagihan is List && tagihan.isNotEmpty && tagihan.first is Map) {
      firstBill = Map<String, dynamic>.from(tagihan.first as Map);
    } else {
      firstBill = _plnFirstDetailMap(plnData);
    }
    final rpTagPln = _asMoney(firstBill['nominal'] ??
        plnData['nominal'] ??
        plnData['selling_price']);
    final adminBank = _asMoney(firstBill['admin'] ?? plnData['admin']);
    final denda = _asMoney(firstBill['denda'] ?? desc['denda']);
    final computed = rpTagPln + adminBank + denda;
    double amount = computed > 0
        ? computed
        : _asDouble(_plnPostpaidInquiryResult!['selling_price']);
    if (amount <= 0) {
      Fluttertoast.showToast(
          msg: 'Total tagihan tidak valid, silakan cek ulang');
      return;
    }

    final buyerSkuCode =
        (_plnPostpaidInquiryResult!['buyer_sku_code'] ?? 'PLNPASCA').toString();
    final customerNo = (_plnPostpaidInquiryResult!['customer_no'] ??
            _customerIdController.text.trim())
        .toString();
    final productName =
        (_plnPostpaidInquiryResult!['product_name'] ?? 'PLN Pascabayar')
            .toString();
    final customerName =
        (_plnPostpaidInquiryResult!['customer_name'] ?? '-').toString();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _PlnPostpaidInlinePinScreen(
          buyerSkuCode: buyerSkuCode,
          customerNo: customerNo,
          productName: productName,
          customerName: customerName,
          amount: amount,
        ),
      ),
    );
  }

  Widget _billRowInline(
    String label,
    String value,
    Color textSecondary,
    Color textPrimary, {
    bool highlight = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              color: textSecondary,
              fontFamily: 'Gilroy Medium',
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: highlight ? const Color(0xFF3F6FB4) : textPrimary,
                fontFamily: highlight ? 'Gilroy Bold' : 'Gilroy Medium',
                fontSize: highlight ? 16 : 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInternetHub(Color textPrimary, Color textSecondary, Color accent) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Pilih Provider',
              style: TextStyle(
                color: textPrimary,
                fontFamily: 'Gilroy Bold',
                fontSize: 15,
              ),
            ),
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _internetProviders.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              mainAxisExtent: 72,
            ),
            itemBuilder: (_, i) {
              final provider = _internetProviders[i];
              final brand = provider['name']!;
              final logo = provider['logo'];
              return InkWell(
                onTap: () => _onPickInternetProvider(brand),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE5E9EE)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: const Color(0xFFEFF1F4), width: 1),
                        ),
                        child: logo == null
                            ? Icon(Icons.wifi, color: accent, size: 20)
                            : Image.asset(
                                logo,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) =>
                                    Icon(Icons.wifi, color: accent, size: 20),
                              ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          brand,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: textPrimary,
                            fontFamily: 'Gilroy Bold',
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Icon(Icons.chevron_right,
                          color: textSecondary.withValues(alpha: 0.6),
                          size: 18),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _onPickInternetProvider(String brand) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PPOBProductScreen(
          category: brand,
          title: brand,
          cmd: 'pasca',
          inquiryOnly: true,
        ),
      ),
    );
  }

  Widget _buildHubSearchField(
      Color textPrimary, Color textSecondary, String hint) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E9EE)),
      ),
      child: TextField(
        controller: _hubSearchCtrl,
        onChanged: (v) => setState(() => _hubSearchQuery = v.trim()),
        textInputAction: TextInputAction.search,
        style: TextStyle(
          color: textPrimary,
          fontFamily: 'Gilroy Medium',
          fontSize: 14,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: textSecondary.withValues(alpha: 0.6),
            fontFamily: 'Gilroy Medium',
          ),
          prefixIcon: Icon(Icons.search,
              color: textSecondary.withValues(alpha: 0.7), size: 20),
          suffixIcon: _hubSearchQuery.isEmpty
              ? null
              : IconButton(
                  icon: Icon(Icons.close,
                      color: textSecondary.withValues(alpha: 0.7),
                      size: 18),
                  onPressed: () {
                    _hubSearchCtrl.clear();
                    setState(() => _hubSearchQuery = '');
                  },
                ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _buildMultifinanceHub(
      Color textPrimary, Color textSecondary, Color accent) {
    final q = _hubSearchQuery.toLowerCase();
    final filtered = q.isEmpty
        ? _multifinanceBrands
        : _multifinanceBrands
            .where((b) => b.toLowerCase().contains(q))
            .toList();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Pilih Provider Multifinance',
              style: TextStyle(
                color: textPrimary,
                fontFamily: 'Gilroy Bold',
                fontSize: 15,
              ),
            ),
          ),
          _buildHubSearchField(
              textPrimary, textSecondary, 'Cari provider multifinance…'),
          const SizedBox(height: 12),
          if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text(
                  'Provider tidak ditemukan',
                  style: TextStyle(
                    color: textSecondary,
                    fontFamily: 'Gilroy Medium',
                    fontSize: 14,
                  ),
                ),
              ),
            )
          else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filtered.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final brand = filtered[i];
              return InkWell(
                onTap: () => _onPickMultifinance(brand),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE5E9EE)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.account_balance_wallet_outlined,
                            color: accent, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          brand,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: textPrimary,
                            fontFamily: 'Gilroy Bold',
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Icon(Icons.chevron_right,
                          color: textSecondary.withValues(alpha: 0.6),
                          size: 18),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _onPickMultifinance(String brand) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PPOBProductScreen(
          category: brand,
          title: brand,
          cmd: 'pasca',
          inquiryOnly: true,
        ),
      ),
    );
  }

  Widget _buildBpjsSection(Color textPrimary, Color textSecondary) {
    final data = _bpjsInquiryResult;
    final hasResult = data != null;
    final currency = NumberFormat('#,###', 'id_ID');
    String moneyOf(dynamic v) {
      final n = _asDouble(v);
      return n > 0 ? 'Rp ${currency.format(n.toInt())}' : 'Gratis!';
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!hasResult) ...[
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _isBpjsInquiring ? null : _doBpjsInquiry,
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: const Color(0xFF3F6FB4),
                  disabledBackgroundColor: const Color(0xFF8AA8D6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isBpjsInquiring
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
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
            if (_bpjsInquiryError != null && !_isBpjsInquiring) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4F4),
                  border: Border.all(color: const Color(0xFFF5C2C2)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _bpjsInquiryError!,
                  style: const TextStyle(
                    color: Color(0xFFB00020),
                    fontFamily: 'Gilroy Medium',
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ] else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE5E9EE)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Detail Tagihan',
                    style: TextStyle(
                      color: textPrimary,
                      fontFamily: 'Gilroy Bold',
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _billRowInline(
                    'No. Pelanggan',
                    (data['customer_no'] ?? '-').toString(),
                    textSecondary,
                    textPrimary,
                  ),
                  _billRowInline(
                    'Nama',
                    (data['customer_name'] ?? '-').toString(),
                    textSecondary,
                    textPrimary,
                  ),
                  if ((data['periode'] ?? '').toString().isNotEmpty)
                    _billRowInline(
                      'Periode',
                      data['periode'].toString(),
                      textSecondary,
                      textPrimary,
                    ),
                  if ((data['lembar_tagihan'] ?? data['lembar_total']) != null)
                    _billRowInline(
                      'Jumlah Bulan',
                      (data['lembar_tagihan'] ?? data['lembar_total'])
                          .toString(),
                      textSecondary,
                      textPrimary,
                    ),
                  const Divider(height: 18, color: Color(0xFFE5E9EE)),
                  _billRowInline(
                    'Tagihan',
                    moneyOf(data['nominal'] ?? data['provider_nominal']),
                    textSecondary,
                    textPrimary,
                  ),
                  _billRowInline(
                    'Biaya Admin',
                    moneyOf(data['admin'] ?? data['provider_admin']),
                    textSecondary,
                    textPrimary,
                  ),
                  const Divider(height: 18, color: Color(0xFFE5E9EE)),
                  _billRowInline(
                    'Total Bayar',
                    moneyOf(data['selling_price'] ?? data['total']),
                    textSecondary,
                    textPrimary,
                    highlight: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _bpjsInquiryResult = null;
                          _bpjsInquiryError = null;
                        });
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF3F6FB4)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Cek Ulang',
                        style: TextStyle(
                          color: Color(0xFF3F6FB4),
                          fontFamily: 'Gilroy Bold',
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _payBpjsBill,
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: Colors.green,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Bayar Sekarang',
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: 'Gilroy Bold',
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPlnPostpaidSection(Color textPrimary, Color textSecondary) {
    final plnData = _plnPostpaidInquiryResult;
    final desc =
        plnData == null ? const <String, dynamic>{} : _plnDescMap(plnData);

    // Ambil rincian tagihan pertama: backend kini meneruskan array `tagihan`
    // dari Loket Bayar (PLN Pasca). Fallback ke desc.detail[0] untuk kompat.
    Map<String, dynamic> firstBill = const <String, dynamic>{};
    if (plnData != null) {
      final tagihan = plnData['tagihan'];
      if (tagihan is List && tagihan.isNotEmpty && tagihan.first is Map) {
        firstBill = Map<String, dynamic>.from(tagihan.first as Map);
      } else {
        firstBill = _plnFirstDetailMap(plnData);
      }
    }

    final idpel =
        (plnData?['customer_no'] ?? plnData?['subscriberID'] ?? '-').toString();
    final nama =
        (plnData?['customer_name'] ?? plnData?['nama'] ?? '-').toString();

    // tarifDaya bisa langsung "R1/1300VA" dari backend, atau terpisah di desc.
    String tarifDaya =
        (plnData?['tariff_daya'] ?? plnData?['tarifDaya'] ?? '').toString().trim();
    if (tarifDaya.isEmpty) {
      final tarif = (desc['tarif'] ?? '').toString().trim();
      final daya = (desc['daya'] ?? '').toString().trim();
      tarifDaya =
          '${tarif.isEmpty ? '-' : tarif}/${daya.isEmpty ? '-' : daya}';
    }

    final periodRaw = firstBill['periode'] ?? plnData?['periode'];
    final periode = _formatPlnBillingPeriod(periodRaw);

    final rpTagPln = _asMoney(firstBill['nominal'] ??
        plnData?['nominal'] ??
        plnData?['selling_price']);
    final adminBank = _asMoney(firstBill['admin'] ?? plnData?['admin']);
    final denda = _asMoney(firstBill['denda'] ?? desc['denda']);
    final meterAwal =
        (firstBill['meterAwal'] ?? firstBill['meter_awal'] ?? '-').toString();
    final meterAkhir =
        (firstBill['meterAkhir'] ?? firstBill['meter_akhir'] ?? '-').toString();
    // Prefer komputasi tagihan + admin + denda agar konsisten dengan baris detail
    // di atasnya. `plnData['total']` kadang berisi nilai lain (mis. harga
    // markup atau admin fee saja) dan menyebabkan total tampak salah.
    final computedTotal = rpTagPln + adminBank + denda;
    final sellingPrice = _asMoney(plnData?['selling_price']);
    double totalBayar;
    if (computedTotal > 0) {
      totalBayar = computedTotal;
    } else if (sellingPrice > 0) {
      totalBayar = sellingPrice;
    } else {
      totalBayar = _asMoney(plnData?['total']);
    }

    // Jumlah lembar tagihan (untuk display "LEMBAR").
    final tagihanList = plnData?['tagihan'];
    final int lembar = () {
      final fromField = plnData?['lembar_tagihan'] ?? plnData?['lembarTagihan'];
      if (fromField is num) return fromField.toInt();
      final parsed = int.tryParse('${fromField ?? ''}');
      if (parsed != null && parsed > 0) return parsed;
      if (tagihanList is List) return tagihanList.length;
      return plnData == null ? 0 : 1;
    }();

    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            children: [
              if (_plnPostpaidInquiryResult == null) ...[
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed:
                        _isPlnPostpaidInquiring ? null : _doPlnPostpaidInquiry,
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: const Color(0xFF3F6FB4),
                      disabledBackgroundColor: const Color(0xFF8AA8D6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isPlnPostpaidInquiring
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  valueColor: AlwaysStoppedAnimation<Color>(
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
                // Pesan error inline (mengganti dialog).
                if (_plnPostpaidError != null &&
                    !_isPlnPostpaidInquiring) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF4F4),
                      border:
                          Border.all(color: const Color(0xFFF5C2C2)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          color: Color(0xFFD94C4C),
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Tidak dapat memeriksa tagihan',
                                style: TextStyle(
                                  color: const Color(0xFF8A2A2A),
                                  fontFamily: 'Gilroy Bold',
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _plnPostpaidError!,
                                style: TextStyle(
                                  color: textSecondary,
                                  fontFamily: 'Gilroy Medium',
                                  fontSize: 12,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
              if (_plnPostpaidInquiryResult != null) ...[
                // ── Card 1: Info Pelanggan ─────────────────────────────
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE5E9F0)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0F000000),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header dengan accent bar.
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF4F7FC),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(14),
                            topRight: Radius.circular(14),
                          ),
                          border: Border(
                            bottom: BorderSide(
                                color: const Color(0xFFE5E9F0)),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: const Color(0xFF3F6FB4)
                                    .withOpacity(0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.electrical_services_rounded,
                                color: Color(0xFF3F6FB4),
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    nama,
                                    style: TextStyle(
                                      color: textPrimary,
                                      fontFamily: 'Gilroy Bold',
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'ID Pelanggan • $idpel',
                                    style: TextStyle(
                                      color: textSecondary,
                                      fontFamily: 'Gilroy Medium',
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF3F6FB4)
                                    .withOpacity(0.10),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                tarifDaya,
                                style: const TextStyle(
                                  color: Color(0xFF3F6FB4),
                                  fontFamily: 'Gilroy Bold',
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Body: Detail Tagihan
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Detail Tagihan',
                              style: TextStyle(
                                color: textPrimary,
                                fontFamily: 'Gilroy Bold',
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _billRowInline('Periode', periode,
                                textSecondary, textPrimary),
                            _billRowInline(
                                'Lembar',
                                lembar > 0 ? '$lembar lembar' : '-',
                                textSecondary,
                                textPrimary),
                            _billRowInline('Meter Awal', meterAwal,
                                textSecondary, textPrimary),
                            _billRowInline('Meter Akhir', meterAkhir,
                                textSecondary, textPrimary),
                            const SizedBox(height: 6),
                            Container(
                              height: 1,
                              color: const Color(0xFFEEF1F6),
                            ),
                            const SizedBox(height: 6),
                            _billRowInline(
                                'Tagihan',
                                _formatPrice(rpTagPln),
                                textSecondary,
                                textPrimary),
                            _billRowInline(
                                'Admin Bank',
                                _formatPrice(adminBank),
                                textSecondary,
                                textPrimary),
                            _billRowInline('Denda', _formatPrice(denda),
                                textSecondary, textPrimary),
                            const SizedBox(height: 10),
                            // Total bayar block (highlight)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF3F6FB4)
                                    .withOpacity(0.08),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    'Total Bayar',
                                    style: TextStyle(
                                      color: textSecondary,
                                      fontFamily: 'Gilroy Bold',
                                      fontSize: 13,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    _formatPrice(totalBayar),
                                    style: const TextStyle(
                                      color: Color(0xFF3F6FB4),
                                      fontFamily: 'Gilroy Bold',
                                      fontSize: 18,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _doPlnPostpaidInquiry,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF3F6FB4),
                          side: const BorderSide(color: Color(0xFF3F6FB4)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text(
                          'Cek Ulang',
                          style: TextStyle(fontFamily: 'Gilroy Bold'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _payPlnPostpaidBill,
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          backgroundColor: Colors.green,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text(
                          'Bayar Sekarang',
                          style: TextStyle(
                            color: Colors.white,
                            fontFamily: 'Gilroy Bold',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        if (_isPlnPostpaidInquiring)
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.28),
              alignment: Alignment.center,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Memuat data tagihan...',
                      style: TextStyle(
                        fontFamily: 'Gilroy Medium',
                        fontSize: 13,
                        color: Color(0xFF1D1D1D),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  double _parseBalanceValue(String raw) {
    final normalized = raw.replaceAll(',', '').trim();
    return double.tryParse(normalized) ?? 0;
  }

  void _goToPin(Map<String, dynamic> product) {
    final customerId = _customerIdController.text.trim();
    final price = product['price'] is int
        ? (product['price'] as int).toDouble()
        : double.tryParse(product['price'].toString()) ?? 0;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final balance = _parseBalanceValue(auth.userBalance);
    final kreditVerified = auth.kreditVerified;

    // If limit is active, show payment source picker
    if (kreditVerified) {
      _showPaymentSourceSheet(product, customerId, price, balance);
      return;
    }

    // Default: saldo only
    if (balance < price) {
      Fluttertoast.showToast(msg: 'Saldo tidak mencukupi untuk transaksi ini');
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ConfirmPayment(
          amount: price,
          bankName: product['product_name'] ?? widget.title,
          type: 'phone',
          phoneNumber: customerId,
          buyerSkuCode: product['buyer_sku_code'],
          provider: (product['provider'] ?? '').toString(),
          category: widget.category.isEmpty ? widget.title : widget.category,
          paymentSource: 'saldo',
          loketbayarRefId: (product['provider'] == 'loketbayar')
              ? _lastInquiryRefId
              : null,
          loketbayarKodeProduk: (product['provider'] == 'loketbayar')
              ? (_lastInquiryKodeProduk ?? product['inquiry_sku'] ?? product['buyer_sku_code'] ?? '').toString()
              : null,
          loketbayarNominal: (product['provider'] == 'loketbayar')
              ? _lastInquiryNominal
              : null,
        ),
      ),
    );
  }

  void _showPaymentSourceSheet(Map<String, dynamic> product, String customerId, double price, double balance) {
    String selected = 'saldo';
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final kreditLimit = auth.kreditLimit;

    // Fetch available limit
    double availableLimit = kreditLimit;
    bool limitActive = auth.kreditVerified;
    bool isLoadingLimit = true;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            // Fetch real available limit on first build
            if (isLoadingLimit) {
              isLoadingLimit = false;
              ApiService.getMerchantLimitDetail().then((response) {
                if (response['status'] == 'active' && response['data'] != null) {
                  final data = response['data'] as Map<String, dynamic>;
                  final real = (data['available_amount'] ?? kreditLimit).toDouble();
                  setSheetState(() => availableLimit = real);
                }
              }).catchError((_) {});
            }
            return Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36, height: 4,
                        decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Pilih Metode Pembayaran',
                      style: TextStyle(fontFamily: 'Gilroy Bold', fontSize: 16, color: Color(0xFF1A1A1A)),
                    ),
                    const SizedBox(height: 14),
                    // Saldo option
                    GestureDetector(
                      onTap: () => setSheetState(() => selected = 'saldo'),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected == 'saldo' ? notifire.getbluecolor : Colors.grey.withOpacity(0.2),
                            width: selected == 'saldo' ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.account_balance_wallet_rounded, color: notifire.getbluecolor, size: 22),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Saldo', style: TextStyle(fontFamily: 'Gilroy Bold', fontSize: 14)),
                                  Text(
                                    'Rp ${_currencyFormat.format(balance.toInt())}',
                                    style: TextStyle(fontFamily: 'Gilroy Medium', fontSize: 12, color: balance < price ? Colors.red : Colors.grey[600]),
                                  ),
                                ],
                              ),
                            ),
                            if (selected == 'saldo')
                              Icon(Icons.check_circle_rounded, color: notifire.getbluecolor, size: 20),
                          ],
                        ),
                      ),
                    ),
                    // Limit option
                    GestureDetector(
                      onTap: limitActive ? () => setSheetState(() => selected = 'limit') : null,
                      child: Opacity(
                        opacity: limitActive ? 1.0 : 0.5,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selected == 'limit' ? notifire.getbluecolor : Colors.grey.withOpacity(0.2),
                              width: selected == 'limit' ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.credit_card_rounded, color: const Color(0xFFF59E0B), size: 22),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Limit', style: TextStyle(fontFamily: 'Gilroy Bold', fontSize: 14)),
                                    Text(
                                      limitActive
                                          ? 'Tersisa Rp ${_currencyFormat.format(availableLimit.toInt())}'
                                          : 'Fitur tidak aktif',
                                      style: TextStyle(fontFamily: 'Gilroy Medium', fontSize: 12, color: limitActive ? Colors.grey[600] : Colors.red[400]),
                                    ),
                                  ],
                                ),
                              ),
                              if (selected == 'limit')
                                Icon(Icons.check_circle_rounded, color: notifire.getbluecolor, size: 20),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          if (selected == 'saldo' && balance < price) {
                            Fluttertoast.showToast(msg: 'Saldo tidak mencukupi');
                            return;
                          }
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ConfirmPayment(
                                amount: price,
                                bankName: product['product_name'] ?? widget.title,
                                type: 'phone',
                                phoneNumber: customerId,
                                buyerSkuCode: product['buyer_sku_code'],
                                provider: (product['provider'] ?? '').toString(),
                                category: widget.category.isEmpty ? widget.title : widget.category,
                                paymentSource: selected,
                                loketbayarRefId: (product['provider'] == 'loketbayar')
                                    ? _lastInquiryRefId
                                    : null,
                                loketbayarKodeProduk: (product['provider'] == 'loketbayar')
                                    ? (_lastInquiryKodeProduk ?? product['inquiry_sku'] ?? product['buyer_sku_code'] ?? '').toString()
                                    : null,
                                loketbayarNominal: (product['provider'] == 'loketbayar')
                                    ? _lastInquiryNominal
                                    : null,
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: notifire.getbluecolor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: const Text('Lanjutkan', style: TextStyle(color: Colors.white, fontFamily: 'Gilroy Bold', fontSize: 15)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _extractRecipientName(Map<String, dynamic> data) {
    final rawName =
        (data['name'] ?? data['customer_name'] ?? '').toString().trim();
    if (rawName.isNotEmpty &&
        rawName != '-' &&
        !rawName.toLowerCase().startsWith('nomor:')) {
      return rawName;
    }

    final desc = (data['desc'] ?? '').toString();
    final match =
        RegExp(r'Nama:([^/]+)', caseSensitive: false).firstMatch(desc);
    if (match != null) {
      final parsed = match.group(1)?.trim() ?? '';
      if (parsed.isNotEmpty && parsed != '-') {
        return parsed;
      }
    }
    return '';
  }

  String _extractPlnCustomerName(Map<String, dynamic> data) {
    final name = _extractRecipientName(data);
    if (name.isNotEmpty) return name;
    final fallback =
        (data['subscriber_name'] ?? data['nama'] ?? '').toString().trim();
    if (fallback.isNotEmpty && fallback != '-') return fallback;
    return 'Nama tidak tersedia';
  }

  Map<String, dynamic> _plnDescMap(Map<String, dynamic> data) {
    final desc = data['desc'];
    if (desc is Map) {
      return Map<String, dynamic>.from(desc);
    }
    return const <String, dynamic>{};
  }

  Map<String, dynamic> _plnFirstDetailMap(Map<String, dynamic> data) {
    final desc = _plnDescMap(data);
    final detail = desc['detail'];
    if (detail is List && detail.isNotEmpty && detail.first is Map) {
      return Map<String, dynamic>.from(detail.first as Map);
    }
    return const <String, dynamic>{};
  }

  String _formatPlnBillingPeriod(dynamic value) {
    final raw = (value ?? '').toString().trim();
    if (raw.isEmpty || raw == '-') return '-';

    final onlyDigits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (onlyDigits.length >= 6) {
      final year = onlyDigits.substring(0, 4);
      final month = onlyDigits.substring(4, 6);
      return '$year/$month';
    }

    return raw;
  }

  double _asMoney(dynamic value) {
    if (value is num) return value.toDouble();
    final normalized = (value ?? '').toString().replaceAll(',', '').trim();
    return double.tryParse(normalized) ?? 0;
  }

  Future<String?> _validateEmoneyRecipient(
    String customerId,
    String checkSku, {
    String? categoryOverride,
    String? brand,
    double? amount,
  }) async {
    Future<void> showInquiryJsonDialog(
      String title,
      Map<String, dynamic> payload,
    ) async {
      if (!mounted) return;
      final pretty = const JsonEncoder.withIndent('  ').convert(payload);
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: SelectableText(
              pretty,
              style: const TextStyle(
                fontFamily: 'Courier',
                fontSize: 12,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Tutup'),
            ),
          ],
        ),
      );
    }

    Map<String, dynamic>? lastResponse;
    for (int i = 0; i < 4; i++) {
      try {
        final response = await ApiService.ppobInquiry(
          buyerSkuCode: checkSku,
          customerNo: customerId,
          category: (categoryOverride != null && categoryOverride.isNotEmpty)
              ? categoryOverride
              : (widget.category.isEmpty ? widget.title : widget.category),
          brand: brand,
          amount: amount,
        );
        lastResponse = Map<String, dynamic>.from(response);

        final status = (response['status'] ?? '').toString().toLowerCase();
        final message = (response['message'] ?? '').toString().toLowerCase();

        // Format standar backend: {"status": "success", "data": {...}}
        if (status == 'success' && response['data'] != null) {
          final data = Map<String, dynamic>.from(response['data']);
          // Capture ref_id, total, and inquiry_sku from inquiry for Loket Bayar payment
          final refId = (data['ref_id'] ?? '').toString();
          if (refId.isNotEmpty) {
            _lastInquiryRefId = refId;
          }
          // `nominal` di backend response = jumlah yang user input (yang
          // sampai ke tujuan). Itu yang dikirim ke endpoint purchase
          // Loket Bayar; backend yang tahu cara hitung total (nominal +
          // admin panel) untuk dipotong dari saldo user.
          final nominalRaw = data['nominal'] ?? data['total'];
          if (nominalRaw != null) {
            _lastInquiryNominal = (nominalRaw is int)
                ? nominalRaw
                : int.tryParse(nominalRaw.toString());
          }
          final inquirySku = (data['inquiry_sku'] ?? '').toString();
          if (inquirySku.isNotEmpty) {
            _lastInquiryKodeProduk = inquirySku;
          }
          // Inject admin_fee dari response inquiry ke selected product map
          // HANYA untuk produk virtual nominal bebas (is_dynamic == true).
          // Produk nominal tetap sudah punya admin_fee dari API list — tidak perlu di-overwrite.
          if (data['admin_fee'] != null &&
              _selectedProduct != null &&
              _selectedProduct!['is_dynamic'] == true) {
            _selectedProduct!['admin_fee'] = data['admin_fee'];
          }
          final name = _extractRecipientName(data);
          if (name.isNotEmpty) {
            return name;
          }
          break;
        }

        // Format Loket Bayar yang diteruskan langsung:
        // {"status": "00", "nama": "...", "keterangan": "Successful"}
        if (status == '00' || status == 'sukses' || status == 'successful') {
          // Capture ref_id and nominal (bukan total — total sudah include admin panel)
          final refId = (response['refID'] ?? response['ref_id'] ?? '').toString();
          if (refId.isNotEmpty) {
            _lastInquiryRefId = refId;
          }
          final nominalRaw = response['nominal'] ?? response['total'];
          if (nominalRaw != null) {
            _lastInquiryNominal = (nominalRaw is int)
                ? nominalRaw
                : int.tryParse(nominalRaw.toString());
          }
          final nama = (response['nama'] ?? response['name'] ?? '').toString().trim();
          if (nama.isNotEmpty) {
            return nama;
          }
          return _verifiedWithoutNameToken;
        }

        // Backend mungkin wrap response Loket Bayar di field 'data'
        if (response['data'] != null && response['data'] is Map) {
          final data = Map<String, dynamic>.from(response['data']);
          final dataStatus = (data['status'] ?? '').toString().toLowerCase();
          if (dataStatus == '00' || dataStatus == 'sukses' || dataStatus == 'successful') {
            final nama = (data['nama'] ?? data['name'] ?? '').toString().trim();
            if (nama.isNotEmpty) {
              return nama;
            }
            return _verifiedWithoutNameToken;
          }
        }

        // Some providers return only a success message without recipient payload.
        if (message.contains('transaksi sukses') && response['data'] == null) {
          return _verifiedWithoutNameToken;
        }

        if (message.contains('pending') && i < 3) {
          await Future.delayed(const Duration(seconds: 1));
          continue;
        }

        break;
      } catch (error) {
        final message = error is AppException
            ? error.message
            : ApiService.userFriendlyMessage(
                error,
                fallback: 'Gagal terhubung saat cek nama penerima',
              );
        lastResponse = {
          'status': 'error',
          'message': message,
          'customer_no': customerId,
          'buyer_sku_code': checkSku,
        };

        final lower = message.toLowerCase();
        if ((lower.contains('pending') || lower.contains('transaksi sukses')) &&
            i < 3) {
          await Future.delayed(const Duration(seconds: 1));
          continue;
        }
        if (lower.contains('transaksi sukses')) {
          return _verifiedWithoutNameToken;
        }
        break;
      }
    }

    final rawMessage =
        (lastResponse?['message'] ?? 'Nomor tidak valid').toString();
    final message = rawMessage.toLowerCase();
    if (message.contains('gagal terhubung')) {
      Fluttertoast.showToast(msg: 'Gagal terhubung saat cek nama penerima');
    } else if (message.contains('pending')) {
      Fluttertoast.showToast(
        msg: 'Pengecekan masih diproses, coba lagi beberapa detik',
      );
    } else {
      Fluttertoast.showToast(
          msg: rawMessage.isEmpty ? 'Nomor tidak valid' : rawMessage);
      if (lastResponse != null) {
        await showInquiryJsonDialog('Hasil JSON Cek Nama', lastResponse!);
      }
    }
    return null;
  }

  Future<void> _onProductSelected(Map<String, dynamic> product) async {
    _dismissInputAndNumpad();

    // PLN prabayar: tap-card hanya memilih produk; inquiry & navigasi
    // ditrigger oleh tombol Lanjutkan via _continuePlnPrabayar().
    if (_isPln && _plnTabIndex == 0) {
      setState(() => _selectedProduct = product);
      return;
    }

    final customerId = _customerIdController.text.trim();
    if (customerId.isEmpty) {
      Fluttertoast.showToast(msg: 'Masukkan nomor pelanggan / nomor HP');
      return;
    }

    final numberError = _validateCustomerIdByBrand(customerId);
    if (numberError != null) {
      Fluttertoast.showToast(msg: numberError);
      return;
    }

    if (_isValidatingRecipient) {
      return;
    }

    setState(() => _selectedProduct = product);

    String? recipientName;
    bool requireRecipientName = _isEmoney;
    bool showRecipientHint = true;
    if (_isPln) {
      showRecipientHint = false;
      setState(() => _isValidatingRecipient = true);
      try {
        final result = await ApiService.ppobInquiryPln(customerNo: customerId);
        final status = (result['status'] ?? '').toString().toLowerCase();
        final message = (result['message'] ?? '').toString().toLowerCase();
        final isSuccess = status == 'success' ||
            status == 'sukses' ||
            message.contains('sukses');

        if (isSuccess && result['data'] != null) {
          final data = Map<String, dynamic>.from(result['data']);
          _inquiryResult = data;
          final name = _extractPlnCustomerName(data);
          if (name.toLowerCase().contains('tidak tersedia')) {
            Fluttertoast.showToast(msg: 'Nama pelanggan tidak tersedia');
          } else {
            recipientName = name;
          }
        } else {
          Fluttertoast.showToast(
              msg: result['message'] ?? 'Cek pelanggan gagal');
        }
      } catch (_) {
        Fluttertoast.showToast(msg: 'Kesalahan koneksi');
      } finally {
        if (mounted) setState(() => _isValidatingRecipient = false);
      }
    }
    if (_isTopupGameFiltered) {
      final gameCode = widget.configInquiryProvider?.trim() ?? '';
      Map<String, dynamic>? gameInquiryData;
      if (gameCode.isNotEmpty) {
        setState(() => _isValidatingRecipient = true);
        try {
          final result = await ApiService.checkGameUsername(
            gameCode: gameCode,
            userId: customerId,
          );
          if (mounted) setState(() => _isValidatingRecipient = false);
          final status = (result['status'] ?? '').toString().toLowerCase();
          final isSuccess = status == 'success' || status == 'sukses';
          if (isSuccess && result['data'] is Map) {
            final data = Map<String, dynamic>.from(result['data'] as Map);
            gameInquiryData = data;
            final name = (data['username'] ?? data['customer_name'] ?? '')
                .toString()
                .trim();
            if (name.isNotEmpty) recipientName = name;
          }
        } catch (_) {
          if (mounted) setState(() => _isValidatingRecipient = false);
        }
      }
      // gameInquiryData != null meskipun inquiry gagal — pakai Map kosong
      // supaya label 'ID Player' tetap tampil di halaman detail.
      gameInquiryData ??= {};
      showRecipientHint = false;
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PpobTransactionDetailTemplatePage(
            title: widget.title,
            product: product,
            customerId: customerId,
            brand: _selectedBrand ?? '-',
            recipientName: recipientName,
            requireRecipientName: false,
            showRecipientHint: false,
            isPlnToken: false,
            plnInquiryData: null,
            gameInquiryData: gameInquiryData,
            formatPrice: _formatPrice,
            onConfirm: () => _goToPin(product),
          ),
        ),
      );
      return;
    }
    if (_isEmoney) {
      setState(() => _isValidatingRecipient = true);
      final isEmoneyDynamic = _isEmoney &&
          !(widget.initialBrand != null &&
              widget.initialBrand!.trim().isNotEmpty);
      final categoryOverride =
          isEmoneyDynamic ? _selectedBrand : null;
      final brandForInquiry = (widget.initialBrand != null &&
              widget.initialBrand!.trim().isNotEmpty)
          ? widget.initialBrand
          : _selectedBrand;

      // Inquiry e-wallet selalu via Loketbayar (backend hardcoded brand→SKU
      // map). Brand di luar daftar didukung tidak punya inquiry → lanjut
      // tanpa verifikasi nama.
      const supportedInquiryBrands = {'gopay', 'dana', 'ovo', 'shopeepay'};
      final brandKey = (brandForInquiry ?? '')
          .toLowerCase()
          .replaceAll(RegExp(r'\s+'), '');
      final brandSupportsInquiry = supportedInquiryBrands.contains(brandKey);

      if (!brandSupportsInquiry) {
        requireRecipientName = false;
        Fluttertoast.showToast(
          msg:
              'Cek nama belum tersedia untuk brand ini, lanjut tanpa verifikasi nama',
        );
      } else {
        final checkSku = (product['inquiry_sku'] ?? product['buyer_sku_code'] ?? '').toString();
        final simulatedAmount = product['simulated_amount'];
        final customAmount = product['custom_amount'];
        final finalAmount = simulatedAmount ?? customAmount;
        recipientName = await _validateEmoneyRecipient(
          customerId,
          checkSku,
          categoryOverride: categoryOverride,
          brand: brandForInquiry,
          amount: finalAmount is num ? finalAmount.toDouble() : null,
        );
        if (recipientName == _verifiedWithoutNameToken) {
          recipientName = null;
          requireRecipientName = false;
          Fluttertoast.showToast(
            msg:
                'Verifikasi berhasil, namun nama penerima tidak dikirim provider',
          );
        }
      }

      if (!mounted) return;
      setState(() => _isValidatingRecipient = false);

      if (requireRecipientName && recipientName == null) {
        return;
      }
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PpobTransactionDetailTemplatePage(
          title: widget.title,
          product: product,
          customerId: customerId,
          brand: _selectedBrand ?? '-',
          recipientName: recipientName,
          requireRecipientName: requireRecipientName,
          showRecipientHint: showRecipientHint,
          isPlnToken: _isPln,
          plnInquiryData: _isPln ? _inquiryResult : null,
          formatPrice: _formatPrice,
          onConfirm: () => _goToPin(product),
        ),
      ),
    );
  }

  Future<void> _continuePlnPrabayar() async {
    _dismissInputAndNumpad();

    final product = _selectedProduct;
    if (product == null) {
      Fluttertoast.showToast(msg: 'Pilih nominal token terlebih dahulu');
      return;
    }

    final customerId = _customerIdController.text.trim();
    if (customerId.isEmpty) {
      Fluttertoast.showToast(msg: 'Masukkan IDPEL terlebih dahulu');
      return;
    }

    // Produk skip_inquiry: inquiry via Digiflazz (info pelanggan saja), tanpa ref_id
    if (product['skip_inquiry'] == true) {
      _lastInquiryRefId = null;
      _lastInquiryNominal = null;
      _lastInquiryKodeProduk = (product['buyer_sku_code'] ?? '').toString();

      setState(() => _isValidatingRecipient = true);
      String? recipientName;
      Map<String, dynamic>? inquiryData;
      try {
        final result = await ApiService.ppobInquiryPln(customerNo: customerId);
        final status = (result['status'] ?? '').toString().toLowerCase();
        final isSuccess = status == 'success' || status == 'sukses';
        if (isSuccess && result['data'] != null) {
          final data = Map<String, dynamic>.from(result['data'] as Map);
          // Normalize Digiflazz response to match expected field names
          inquiryData = {
            'customer_name': (data['name'] ?? data['customer_name'] ?? '').toString().trim(),
            'customer_no': data['customer_no'] ?? data['subscriber_id'] ?? customerId,
            'subscriber_id': data['subscriber_id'] ?? data['customer_no'] ?? customerId,
            'meter_no': data['meter_no'] ?? '',
            'tariff_daya': data['segment_power'] ?? data['tariff_daya'] ?? '',
          };
          final name = (inquiryData!['customer_name'] ?? '').toString();
          if (name.isNotEmpty && !name.toLowerCase().contains('tidak tersedia')) {
            recipientName = name;
          }
        }
      } catch (_) {}

      if (!mounted) return;
      setState(() => _isValidatingRecipient = false);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PpobTransactionDetailTemplatePage(
            title: widget.title,
            product: product,
            customerId: customerId,
            brand: _selectedBrand ?? '-',
            recipientName: recipientName,
            requireRecipientName: false,
            showRecipientHint: false,
            isPlnToken: true,
            plnInquiryData: inquiryData,
            formatPrice: _formatPrice,
            onConfirm: () => _goToPin(product),
          ),
        ),
      );
      return;
    }

    if (_isValidatingRecipient) return;

    setState(() => _isValidatingRecipient = true);
    String? recipientName;
    // Prioritas SKU/provider untuk inquiry:
    //   1. Admin override (configInquirySku / configInquiryProvider)
    //   2. SKU/provider produk yang dipilih user
    // Override admin dipakai supaya cek nama pelanggan PLN tidak
    // tergantung produk yang dipilih (bisa pakai SKU paling murah).
    final productSku = (product['buyer_sku_code'] ?? '').toString();
    final productProvider = (product['provider'] ?? '').toString().toLowerCase();
    final overrideProvider =
        widget.configInquiryProvider?.trim().toLowerCase() ?? '';
    // Token Listrik: inquiry selalu pakai SKU produk yang dipilih
    final buyerSku = productSku;
    final provider =
        overrideProvider.isNotEmpty ? overrideProvider : productProvider;
    try {
      final result = await ApiService.ppobInquiry(
        buyerSkuCode: buyerSku,
        customerNo: customerId,
        provider: provider.isEmpty ? null : provider,
        category: widget.category.isEmpty ? widget.title : widget.category,
        selectedSkuCode: productSku.isNotEmpty ? productSku : null,
      );
      final status = (result['status'] ?? '').toString().toLowerCase();
      final message = (result['message'] ?? '').toString().toLowerCase();
      final isSuccess = status == 'success' ||
          status == 'sukses' ||
          message.contains('sukses');

      if (isSuccess && result['data'] != null) {
        final data = Map<String, dynamic>.from(result['data']);
        _inquiryResult = data;
        // Capture ref_id and provider_nominal for Loket Bayar payment
        final refId = (data['ref_id'] ?? '').toString();
        if (refId.isNotEmpty) {
          _lastInquiryRefId = refId;
        }
        // Use provider_nominal (raw from Loket Bayar) for payment, not product total
        final providerNominal = data['provider_nominal'] ?? data['provider_total'] ?? data['total'];
        if (providerNominal != null) {
          _lastInquiryNominal = (providerNominal is int) ? providerNominal : int.tryParse(providerNominal.toString());
        }
        // Untuk Token Listrik, kode_produk payment = SKU produk yang dipilih
        _lastInquiryKodeProduk = productSku;
        final name = (data['customer_name'] ?? data['name'] ?? '').toString();
        if (name.isNotEmpty && !name.toLowerCase().contains('tidak tersedia')) {
          recipientName = name;
        }
      } else {
        Fluttertoast.showToast(msg: result['message'] ?? 'Cek pelanggan gagal');
        if (mounted) setState(() => _isValidatingRecipient = false);
        return;
      }
    } catch (_) {
      Fluttertoast.showToast(msg: 'Kesalahan koneksi');
      if (mounted) setState(() => _isValidatingRecipient = false);
      return;
    }

    if (!mounted) return;
    setState(() => _isValidatingRecipient = false);

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PpobTransactionDetailTemplatePage(
          title: widget.title,
          product: product,
          customerId: customerId,
          brand: _selectedBrand ?? '-',
          recipientName: recipientName,
          requireRecipientName: false,
          showRecipientHint: false,
          isPlnToken: true,
          plnInquiryData: _inquiryResult,
          formatPrice: _formatPrice,
          onConfirm: () => _goToPin(product),
        ),
      ),
    );
  }

  String? _validateCustomerIdByBrand(String customerId) {
    if (_isPln || _isTopupGameFiltered) {
      return null;
    }

    if (_isInject) {
      if (customerId.length < 5 || customerId.length > 30) {
        return 'Format serial number tidak valid';
      }
      return null;
    }

    if (!RegExp(r'^0[0-9]{9,14}$').hasMatch(customerId)) {
      return 'Format nomor tidak valid';
    }

    final brand = (_selectedBrand ?? widget.title).toUpperCase();
    final isStrictWallet = brand.contains('OVO') ||
        brand.contains('GO PAY') ||
        brand.contains('GOPAY') ||
        brand.contains('DANA');

    if (isStrictWallet && (customerId.length < 10 || customerId.length > 13)) {
      return 'Nomor tidak valid untuk $brand';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    notifire = Provider.of<ColorNotifire>(context, listen: true);
    final textPrimary = const Color(0xFF1D1D1D);
    final textSecondary = const Color(0xFF6B7280);
    final accent = const Color(0xFF3F6FB4);
    final headerBlue = const Color(0xFF3F6FB4);
    final pageBg = const Color(0xFFFAFAFA);
    final hasCustomerInput = _customerIdController.text.trim().isNotEmpty;
    final isPlnPrabayarTab = _isPln && _plnTabIndex == 0;
    final isPlnPostpaidTab = _isPln && _plnTabIndex == 1;
    final canContinuePlnPrabayar = isPlnPrabayarTab &&
        _selectedProduct != null &&
        hasCustomerInput;
    final isPulsaTransferTab = _isPulsaCategory && _pulsaTabIndex == 1;
    final shouldShowProducts =
        !isPlnPostpaidTab && (!_isCellularCategory || _isPulsaPrefixDetected || _isInject);
    // Sembunyikan tab brand horizontal jika:
    // 1. User datang dari brand-selection screen (initialBrand sudah di-set).
    // 2. Kategori E-Money/E-Wallet dengan brand spesifik.
    final hasInitialBrand = widget.initialBrand != null &&
        widget.initialBrand!.trim().isNotEmpty;
    // Admin override: kalau configShowBrandTabs di-set, hormati nilainya
    // (true=paksa tampil, false=paksa sembunyi). Kalau null, pakai heuristik.
    final bool showBrandTabs = widget.configShowBrandTabs ??
        (_brands.isNotEmpty &&
            !_isTopupGameFiltered &&
            !(_isEmoney && hasInitialBrand) &&
            !(hasInitialBrand && _brands.length <= 1));

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: pageBg,
      bottomNavigationBar: isPlnPrabayarTab
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: SizedBox(
                  height: 50,
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (canContinuePlnPrabayar &&
                            !_isValidatingRecipient)
                        ? _continuePlnPrabayar
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      disabledBackgroundColor:
                          accent.withValues(alpha: 0.35),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isValidatingRecipient
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Lanjutkan',
                            style: TextStyle(
                              fontFamily: 'Gilroy Bold',
                              fontSize: 15,
                            ),
                          ),
                  ),
                ),
              ),
            )
          : null,
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: headerBlue,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarBrightness: Brightness.dark,
          statusBarIconBrightness: Brightness.light,
          statusBarColor: Colors.transparent,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          widget.title,
          style: const TextStyle(
            color: Colors.white,
            fontFamily: 'Gilroy Bold',
            fontSize: 18,
          ),
        ),
      ),
      body: Stack(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _dismissInputAndNumpad,
            child: Column(
              children: [
                if (!_isInternetHub && !_isMultifinanceHub)
                Container(
                  color: headerBlue,
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
                        Text(
                          // Prioritas: config dari admin → heuristik existing.
                          widget.configInputLabel != null &&
                                  widget.configInputLabel!.trim().isNotEmpty
                              ? widget.configInputLabel!
                              : _isPln
                                  ? 'IDPEL'
                                  : _isTopupGameFiltered
                                      ? 'ID Player'
                                      : (_isCategoryInquiry
                                          ? 'ID Pelanggan'
                                          : 'Masukan Nomor HP'),
                          style: const TextStyle(
                            color: Color(0xFF121212),
                            fontFamily: 'Gilroy Bold',
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 48,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF3F4F6),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: const Color(0xFFD4D8DF)),
                                ),
                                child: TextField(
                                  controller: _customerIdController,
                                  focusNode: _customerIdFocusNode,
                                  readOnly: _enableCustomNumpad,
                                  showCursor: true,
                                  keyboardType: TextInputType.phone,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly
                                  ],
                                  style: TextStyle(
                                    color: textPrimary,
                                    fontFamily: 'Gilroy Medium',
                                    fontSize: 14,
                                  ),
                                  onChanged: (value) {
                                    final digitsOnly =
                                        value.replaceAll(RegExp(r'[^0-9]'), '');
                                    if (value != digitsOnly) {
                                      _setCustomerId(digitsOnly);
                                      return;
                                    }
                                    _onCustomerInputChanged();
                                    if (_isPln &&
                                        _plnTabIndex == 1 &&
                                        (_plnPostpaidInquiryResult != null ||
                                            _plnPostpaidError != null)) {
                                      setState(() {
                                        _plnPostpaidInquiryResult = null;
                                        _plnPostpaidError = null;
                                      });
                                    }
                                    if (_isCategoryInquiry &&
                                        (_bpjsInquiryResult != null ||
                                            _bpjsInquiryError != null)) {
                                      setState(() {
                                        _bpjsInquiryResult = null;
                                        _bpjsInquiryError = null;
                                      });
                                    }
                                  },
                                  onTap: () {
                                    if (!_customerIdFocusNode.hasFocus) {
                                      _customerIdFocusNode.requestFocus();
                                    }
                                    _showCustomNumpadSafely();
                                  },
                                  decoration: InputDecoration(
                                    hintText: widget.configInputHint != null &&
                                            widget.configInputHint!
                                                .trim()
                                                .isNotEmpty
                                        ? widget.configInputHint!
                                        : _isPln
                                            ? 'IDPEL : 1122xxxx'
                                            : _isTopupGameFiltered
                                                ? 'Masukkan ID Player'
                                                : _isCategoryInquiry
                                                    ? _categoryInquiryHint()
                                                    : 'Contoh : 08xxxxxxxxxx',
                                    hintStyle: TextStyle(
                                      color:
                                          textSecondary.withValues(alpha: 0.6),
                                      fontFamily: 'Gilroy Medium',
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: _pickNumberFromContact,
                              child: Padding(
                                padding: const EdgeInsets.all(2),
                                child: Icon(
                                  Icons.contact_page_outlined,
                                  color: accent,
                                  size: 34,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (_isPln && _isPlnPostpaidOnly)
                  const SizedBox.shrink()
                else if (_isPln)
                  Container(
                    margin: const EdgeInsets.only(top: 0),
                    decoration: const BoxDecoration(color: Colors.white),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              if (_plnTabIndex == 0) return;
                              setState(() {
                                _plnTabIndex = 0;
                                _plnPostpaidInquiryResult = null;
                              });
                            },
                            child: Container(
                              height: 48,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                border: Border(
                                  right: const BorderSide(
                                      color: Color(0xFFD9DEE7)),
                                  bottom: BorderSide(
                                    color: _plnTabIndex == 0
                                        ? accent
                                        : const Color(0xFFD9DEE7),
                                    width: _plnTabIndex == 0 ? 3 : 1,
                                  ),
                                ),
                              ),
                              child: Text(
                                'Prabayar',
                                style: TextStyle(
                                  color: Color(0xFF3A3A3A),
                                  fontFamily: _plnTabIndex == 0
                                      ? 'Gilroy Bold'
                                      : 'Gilroy Medium',
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              if (_plnTabIndex == 1) return;
                              setState(() {
                                _plnTabIndex = 1;
                                _selectedProduct = null;
                                _inquiryResult = null;
                              });
                            },
                            child: Container(
                              height: 48,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: _plnTabIndex == 1
                                        ? accent
                                        : const Color(0xFFD9DEE7),
                                    width: _plnTabIndex == 1 ? 3 : 1,
                                  ),
                                ),
                              ),
                              child: Text(
                                'Pascabayar',
                                style: TextStyle(
                                  color: Color(0xFF3A3A3A),
                                  fontFamily: _plnTabIndex == 1
                                      ? 'Gilroy Bold'
                                      : 'Gilroy Medium',
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else if (_isPulsaCategory && _brands.length >= 2)
                  Container(
                    margin: const EdgeInsets.only(top: 0),
                    decoration: const BoxDecoration(color: Colors.white),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              setState(() => _pulsaTabIndex = 0);

                              final customerId =
                                  _customerIdController.text.trim();
                              if (customerId.isNotEmpty) {
                                await _handlePulsaPrefixAutoSwitch(customerId);
                              }

                              if (_isPulsaPrefixDetected && _products.isEmpty) {
                                await _loadProducts(showLoading: true);
                              }
                            },
                            child: Container(
                              height: 48,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                border: Border(
                                  right: const BorderSide(
                                      color: Color(0xFFD9DEE7)),
                                  bottom: BorderSide(
                                    color: _pulsaTabIndex == 0
                                        ? accent
                                        : const Color(0xFFD9DEE7),
                                    width: _pulsaTabIndex == 0 ? 3 : 1,
                                  ),
                                ),
                              ),
                              child: Text(
                                'Pulsa',
                                style: TextStyle(
                                  color: const Color(0xFF3A3A3A),
                                  fontFamily: _pulsaTabIndex == 0
                                      ? 'Gilroy Bold'
                                      : 'Gilroy Medium',
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              setState(() {
                                _pulsaTabIndex = 1;
                                _products = [];
                              });

                              if (_selectedBrand != null) {
                                await _loadProducts(showLoading: true);
                              }
                            },
                            child: Container(
                              height: 48,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: _pulsaTabIndex == 1
                                        ? accent
                                        : const Color(0xFFD9DEE7),
                                    width: _pulsaTabIndex == 1 ? 3 : 1,
                                  ),
                                ),
                              ),
                              child: Text(
                                'Pulsa Transfer',
                                style: TextStyle(
                                  color: const Color(0xFF3A3A3A),
                                  fontFamily: _pulsaTabIndex == 1
                                      ? 'Gilroy Bold'
                                      : 'Gilroy Medium',
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                Expanded(
                  child: _isEmoney && !hasInitialBrand
                      ? (_ewalletBrandPicked
                          ? _buildEwalletProductsView(
                              textPrimary, textSecondary, accent)
                          : _buildEwalletList(
                              textPrimary, textSecondary, accent))
                      : _isEmoney && hasInitialBrand
                          ? _buildEwalletWithDynamicView(
                              textPrimary, textSecondary, accent)
                      : _isInternetHub
                          ? _buildInternetHub(textPrimary, textSecondary, accent)
                          : _isMultifinanceHub
                          ? _buildMultifinanceHub(textPrimary, textSecondary, accent)
                          : _isCategoryInquiry
                          ? _buildBpjsSection(textPrimary, textSecondary)
                          : isPlnPostpaidTab
                          ? _buildPlnPostpaidSection(textPrimary, textSecondary)
                          : (showBrandTabs ||
                                  _isTopupGameFiltered ||
                                  // Admin config kasih layout eksplisit
                                  // (mis. Token PLN: list 1 kolom tanpa brand tab)
                                  (widget.configProductLayout != null &&
                                      widget.configProductLayout!.trim().isNotEmpty))
                              ? Column(
                                  children: [
                                    if (showBrandTabs) ...[
                                      SizedBox(
                                        height: 42,
                                        child: ListView.builder(
                                          scrollDirection: Axis.horizontal,
                                          padding: const EdgeInsets.symmetric(horizontal: 16),
                                          itemCount: _brands.length,
                                          itemBuilder: (_, i) {
                                            final brand = _brands[i].toString();
                                            final selected = _selectedBrand == brand;
                                            return Padding(
                                              padding: const EdgeInsets.only(right: 8),
                                              child: ChoiceChip(
                                                selected: selected,
                                                side: BorderSide.none,
                                                selectedColor: accent.withValues(alpha: 0.15),
                                                backgroundColor: Colors.white,
                                                labelStyle: TextStyle(
                                                  color: selected ? accent : textPrimary,
                                                  fontFamily:
                                                      selected ? 'Gilroy Bold' : 'Gilroy Medium',
                                                ),
                                                label: Text(brand),
                                                onSelected: (_) => _selectBrand(brand),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      const SizedBox(height: 4),
                                    ],
                                    Expanded(
                                      child: !shouldShowProducts
                                          ? Center(
                                              child: isPulsaTransferTab
                                                  ? Column(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        SizedBox(
                                                          height: 240,
                                                          width: 240,
                                                          child: Lottie.asset(
                                                              'assets/lottie/empty_cart.json'),
                                                        ),
                                                      ],
                                                    )
                                                  : Text(
                                                      hasCustomerInput && _isCellularCategory
                                                          ? 'Prefix nomor tidak terdeteksi'
                                                          : 'Harap masukan no.hp terlebih dahulu',
                                                      style: TextStyle(
                                                        color: textSecondary.withValues(
                                                            alpha: 0.6),
                                                        fontFamily: 'Gilroy Medium',
                                                        fontSize: 18,
                                                      ),
                                                    ),
                                            )
                                          : _isLoadingProducts
                                              ? _buildShimmerProducts()
                                              : _products.isEmpty
                                                  ? Center(
                                                      child: Text(
                                                        'Belum ada produk tersedia',
                                                        style: TextStyle(
                                                          color: textSecondary,
                                                          fontFamily: 'Gilroy Medium',
                                                        ),
                                                      ),
                                                    )
                                                  : RepaintBoundary(
                                                      child: NotificationListener<
                                                          UserScrollNotification>(
                                                        onNotification: (notification) {
                                                          if (notification.direction !=
                                                              ScrollDirection.idle) {
                                                            _hideCustomNumpad();
                                                          }
                                                          return false;
                                                        },
                                                        child: GridView.builder(
                                                          padding: const EdgeInsets.fromLTRB(
                                                              16, 0, 16, 16),
                                                          physics:
                                                              const ClampingScrollPhysics(),
                                                          itemCount: _products.length,
                                                          gridDelegate:
                                                              SliverGridDelegateWithFixedCrossAxisCount(
                                                            // Prioritas: config admin
                                                            // (configProductLayout='list' → 1 kolom,
                                                            //  configProductColumns → N kolom)
                                                            // → fallback heuristik existing.
                                                            crossAxisCount: () {
                                                              final cfgLayout = widget
                                                                  .configProductLayout
                                                                  ?.toLowerCase();
                                                              if (cfgLayout == 'list') return 1;
                                                              if (widget.configProductColumns !=
                                                                      null &&
                                                                  widget.configProductColumns! >= 1 &&
                                                                  widget.configProductColumns! <= 3) {
                                                                return widget.configProductColumns!;
                                                              }
                                                              return (isPlnPrabayarTab ||
                                                                      _isTopupGameFiltered)
                                                                  ? 1
                                                                  : 2;
                                                            }(),
                                                            crossAxisSpacing: 10,
                                                            mainAxisSpacing: 10,
                                                            mainAxisExtent: () {
                                                              final cfgLayout = widget
                                                                  .configProductLayout
                                                                  ?.toLowerCase();
                                                              final isList = cfgLayout == 'list' ||
                                                                  isPlnPrabayarTab ||
                                                                  _isTopupGameFiltered;
                                                              if (isPlnPrabayarTab) return 100.0;
                                                              if (_isTopupGameFiltered) return 124.0;
                                                              if (isList) return 100.0;
                                                              return 148.0;
                                                            }(),
                                                          ),
                                                          itemBuilder: (_, i) {
                                                            final p = Map<String, dynamic>.from(
                                                                _products[i]);
                                                            final isPromo = _isPromoProduct(p);
                                                            final originalPrice =
                                                                _originalPrice(p);
                                                            final promoPrice = _promoPrice(p);
                                                            final rewardCoins =
                                                                _extractRewardCoins(p);
                                                            final isSelected = (_isEmoney ||
                                                                    (_isPln &&
                                                                        _plnTabIndex == 0)) &&
                                                                _selectedProduct != null &&
                                                                _selectedProduct![
                                                                        'buyer_sku_code'] ==
                                                                    p['buyer_sku_code'];
                                                            final providerLogoAsset =
                                                                _isCellularCategory
                                                                    ? _pulsaProviderLogoAsset(p)
                                                                    : '';

                                                            return Material(
                                                              color: Colors.white,
                                                              borderRadius:
                                                                  BorderRadius.circular(12),
                                                              elevation: 16,
                                                              shadowColor: Colors.black
                                                                  .withValues(alpha: 0.18),
                                                              child: Container(
                                                                child: Ink(
                                                                  decoration: BoxDecoration(
                                                                    color: Colors.white,
                                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                    border: Border.all(
                                                      color: isSelected
                                                          ? accent.withValues(
                                                              alpha: 0.35)
                                                          : Colors.transparent,
                                                    ),
                                                  ),
                                                  child: InkWell(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                    onTap: () =>
                                                        _onProductSelected(p),
                                                    child: Padding(
                                                      padding: const EdgeInsets
                                                          .fromLTRB(
                                                          10, 10, 10, 10),
                                                      child: Stack(
                                                        children: [
                                                          if (providerLogoAsset
                                                              .isNotEmpty)
                                                            Positioned(
                                                              right: 6,
                                                              bottom: 2,
                                                              child: Opacity(
                                                                opacity: 0.30,
                                                                child:
                                                                    Image.asset(
                                                                  providerLogoAsset,
                                                                  width: 72,
                                                                  height: 72,
                                                                  fit: BoxFit
                                                                      .contain,
                                                                ),
                                                              ),
                                                            ),
                                                          Row(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment.start,
                                                            children: [
                                                              Expanded(
                                                                child: Column(
                                                                  crossAxisAlignment:
                                                                      CrossAxisAlignment.start,
                                                                  mainAxisSize:
                                                                      MainAxisSize.min,
                                                                  children: [
                                                                    Text(
                                                                      p['product_name'] ?? '-',
                                                                      maxLines: 2,
                                                                      overflow: TextOverflow.ellipsis,
                                                                      style: TextStyle(
                                                                        color: textPrimary,
                                                                        fontFamily: 'Gilroy Bold',
                                                                        fontSize: 14,
                                                                      ),
                                                                    ),
                                                                    const SizedBox(height: 4),
                                                                    if (isPromo)
                                                                      Text(
                                                                        _formatPrice(originalPrice),
                                                                        style: TextStyle(
                                                                          color: textSecondary,
                                                                          fontFamily: 'Gilroy Medium',
                                                                          fontSize: 11,
                                                                          decoration: TextDecoration.lineThrough,
                                                                        ),
                                                                      ),
                                                                    if (isPromo)
                                                                      const SizedBox(height: 2),
                                                                    Text(
                                                                      _formatPrice(isPromo ? promoPrice : p['price']),
                                                                      style: TextStyle(
                                                                        color: isPromo
                                                                            ? const Color(0xFFE53935)
                                                                            : accent,
                                                                        fontFamily: 'Gilroy Bold',
                                                                        fontSize: 18,
                                                                      ),
                                                                    ),
                                                                    if (rewardCoins != null && !isPromo) ...[
                                                                      const SizedBox(height: 4),
                                                                      Text(
                                                                        '+$rewardCoins coin',
                                                                        style: const TextStyle(
                                                                          color: Color(0xFFFF9800),
                                                                          fontFamily: 'Gilroy Bold',
                                                                          fontSize: 11,
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ],
                                                                ),
                                                              ),
                                                              if (isPromo)
                                                                Container(
                                                                  margin: const EdgeInsets.only(left: 6),
                                                                  child: Column(
                                                                    crossAxisAlignment: CrossAxisAlignment.end,
                                                                    mainAxisSize: MainAxisSize.min,
                                                                    children: [
                                                                      Container(
                                                                        padding: const EdgeInsets.symmetric(
                                                                          horizontal: 6,
                                                                          vertical: 2,
                                                                        ),
                                                                        decoration: BoxDecoration(
                                                                          color: const Color(0xFFE53935),
                                                                          borderRadius: BorderRadius.circular(6),
                                                                        ),
                                                                        child: const Text(
                                                                          'PROMO',
                                                                          style: TextStyle(
                                                                            color: Colors.white,
                                                                            fontFamily: 'Gilroy Bold',
                                                                            fontSize: 9,
                                                                          ),
                                                                        ),
                                                                      ),
                                                                      const SizedBox(height: 4),
                                                                      Text(
                                                                        _promoRemainingLabel(p),
                                                                        style: const TextStyle(
                                                                          color: Color(0xFFEF6C00),
                                                                          fontFamily: 'Gilroy Medium',
                                                                          fontSize: 10,
                                                                        ),
                                                                      ),
                                                                      if (rewardCoins != null) ...[
                                                                        const SizedBox(height: 2),
                                                                        Text(
                                                                          '+$rewardCoins coin',
                                                                          style: const TextStyle(
                                                                            color: Color(0xFFFF9800),
                                                                            fontFamily: 'Gilroy Bold',
                                                                            fontSize: 11,
                                                                          ),
                                                                        ),
                                                                      ],
                                                                    ],
                                                                  ),
                                                                ),
                                                            ],
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
                                    ),
                                  ),
                                  ],
                                )
                              : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
          if (_enableCustomNumpad && _showCustomNumpad)
            Align(
              alignment: Alignment.bottomCenter,
              child: _buildCustomNumpad(accent, textPrimary, textSecondary),
            ),
          if (_isValidatingRecipient)
            Positioned.fill(
              child: AbsorbPointer(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.35),
                  alignment: Alignment.center,
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          height: 28,
                          width: 28,
                          child: CircularProgressIndicator(strokeWidth: 3),
                        ),
                        SizedBox(height: 10),
                        Text(
                          'Memuat...',
                          style: TextStyle(
                            color: Color(0xFF1D1D1D),
                            fontFamily: 'Gilroy Medium',
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _onEwalletBrandTap(String brandName) async {
    final phone = _customerIdController.text.trim();
    if (phone.isEmpty) {
      Fluttertoast.showToast(msg: 'Masukan Nomor HP terlebih dahulu');
      _customerIdFocusNode.requestFocus();
      return;
    }
    setState(() {
      _ewalletBrandPicked = true;
      _selectedBrand = brandName;
      _selectedProduct = null;
      _products = [];
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedBrandCacheKey, brandName);
    // Selalu fetch fresh agar tidak terjebak cache kosong dari fetch lama.
    await _loadProducts(showLoading: true);
  }

  void _backToEwalletList() {
    setState(() {
      _ewalletBrandPicked = false;
      _selectedBrand = null;
      _selectedProduct = null;
      _products = [];
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // E-Wallet UI: Produk Statis (Digiflazz) + Dinamis (Loket Bayar)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Memisahkan produk statis (nominal tetap, dari Digiflazz) dan dinamis
  /// (nominal custom, dari Loket Bayar) berdasarkan flag `is_dynamic` atau
  /// provider == 'loketbayar'.
  bool _isDynamicProduct(Map<String, dynamic> p) {
    if (p['simulated_amount'] != null) return false;
    if (p['is_dynamic'] == true) return true;
    final provider = (p['provider'] ?? '').toString().toLowerCase();
    final isLb = provider.contains('loketbayar') || provider.contains('loket_bayar');
    if (isLb) {
      final name = (p['product_name'] ?? '').toString().toLowerCase();
      if (!name.contains('nominal bebas') && !name.contains('bebas')) {
        return false;
      }
      return true;
    }
    return false;
  }

  List<dynamic> get _staticProducts {
    final list = _products.where((p) => !_isDynamicProduct(Map<String, dynamic>.from(p))).toList();
    if (list.isNotEmpty) return list;

    if (!_isEmoney) return [];

    final dynamicProd = _products.firstWhere(
      (p) => _isDynamicProduct(Map<String, dynamic>.from(p)),
      orElse: () => null,
    );
    if (dynamicProd == null) return [];

    final dp = Map<String, dynamic>.from(dynamicProd as Map);
    final brandName = _selectedBrand ?? dp['operator_name'] ?? dp['brand'] ?? '';
    
    final simulated = <dynamic>[];
    final presets = [10000, 20000, 50000, 100000, 200000, 500000];
    for (final amt in presets) {
      final newProd = Map<String, dynamic>.from(dp);
      final adminFee = (dp['admin_fee'] ?? dp['admin'] ?? 0.0) is num
          ? (dp['admin_fee'] ?? dp['admin'] ?? 0.0).toDouble()
          : double.tryParse((dp['admin_fee'] ?? dp['admin'] ?? 0.0).toString()) ?? 0.0;
      final price = amt.toDouble() + adminFee;
      
      newProd['product_name'] = '$brandName ${NumberFormat('#,###', 'id_ID').format(amt)}';
      newProd['price'] = price;
      newProd['simulated_amount'] = amt;
      simulated.add(newProd);
    }
    return simulated;
  }

  List<dynamic> get _dynamicProducts =>
      _products.where((p) => _isDynamicProduct(Map<String, dynamic>.from(p))).toList();

  void _onCustomAmountSubmit() {
    final amountText = _customAmountController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final amount = int.tryParse(amountText) ?? 0;
    if (amount < 1000) {
      Fluttertoast.showToast(msg: 'Minimal nominal Rp 10.000');
      return;
    }
    if (amount > 10000000) {
      Fluttertoast.showToast(msg: 'Maksimal nominal Rp 10.000.000');
      return;
    }

    final brandName = _selectedBrand ?? widget.initialBrand ?? 'DANA';

    // Map brand ke SKU Loket Bayar
    final brandSkuMap = <String, Map<String, String>>{
      'dana': {'inquiry_sku': 'DANA', 'buyer_sku_code': 'DANA'},
      'gopay': {'inquiry_sku': 'GOPAYP', 'buyer_sku_code': 'GOPAYP'},
      'ovo': {'inquiry_sku': 'OVO', 'buyer_sku_code': 'OVOP'},
      'shopeepay': {'inquiry_sku': 'SHOPEEP', 'buyer_sku_code': 'SHOPEEP'},
    };
    final brandKey = brandName.toLowerCase().replaceAll(RegExp(r'\s+'), '');
    final skuInfo = brandSkuMap[brandKey] ?? {'inquiry_sku': brandName.toUpperCase(), 'buyer_sku_code': '${brandName.toUpperCase()}P'};

    // Produk virtual untuk custom nominal.
    // - inquiry_sku: SKU untuk cek nama penerima
    // - buyer_sku_code: SKU untuk transaksi pembelian
    final customProduct = <String, dynamic>{
      'buyer_sku_code': skuInfo['buyer_sku_code'],
      'inquiry_sku': skuInfo['inquiry_sku'],
      'product_name': '$brandName Rp ${_currencyFormat.format(amount)}',
      'price': amount,
      'custom_amount': amount,
      'brand': brandName,
      'provider': 'loketbayar',
      'category': widget.category,
      'is_dynamic': true,
    };
    _onProductSelected(customProduct);
  }

  Widget _buildEwalletWithDynamicView(
      Color textPrimary, Color textSecondary, Color accent) {
    final quickAmounts = [10000, 20000, 50000, 100000, 200000, 500000];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _isLoadingProducts
              ? _buildShimmerProducts()
              : _buildCustomAmountSection(
                  textPrimary, textSecondary, accent, quickAmounts),
        ),
      ],
    );
  }

  Widget _buildTabChip({
    required String label,
    required bool isActive,
    required Color accent,
    required Color textPrimary,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? accent.withValues(alpha: 0.12) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? accent : Colors.grey.shade300,
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? accent : textPrimary.withValues(alpha: 0.7),
            fontFamily: isActive ? 'Gilroy Bold' : 'Gilroy Medium',
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildStaticProductGrid(List<dynamic> staticList, Color textPrimary,
      Color textSecondary, Color accent) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      physics: const ClampingScrollPhysics(),
      itemCount: staticList.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        mainAxisExtent: 100,
      ),
      itemBuilder: (_, i) {
        final p = Map<String, dynamic>.from(staticList[i]);
        final isPromo = _isPromoProduct(p);
        final originalPrice = _originalPrice(p);
        final promoPrice = _promoPrice(p);
        final isSelected = _selectedProduct != null &&
            _selectedProduct!['buyer_sku_code'] == p['buyer_sku_code'];

        return Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          elevation: isSelected ? 4 : 1,
          shadowColor: isSelected
              ? accent.withValues(alpha: 0.3)
              : Colors.black.withValues(alpha: 0.08),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _onProductSelected(p),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? accent : Colors.grey.shade200,
                  width: isSelected ? 2 : 1,
                ),
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    (p['product_name'] ?? '-').toString(),
                    style: TextStyle(
                      color: textPrimary,
                      fontFamily: 'Gilroy Bold',
                      fontSize: 13,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  if (isPromo)
                    Text(
                      _formatPrice(originalPrice),
                      style: TextStyle(
                        color: textSecondary,
                        fontFamily: 'Gilroy Medium',
                        fontSize: 11,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                  Text(
                    _formatPrice(isPromo ? promoPrice : p['price']),
                    style: TextStyle(
                      color: isPromo ? const Color(0xFFE53935) : accent,
                      fontFamily: 'Gilroy Bold',
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCustomAmountSection(Color textPrimary, Color textSecondary,
      Color accent, List<int> quickAmounts) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Input nominal ─────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Masukkan Nominal',
                  style: TextStyle(
                    color: textPrimary,
                    fontFamily: 'Gilroy Bold',
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _customAmountController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  style: TextStyle(
                    color: textPrimary,
                    fontFamily: 'Gilroy Bold',
                    fontSize: 22,
                  ),
                  decoration: InputDecoration(
                    prefixText: 'Rp ',
                    prefixStyle: TextStyle(
                      color: textPrimary,
                      fontFamily: 'Gilroy Bold',
                      fontSize: 22,
                    ),
                    hintText: '0',
                    hintStyle: TextStyle(
                      color: textSecondary.withValues(alpha: 0.4),
                      fontFamily: 'Gilroy Medium',
                      fontSize: 22,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: accent, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Min. Rp 10.000 — Maks. Rp 10.000.000',
                  style: TextStyle(
                    color: textSecondary.withValues(alpha: 0.6),
                    fontFamily: 'Gilroy Medium',
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ─── Quick amount chips ────────────────────────────────
          Text(
            'Pilih Cepat',
            style: TextStyle(
              color: textPrimary,
              fontFamily: 'Gilroy Bold',
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: quickAmounts.map((amount) {
              final isSelected =
                  _customAmountController.text == amount.toString();
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _customAmountController.text = amount.toString();
                  });
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? accent.withValues(alpha: 0.12)
                        : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? accent : Colors.grey.shade300,
                    ),
                  ),
                  child: Text(
                    'Rp ${_currencyFormat.format(amount)}',
                    style: TextStyle(
                      color: isSelected ? accent : textPrimary,
                      fontFamily:
                          isSelected ? 'Gilroy Bold' : 'Gilroy Medium',
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // ─── Tombol Lanjutkan ──────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _onCustomAmountSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Lanjutkan',
                style: TextStyle(
                  fontFamily: 'Gilroy Bold',
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEwalletProductsView(
      Color textPrimary, Color textSecondary, Color accent) {
    final quickAmounts = [10000, 20000, 50000, 100000, 200000, 500000];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 16, 8),
          child: Row(
            children: [
              IconButton(
                onPressed: _backToEwalletList,
                icon: Icon(Icons.arrow_back_rounded, color: textPrimary),
                splashRadius: 22,
              ),
              Text(
                _selectedBrand ?? '',
                style: TextStyle(
                  color: textPrimary,
                  fontFamily: 'Gilroy Bold',
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoadingProducts
              ? _buildShimmerProducts()
              : _buildCustomAmountSection(
                  textPrimary, textSecondary, accent, quickAmounts),
        ),
      ],
    );
  }

  Widget _buildEwalletList(Color textPrimary, Color textSecondary, Color accent) {
    final ewalletBrands = [
      {'name': 'GoPay', 'logo': 'images/ewallet_logos/gopay.svg', 'icon': Icons.account_balance_wallet, 'color': const Color(0xFF00AED6)},
      {'name': 'DANA', 'logo': 'images/ewallet_logos/dana.svg', 'icon': Icons.chat_bubble, 'color': const Color(0xFF108EE9)},
      {'name': 'OVO', 'logo': 'images/ewallet_logos/ovo.svg', 'icon': Icons.circle_outlined, 'color': const Color(0xFF4C3494)},
      {'name': 'ShopeePay', 'logo': 'images/ewallet_logos/shopeepay.svg', 'icon': Icons.shopping_bag, 'color': const Color(0xFFEE4D2D)},
      {'name': 'LinkAja', 'logo': 'images/ewallet_logos/linkaja.svg', 'icon': Icons.link, 'color': const Color(0xFFE42313)},
      {'name': 'DOKU', 'logo': 'images/ewallet_logos/DOKU.svg', 'icon': Icons.payments, 'color': const Color(0xFFE74C3C)},
      {'name': 'KasPro', 'logo': 'images/ewallet_logos/kaspro.svg', 'icon': Icons.account_balance_wallet, 'color': const Color(0xFF4CAF50)},
      {'name': 'iSaku', 'logo': 'images/ewallet_logos/isaku.svg', 'icon': Icons.info_outline, 'color': const Color(0xFF00B0F0)},
    ];

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: ewalletBrands.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, index) {
        final brand = ewalletBrands[index];
        final brandName = brand['name'] as String;
        final brandIcon = brand['icon'] as IconData;
        final brandColor = brand['color'] as Color;
        final brandLogo = brand['logo'] as String?;

        return InkWell(
          onTap: () => _onEwalletBrandTap(brandName),
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: textSecondary.withValues(alpha: 0.14),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: (brandLogo != null && brandLogo.isNotEmpty)
                        ? (brandLogo.toLowerCase().endsWith('.svg')
                            ? SvgPicture.asset(
                                brandLogo,
                                fit: BoxFit.contain,
                                placeholderBuilder: (_) => Icon(
                                  brandIcon,
                                  color: brandColor,
                                  size: 24,
                                ),
                              )
                            : Image.asset(
                                brandLogo,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => Icon(
                                  brandIcon,
                                  color: brandColor,
                                  size: 24,
                                ),
                              ))
                        : Icon(
                            brandIcon,
                            color: brandColor,
                            size: 24,
                          ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      brandName,
                      style: TextStyle(
                        color: textPrimary,
                        fontFamily: 'Gilroy Bold',
                        fontSize: 15,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: textSecondary.withValues(alpha: 0.45),
                    size: 24,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PlnPostpaidInlinePinScreen extends StatefulWidget {
  final String buyerSkuCode;
  final String customerNo;
  final String productName;
  final String customerName;
  final double amount;

  const _PlnPostpaidInlinePinScreen({
    required this.buyerSkuCode,
    required this.customerNo,
    required this.productName,
    required this.customerName,
    required this.amount,
  });

  @override
  State<_PlnPostpaidInlinePinScreen> createState() =>
      _PlnPostpaidInlinePinScreenState();
}

class _PlnPostpaidInlinePinScreenState
    extends State<_PlnPostpaidInlinePinScreen> {
  final TextEditingController _pinController = TextEditingController();
  final NumberFormat _currencyFormat = NumberFormat('#,###', 'id_ID');
  bool _isLoading = false;
  bool _usedBiometric = false;

  String _formatPrice(double amount) =>
      'Rp ${_currencyFormat.format(amount.toInt())}';

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _handleBiometricPay() async {
    if (_isLoading) return;
    final success = await BiometricService.authenticate(
      reason: 'Konfirmasi pembayaran ${widget.productName}',
    );
    if (!success || !mounted) return;
    _usedBiometric = true;
    await _submitPayment(pin: '');
  }

  Future<void> _submitPayment({required String pin}) async {
    if (_isLoading) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.pinRequired && !_usedBiometric && pin.length != 4) {
      Fluttertoast.showToast(msg: 'Masukkan PIN 4 digit');
      return;
    }

    setState(() => _isLoading = true);
    final stopwatch = Stopwatch()..start();

    try {
      final response = await ApiService.purchasePpobPostpaid(
        buyerSkuCode: widget.buyerSkuCode,
        customerNo: widget.customerNo,
        pin: pin,
        amount: widget.amount,
        biometricAuth: _usedBiometric,
      );

      stopwatch.stop();
      if (!mounted) return;
      setState(() => _isLoading = false);

      if (response.containsKey('transaction')) {
        Provider.of<AuthProvider>(context, listen: false).updateBalance();
        final tx = response['transaction'] as Map<String, dynamic>? ?? {};
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
      if (!mounted) return;
      setState(() => _isLoading = false);
      Fluttertoast.showToast(
        msg: ApiService.userFriendlyMessage(e, fallback: 'Pembayaran gagal'),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final needPin = auth.pinRequired;

    return Scaffold(
      backgroundColor: const Color(0xFF0D47A1),
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Konfirmasi Pembayaran',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Gilroy Bold',
            fontSize: 17,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.productName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'Gilroy Bold',
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.customerName,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontFamily: 'Gilroy Medium',
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _formatPrice(widget.amount),
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'Gilroy Bold',
                        fontSize: 24,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (needPin)
                TextField(
                  controller: _pinController,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: 'Masukkan PIN 4 digit',
                    hintStyle:
                        TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                          color: Colors.white.withValues(alpha: 0.25)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                          color: Colors.white.withValues(alpha: 0.25)),
                    ),
                  ),
                ),
              if (needPin) const SizedBox(height: 10),
              FutureBuilder<bool>(
                future: BiometricService.isAvailable(),
                builder: (context, snapshot) {
                  final available = snapshot.data == true;
                  if (!available) return const SizedBox.shrink();
                  return TextButton(
                    onPressed: _isLoading ? null : _handleBiometricPay,
                    child: Text(
                      'Gunakan Sidik Jari / Face ID',
                      style:
                          TextStyle(color: Colors.white.withValues(alpha: 0.9)),
                    ),
                  );
                },
              ),
              const Spacer(),
              SizedBox(
                height: 46,
                child: ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : () => _submitPayment(pin: _pinController.text.trim()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    disabledBackgroundColor:
                        Colors.white.withValues(alpha: 0.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Konfirmasi Pembayaran',
                          style: TextStyle(
                            color: Colors.white,
                            fontFamily: 'Gilroy Bold',
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PpobTransactionDetailTemplatePage extends StatefulWidget {
  final String title;
  final Map<String, dynamic> product;
  final String customerId;
  final String brand;
  final String? recipientName;
  final bool requireRecipientName;
  final bool showRecipientHint;
  final bool isPlnToken;
  final Map<String, dynamic>? plnInquiryData;
  final Map<String, dynamic>? gameInquiryData;
  final String Function(dynamic) formatPrice;
  final VoidCallback? onConfirm;
  final bool showBottomAction;

  const PpobTransactionDetailTemplatePage({
    required this.title,
    required this.product,
    required this.customerId,
    required this.brand,
    required this.recipientName,
    required this.requireRecipientName,
    required this.showRecipientHint,
    required this.isPlnToken,
    required this.plnInquiryData,
    this.gameInquiryData,
    required this.formatPrice,
    this.onConfirm,
    this.showBottomAction = true,
  });

  @override
  State<PpobTransactionDetailTemplatePage> createState() =>
      _PpobTransactionDetailTemplatePageState();
}

class _PpobTransactionDetailTemplatePageState
    extends State<PpobTransactionDetailTemplatePage> {
  String? _recipientName;

  @override
  void initState() {
    super.initState();
    _recipientName = widget.recipientName;
  }

  void _handleConfirm() {
    if (widget.requireRecipientName &&
        (_recipientName == null || _recipientName!.trim().isEmpty)) {
      Fluttertoast.showToast(msg: 'Nama penerima belum terverifikasi');
      return;
    }
    widget.onConfirm?.call();
  }

  @override
  void dispose() {
    super.dispose();
  }

  double _parseAmount(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) {
      final normalized = value.replaceAll(RegExp(r'[^0-9\.]'), '').trim();
      return double.tryParse(normalized) ?? 0;
    }
    return 0;
  }

  String _pickFirstString(List<dynamic> candidates, {String fallback = '-'}) {
    for (final c in candidates) {
      final text = c?.toString().trim();
      if (text != null && text.isNotEmpty && text != '-') return text;
    }
    return fallback;
  }

  double _pickFirstAmount(List<dynamic> candidates, {double fallback = 0}) {
    for (final c in candidates) {
      final value = _parseAmount(c);
      if (value > 0) return value;
    }
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    final notifire = Provider.of<ColorNotifire>(context, listen: true);
    final textPrimary = notifire.getdarkscolor;
    final textSecondary = notifire.getdarkgreycolor;
    final cardBg = notifire.gettabwhitecolor;

    const headerBlue = Color(0xFF3F75B7);
    const pageBg = Color(0xFFF5F5F7);
    const headerBlendHeight = 280.0;

    final productName = widget.product['product_name']?.toString() ??
        widget.product['name']?.toString() ??
        widget.title;
    final inquiry = widget.plnInquiryData;
    final isPlnDetail = widget.isPlnToken && inquiry != null;

    final apiCustomerName = isPlnDetail
        ? _pickFirstString([
            inquiry['customer_name'],
            inquiry['name'],
            inquiry['subscriber_name'],
            widget.recipientName,
          ])
        : _pickFirstString([widget.recipientName], fallback: '-');

    final apiCustomerNo = isPlnDetail
        ? _pickFirstString([
            inquiry['customer_no'],
            inquiry['customer_number'],
            inquiry['idpel'],
            inquiry['subscriber_id'],
            inquiry['meter_no'],
            widget.customerId,
          ], fallback: widget.customerId)
        : widget.customerId;

    final apiPower = isPlnDetail
        ? _pickFirstString([
            inquiry['tariff_daya'],
            inquiry['segment_power'],
            inquiry['power'],
            inquiry['desc'] is Map ? inquiry['desc']['power'] : null,
            inquiry['daya'],
            inquiry['desc'] is Map ? inquiry['desc']['daya'] : null,
          ], fallback: '')
        : '';

    final apiTarif = isPlnDetail
        ? _pickFirstString([
            inquiry['tarif'],
            inquiry['rate'],
            inquiry['desc'] is Map ? inquiry['desc']['tarif'] : null,
          ], fallback: '')
        : '';

    final apiTarifDaya = isPlnDetail
        ? (apiPower.isNotEmpty
            ? apiPower
            : (apiTarif.isNotEmpty
                ? (apiPower.isNotEmpty ? '$apiTarif/$apiPower' : apiTarif)
                : '-'))
        : '';

    final price = isPlnDetail
        ? _pickFirstAmount([
            widget.product['price'],
            widget.product['sell_price'],
            widget.product['amount'],
            inquiry['nominal'],
          ])
        : _parseAmount(
            widget.product['price'] ??
                widget.product['sell_price'] ??
                widget.product['amount'],
          );

    final adminFee = isPlnDetail
        ? _pickFirstAmount([
            widget.product['admin_fee'],
            widget.product['biaya_admin'],
            widget.product['admin'],
            inquiry['admin'],
          ])
        : _parseAmount(
            widget.product['admin_fee'] ?? widget.product['biaya_admin'] ?? 0);

    final total = price + adminFee;

    return Scaffold(
      backgroundColor: pageBg,
      body: Stack(
        children: [
          const Column(
            children: [
              SizedBox(
                  height: headerBlendHeight,
                  child: ColoredBox(color: headerBlue)),
              Expanded(child: ColoredBox(color: pageBg)),
            ],
          ),
          SafeArea(
            top: false,
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  color: headerBlue,
                  padding: EdgeInsets.fromLTRB(
                      16, MediaQuery.of(context).padding.top + 6, 16, 10),
                  child: Row(
                    children: [
                      InkWell(
                        onTap: () => Navigator.of(context).maybePop(),
                        borderRadius: BorderRadius.circular(20),
                        child: const Padding(
                          padding: EdgeInsets.all(6),
                          child: Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Detail Transaksi',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 126),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.16),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Text(
                              'Detail Transaksi',
                              style: GoogleFonts.poppins(
                                color: textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          _paymentRow('Nama Produk', productName),
                          const SizedBox(height: 10),
                          if (isPlnDetail) ...[
                            _paymentRow('Nama Pelanggan', apiCustomerName),
                            const SizedBox(height: 10),
                            _paymentRow('IDPEL', apiCustomerNo),
                            const SizedBox(height: 10),
                            _paymentRow('TARIF/DAYA', apiTarifDaya),
                          ] else if (widget.gameInquiryData != null) ...[
                            _paymentRow('ID Player', widget.customerId),
                            if ((widget.gameInquiryData!['username'] ?? '').toString().isNotEmpty) ...[
                              const SizedBox(height: 10),
                              _paymentRow('Username', widget.gameInquiryData!['username'].toString()),
                            ],
                            if ((widget.gameInquiryData!['region'] ?? '').toString().isNotEmpty) ...[
                              const SizedBox(height: 10),
                              _paymentRow('Region', widget.gameInquiryData!['region'].toString()),
                            ],
                          ] else
                            _paymentRow('Nomor Handphone', widget.customerId),
                          const SizedBox(height: 10),
                          _paymentRow('Harga', widget.formatPrice(price)),
                          const SizedBox(height: 10),
                          _paymentRow(
                            'Biaya Admin',
                            adminFee <= 0
                                ? 'Gratis!'
                                : widget.formatPrice(adminFee),
                          ),
                          const SizedBox(height: 8),
                          Divider(
                            height: 1,
                            thickness: 1,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 10),
                          _paymentRow(
                            'Total Pembayaran',
                            widget.formatPrice(total),
                            valueStyle: GoogleFonts.poppins(
                              color: textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _recipientSection(notifire),
                        ],
                      ),
                    ),
                  ),
                ),
                if (widget.showBottomAction)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF0F0F1),
                      border: Border(top: BorderSide(color: Color(0xFFD6D6DA))),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Text(
                              'Total Pembayaran',
                              style: GoogleFonts.poppins(
                                color: textPrimary,
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              widget.formatPrice(total),
                              style: GoogleFonts.poppins(
                                color: headerBlue,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: ElevatedButton(
                            onPressed: _handleConfirm,
                            style: ElevatedButton.styleFrom(
                              elevation: 0,
                              backgroundColor: headerBlue,
                              disabledBackgroundColor: const Color(0xFF233B63),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Text(
                              'Bayar Sekarang',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                                fontSize: 13,
                                height: 1,
                                letterSpacing: 1.6,
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
        ],
      ),
    );
  }

  Widget _paymentRow(String label, String value, {TextStyle? valueStyle}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.poppins(
              color: const Color(0xFF1A1A1A),
              fontWeight: FontWeight.w400,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: valueStyle ??
                GoogleFonts.poppins(
                  color: const Color(0xFF1A1A1A),
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
          ),
        ),
      ],
    );
  }

  Widget _recipientSection(ColorNotifire notifire) {
    final textSecondary = notifire.getdarkgreycolor;
    final surface = notifire.gettabwhitecolor;

    if (!widget.showRecipientHint && widget.recipientName == null) {
      return const SizedBox.shrink();
    }

    if (!widget.requireRecipientName) {
      return const SizedBox.shrink();
    }

    if (_recipientName != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              height: 34,
              width: 34,
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.verified_rounded,
                  color: Colors.green, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nama Penerima Terverifikasi',
                    style: TextStyle(
                      color: textSecondary,
                      fontFamily: 'Gilroy Medium',
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _recipientName!,
                    style: TextStyle(
                      color: notifire.getdarkscolor,
                      fontFamily: 'Gilroy Bold',
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.error_outline_rounded,
                  color: Colors.red, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Nama penerima tidak tersedia',
                  style: const TextStyle(
                    color: Colors.red,
                    fontFamily: 'Gilroy Medium',
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _divider(Color textSecondary) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Divider(
        height: 1,
        thickness: 1,
        color: textSecondary.withValues(alpha: 0.12),
      ),
    );
  }

  Widget _infoTile({
    required IconData icon,
    required String label,
    required String value,
    required Color textPrimary,
    required Color textSecondary,
    required Color accent,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 34,
          width: 34,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: accent),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: textSecondary,
                  fontFamily: 'Gilroy Medium',
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  color: textPrimary,
                  fontFamily: 'Gilroy Bold',
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
