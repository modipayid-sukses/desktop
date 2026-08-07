import 'dart:async';
import 'package:modipay/widgets/desktop_title_wrapper.dart';

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_native_contact_picker/flutter_native_contact_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:modipay/utils/toast.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../providers/auth_provider.dart';
import '../../services/app_exception.dart';
import '../../services/api_service.dart';
import '../../services/biometric_service.dart';
import '../../utils/colornotifire.dart';
import '../../utils/color.dart';
import '../../widgets/transaction_receipt.dart';
import '../transaction_detail.dart';
import '../topup/topupcard/confirmpayment.dart';
import 'components/ppob_numpad.dart';
import 'components/ppob_cellular_form.dart';
import 'components/saved_customers_bottom_sheet.dart';
import '../../utils/responsive.dart';
import '../../design/design.dart';


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

  // Desktop Token Listrik: verifikasi ID Pelanggan otomatis (debounced) saat
  // user mengetik, independen dari pemilihan nominal — meniru referensi
  // desain desktop (banner "ID Pelanggan terverifikasi" muncul di step 1).
  bool _isPlnCustomerVerifying = false;
  Timer? _plnVerifyDebounce;

  // Desktop PLN Pasca: cek tagihan otomatis (debounced) saat user mengetik
  // ID Pelanggan, plus toggle rincian tagihan tambahan (admin/denda/meter).
  Timer? _plnPascaVerifyDebounce;
  bool _showPlnPascaDetail = false;

  Timer? _inputDebounce;

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

  // Kartu Tol/E-Toll: input-nya nomor kartu, bukan nomor HP, jadi ikon
  // "pilih dari kontak" (Icons.contacts_rounded) tidak relevan di sini.
  bool get _isTollCategory {
    final hay =
        '${widget.category.toLowerCase()} ${widget.title.toLowerCase()} ${(widget.initialBrand ?? '').toLowerCase()}';
    return hay.contains('e-toll') || hay.contains('etoll') || hay.contains('toll') || hay.contains('tol');
  }

  // Layout desktop dua-kolom baru hanya untuk kategori "sederhana" (Pulsa,
  // Paket Data/Telfon/SMS, dan kategori grid generik lain) yang cocok
  // dengan referensi desain. Kategori dengan alur khusus (PLN, e-money,
  // game, inject, hub) tetap pakai layout mobile lama (masih berfungsi
  // penuh, hanya dipusatkan di window lebar alih-alih dipaksa 460px).
  bool get _supportsDesktopTwoColumn =>
      !_isPln &&
      !_isTopupGameFiltered &&
      !_isCategoryInquiry &&
      !_isInternetHub &&
      !_isMultifinanceHub &&
      !_isEmoney &&
      !_isInject;

  // Input merepresentasikan nomor HP (Pulsa, Data, E-Wallet, dll) sehingga
  // bisa diisi dari kontak handphone pengguna.
  bool get _isPhoneNumberInput =>
      !_isPln && !_isTopupGameFiltered && !_isCategoryInquiry && !_isTollCategory;

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

  // ── Desktop hub "Internet & TV": provider dipilih di halaman yang sama
  // (bukan navigasi ke instance PPOBProductScreen baru seperti alur mobile
  // _onPickInternetProvider), jadi butuh state cek-tagihan sendiri.
  String? _selectedInternetProvider;
  bool _isInternetInquiring = false;
  Map<String, dynamic>? _internetInquiryResult;
  String? _internetInquiryError;

  // ── Desktop hub "Multifinance": sama seperti Internet & TV, provider
  // dipilih di halaman yang sama (bukan navigasi ke instance baru).
  String? _selectedMultifinanceBrand;
  bool _isMultifinanceInquiring = false;
  Map<String, dynamic>? _multifinanceInquiryResult;
  String? _multifinanceInquiryError;

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
    _plnVerifyDebounce?.cancel();
    _plnPascaVerifyDebounce?.cancel();
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
        showToast(msg: 'Gagal memuat brand');
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
        showToast(msg: 'Gagal memuat produk');
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
    return source.map((item) {
      final p = Map<String, dynamic>.from(item as Map);
      
      // Pre-calculate expensive fields
      p['_is_promo_pre'] = _isPromoProduct(p);
      p['_promo_price_pre'] = _promoPrice(p);
      p['_original_price_pre'] = _originalPrice(p);
      p['_reward_coins_pre'] = _extractRewardCoins(p);
      p['_description_pre'] = _productDescription(p);
      p['_promo_label_pre'] = _promoRemainingLabel(p);
      p['_logo_asset_pre'] = _pulsaProviderLogoAsset(p);

      if (_promoIndex.isEmpty) return p;
      final key = _skuKey(p);
      if (key.isEmpty) return p;
      final promo = _promoIndex[key];
      if (promo == null) return p;
      
      final promoPrice = promo['promo_price'] ?? promo['price'];
      final originalPrice = promo['original_price'] ?? p['price'];
      p['is_promo'] = true;
      if (promoPrice != null) p['promo_price'] = promoPrice;
      if (originalPrice != null) p['original_price'] = originalPrice;
      if (promo['promo_end'] != null) p['promo_end'] = promo['promo_end'];
      if (promo['promo_end_at'] != null) {
        p['promo_end_at'] = promo['promo_end_at'];
      }
      
      // Re-calculate after promo enrichment
      p['_is_promo_pre'] = _isPromoProduct(p);
      p['_promo_price_pre'] = _promoPrice(p);
      p['_original_price_pre'] = _originalPrice(p);
      p['_promo_label_pre'] = _promoRemainingLabel(p);

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

    if (_isPln && _inquiryResult != null) {
      setState(() {
        _inquiryResult = null;
      });
    }

    if (_isInject) return;

    _inputDebounce?.cancel();
    _inputDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      if (_isCellularCategory &&
          (_isPulsaCategory ? _pulsaTabIndex == 0 : true)) {
        unawaited(_handlePulsaPrefixAutoSwitch(_customerIdController.text));
      }
    });
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
    return PPOBNumpad(
      accentColor: accent,
      textPrimaryColor: textPrimary,
      textSecondaryColor: textSecondary,
      onDigitPressed: _appendDigit,
      onDeletePressed: _deleteDigit,
      onClearPressed: () => _setCustomerId(''),
      onClosePressed: () => setState(() => _showCustomNumpad = false),
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
        showToast(msg: 'Kontak tidak memiliki nomor telepon');
        return;
      }

      final normalized = _normalizeMsisdn(raw);
      if (normalized.isEmpty) {
        showToast(msg: 'Nomor dari kontak tidak valid');
        return;
      }

      if (!mounted) return;
      _setCustomerId(normalized);
    } catch (_) {
      showToast(msg: 'Gagal mengambil kontak');
    }
  }

  Future<void> _openSavedCustomers(Color accentColor) async {
    final selectedNo = await SavedCustomersBottomSheet.show(
      context,
      category: widget.category.toLowerCase(),
      accentColor: accentColor,
    );
    if (selectedNo != null && selectedNo.isNotEmpty) {
      _setCustomerId(selectedNo);
    }
  }

  Widget _buildShimmerProducts() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shrinkWrap: true,
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
      showToast(msg: 'Masukkan ID pelanggan / No meter');
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
        showToast(msg: result['message'] ?? 'Cek pelanggan gagal');
      }
    } catch (_) {
      if (mounted) {
        showToast(msg: 'Kesalahan koneksi');
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
      showToast(msg: 'Masukkan nomor pelanggan');
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
    await AppDialog.show(
      context: context,
      title: title,
      description: message,
      primaryActionText: 'OK',
    );
  }

  Future<void> _doBpjsInquiry() async {
    final customerId = _customerIdController.text.trim();
    if (customerId.isEmpty) {
      showToast(msg: 'Masukkan ID Pelanggan');
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
    final data = _bpjsInquiryResult!;
    // Backend kadang meneruskan response mentah Loket Bayar (selling_price belum
    // dihitung / 0) — fallback ke total provider lalu tagihan+admin+denda.
    double amount = _asDouble(data['selling_price']);
    if (amount <= 0) amount = _asDouble(data['total']);
    if (amount <= 0) {
      amount = _asDouble(data['tagihan']) +
          _asDouble(data['admin']) +
          _asDouble(data['denda']);
    }
    if (amount <= 0) {
      showToast(
          msg: 'Total tagihan tidak valid, silakan cek ulang');
      return;
    }
    final buyerSkuCode = (data['buyer_sku_code'] ??
            data['inquiry_sku'] ??
            data['kodeProduk'] ??
            '')
        .toString();
    final customerNo = (data['customer_no'] ??
            data['noVA'] ??
            data['no_va'] ??
            _customerIdController.text.trim())
        .toString();
    final productName =
        (data['product_name'] ?? widget.title).toString();
    final customerName =
        (data['customer_name'] ?? data['nama'] ?? '-').toString();

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

  // ── Hub "Internet & TV" (desktop): cek tagihan per-provider yang dipilih
  // di halaman yang sama — sama seperti _doBpjsInquiry (endpoint generik
  // /ppob/inquiry berbasis `category`), hanya categorynya dinamis mengikuti
  // _selectedInternetProvider, bukan widget.category yang tetap.
  Future<void> _doInternetInquiry() async {
    final provider = _selectedInternetProvider;
    if (provider == null) {
      showToast(msg: 'Pilih penyedia terlebih dahulu');
      return;
    }
    final customerId = _customerIdController.text.trim();
    if (customerId.isEmpty) {
      showToast(msg: 'Masukkan ID Pelanggan');
      return;
    }

    setState(() {
      _isInternetInquiring = true;
      _internetInquiryResult = null;
      _internetInquiryError = null;
    });

    try {
      final result = await ApiService.ppobInquiry(
        customerNo: customerId,
        category: provider,
      );
      if (!mounted) return;
      final status = (result['status'] ?? '').toString().toLowerCase();
      final isSuccess = status == 'success' || status == 'sukses';
      if (isSuccess && result['data'] is Map) {
        setState(() {
          _internetInquiryResult = Map<String, dynamic>.from(result['data'] as Map);
        });
      } else {
        final msg = (result['message'] ?? 'Cek tagihan gagal').toString();
        setState(() => _internetInquiryError = msg);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _internetInquiryError = ApiService.userFriendlyMessage(e, fallback: 'Cek tagihan gagal'));
    } finally {
      if (mounted) setState(() => _isInternetInquiring = false);
    }
  }

  void _payInternetBill() {
    final data = _internetInquiryResult;
    if (data == null) return;
    // Backend kadang meneruskan response mentah Loket Bayar (selling_price belum
    // dihitung / 0) — fallback ke total provider lalu tagihan+admin+denda.
    double amount = _asDouble(data['selling_price']);
    if (amount <= 0) amount = _asDouble(data['total']);
    if (amount <= 0) {
      amount = _asDouble(data['tagihan']) + _asDouble(data['admin']) + _asDouble(data['ppn'] ?? data['pajak']) + _asDouble(data['denda']);
    }
    if (amount <= 0) {
      showToast(msg: 'Total tagihan tidak valid, silakan cek ulang');
      return;
    }
    final buyerSkuCode = (data['buyer_sku_code'] ?? data['inquiry_sku'] ?? data['kodeProduk'] ?? '').toString();
    final customerNo = (data['customer_no'] ?? data['noVA'] ?? data['no_va'] ?? _customerIdController.text.trim()).toString();
    final productName = (data['product_name'] ?? _selectedInternetProvider ?? widget.title).toString();
    final customerName = (data['customer_name'] ?? data['nama'] ?? '-').toString();

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

  // ── Hub "Multifinance" (desktop): sama polanya dengan hub Internet & TV —
  // cek tagihan generik (/ppob/inquiry berbasis `category`) dengan brand
  // yang dipilih di halaman yang sama, bukan navigasi ke instance baru.
  Future<void> _doMultifinanceInquiry() async {
    final brand = _selectedMultifinanceBrand;
    if (brand == null) {
      showToast(msg: 'Pilih provider terlebih dahulu');
      return;
    }
    final customerId = _customerIdController.text.trim();
    if (customerId.isEmpty) {
      showToast(msg: 'Masukkan nomor kontrak / ID pelanggan');
      return;
    }

    setState(() {
      _isMultifinanceInquiring = true;
      _multifinanceInquiryResult = null;
      _multifinanceInquiryError = null;
    });

    try {
      final result = await ApiService.ppobInquiry(
        customerNo: customerId,
        category: brand,
      );
      if (!mounted) return;
      final status = (result['status'] ?? '').toString().toLowerCase();
      final isSuccess = status == 'success' || status == 'sukses';
      if (isSuccess && result['data'] is Map) {
        setState(() {
          _multifinanceInquiryResult = Map<String, dynamic>.from(result['data'] as Map);
        });
      } else {
        final msg = (result['message'] ?? 'Cek tagihan gagal').toString();
        setState(() => _multifinanceInquiryError = msg);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _multifinanceInquiryError = ApiService.userFriendlyMessage(e, fallback: 'Cek tagihan gagal'));
    } finally {
      if (mounted) setState(() => _isMultifinanceInquiring = false);
    }
  }

  void _payMultifinanceBill() {
    final data = _multifinanceInquiryResult;
    if (data == null) return;
    double amount = _asDouble(data['selling_price']);
    if (amount <= 0) amount = _asDouble(data['total']);
    if (amount <= 0) {
      amount = _asDouble(data['tagihan']) + _asDouble(data['admin']) + _asDouble(data['denda']);
    }
    if (amount <= 0) {
      showToast(msg: 'Total tagihan tidak valid, silakan cek ulang');
      return;
    }
    final buyerSkuCode = (data['buyer_sku_code'] ?? data['inquiry_sku'] ?? data['kodeProduk'] ?? '').toString();
    final customerNo = (data['customer_no'] ?? data['noVA'] ?? data['no_va'] ?? _customerIdController.text.trim()).toString();
    final productName = (data['product_name'] ?? _selectedMultifinanceBrand ?? widget.title).toString();
    final customerName = (data['customer_name'] ?? data['nama'] ?? '-').toString();

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
      showToast(
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
                // Defer: Navigator.push sync di onTap rawan _debugDuringDeviceUpdate di desktop.
                onTap: () => Future.microtask(() => _onPickInternetProvider(brand)),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
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
        borderRadius: BorderRadius.circular(16),
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
                // Defer: Navigator.push sync di onTap rawan _debugDuringDeviceUpdate di desktop.
                onTap: () => Future.microtask(() => _onPickMultifinance(brand)),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
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
    // Backend kadang meneruskan response mentah Loket Bayar (key: tagihan/total/
    // nama/noVA) atau gagal men-summarize sehingga nominal bernilai 0/null.
    // Pilih kandidat pertama yang bernilai > 0 supaya tagihan tidak salah
    // tampil "Gratis!".
    double firstAmount(List<dynamic> candidates) {
      for (final c in candidates) {
        final n = _asDouble(c);
        if (n > 0) return n;
      }
      return 0;
    }
    String firstText(List<dynamic> candidates) {
      for (final c in candidates) {
        final s = (c ?? '').toString().trim();
        if (s.isNotEmpty) return s;
      }
      return '-';
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
                borderRadius: BorderRadius.circular(20),
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
                    firstText([
                      data['customer_no'],
                      data['noVA'],
                      data['no_va'],
                    ]),
                    textSecondary,
                    textPrimary,
                  ),
                  _billRowInline(
                    'Nama',
                    firstText([data['customer_name'], data['nama']]),
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
                    moneyOf(firstAmount([
                      data['nominal'],
                      data['provider_nominal'],
                      data['tagihan'],
                    ])),
                    textSecondary,
                    textPrimary,
                  ),
                  _billRowInline(
                    'Biaya Admin',
                    moneyOf(firstAmount([
                      data['admin'],
                      data['provider_admin'],
                    ])),
                    textSecondary,
                    textPrimary,
                  ),
                  const Divider(height: 18, color: Color(0xFFE5E9EE)),
                  _billRowInline(
                    'Total Bayar',
                    moneyOf(firstAmount([
                      data['selling_price'],
                      data['total'],
                    ])),
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
                AppButton.primary(
                  expand: true,
                  loading: _isPlnPostpaidInquiring,
                  label: 'Cek Tagihan',
                  onPressed: _isPlnPostpaidInquiring ? null : _doPlnPostpaidInquiry,
                ),
                // Pesan error inline (mengganti dialog).
                if (_plnPostpaidError != null && !_isPlnPostpaidInquiring) ...[
                  const SizedBox(height: AppSpacing.md),
                  AppAlert(
                    tone: AppAlertTone.error,
                    title: 'Tidak dapat memeriksa tagihan',
                    description: _plnPostpaidError!,
                  ),
                ],
              ],
              if (_plnPostpaidInquiryResult != null) ...[
                // ── Card 1: Info Pelanggan ─────────────────────────────
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.dialog),
                    border: Border.all(color: grey200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header.
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md, vertical: AppSpacing.md),
                        decoration: BoxDecoration(
                          color: primaryBlue50,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(AppRadius.dialog),
                            topRight: Radius.circular(AppRadius.dialog),
                          ),
                          border: Border(bottom: BorderSide(color: grey200)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: primaryBlue500.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(AppRadius.md),
                              ),
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.electrical_services_rounded,
                                color: primaryBlue500,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
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
                            AppBadge(label: tarifDaya, tone: AppBadgeTone.primary),
                          ],
                        ),
                      ),
                      // Body: Detail Tagihan
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                            AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.lg),
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
                            const SizedBox(height: AppSpacing.sm),
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
                            const SizedBox(height: AppSpacing.xs),
                            Divider(height: 1, color: grey200),
                            const SizedBox(height: AppSpacing.xs),
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
                            const SizedBox(height: AppSpacing.sm),
                            // Total bayar block (highlight)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.md, vertical: AppSpacing.md),
                              decoration: BoxDecoration(
                                color: primaryBlue50,
                                borderRadius: BorderRadius.circular(AppRadius.md),
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
                                      color: primaryBlue500,
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
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: AppButton.secondary(
                        expand: true,
                        label: 'Cek Ulang',
                        onPressed: _doPlnPostpaidInquiry,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: AppButton.success(
                        expand: true,
                        label: 'Bayar Sekarang',
                        onPressed: _payPlnPostpaidBill,
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
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: grey200),
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
      showToast(msg: 'Saldo tidak mencukupi untuk transaksi ini');
      return;
    }

    if (isDesktop(context)) {
      _showTransactionPinDialog(
        product: product,
        customerId: customerId,
        price: price,
        paymentSource: 'saldo',
      );
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

  /// Desktop-only PIN authentication popup (replaces the mobile numpad
  /// ConfirmPayment page for wide layouts): collects "Nama Kasir" + PIN,
  /// then submits the purchase directly and routes to the receipt page.
  void _showTransactionPinDialog({
    required Map<String, dynamic> product,
    required String customerId,
    required double price,
    required String paymentSource,
  }) {
    TransactionPinAuthDialog.show(
      context: context,
      onConfirm: (kasirCode, kasirPin) => _purchaseWithPin(
        product: product,
        customerId: customerId,
        price: price,
        paymentSource: paymentSource,
        kasirCode: kasirCode,
        kasirPin: kasirPin,
      ),
    );
  }

  Future<void> _purchaseWithPin({
    required Map<String, dynamic> product,
    required String customerId,
    required double price,
    required String paymentSource,
    required String kasirCode,
    required String kasirPin,
  }) async {
    final isLoketbayar = product['provider'] == 'loketbayar';
    // Kirim ketiga field sekaligus: backend yang menentukan mode mana yang
    // dipakai (PIN akun toko vs kode+PIN kasir) tergantung apakah toko ini
    // sudah punya kasir terdaftar — lihat ValidatesKasir::validateKasirOrPin
    // di backend. Tidak ada percabangan di sisi client.
    final Map<String, dynamic> response = isLoketbayar
        ? await ApiService.purchaseLoketbayar(
            kodeProduk: (_lastInquiryKodeProduk ??
                    product['inquiry_sku'] ??
                    product['buyer_sku_code'] ??
                    '')
                .toString(),
            customerNo: customerId,
            nominal: _lastInquiryNominal ?? price.toInt(),
            refId: _lastInquiryRefId ?? '',
            pin: kasirPin,
            kasirCode: kasirCode,
            kasirPin: kasirPin,
            paymentSource: paymentSource,
            productName: (product['product_name'] ?? widget.title).toString(),
          )
        : await ApiService.purchasePpob(
            buyerSkuCode: (product['buyer_sku_code'] ?? '').toString(),
            customerNo: customerId,
            pin: kasirPin,
            kasirCode: kasirCode,
            kasirPin: kasirPin,
            provider: (product['provider'] ?? '').toString(),
            category: widget.category.isEmpty ? widget.title : widget.category,
            paymentSource: paymentSource,
            amount: price,
          );

    if (!response.containsKey('transaction')) {
      throw AppException((response['message'] ?? 'Pembelian gagal').toString());
    }

    if (!mounted) return;
    Provider.of<AuthProvider>(context, listen: false).updateBalance();
    final tx = response['transaction'] as Map<String, dynamic>? ?? {};
    final meta = response['meta'] is Map
        ? Map<String, dynamic>.from(response['meta'] as Map)
        : null;
    final hasTxNote = tx['note'] != null && tx['note'].toString().isNotEmpty;
    final data = <String, dynamic>{
      ...tx,
      'amount': tx['amount'] ?? price,
      'phone_number': customerId,
      'customer_no': customerId,
      'cashier_name': kasirCode,
      if (meta != null && meta.isNotEmpty) 'meta': meta,
      if (!hasTxNote && meta != null && meta.isNotEmpty) 'note': jsonEncode(meta),
    };

    // Close the PIN dialog before showing the result.
    Navigator.of(context, rootNavigator: true).pop();

    if (isDesktop(context)) {
      final adminFee = _asAdminFee(product);
      final destinationLabel = _isPln ? 'ID Pelanggan' : 'Nomor Tujuan';
      TransactionSuccessDialog.show(
        context: context,
        subtitle: '${widget.title} berhasil dikirim',
        orderId: (tx['order_id'] ?? '-').toString(),
        rows: [
          MapEntry(destinationLabel, customerId),
          if ((_selectedBrand ?? '').trim().isNotEmpty) MapEntry('Operator', _selectedBrand!),
          MapEntry('Produk', (product['product_name'] ?? widget.title).toString()),
          MapEntry('Nominal', _formatPrice(price)),
          MapEntry('Harga', _formatPrice(price)),
          MapEntry('Admin', _formatPrice(adminFee)),
        ],
        totalLabel: _formatPrice(price + adminFee),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TransactionDetail(data: data)),
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
                            showToast(msg: 'Saldo tidak mencukupi');
                            return;
                          }
                          if (isDesktop(context)) {
                            _showTransactionPinDialog(
                              product: product,
                              customerId: customerId,
                              price: price,
                              paymentSource: selected,
                            );
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
      await AppDialog.show(
        context: context,
        title: title,
        body: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 320),
          child: SingleChildScrollView(
            child: SelectableText(
              pretty,
              style: const TextStyle(fontFamily: 'Courier', fontSize: 12),
            ),
          ),
        ),
        primaryActionText: 'Tutup',
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
      showToast(msg: 'Gagal terhubung saat cek nama penerima');
    } else if (message.contains('pending')) {
      showToast(
        msg: 'Pengecekan masih diproses, coba lagi beberapa detik',
      );
    } else {
      showToast(
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
      showToast(msg: 'Masukkan nomor pelanggan / nomor HP');
      return;
    }

    final numberError = _validateCustomerIdByBrand(customerId);
    if (numberError != null) {
      showToast(msg: numberError);
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
            showToast(msg: 'Nama pelanggan tidak tersedia');
          } else {
            recipientName = name;
          }
        } else {
          showToast(
              msg: result['message'] ?? 'Cek pelanggan gagal');
        }
      } catch (_) {
        showToast(msg: 'Kesalahan koneksi');
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
        showToast(
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
          showToast(
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

    // Desktop two-column layout (Pulsa, Paket Data, dll) sudah menampilkan
    // ringkasan "Detail Transaksi" di sidebar kanan, jadi halaman detail
    // terpisah ini redundan — langsung ke popup autentikasi PIN.
    if (isDesktop(context) && _supportsDesktopTwoColumn) {
      _goToPin(product);
      return;
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
      showToast(msg: 'Pilih nominal token terlebih dahulu');
      return;
    }

    final customerId = _customerIdController.text.trim();
    if (customerId.isEmpty) {
      showToast(msg: 'Masukkan IDPEL terlebih dahulu');
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
      if (inquiryData != null) _inquiryResult = inquiryData;

      // Layout desktop Token Listrik sudah menampilkan ringkasan "Detail
      // Transaksi" di sidebar kanan, jadi halaman detail terpisah ini
      // redundan — langsung ke popup autentikasi PIN.
      if (isDesktop(context) && _isPln && _plnTabIndex == 0) {
        _goToPin(product);
        return;
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
        showToast(msg: result['message'] ?? 'Cek pelanggan gagal');
        if (mounted) setState(() => _isValidatingRecipient = false);
        return;
      }
    } catch (_) {
      showToast(msg: 'Kesalahan koneksi');
      if (mounted) setState(() => _isValidatingRecipient = false);
      return;
    }

    if (!mounted) return;
    setState(() => _isValidatingRecipient = false);

    // Layout desktop Token Listrik sudah menampilkan ringkasan "Detail
    // Transaksi" di sidebar kanan, jadi halaman detail terpisah ini
    // redundan — langsung ke popup autentikasi PIN.
    if (isDesktop(context) && _isPln && _plnTabIndex == 0) {
      _goToPin(product);
      return;
    }

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

  IconData get _desktopCategoryIcon {
    final t = ('${widget.category} ${widget.title}').toLowerCase();
    if (t.contains('pulsa')) return Icons.smartphone_rounded;
    if (t.contains('data') || t.contains('internet')) return Icons.wifi_rounded;
    if (t.contains('listrik') || t.contains('token') || t.contains('pln')) return Icons.bolt_rounded;
    if (t.contains('game')) return Icons.sports_esports_rounded;
    if (t.contains('wallet') || t.contains('money')) return Icons.account_balance_wallet_rounded;
    return Icons.shopping_bag_rounded;
  }

  String get _desktopCategorySubtitle => 'Beli ${widget.title} dengan cepat dan mudah';

  double _asAdminFee(Map<String, dynamic> product) {
    final raw = product['admin_fee'] ?? product['admin'];
    return _asDouble(raw);
  }

  // Header kategori dipakai di semua layout desktop dua-kolom (Pulsa, Token
  // Listrik, dll): avatar bulat + judul + subjudul.
  Widget _buildDesktopCategoryHeader({String? titleOverride, String? subtitleOverride, Widget? trailing}) {
    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(color: desktopPrimaryBtn.withValues(alpha: 0.08), shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Icon(_desktopCategoryIcon, color: desktopPrimaryBtn, size: 24),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titleOverride ?? widget.title, style: GoogleFonts.hankenGrotesk(fontSize: 20, fontWeight: FontWeight.w800, color: desktopTextPrimary)),
              Text(subtitleOverride ?? _desktopCategorySubtitle, style: GoogleFonts.hankenGrotesk(fontSize: 13, color: desktopTextSecondary)),
            ],
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  // ── Token Listrik (desktop): verifikasi ID Pelanggan otomatis ──────────
  void _onPlnCustomerIdChangedDesktop(String value) {
    final digitsOnly = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (value != digitsOnly) {
      _setCustomerId(digitsOnly);
      return;
    }
    if (_inquiryResult != null) {
      setState(() => _inquiryResult = null);
    } else {
      setState(() {});
    }
    _plnVerifyDebounce?.cancel();
    if (digitsOnly.length < 8) return;
    _plnVerifyDebounce = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      unawaited(_verifyPlnCustomerId(digitsOnly));
    });
  }

  Future<void> _verifyPlnCustomerId(String customerId) async {
    if (!mounted) return;
    setState(() => _isPlnCustomerVerifying = true);
    try {
      final result = await ApiService.ppobInquiryPln(customerNo: customerId);
      final status = (result['status'] ?? '').toString().toLowerCase();
      final isSuccess = status == 'success' || status == 'sukses';
      // Buang hasil kalau user sudah lanjut mengetik ID lain sebelum request selesai.
      if (!mounted || _customerIdController.text.trim() != customerId) return;
      if (isSuccess && result['data'] != null) {
        final data = Map<String, dynamic>.from(result['data'] as Map);
        final name = (data['name'] ?? data['customer_name'] ?? '').toString().trim();
        setState(() {
          _inquiryResult = {
            'customer_name': name,
            'customer_no': data['customer_no'] ?? data['subscriber_id'] ?? customerId,
            'subscriber_id': data['subscriber_id'] ?? data['customer_no'] ?? customerId,
            'meter_no': data['meter_no'] ?? '',
            'tariff_daya': data['segment_power'] ?? data['tariff_daya'] ?? '',
          };
        });
      } else {
        setState(() => _inquiryResult = null);
      }
    } catch (_) {
      if (mounted) setState(() => _inquiryResult = null);
    } finally {
      if (mounted) setState(() => _isPlnCustomerVerifying = false);
    }
  }

  Future<void> _pastePlnCustomerId() async {
    final data = await Clipboard.getData('text/plain');
    final text = data?.text?.trim() ?? '';
    if (text.isEmpty) {
      showToast(msg: 'Clipboard kosong');
      return;
    }
    _onPlnCustomerIdChangedDesktop(text);
  }

  Future<void> _openPlnHistoryDesktop() async {
    await _openSavedCustomers(desktopAccentBlue);
    final id = _customerIdController.text.trim();
    if (id.length >= 8) {
      unawaited(_verifyPlnCustomerId(id));
    }
  }

  Widget _inlineFieldAction({required IconData icon, required String label, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: desktopAccentBlue),
              const SizedBox(width: 4),
              Text(label, style: GoogleFonts.hankenGrotesk(fontSize: 12.5, fontWeight: FontWeight.w700, color: desktopAccentBlue)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _verifiedInfoChip(String label, String value) {
    return RichText(
      text: TextSpan(
        style: GoogleFonts.hankenGrotesk(fontSize: 12, color: desktopTextSecondary),
        children: [
          TextSpan(text: '$label : '),
          TextSpan(
            text: value,
            style: GoogleFonts.hankenGrotesk(fontSize: 12, fontWeight: FontWeight.w700, color: desktopTextPrimary),
          ),
        ],
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

  // Layout desktop dua-kolom khusus Token Listrik (PLN Prabayar): kiri =
  // input ID Pelanggan (dengan verifikasi otomatis) + grid nominal, kanan =
  // ringkasan transaksi sticky. Tombol "Beli Sekarang" memanggil
  // _continuePlnPrabayar yang sama dengan alur mobile (inquiry SKU +
  // navigasi ke PIN) — logika pembayaran tidak diduplikasi.
  Widget _buildDesktopPlnLayout() {
    final customerId = _customerIdController.text.trim();
    final hasCustomerInput = customerId.isNotEmpty;
    final selected = _selectedProduct;
    final price = selected == null
        ? 0.0
        : (_isPromoProduct(selected) ? _promoPrice(selected) : _originalPrice(selected));
    final adminFee = selected == null ? 0.0 : _asAdminFee(selected);
    final total = price + adminFee;
    final canConfirm = selected != null && hasCustomerInput && !_isValidatingRecipient;

    final verified = _inquiryResult;
    final verifiedName = (verified?['customer_name'] ?? '').toString().trim();
    final verifiedDaya = (verified?['tariff_daya'] ?? '').toString().trim();

    return Scaffold(
      backgroundColor: desktopSurfacePage,
      body: PpobDesktopTwoColumnLayout(
        left: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDesktopCategoryHeader(
              titleOverride: 'Token Listrik',
              subtitleOverride: 'Beli token listrik prabayar dengan mudah dan cepat',
            ),
            const SizedBox(height: 28),
            const PpobStepHeader(step: 1, title: 'Masukkan ID Pelanggan / Nomor Meter'),
            const SizedBox(height: 12),
            desktopBorderedField(
              icon: Icons.bolt_rounded,
              controller: _customerIdController,
              focusNode: _customerIdFocusNode,
              keyboardType: TextInputType.number,
              hint: 'Contoh: 1234 5678 9012',
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: _onPlnCustomerIdChangedDesktop,
              suffix: Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isPlnCustomerVerifying)
                      const Padding(
                        padding: EdgeInsets.only(right: 8),
                        child: SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(desktopAccentBlue)),
                        ),
                      ),
                    _inlineFieldAction(icon: Icons.content_paste_rounded, label: 'Tempel', onTap: _pastePlnCustomerId),
                    Container(height: 18, width: 1, color: desktopBorder, margin: const EdgeInsets.symmetric(horizontal: 4)),
                    _inlineFieldAction(icon: Icons.history_rounded, label: 'Riwayat', onTap: _openPlnHistoryDesktop),
                  ],
                ),
              ),
            ),
            if (verified != null && verifiedName.isNotEmpty) ...[
              const SizedBox(height: 14),
              PpobDesktopBanner(
                icon: Icons.check_circle_rounded,
                title: 'ID Pelanggan terverifikasi',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _verifiedInfoChip('Nama', verifiedName),
                    if (verifiedDaya.isNotEmpty) ...[
                      const SizedBox(width: 16),
                      _verifiedInfoChip('Daya', verifiedDaya),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 28),
            const PpobStepHeader(step: 2, title: 'Pilih Nominal Token'),
            const SizedBox(height: 14),
            _buildDesktopProductGrid(emptyMessage: 'Belum ada nominal token tersedia'),
            const SizedBox(height: 16),
            PpobDesktopBanner(
              icon: Icons.info_outline_rounded,
              title: 'Pastikan ID Pelanggan / Nomor Meter sudah benar. Token yang sudah dibeli tidak dapat dikembalikan.',
              tone: PpobBannerTone.info,
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: desktopBorder.withValues(alpha: 0.5))),
              ),
              child: Row(
                children: [
                  _desktopTrustBadge(Icons.verified_rounded, 'Token Resmi', 'langsung dari PLN'),
                  _desktopTrustBadge(Icons.bolt_rounded, 'Proses Cepat', '1-3 detik'),
                  _desktopTrustBadge(Icons.shield_outlined, 'Aman & Terpercaya', 'Transaksi terenkripsi'),
                  _desktopTrustBadge(Icons.access_time_rounded, '24/7', 'Layanan selalu tersedia'),
                ],
              ),
            ),
          ],
        ),
        right: PpobDesktopSummaryPanel(
          rows: [
            PpobDetailRow(icon: Icons.badge_outlined, label: 'ID Pelanggan', value: hasCustomerInput ? customerId : '-'),
            PpobDetailRow(icon: Icons.person_outline, label: 'Nama', value: verifiedName.isNotEmpty ? verifiedName : '-'),
            PpobDetailRow(icon: Icons.bolt_outlined, label: 'Daya', value: verifiedDaya.isNotEmpty ? verifiedDaya : '-'),
            const PpobDetailRow(icon: Icons.inventory_2_outlined, label: 'Produk', value: 'Token Listrik'),
            PpobDetailRow(icon: Icons.confirmation_number_outlined, label: 'Nominal', value: (selected?['product_name'] ?? '-').toString()),
            PpobDetailRow(icon: Icons.sell_outlined, label: 'Harga', value: selected != null ? _formatPrice(price) : 'Rp 0'),
            PpobDetailRow(icon: Icons.receipt_long_outlined, label: 'Admin', value: _formatPrice(adminFee)),
          ],
          totalLabel: _formatPrice(total),
          confirmLabel: 'Beli Sekarang',
          loading: _isValidatingRecipient,
          onConfirm: canConfirm ? _continuePlnPrabayar : null,
        ),
      ),
    );
  }

  // ── E-Wallet (desktop): daftar penyedia yang ditampilkan di layout ─────
  // dua-kolom, urutan disesuaikan dengan referensi desain (DANA lebih dulu)
  // tapi tetap mencakup semua brand yang didukung mobile (`_buildEwalletList`).
  // LinkAja, DOKU, KasPro, dan iSaku disembunyikan dari grid — brand-brand
  // itu tidak ada di `_ewalletSkuInfo` (cuma DANA/GoPay/OVO/ShopeePay yang
  // punya SKU Loket Bayar terdaftar), jadi tidak bisa benar-benar dibeli.
  static const List<Map<String, dynamic>> _ewalletBrandsDesktop = [
    {'name': 'DANA', 'logo': 'images/ewallet_logos/dana.svg', 'icon': Icons.account_balance_wallet_rounded, 'color': Color(0xFF118EEA)},
    {'name': 'ShopeePay', 'logo': 'images/ewallet_logos/shopeepay.svg', 'icon': Icons.shopping_bag_rounded, 'color': Color(0xFFEE4D2D)},
    {'name': 'GoPay', 'logo': 'images/ewallet_logos/gopay.svg', 'icon': Icons.account_balance_wallet_rounded, 'color': Color(0xFF00AED6)},
    {'name': 'OVO', 'logo': 'images/ewallet_logos/ovo.svg', 'icon': Icons.circle_outlined, 'color': Color(0xFF4C3494)},
  ];

  static const List<int> _ewalletPresetAmounts = [
    10000, 20000, 50000, 100000, 200000, 300000, 500000, 1000000, 2000000,
  ];

  /// Map brand → SKU Loket Bayar. Diekstrak dari `_onCustomAmountSubmit`
  /// (alur mobile lama) supaya logikanya tidak diduplikasi.
  Map<String, String> _ewalletSkuInfo(String brandName) {
    const brandSkuMap = <String, Map<String, String>>{
      'dana': {'inquiry_sku': 'DANA', 'buyer_sku_code': 'DANA'},
      'gopay': {'inquiry_sku': 'GOPAYP', 'buyer_sku_code': 'GOPAYP'},
      'ovo': {'inquiry_sku': 'OVO', 'buyer_sku_code': 'OVOP'},
      'shopeepay': {'inquiry_sku': 'SHOPEEP', 'buyer_sku_code': 'SHOPEEP'},
    };
    final brandKey = brandName.toLowerCase().replaceAll(RegExp(r'\s+'), '');
    return brandSkuMap[brandKey] ??
        {'inquiry_sku': brandName.toUpperCase(), 'buyer_sku_code': '${brandName.toUpperCase()}P'};
  }

  /// admin_fee produk dinamis (nominal bebas) milik brand yang sedang
  /// dipilih — dipakai untuk menghitung Harga semua nominal preset/custom.
  double _ewalletAdminFeeForBrand() {
    final dyn = _products.firstWhere(
      (p) => _isDynamicProduct(Map<String, dynamic>.from(p as Map)),
      orElse: () => null,
    );
    if (dyn == null) return 0.0;
    return _asAdminFee(Map<String, dynamic>.from(dyn as Map));
  }

  Map<String, dynamic> _buildEwalletVirtualProduct({
    required String brandName,
    required int amount,
    required double adminFee,
    required bool isCustom,
    double apiPrice = 0.0,
  }) {
    final skuInfo = _ewalletSkuInfo(brandName);
    return {
      'buyer_sku_code': skuInfo['buyer_sku_code'],
      'inquiry_sku': skuInfo['inquiry_sku'],
      'product_name': _currencyFormat.format(amount),
      // `nominal` = preset amount murni; `price` = harga retail final
      // (nominal + margin dari response API) — dipisah supaya UI bisa
      // menampilkan keduanya tanpa saling menimpa.
      'nominal': amount,
      'price': amount + apiPrice,
      'admin_fee': adminFee,
      if (isCustom) 'custom_amount': amount else 'simulated_amount': amount,
      'brand': brandName,
      'provider': 'loketbayar',
      'category': widget.category,
      'is_dynamic': true,
    };
  }

  bool _isEwalletAmountSelected(int amount, {bool custom = false}) {
    final sel = _selectedProduct;
    if (sel == null) return false;
    final key = custom ? sel['custom_amount'] : sel['simulated_amount'];
    return key is num && key.toInt() == amount;
  }

  Future<void> _onEwalletProviderTapDesktop(String brandName) async {
    if (_selectedBrand == brandName) return;
    setState(() {
      _ewalletBrandPicked = true;
      _selectedBrand = brandName;
      _selectedProduct = null;
      _products = [];
      _customAmountController.clear();
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedBrandCacheKey, brandName);
    await _loadProducts(showLoading: true);
  }

  /// Alur konfirmasi Top Up E-Wallet desktop: cek nama penerima (sama
  /// persis dengan blok `_isEmoney` di `_onProductSelected`, dipindah ke
  /// tombol "Top Up Sekarang" alih-alih dieksekusi otomatis saat kartu
  /// nominal disentuh) lalu langsung ke popup PIN — panel "Detail
  /// Transaksi" di sidebar kanan sudah menggantikan halaman detail terpisah.
  Future<void> _continueEwalletTopUp() async {
    _dismissInputAndNumpad();

    final product = _selectedProduct;
    if (product == null) {
      showToast(msg: 'Pilih nominal top up terlebih dahulu');
      return;
    }
    final customerId = _customerIdController.text.trim();
    if (customerId.isEmpty) {
      showToast(msg: 'Masukkan nomor tujuan terlebih dahulu');
      return;
    }
    if (_isValidatingRecipient) return;

    setState(() => _isValidatingRecipient = true);

    final isEmoneyDynamic =
        !(widget.initialBrand != null && widget.initialBrand!.trim().isNotEmpty);
    final categoryOverride = isEmoneyDynamic ? _selectedBrand : null;
    final brandForInquiry = (widget.initialBrand != null && widget.initialBrand!.trim().isNotEmpty)
        ? widget.initialBrand
        : _selectedBrand;

    const supportedInquiryBrands = {'gopay', 'dana', 'ovo', 'shopeepay'};
    final brandKey = (brandForInquiry ?? '').toLowerCase().replaceAll(RegExp(r'\s+'), '');
    final brandSupportsInquiry = supportedInquiryBrands.contains(brandKey);

    String? recipientName;
    bool requireRecipientName = true;
    if (!brandSupportsInquiry) {
      requireRecipientName = false;
      showToast(msg: 'Cek nama belum tersedia untuk brand ini, lanjut tanpa verifikasi nama');
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
        showToast(msg: 'Verifikasi berhasil, namun nama penerima tidak dikirim provider');
      }
    }

    if (!mounted) return;
    setState(() => _isValidatingRecipient = false);

    if (requireRecipientName && recipientName == null) {
      return;
    }

    _goToPin(product);
  }

  Widget _buildEwalletProviderCard(Map<String, dynamic> brand) {
    final name = brand['name'] as String;
    final icon = brand['icon'] as IconData;
    final color = brand['color'] as Color;
    final logo = brand['logo'] as String?;
    final selected = _selectedBrand == name;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => unawaited(_onEwalletProviderTapDesktop(name)),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
          decoration: BoxDecoration(
            color: desktopSurfaceCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? desktopAccentBlue : desktopBorder, width: selected ? 1.5 : 1),
          ),
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 52,
                    height: 52,
                    child: (logo != null && logo.isNotEmpty)
                        ? (logo.toLowerCase().endsWith('.svg')
                            ? SvgPicture.asset(
                                logo,
                                fit: BoxFit.contain,
                                placeholderBuilder: (_) => Icon(icon, color: color, size: 36),
                                errorBuilder: (_, __, ___) => Icon(icon, color: color, size: 36),
                              )
                            : Image.asset(
                                logo,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => Icon(icon, color: color, size: 36),
                              ))
                        : Icon(icon, color: color, size: 36),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    name,
                    style: GoogleFonts.hankenGrotesk(fontSize: 12.5, fontWeight: FontWeight.w700, color: desktopTextPrimary),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              if (selected)
                Positioned(
                  top: -8,
                  right: -8,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: const BoxDecoration(color: desktopAccentBlue, shape: BoxShape.circle),
                    child: const Icon(Icons.check_rounded, size: 12, color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Margin (field `retail` di response API) untuk brand yang sedang
  /// dipilih. Berbeda dari dugaan awal: API e-wallet TIDAK mengembalikan
  /// satu produk per nominal preset — cuma satu SKU "Nominal Bebas" per
  /// brand (lihat log `[EWALLET][DEBUG]`), dan `retail`-nya itu satu angka
  /// tetap yang berlaku untuk nominal berapa pun (preset maupun custom).
  /// Diambil dari produk dinamis brand ini, sama seperti
  /// `_ewalletAdminFeeForBrand`.
  double _ewalletRetailMarginForBrand() {
    final dyn = _products.firstWhere(
      (p) => _isDynamicProduct(Map<String, dynamic>.from(p as Map)),
      orElse: () => null,
    );
    if (dyn == null) return 0.0;
    return _asDouble(Map<String, dynamic>.from(dyn as Map)['retail']);
  }

  Widget _buildEwalletNominalTile(int amount, double adminFee, double retailMargin) {
    final selected = _isEwalletAmountSelected(amount);
    // Harga retail e-wallet = nominal (preset amount) + retail dari response
    // API (margin flat per brand) — biaya admin baru ditambahkan belakangan
    // di ringkasan/konfirmasi, bukan digabung di sini.
    final harga = amount + retailMargin;
    return PpobNominalCard(
      title: _currencyFormat.format(amount),
      priceLabel: _formatPrice(harga),
      selected: selected,
      onTap: () {
        setState(() {
          _selectedProduct = _buildEwalletVirtualProduct(
            brandName: _selectedBrand ?? widget.initialBrand ?? 'DANA',
            amount: amount,
            adminFee: adminFee,
            isCustom: false,
            apiPrice: retailMargin,
          );
          _customAmountController.clear();
        });
      },
    );
  }

  // Layout desktop dua-kolom khusus Top Up E-Wallet: kiri = pilih penyedia
  // + nomor tujuan + grid nominal (dengan opsi nominal custom), kanan =
  // ringkasan transaksi sticky. Tombol "Top Up Sekarang" memanggil
  // _continueEwalletTopUp (cek nama penerima via Loket Bayar, lalu ke PIN).
  Widget _buildDesktopEwalletLayout() {
    // Default provider begitu halaman ini dibuka tanpa brand terpilih
    // (mis. pertama kali masuk dari menu "E-Wallet"), meniru referensi
    // desain yang langsung menampilkan grid nominal DANA. Dijadwalkan
    // setelah frame pertama supaya tidak memicu setState() saat build().
    if (_selectedBrand == null && !_isLoadingBrands) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _selectedBrand != null) return;
        unawaited(_onEwalletProviderTapDesktop('DANA'));
      });
    }

    final customerId = _customerIdController.text.trim();
    final hasCustomerInput = customerId.isNotEmpty;
    final brandName = _selectedBrand ?? 'DANA';
    final adminFee = _ewalletAdminFeeForBrand();
    final retailMargin = _ewalletRetailMarginForBrand();
    final selected = _selectedProduct;
    // `nominal` = preset amount murni (face value). `harga` = harga retail
    // final yang sudah disimpan di `_buildEwalletVirtualProduct` sebagai
    // `price` (nominal + margin dari response API) — bukan `selected['price']`
    // dianggap nominal seperti sebelumnya. `total` baru menambahkan admin.
    final nominal = selected == null ? 0.0 : _asDouble(selected['nominal']);
    final harga = selected == null ? 0.0 : _asDouble(selected['price']);
    final total = selected == null ? 0.0 : harga + _asAdminFee(selected);
    final numberValid = hasCustomerInput && _validateCustomerIdByBrand(customerId) == null;
    final canConfirm = selected != null && numberValid && !_isValidatingRecipient;

    return Scaffold(
      backgroundColor: desktopSurfacePage,
      body: PpobDesktopTwoColumnLayout(
        left: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDesktopCategoryHeader(
              titleOverride: 'Top Up E-Wallet',
              subtitleOverride: 'Isi saldo e-wallet favoritmu dengan mudah dan cepat',
            ),
            const SizedBox(height: 28),
            const PpobStepHeader(step: 1, title: 'Pilih Penyedia E-Wallet'),
            const SizedBox(height: 14),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _ewalletBrandsDesktop.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                mainAxisExtent: 116,
              ),
              itemBuilder: (_, i) => _buildEwalletProviderCard(_ewalletBrandsDesktop[i]),
            ),
            const SizedBox(height: 28),
            const PpobStepHeader(step: 2, title: 'Masukkan Nomor / ID'),
            const SizedBox(height: 12),
            desktopBorderedField(
              icon: Icons.smartphone_outlined,
              controller: _customerIdController,
              focusNode: _customerIdFocusNode,
              keyboardType: TextInputType.phone,
              hint: 'Masukkan nomor $brandName',
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => setState(() {}),
              suffix: _inlineFieldAction(icon: Icons.contacts_rounded, label: 'Kontak', onTap: _pickNumberFromContact),
            ),
            if (numberValid) ...[
              const SizedBox(height: 14),
              PpobDesktopBanner(
                icon: Icons.check_circle_rounded,
                title: 'Nomor terverifikasi',
                trailing: _verifiedInfoChip('Akun $brandName', customerId),
              ),
            ],
            const SizedBox(height: 28),
            const PpobStepHeader(step: 3, title: 'Pilih Nominal Top Up'),
            const SizedBox(height: 14),
            if (_isLoadingProducts)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _ewalletPresetAmounts.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  mainAxisExtent: 100,
                ),
                itemBuilder: (_, i) => _buildEwalletNominalTile(_ewalletPresetAmounts[i], adminFee, retailMargin),
              ),
            const SizedBox(height: 16),
            PpobDesktopBanner(
              icon: Icons.info_outline_rounded,
              title: 'Pastikan nomor e-wallet sudah benar. Saldo yang sudah diisi tidak dapat dikembalikan.',
              tone: PpobBannerTone.info,
            ),
          ],
        ),
        right: PpobDesktopSummaryPanel(
          rows: [
            PpobDetailRow(icon: Icons.account_balance_wallet_outlined, label: 'Penyedia', value: brandName),
            PpobDetailRow(icon: Icons.smartphone_outlined, label: 'Nomor', value: hasCustomerInput ? customerId : '-'),
            const PpobDetailRow(icon: Icons.inventory_2_outlined, label: 'Produk', value: 'Top Up E-Wallet'),
            PpobDetailRow(icon: Icons.confirmation_number_outlined, label: 'Nominal', value: selected != null ? _formatPrice(nominal) : '-'),
            // "Harga" = harga retail = nominal + price dari response API,
            // belum termasuk admin — admin ditambahkan terpisah di baris di
            // bawah, dan digabung ke "Total Pembayaran" (`totalLabel`).
            PpobDetailRow(icon: Icons.sell_outlined, label: 'Harga', value: selected != null ? _formatPrice(harga) : 'Rp 0'),
            PpobDetailRow(icon: Icons.receipt_long_outlined, label: 'Admin', value: _formatPrice(adminFee)),
          ],
          totalLabel: _formatPrice(total),
          confirmLabel: 'Top Up Sekarang',
          loading: _isValidatingRecipient,
          onConfirm: canConfirm ? _continueEwalletTopUp : null,
        ),
      ),
    );
  }

  // ── PLN Pasca (desktop): cek tagihan otomatis (debounced) ──────────────
  void _onPlnPascaCustomerIdChangedDesktop(String value) {
    final digitsOnly = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (value != digitsOnly) {
      _setCustomerId(digitsOnly);
      return;
    }
    if (_plnPostpaidInquiryResult != null || _plnPostpaidError != null) {
      setState(() {
        _plnPostpaidInquiryResult = null;
        _plnPostpaidError = null;
        _showPlnPascaDetail = false;
      });
    } else {
      setState(() {});
    }
    _plnPascaVerifyDebounce?.cancel();
    if (digitsOnly.length < 8) return;
    _plnPascaVerifyDebounce = Timer(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      unawaited(_doPlnPostpaidInquiry());
    });
  }

  Future<void> _pastePlnPascaCustomerId() async {
    final data = await Clipboard.getData('text/plain');
    final text = data?.text?.trim() ?? '';
    if (text.isEmpty) {
      showToast(msg: 'Clipboard kosong');
      return;
    }
    _onPlnPascaCustomerIdChangedDesktop(text);
  }

  Future<void> _openPlnPascaHistoryDesktop() async {
    await _openSavedCustomers(desktopAccentBlue);
    final id = _customerIdController.text.trim();
    if (id.length >= 8) {
      unawaited(_doPlnPostpaidInquiry());
    }
  }

  /// Ekstrak field tampilan dari `_plnPostpaidInquiryResult`, sama persis
  /// dengan komputasi di `_buildPlnPostpaidSection` (alur mobile) supaya
  /// nilai yang ditampilkan konsisten — plus alamat/nomor meter/batas bayar
  /// yang tidak dipakai di kartu mobile.
  Map<String, dynamic> _plnPascaSummary() {
    final plnData = _plnPostpaidInquiryResult;
    final desc = plnData == null ? const <String, dynamic>{} : _plnDescMap(plnData);
    Map<String, dynamic> firstBill = const <String, dynamic>{};
    if (plnData != null) {
      final tagihan = plnData['tagihan'];
      if (tagihan is List && tagihan.isNotEmpty && tagihan.first is Map) {
        firstBill = Map<String, dynamic>.from(tagihan.first as Map);
      } else {
        firstBill = _plnFirstDetailMap(plnData);
      }
    }

    final idpel = (plnData?['customer_no'] ?? plnData?['subscriberID'] ?? '-').toString();
    final nama = (plnData?['customer_name'] ?? plnData?['nama'] ?? '-').toString();
    final alamat =
        (plnData?['alamat'] ?? plnData?['address'] ?? desc['alamat'] ?? desc['address'] ?? '-').toString();

    String tarifDaya = (plnData?['tariff_daya'] ?? plnData?['tarifDaya'] ?? '').toString().trim();
    if (tarifDaya.isEmpty) {
      final tarif = (desc['tarif'] ?? '').toString().trim();
      final daya = (desc['daya'] ?? '').toString().trim();
      tarifDaya = '${tarif.isEmpty ? '-' : tarif}/${daya.isEmpty ? '-' : daya}';
    }

    final meterNo =
        (plnData?['meter_no'] ?? plnData?['no_meter'] ?? plnData?['nometer'] ?? firstBill['meter_no'] ?? '-')
            .toString();

    final periodRaw = firstBill['periode'] ?? plnData?['periode'];
    final periode = _formatPlnBillingPeriod(periodRaw);

    final dueDate = (plnData?['due_date'] ??
            plnData?['tgl_jatuh_tempo'] ??
            plnData?['jatuh_tempo'] ??
            desc['due_date'] ??
            firstBill['due_date'] ??
            '-')
        .toString();

    final rpTagPln = _asMoney(firstBill['nominal'] ?? plnData?['nominal'] ?? plnData?['selling_price']);
    final adminBank = _asMoney(firstBill['admin'] ?? plnData?['admin']);
    final denda = _asMoney(firstBill['denda'] ?? desc['denda']);
    final meterAwal = (firstBill['meterAwal'] ?? firstBill['meter_awal'] ?? '-').toString();
    final meterAkhir = (firstBill['meterAkhir'] ?? firstBill['meter_akhir'] ?? '-').toString();
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
    final tagihanList = plnData?['tagihan'];
    final int lembar = () {
      final fromField = plnData?['lembar_tagihan'] ?? plnData?['lembarTagihan'];
      if (fromField is num) return fromField.toInt();
      final parsed = int.tryParse('${fromField ?? ''}');
      if (parsed != null && parsed > 0) return parsed;
      if (tagihanList is List) return tagihanList.length;
      return plnData == null ? 0 : 1;
    }();

    return {
      'idpel': idpel,
      'nama': nama,
      'alamat': alamat,
      'tarifDaya': tarifDaya,
      'meterNo': meterNo,
      'periode': periode,
      'dueDate': dueDate,
      'rpTagPln': rpTagPln,
      'adminBank': adminBank,
      'denda': denda,
      'meterAwal': meterAwal,
      'meterAkhir': meterAkhir,
      'totalBayar': totalBayar,
      'lembar': lembar,
    };
  }

  Widget _plnPascaInfoPair(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.hankenGrotesk(fontSize: 11.5, color: desktopTextSecondary)),
          const SizedBox(height: 3),
          Text(
            value,
            style: GoogleFonts.hankenGrotesk(fontSize: 12.5, fontWeight: FontWeight.w700, color: desktopTextPrimary),
          ),
        ],
      ),
    );
  }

  Widget _plnPascaBillTile(IconData icon, String label, String value, {Color? valueColor}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: desktopSurfaceCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: desktopBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: desktopAccentBlue),
            const SizedBox(height: 8),
            Text(label, style: GoogleFonts.hankenGrotesk(fontSize: 11, color: desktopTextSecondary)),
            const SizedBox(height: 2),
            Text(
              value,
              style: GoogleFonts.hankenGrotesk(fontSize: 12.5, fontWeight: FontWeight.w700, color: valueColor ?? desktopTextPrimary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // Layout desktop dua-kolom khusus Pembayaran PLN Pasca: kiri = input ID
  // Pelanggan (cek tagihan otomatis, debounced) + kartu info pelanggan +
  // rincian tagihan + metode pembayaran, kanan = ringkasan transaksi
  // sticky. Tombol "Bayar Sekarang" memanggil _payPlnPostpaidBill yang
  // sudah ada (alur mobile) — API pembayaran PLN Pasca (purchasePpobPostpaid)
  // beda dari alur PPOB lain, jadi tidak dialihkan ke TransactionPinAuthDialog.
  Widget _buildDesktopPlnPascaLayout() {
    final customerId = _customerIdController.text.trim();
    final hasCustomerInput = customerId.isNotEmpty;
    final summary = _plnPascaSummary();
    final hasBill = _plnPostpaidInquiryResult != null;
    final canConfirm = hasBill && !_isPlnPostpaidInquiring;

    return Scaffold(
      backgroundColor: desktopSurfacePage,
      body: PpobDesktopTwoColumnLayout(
        left: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDesktopCategoryHeader(
              titleOverride: 'Pembayaran PLN Pasca',
              subtitleOverride: 'Bayar tagihan listrik pascabayar lebih mudah dan cepat',
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: desktopSurfacePage,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: desktopBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(color: const Color(0xFFFFC728), borderRadius: BorderRadius.circular(6)),
                      alignment: Alignment.center,
                      child: const Icon(Icons.bolt_rounded, size: 16, color: Color(0xFF1A1A1A)),
                    ),
                    const SizedBox(width: 8),
                    Text('PLN\nPascabayar', style: GoogleFonts.hankenGrotesk(fontSize: 10.5, fontWeight: FontWeight.w800, color: desktopTextPrimary, height: 1.1)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),
            const PpobStepHeader(step: 1, title: 'Masukkan ID Pelanggan / Nomor Meter'),
            const SizedBox(height: 12),
            desktopBorderedField(
              icon: Icons.badge_outlined,
              controller: _customerIdController,
              focusNode: _customerIdFocusNode,
              keyboardType: TextInputType.number,
              hint: 'Masukkan ID Pelanggan / Nomor Meter',
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: _onPlnPascaCustomerIdChangedDesktop,
              suffix: Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isPlnPostpaidInquiring)
                      const Padding(
                        padding: EdgeInsets.only(right: 8),
                        child: SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(desktopAccentBlue)),
                        ),
                      ),
                    _inlineFieldAction(icon: Icons.content_paste_rounded, label: 'Tempel', onTap: _pastePlnPascaCustomerId),
                    Container(height: 18, width: 1, color: desktopBorder, margin: const EdgeInsets.symmetric(horizontal: 4)),
                    _inlineFieldAction(icon: Icons.history_rounded, label: 'Riwayat', onTap: _openPlnPascaHistoryDesktop),
                  ],
                ),
              ),
            ),
            if (_plnPostpaidError != null && !_isPlnPostpaidInquiring) ...[
              const SizedBox(height: 14),
              AppAlert(
                tone: AppAlertTone.error,
                title: 'Tidak dapat memeriksa tagihan',
                description: _plnPostpaidError!,
              ),
            ],
            if (hasBill) ...[
              const SizedBox(height: 14),
              const PpobDesktopBanner(icon: Icons.check_circle_rounded, title: 'ID Pelanggan ditemukan'),
              const SizedBox(height: 14),
              // ── Informasi Pelanggan ──────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: desktopSurfacePage,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(color: desktopAccentBlue.withValues(alpha: 0.1), shape: BoxShape.circle),
                          alignment: Alignment.center,
                          child: const Icon(Icons.person_outline_rounded, size: 16, color: desktopAccentBlue),
                        ),
                        const SizedBox(width: 10),
                        Text('Informasi Pelanggan', style: GoogleFonts.hankenGrotesk(fontSize: 13, fontWeight: FontWeight.w700, color: desktopTextPrimary)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _plnPascaInfoPair('Nama', summary['nama'] as String),
                        _plnPascaInfoPair('ID Pelanggan', summary['idpel'] as String),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _plnPascaInfoPair('Alamat', summary['alamat'] as String),
                        _plnPascaInfoPair('Tarif / Daya', summary['tarifDaya'] as String),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Expanded(child: SizedBox.shrink()),
                        _plnPascaInfoPair('Nomor Meter', summary['meterNo'] as String),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const PpobStepHeader(step: 2, title: 'Detail Tagihan'),
              const SizedBox(height: 12),
              Row(
                children: [
                  _plnPascaBillTile(Icons.calendar_month_outlined, 'Bulan Tagihan', summary['periode'] as String),
                  const SizedBox(width: 10),
                  _plnPascaBillTile(Icons.description_outlined, 'Jumlah Tagihan', _formatPrice(summary['rpTagPln'] as double)),
                  const SizedBox(width: 10),
                  _plnPascaBillTile(Icons.schedule_outlined, 'Batas Bayar', summary['dueDate'] as String),
                  const SizedBox(width: 10),
                  _plnPascaBillTile(Icons.info_outline_rounded, 'Status', 'Belum Dibayar', valueColor: desktopErrorRed),
                ],
              ),
              const SizedBox(height: 10),
              InkWell(
                onTap: () => setState(() => _showPlnPascaDetail = !_showPlnPascaDetail),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _showPlnPascaDetail ? 'Sembunyikan Rincian Tagihan' : 'Lihat Rincian Tagihan',
                        style: GoogleFonts.hankenGrotesk(fontSize: 12.5, fontWeight: FontWeight.w700, color: desktopAccentBlue),
                      ),
                      const SizedBox(width: 4),
                      Icon(_showPlnPascaDetail ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, size: 18, color: desktopAccentBlue),
                    ],
                  ),
                ),
              ),
              if (_showPlnPascaDetail) ...[
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: desktopSurfacePage,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      PpobDetailRow(icon: Icons.speed_outlined, label: 'Meter Awal', value: summary['meterAwal'] as String),
                      PpobDetailRow(icon: Icons.speed_outlined, label: 'Meter Akhir', value: summary['meterAkhir'] as String),
                      PpobDetailRow(icon: Icons.receipt_long_outlined, label: 'Admin Bank', value: _formatPrice(summary['adminBank'] as double)),
                      PpobDetailRow(icon: Icons.report_gmailerrorred_outlined, label: 'Denda', value: _formatPrice(summary['denda'] as double)),
                      PpobDetailRow(icon: Icons.description_outlined, label: 'Lembar Tagihan', value: '${summary['lembar']} lembar'),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              const PpobStepHeader(step: 3, title: 'Metode Pembayaran'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: desktopSurfaceCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: desktopAccentBlue, width: 1.5),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.radio_button_checked_rounded, color: desktopAccentBlue, size: 20),
                    const SizedBox(width: 12),
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(color: desktopAccentBlue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                      alignment: Alignment.center,
                      child: const Icon(Icons.account_balance_wallet_rounded, size: 17, color: desktopAccentBlue),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Saldo Modipay', style: GoogleFonts.hankenGrotesk(fontSize: 13, fontWeight: FontWeight.w700, color: desktopTextPrimary)),
                          Text(
                            'Saldo tersedia ${_formatPrice(_parseBalanceValue(Provider.of<AuthProvider>(context, listen: false).userBalance))}',
                            style: GoogleFonts.hankenGrotesk(fontSize: 11.5, color: desktopTextSecondary),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: desktopSuccessBg, borderRadius: BorderRadius.circular(20)),
                      child: Text('Disarankan', style: GoogleFonts.hankenGrotesk(fontSize: 10.5, fontWeight: FontWeight.w700, color: desktopSuccessFg)),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            PpobDesktopBanner(
              icon: Icons.info_outline_rounded,
              title: 'Pastikan ID Pelanggan sudah benar. Pembayaran yang sudah berhasil tidak dapat dibatalkan.',
              tone: PpobBannerTone.info,
            ),
          ],
        ),
        right: PpobDesktopSummaryPanel(
          rows: [
            const PpobDetailRow(icon: Icons.bolt_outlined, label: 'Penyedia', value: 'PLN Pasca'),
            PpobDetailRow(icon: Icons.badge_outlined, label: 'ID Pelanggan', value: hasCustomerInput ? customerId : '-'),
            PpobDetailRow(icon: Icons.person_outline, label: 'Nama', value: hasBill ? summary['nama'] as String : '-'),
            PpobDetailRow(icon: Icons.flash_on_outlined, label: 'Tarif / Daya', value: hasBill ? summary['tarifDaya'] as String : '-'),
            PpobDetailRow(icon: Icons.calendar_month_outlined, label: 'Bulan Tagihan', value: hasBill ? summary['periode'] as String : '-'),
            PpobDetailRow(icon: Icons.description_outlined, label: 'Jumlah Tagihan', value: hasBill ? _formatPrice(summary['rpTagPln'] as double) : 'Rp 0'),
            PpobDetailRow(
              icon: Icons.receipt_long_outlined,
              label: 'Admin',
              value: hasBill ? _formatPrice((summary['adminBank'] as double) + (summary['denda'] as double)) : 'Rp 0',
            ),
          ],
          totalLabel: hasBill ? _formatPrice(summary['totalBayar'] as double) : 'Rp 0',
          confirmLabel: 'Bayar Sekarang',
          loading: _isPlnPostpaidInquiring,
          onConfirm: canConfirm ? _payPlnPostpaidBill : null,
        ),
      ),
    );
  }

  // ── Hub "Internet & TV" (desktop) ───────────────────────────────────────
  static const List<Map<String, String>> _internetProvidersDesktop = [
    {'name': 'IndiHome', 'logo': 'images/provider_logos/indihome.png'},
    {'name': 'ICONNET', 'logo': ''},
    {'name': 'CBN', 'logo': 'images/provider_logos/cbn.png'},
    {'name': 'MyRepublic', 'logo': 'images/provider_logos/myrep.png'},
    {'name': 'Biznet', 'logo': 'images/provider_logos/biznet.png'},
  ];

  void _onInternetCustomerIdChangedDesktop(String value) {
    final digitsOnly = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (value != digitsOnly) {
      _setCustomerId(digitsOnly);
      return;
    }
    if (_internetInquiryResult != null || _internetInquiryError != null) {
      setState(() {
        _internetInquiryResult = null;
        _internetInquiryError = null;
      });
    } else {
      setState(() {});
    }
  }

  void _onSelectInternetProvider(String provider) {
    if (_selectedInternetProvider == provider) return;
    setState(() {
      _selectedInternetProvider = provider;
      _internetInquiryResult = null;
      _internetInquiryError = null;
    });
  }

  Widget _internetProviderCard(Map<String, String> provider) {
    final name = provider['name']!;
    final logo = provider['logo'] ?? '';
    final selected = _selectedInternetProvider == name;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _onSelectInternetProvider(name),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          decoration: BoxDecoration(
            color: desktopSurfaceCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? desktopAccentBlue : desktopBorder, width: selected ? 1.5 : 1),
          ),
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: logo.isEmpty
                        ? Icon(Icons.wifi_rounded, color: desktopAccentBlue, size: 28)
                        : Image.asset(
                            logo,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => Icon(Icons.wifi_rounded, color: desktopAccentBlue, size: 28),
                          ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    name,
                    style: GoogleFonts.hankenGrotesk(fontSize: 12, fontWeight: FontWeight.w700, color: desktopTextPrimary),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              if (selected)
                Positioned(
                  top: -8,
                  right: -8,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: const BoxDecoration(color: desktopAccentBlue, shape: BoxShape.circle),
                    child: const Icon(Icons.check_rounded, size: 12, color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _internetInfoPair(String label, Widget value) {
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

  Widget _internetInfoPairText(String label, String value) {
    return _internetInfoPair(
      label,
      Text(value, style: GoogleFonts.hankenGrotesk(fontSize: 12.5, fontWeight: FontWeight.w700, color: desktopTextPrimary)),
    );
  }

  Widget _internetRincianRow(String label, String value, {bool highlight = false}) {
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

  Widget _buildDesktopInternetBillInfo() {
    final data = _internetInquiryResult;
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
    final periode = (data['periode'] ?? '-').toString();
    final paket = (data['product_name'] ?? _selectedInternetProvider ?? '-').toString();
    final alamat = (data['alamat'] ?? data['address'] ?? '').toString();
    final tagihanAmount = _asDouble(data['nominal'] ?? data['tagihan']);
    final admin = _asDouble(data['admin']);
    final ppn = _asDouble(data['ppn'] ?? data['pajak'] ?? data['tax']);
    var total = _asDouble(data['total'] ?? data['selling_price']);
    if (total <= 0) total = tagihanAmount + admin + ppn;

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
                decoration: BoxDecoration(color: desktopAccentBlue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                alignment: Alignment.center,
                child: const Icon(Icons.wifi_rounded, color: desktopAccentBlue, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _internetInfoPairText('Nama Pelanggan', (data['nama'] ?? data['customer_name'] ?? '-').toString()),
                        _internetInfoPairText('Periode', periode),
                      ],
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _internetInfoPairText('ID Pelanggan', (data['idpel'] ?? data['customer_no'] ?? customerId).toString()),
                        _internetInfoPairText('Tagihan Bulan', periode),
                      ],
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _internetInfoPairText('Paket', paket),
                        _internetInfoPair('Status', _statusBadgeChip('Belum Dibayar', desktopErrorRed)),
                      ],
                    ),
                    if (alamat.isNotEmpty) _internetInfoPairText('Alamat', alamat),
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
                _internetRincianRow('Tagihan Paket${paket != '-' ? ' ($paket)' : ''}', _formatPrice(tagihanAmount)),
                if (ppn > 0) _internetRincianRow('PPN 11%', _formatPrice(ppn)),
                _internetRincianRow('Admin', _formatPrice(admin)),
                const SizedBox(height: 6),
                Divider(color: desktopBorder.withValues(alpha: 0.6), height: 1),
                const SizedBox(height: 6),
                _internetRincianRow('Total Tagihan', _formatPrice(total), highlight: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadgeChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: GoogleFonts.hankenGrotesk(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }

  // Layout desktop dua-kolom khusus hub Internet & TV: kiri = pilih
  // penyedia + ID Pelanggan + tombol "Cek Tagihan" + informasi tagihan
  // inline, kanan = ringkasan transaksi sticky. Tombol "Bayar Sekarang"
  // memanggil _payInternetBill (alur PIN yang sama dengan BPJS/PLN Pasca).
  Widget _buildDesktopInternetLayout() {
    final data = _internetInquiryResult;
    final customerId = _customerIdController.text.trim();
    final periode = data != null ? (data['periode'] ?? '-').toString() : '-';
    final paket = data != null ? (data['product_name'] ?? _selectedInternetProvider ?? '-').toString() : '-';
    final tagihanAmount = data != null ? _asDouble(data['nominal'] ?? data['tagihan']) : 0.0;
    final admin = data != null ? _asDouble(data['admin']) : 0.0;
    final ppn = data != null ? _asDouble(data['ppn'] ?? data['pajak'] ?? data['tax']) : 0.0;
    var total = data != null ? _asDouble(data['total'] ?? data['selling_price']) : 0.0;
    if (data != null && total <= 0) total = tagihanAmount + admin + ppn;
    final canConfirm = data != null && !_isInternetInquiring;

    return Scaffold(
      backgroundColor: desktopSurfacePage,
      body: PpobDesktopTwoColumnLayout(
        left: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDesktopCategoryHeader(
              titleOverride: 'Pembayaran Internet & TV',
              subtitleOverride: 'Bayar tagihan internet & TV IndiHome, Iconnet, CBN, MyRepublic, Biznet dengan mudah',
            ),
            const SizedBox(height: 28),
            const PpobStepHeader(step: 1, title: 'Pilih Penyedia'),
            const SizedBox(height: 14),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _internetProvidersDesktop.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                mainAxisExtent: 108,
              ),
              itemBuilder: (_, i) => _internetProviderCard(_internetProvidersDesktop[i]),
            ),
            const SizedBox(height: 28),
            const PpobStepHeader(
              step: 2,
              title: 'Masukkan ID Pelanggan',
              subtitle: 'ID Pelanggan / Nomor Internet',
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: desktopBorderedField(
                    icon: Icons.person_outline_rounded,
                    controller: _customerIdController,
                    focusNode: _customerIdFocusNode,
                    keyboardType: TextInputType.number,
                    hint: 'Contoh: 123456789012',
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: _onInternetCustomerIdChangedDesktop,
                    onSubmitted: (_) => _isInternetInquiring ? null : _doInternetInquiry(),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _isInternetInquiring ? null : _doInternetInquiry,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: desktopPrimaryBtn,
                      disabledBackgroundColor: desktopPrimaryBtn.withValues(alpha: 0.5),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: _isInternetInquiring
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
            if (_internetInquiryError != null && !_isInternetInquiring) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4F4),
                  border: Border.all(color: const Color(0xFFF5C2C2)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(_internetInquiryError!, style: GoogleFonts.hankenGrotesk(fontSize: 12.5, color: const Color(0xFFB00020))),
              ),
            ] else ...[
              const SizedBox(height: 12),
              const PpobDesktopBanner(
                icon: Icons.info_outline_rounded,
                title: 'Pastikan ID Pelanggan / Nomor Internet sesuai dengan tagihan Anda.',
                tone: PpobBannerTone.info,
              ),
            ],
            const SizedBox(height: 28),
            const PpobStepHeader(step: 3, title: 'Informasi Tagihan'),
            const SizedBox(height: 12),
            _buildDesktopInternetBillInfo(),
            if (data != null) ...[
              const SizedBox(height: 12),
              const PpobDesktopBanner(
                icon: Icons.info_outline_rounded,
                title: 'Tagihan akan dibayarkan secara real-time dan langsung tercatat.',
                tone: PpobBannerTone.info,
              ),
            ],
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: desktopBorder.withValues(alpha: 0.5)))),
              child: Row(
                children: [
                  _desktopTrustBadge(Icons.bolt_rounded, 'Pembayaran Instan', 'Langsung diproses'),
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
            PpobDetailRow(icon: Icons.wifi_outlined, label: 'Penyedia', value: _selectedInternetProvider ?? '-'),
            PpobDetailRow(icon: Icons.badge_outlined, label: 'ID Pelanggan', value: data != null ? (data['idpel'] ?? data['customer_no'] ?? customerId).toString() : '-'),
            PpobDetailRow(icon: Icons.person_outline, label: 'Nama Pelanggan', value: data != null ? (data['nama'] ?? data['customer_name'] ?? '-').toString() : '-'),
            PpobDetailRow(icon: Icons.inventory_2_outlined, label: 'Paket', value: paket),
            PpobDetailRow(icon: Icons.calendar_month_outlined, label: 'Periode', value: periode),
            PpobDetailRow(icon: Icons.description_outlined, label: 'Tagihan', value: data != null ? _formatPrice(tagihanAmount) : '-'),
            PpobDetailRow(icon: Icons.receipt_long_outlined, label: 'Admin', value: data != null ? _formatPrice(admin) : '-'),
          ],
          totalLabel: data != null ? _formatPrice(total) : 'Rp 0',
          confirmLabel: 'Bayar Sekarang',
          loading: _isInternetInquiring,
          onConfirm: canConfirm ? _payInternetBill : null,
        ),
      ),
    );
  }

  // ── Hub "Multifinance" (desktop) ────────────────────────────────────────
  void _onSelectMultifinanceBrand(String brand) {
    if (_selectedMultifinanceBrand == brand) return;
    setState(() {
      _selectedMultifinanceBrand = brand;
      _multifinanceInquiryResult = null;
      _multifinanceInquiryError = null;
    });
  }

  Widget _multifinanceBrandRow(String brand) {
    final selected = _selectedMultifinanceBrand == brand;
    return InkWell(
      onTap: () => _onSelectMultifinanceBrand(brand),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: selected ? desktopAccentBlue.withValues(alpha: 0.06) : desktopSurfaceCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? desktopAccentBlue : desktopBorder, width: selected ? 1.5 : 1),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: desktopAccentBlue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              alignment: Alignment.center,
              child: const Icon(Icons.account_balance_outlined, color: desktopAccentBlue, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                brand,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.hankenGrotesk(fontSize: 12.5, fontWeight: FontWeight.w700, color: desktopTextPrimary),
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle_rounded, color: desktopAccentBlue, size: 18)
            else
              Icon(Icons.chevron_right_rounded, color: desktopTextSecondary.withValues(alpha: 0.5), size: 18),
          ],
        ),
      ),
    );
  }

  // Layout desktop dua-kolom khusus hub Multifinance: kiri = cari & pilih
  // provider (33 brand, jadi pakai list+search alih-alih grid ikon seperti
  // Internet & TV) + ID Pelanggan/Kontrak + tombol "Cek Tagihan" +
  // informasi tagihan inline, kanan = ringkasan transaksi sticky.
  Widget _buildDesktopMultifinanceLayout() {
    final q = _hubSearchQuery.toLowerCase();
    final filteredBrands = q.isEmpty
        ? _multifinanceBrands
        : _multifinanceBrands.where((b) => b.toLowerCase().contains(q)).toList();

    final data = _multifinanceInquiryResult;
    final customerId = _customerIdController.text.trim();
    final periode = data != null ? (data['periode'] ?? '-').toString() : '-';
    final produk = data != null ? (data['product_name'] ?? _selectedMultifinanceBrand ?? '-').toString() : '-';
    final tagihanAmount = data != null ? _asDouble(data['nominal'] ?? data['tagihan']) : 0.0;
    final admin = data != null ? _asDouble(data['admin']) : 0.0;
    final denda = data != null ? _asDouble(data['denda']) : 0.0;
    var total = data != null ? _asDouble(data['total'] ?? data['selling_price']) : 0.0;
    if (data != null && total <= 0) total = tagihanAmount + admin + denda;
    final canConfirm = data != null && !_isMultifinanceInquiring;

    return Scaffold(
      backgroundColor: desktopSurfacePage,
      body: PpobDesktopTwoColumnLayout(
        left: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDesktopCategoryHeader(
              titleOverride: 'Pembayaran Multifinance',
              subtitleOverride: 'Bayar cicilan/kredit multifinance dari berbagai provider dengan mudah',
            ),
            const SizedBox(height: 28),
            const PpobStepHeader(step: 1, title: 'Pilih Provider Multifinance'),
            const SizedBox(height: 12),
            desktopBorderedField(
              icon: Icons.search_rounded,
              controller: _hubSearchCtrl,
              hint: 'Cari provider multifinance…',
              onChanged: (v) => setState(() => _hubSearchQuery = v.trim()),
              suffix: _hubSearchQuery.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18, color: desktopTextSecondary),
                      onPressed: () {
                        _hubSearchCtrl.clear();
                        setState(() => _hubSearchQuery = '');
                      },
                    ),
            ),
            const SizedBox(height: 12),
            if (filteredBrands.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text('Provider tidak ditemukan', style: GoogleFonts.hankenGrotesk(fontSize: 13, color: desktopTextSecondary)),
                ),
              )
            else
              Container(
                constraints: const BoxConstraints(maxHeight: 280),
                decoration: BoxDecoration(
                  border: Border.all(color: desktopBorder.withValues(alpha: 0.6)),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(8),
                child: Scrollbar(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: filteredBrands.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (_, i) => _multifinanceBrandRow(filteredBrands[i]),
                  ),
                ),
              ),
            const SizedBox(height: 28),
            const PpobStepHeader(
              step: 2,
              title: 'Masukkan ID Pelanggan',
              subtitle: 'Nomor Kontrak / ID Pelanggan',
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: desktopBorderedField(
                    icon: Icons.badge_outlined,
                    controller: _customerIdController,
                    focusNode: _customerIdFocusNode,
                    keyboardType: TextInputType.number,
                    hint: 'Contoh: 1234567890',
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (_) => setState(() {
                      _multifinanceInquiryResult = null;
                      _multifinanceInquiryError = null;
                    }),
                    onSubmitted: (_) => _isMultifinanceInquiring ? null : _doMultifinanceInquiry(),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _isMultifinanceInquiring ? null : _doMultifinanceInquiry,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: desktopPrimaryBtn,
                      disabledBackgroundColor: desktopPrimaryBtn.withValues(alpha: 0.5),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: _isMultifinanceInquiring
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
            if (_multifinanceInquiryError != null && !_isMultifinanceInquiring) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4F4),
                  border: Border.all(color: const Color(0xFFF5C2C2)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(_multifinanceInquiryError!, style: GoogleFonts.hankenGrotesk(fontSize: 12.5, color: const Color(0xFFB00020))),
              ),
            ] else ...[
              const SizedBox(height: 12),
              const PpobDesktopBanner(
                icon: Icons.info_outline_rounded,
                title: 'Pastikan nomor kontrak / ID pelanggan sesuai dengan tagihan Anda.',
                tone: PpobBannerTone.info,
              ),
            ],
            const SizedBox(height: 28),
            const PpobStepHeader(step: 3, title: 'Informasi Tagihan'),
            const SizedBox(height: 12),
            if (data == null)
              Container(
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
              )
            else
              Container(
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
                          decoration: BoxDecoration(color: desktopAccentBlue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                          alignment: Alignment.center,
                          child: const Icon(Icons.account_balance_outlined, color: desktopAccentBlue, size: 28),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _internetInfoPairText('Nama Pelanggan', (data['nama'] ?? data['customer_name'] ?? '-').toString()),
                                  _internetInfoPairText('Periode', periode),
                                ],
                              ),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _internetInfoPairText('ID Pelanggan', (data['idpel'] ?? data['customer_no'] ?? customerId).toString()),
                                  _internetInfoPairText('Provider', _selectedMultifinanceBrand ?? '-'),
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
                          _internetRincianRow('Angsuran${produk != '-' ? ' ($produk)' : ''}', _formatPrice(tagihanAmount)),
                          if (denda > 0) _internetRincianRow('Denda Keterlambatan', _formatPrice(denda)),
                          _internetRincianRow('Admin', _formatPrice(admin)),
                          const SizedBox(height: 6),
                          Divider(color: desktopBorder.withValues(alpha: 0.6), height: 1),
                          const SizedBox(height: 6),
                          _internetRincianRow('Total Tagihan', _formatPrice(total), highlight: true),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            if (data != null) ...[
              const SizedBox(height: 12),
              const PpobDesktopBanner(
                icon: Icons.info_outline_rounded,
                title: 'Tagihan akan dibayarkan secara real-time dan langsung tercatat.',
                tone: PpobBannerTone.info,
              ),
            ],
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: desktopBorder.withValues(alpha: 0.5)))),
              child: Row(
                children: [
                  _desktopTrustBadge(Icons.bolt_rounded, 'Pembayaran Instan', 'Langsung diproses'),
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
            PpobDetailRow(icon: Icons.account_balance_outlined, label: 'Penyedia', value: _selectedMultifinanceBrand ?? '-'),
            PpobDetailRow(icon: Icons.badge_outlined, label: 'ID Pelanggan', value: data != null ? (data['idpel'] ?? data['customer_no'] ?? customerId).toString() : '-'),
            PpobDetailRow(icon: Icons.person_outline, label: 'Nama Pelanggan', value: data != null ? (data['nama'] ?? data['customer_name'] ?? '-').toString() : '-'),
            PpobDetailRow(icon: Icons.calendar_month_outlined, label: 'Periode', value: periode),
            PpobDetailRow(icon: Icons.description_outlined, label: 'Angsuran', value: data != null ? _formatPrice(tagihanAmount) : '-'),
            PpobDetailRow(icon: Icons.receipt_long_outlined, label: 'Admin', value: data != null ? _formatPrice(admin) : '-'),
          ],
          totalLabel: data != null ? _formatPrice(total) : 'Rp 0',
          confirmLabel: 'Bayar Sekarang',
          loading: _isMultifinanceInquiring,
          onConfirm: canConfirm ? _payMultifinanceBill : null,
        ),
      ),
    );
  }

  // Layout desktop dua-kolom: kiri = input nomor + grid nominal (scroll),
  // kanan = ringkasan transaksi sticky yang update live saat nominal
  // dipilih. Tombol "Konfirmasi Pembayaran" memanggil _onProductSelected
  // yang sama persis dengan alur mobile (inquiry/verifikasi + navigasi ke
  // PpobTransactionDetailTemplatePage) — logika pembayaran tidak diduplikasi.
  Widget _buildDesktopLayout(bool showBrandTabs) {
    final customerId = _customerIdController.text.trim();
    final hasCustomerInput = customerId.isNotEmpty;
    final selected = _selectedProduct;
    final price = selected == null
        ? 0.0
        : (_isPromoProduct(selected) ? _promoPrice(selected) : _originalPrice(selected));
    final adminFee = selected == null ? 0.0 : _asAdminFee(selected);
    final total = price + adminFee;
    final canConfirm = selected != null && hasCustomerInput && !_isValidatingRecipient;

    return Scaffold(
      backgroundColor: desktopSurfacePage,
      body: PpobDesktopTwoColumnLayout(
        left: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDesktopCategoryHeader(),
            const SizedBox(height: 28),
            const PpobStepHeader(step: 1, title: 'Isi Nomor Tujuan'),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: desktopBorderedField(
                    icon: Icons.smartphone_outlined,
                    controller: _customerIdController,
                    focusNode: _customerIdFocusNode,
                    keyboardType: TextInputType.phone,
                    hint: widget.configInputHint?.trim().isNotEmpty == true ? widget.configInputHint! : 'Masukkan nomor HP',
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (_) => setState(_onCustomerInputChanged),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: () => _openSavedCustomers(desktopPrimaryBtn),
                  icon: const Icon(Icons.badge_outlined, size: 16),
                  label: const Text('Kontak'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: desktopAccentBlue,
                    side: const BorderSide(color: desktopBorder),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
            if (_isCellularCategory && _isPulsaPrefixDetected) ...[
              const SizedBox(height: 14),
              PpobDesktopBanner(
                icon: Icons.check_circle_rounded,
                title: 'Nomor terverifikasi',
                trailing: Text(
                  _selectedBrand ?? '-',
                  style: GoogleFonts.hankenGrotesk(fontSize: 12, fontWeight: FontWeight.w700, color: desktopTextPrimary),
                ),
              ),
            ],
            const SizedBox(height: 28),
            PpobStepHeader(
              step: 2,
              title: 'Pilih Nominal ${widget.title}',
              subtitle: hasCustomerInput ? 'Pilih nominal ${widget.title} untuk nomor $customerId' : null,
            ),
            const SizedBox(height: 14),
            if (showBrandTabs && _brands.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _brands.map((b) {
                    final brand = b.toString();
                    final sel = _selectedBrand == brand;
                    return ChoiceChip(
                      label: Text(brand),
                      selected: sel,
                      onSelected: (_) => _selectBrand(brand),
                      selectedColor: desktopPrimaryBtn.withValues(alpha: 0.12),
                      backgroundColor: desktopSurfacePage,
                      side: BorderSide(color: sel ? desktopAccentBlue : desktopBorder),
                      labelStyle: GoogleFonts.hankenGrotesk(
                        fontSize: 12,
                        fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                        color: sel ? desktopAccentBlue : desktopTextPrimary,
                      ),
                    );
                  }).toList(),
                ),
              ),
            _buildDesktopProductGrid(),
          ],
        ),
        right: PpobDesktopSummaryPanel(
          rows: [
            PpobDetailRow(icon: Icons.smartphone_outlined, label: 'Nomor Tujuan', value: hasCustomerInput ? customerId : '-'),
            PpobDetailRow(icon: Icons.sim_card_outlined, label: 'Operator', value: _selectedBrand ?? '-'),
            PpobDetailRow(icon: Icons.inventory_2_outlined, label: 'Produk', value: (selected?['product_name'] ?? widget.title).toString()),
            PpobDetailRow(icon: Icons.confirmation_number_outlined, label: 'Nominal', value: selected != null ? _formatPrice(price) : '-'),
            PpobDetailRow(icon: Icons.payments_outlined, label: 'Harga', value: selected != null ? _formatPrice(price) : 'Rp 0'),
            PpobDetailRow(icon: Icons.receipt_long_outlined, label: 'Admin', value: _formatPrice(adminFee)),
          ],
          totalLabel: _formatPrice(total),
          loading: _isValidatingRecipient,
          onConfirm: canConfirm ? () => _onProductSelected(selected) : null,
        ),
      ),
    );
  }

  Widget _buildDesktopProductGrid({String? emptyMessage}) {
    if (_isLoadingProducts) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_products.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Text(
            emptyMessage ??
                (_customerIdController.text.trim().isEmpty ? 'Masukkan nomor tujuan terlebih dahulu' : 'Belum ada produk tersedia'),
            style: GoogleFonts.hankenGrotesk(fontSize: 13, color: desktopTextSecondary),
          ),
        ),
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _products.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        mainAxisExtent: 96,
      ),
      itemBuilder: (_, i) {
        final p = Map<String, dynamic>.from(_products[i] as Map);
        final isPromo = _isPromoProduct(p);
        final priceValue = isPromo ? _promoPrice(p) : _originalPrice(p);
        final isSelected = _selectedProduct != null && _selectedProduct!['buyer_sku_code'] == p['buyer_sku_code'];
        return PpobNominalCard(
          title: (p['product_name'] ?? '-').toString(),
          priceLabel: _formatPrice(priceValue),
          badge: isPromo ? 'Promo' : null,
          selected: isSelected,
          onTap: () => setState(() => _selectedProduct = p),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    notifire = Provider.of<ColorNotifire>(context, listen: true);
    final textPrimary = const Color(0xFF1D1D1D);
    final textSecondary = const Color(0xFF6B7280);
    final accent = const Color(0xFF3F6FB4);
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

    // Token Listrik (PLN Prabayar) punya layout desktop khusus meniru
    // referensi desain: input ID Pelanggan dengan verifikasi otomatis +
    // grid nominal, terpisah dari layout desktop dua-kolom generik (Pulsa,
    // dll). Tab Pascabayar (jika ada) tetap pakai layout mobile existing.
    if (isDesktop(context) && isPlnPrabayarTab) {
      return _buildDesktopPlnLayout();
    }

    // PLN Pasca (postpaid) juga punya layout desktop khusus meniru
    // referensi desain: cek tagihan otomatis + kartu info pelanggan +
    // rincian tagihan, terpisah dari layout prabayar di atas.
    if (isDesktop(context) && isPlnPostpaidTab) {
      return _buildDesktopPlnPascaLayout();
    }

    // Top Up E-Wallet (hub generik, brand dipilih di dalam halaman ini)
    // juga punya layout desktop khusus meniru referensi desain. Varian
    // dengan initialBrand (mis. dari promo card) tetap pakai layout lama.
    if (isDesktop(context) && _isEmoney && !hasInitialBrand) {
      return _buildDesktopEwalletLayout();
    }

    // Hub "Internet & TV" (IndiHome, ICONNET, CBN, MyRepublic, Biznet) juga
    // punya layout desktop khusus meniru referensi desain.
    if (isDesktop(context) && _isInternetHub) {
      return _buildDesktopInternetLayout();
    }

    // Hub "Multifinance" (33 provider cicilan/kredit) juga punya layout
    // desktop khusus mengikuti pola yang sama.
    if (isDesktop(context) && _isMultifinanceHub) {
      return _buildDesktopMultifinanceLayout();
    }

    final supportsDesktopTwoColumn = _supportsDesktopTwoColumn;
    if (isDesktop(context) && supportsDesktopTwoColumn) {
      return _buildDesktopLayout(showBrandTabs);
    }

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: const Color(0xFFF8F9FD),
      bottomNavigationBar: null,
      appBar: isDesktopPopup(context) ? null : AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        backgroundColor: pageBg,
        leading: DesktopLeadingWrapper(
          child: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.arrow_back, color: textPrimary),
          ),
        ),
        iconTheme: IconThemeData(color: textPrimary),
        title: DesktopTitleWrapper(child: Text(
          widget.title,
          style: TextStyle(
            color: textPrimary,
            fontFamily: 'Gilroy Bold',
            fontSize: 18,
          ),
        ))
      ),
      body: Stack(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _dismissInputAndNumpad,
            child: SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          child: Column(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF16215C).withOpacity(0.06),
                                      blurRadius: 20,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                    // content inside card (Card Header + tabs + products)
                              if (!_isInternetHub && !_isMultifinanceHub)
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                                      child: Text(
                                        widget.title,
                                        style: TextStyle(
                                          color: textPrimary,
                                          fontFamily: 'Gilroy Bold',
                                          fontSize: 22,
                                        ),
                                      ),
                                    ),
                                    const Divider(height: 0, color: Color(0xFFECEEF2)),
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
                                      child: Text(
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
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Container(
                                              height: 48,
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF5F6F8),
                                                borderRadius: BorderRadius.circular(12),
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

                                                  if (_isPln && _plnTabIndex == 1) {
                                                    if (_plnPostpaidInquiryResult != null ||
                                                        _plnPostpaidError != null) {
                                                      setState(() {
                                                        _plnPostpaidInquiryResult = null;
                                                        _plnPostpaidError = null;
                                                      });
                                                    }
                                                  }
                                                  if (_isCategoryInquiry) {
                                                    if (_bpjsInquiryResult != null ||
                                                        _bpjsInquiryError != null) {
                                                      setState(() {
                                                        _bpjsInquiryResult = null;
                                                        _bpjsInquiryError = null;
                                                      });
                                                    }
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
                                            onTap: () => _openSavedCustomers(accent),
                                            child: Padding(
                                              padding: const EdgeInsets.all(2),
                                              child: Icon(
                                                Icons.contact_page_outlined,
                                                color: accent,
                                                size: 34,
                                              ),
                                            ),
                                          ),
                                          if (_isPhoneNumberInput) ...[
                                            const SizedBox(width: 6),
                                            InkWell(
                                              borderRadius: BorderRadius.circular(8),
                                              onTap: _pickNumberFromContact,
                                              child: Padding(
                                                padding: const EdgeInsets.all(2),
                                                child: Icon(
                                                  Icons.contacts_rounded,
                                                  color: accent,
                                                  size: 34,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              if (_isPln && _isPlnPostpaidOnly)
                                const SizedBox.shrink()
                              else if (_isPln)
                                Container(
                                  decoration: const BoxDecoration(
                                    border: Border(
                                      top: BorderSide(color: Color(0xFFECEEF2)),
                                    ),
                                  ),
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
                                                color: const Color(0xFF3A3A3A),
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
                                                color: const Color(0xFF3A3A3A),
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
                                  decoration: const BoxDecoration(
                                    border: Border(
                                      top: BorderSide(color: Color(0xFFECEEF2)),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: InkWell(
                                          onTap: () async {
                                            setState(() => _pulsaTabIndex = 0);
                                            final customerId = _customerIdController.text.trim();
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
                              _isEmoney && !hasInitialBrand
                                  ? (_ewalletBrandPicked
                                      ? _buildEwalletProductsView(textPrimary, textSecondary, accent)
                                      : _buildEwalletList(textPrimary, textSecondary, accent))
                                  : _isEmoney && hasInitialBrand
                                      ? _buildEwalletWithDynamicView(textPrimary, textSecondary, accent)
                                      : _isInternetHub
                                          ? _buildInternetHub(textPrimary, textSecondary, accent)
                                          : _isMultifinanceHub
                                          ? _buildMultifinanceHub(textPrimary, textSecondary, accent)
                                          : _isCategoryInquiry
                                          ? _buildBpjsSection(textPrimary, textSecondary)
                                          : isPlnPostpaidTab
                                          ? _buildPlnPostpaidSection(textPrimary, textSecondary)
                                          : _isCellularCategory
                                          ? PPOBCellularForm(
                                              controller: _customerIdController,
                                              focusNode: _customerIdFocusNode,
                                              brands: _brands,
                                              selectedBrand: _selectedBrand,
                                              products: _products,
                                              selectedProduct: _selectedProduct,
                                              showBrandTabs: showBrandTabs,
                                              isPulsaPrefixDetected: _isPulsaPrefixDetected,
                                              isInject: _isInject,
                                              onBrandSelected: _selectBrand,
                                              onProductSelected: _onProductSelected,
                                              pulsaTabIndex: _pulsaTabIndex,
                                              onPulsaTabChanged: (index) => setState(() => _pulsaTabIndex = index),
                                              validator: _validateCustomerIdByBrand,
                                              formatPrice: _formatPrice,
                                              productDescription: _productDescription,
                                              buildShimmerProducts: _buildShimmerProducts,
                                              isLoadingProducts: _isLoadingProducts,
                                              isPulsaTransferTab: isPulsaTransferTab,
                                              hasCustomerInput: hasCustomerInput,
                                              originalPrice: _originalPrice,
                                              promoPrice: _promoPrice,
                                              isPromoProduct: _isPromoProduct,
                                              extractRewardCoins: _extractRewardCoins,
                                              promoRemainingLabel: _promoRemainingLabel,
                                              pulsaProviderLogoAsset: _pulsaProviderLogoAsset,
                                              accentColor: accent,
                                              textPrimary: textPrimary,
                                              textSecondary: textSecondary,
                                            )
                                          : Column(
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
                                                              fontFamily: selected ? 'Gilroy Bold' : 'Gilroy Medium',
                                                            ),
                                                            label: Text(brand),
                                                            onSelected: (_) => _selectBrand(brand),
                                                          ),
                                                        );
                                                      },
                                                    ),
                                                  ),
                                                  const SizedBox(height: 8),
                                                ],
                                                if (!shouldShowProducts)
                                                  Padding(
                                                    padding: const EdgeInsets.symmetric(vertical: 32),
                                                    child: Center(
                                                      child: isPulsaTransferTab
                                                          ? Column(
                                                              mainAxisSize: MainAxisSize.min,
                                                              children: [
                                                                SizedBox(
                                                                  height: 240,
                                                                  width: 240,
                                                                  child: Lottie.asset('assets/lottie/empty_cart.json'),
                                                                ),
                                                              ],
                                                            )
                                                          : Text(
                                                              hasCustomerInput && _isCellularCategory
                                                                  ? 'Prefix nomor tidak terdeteksi'
                                                                  : 'Harap masukan no.hp terlebih dahulu',
                                                              style: TextStyle(
                                                                color: textSecondary.withValues(alpha: 0.6),
                                                                fontFamily: 'Gilroy Medium',
                                                                fontSize: 18,
                                                              ),
                                                            ),
                                                    ),
                                                  )
                                                else if (_products.isEmpty)
                                                  Padding(
                                                    padding: const EdgeInsets.symmetric(vertical: 32),
                                                    child: Center(
                                                      child: Text(
                                                        'Belum ada produk tersedia',
                                                        style: TextStyle(
                                                          color: textSecondary,
                                                          fontFamily: 'Gilroy Medium',
                                                        ),
                                                      ),
                                                    ),
                                                  )
                                                else
                                                  RepaintBoundary(
                                                    child: NotificationListener<UserScrollNotification>(
                                                      onNotification: (notification) {
                                                        if (notification.direction != ScrollDirection.idle) {
                                                          _hideCustomNumpad();
                                                        }
                                                        return false;
                                                      },
                                                      child: GridView.builder(
                                                        shrinkWrap: true,
                                                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                                        physics: const NeverScrollableScrollPhysics(),
                                                        itemCount: _products.length,
                                                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                                          crossAxisCount: () {
                                                            final cfgLayout = widget.configProductLayout?.toLowerCase();
                                                            if (cfgLayout == 'list') return 1;
                                                            if (widget.configProductColumns != null &&
                                                                widget.configProductColumns! >= 1 &&
                                                                widget.configProductColumns! <= 3) {
                                                              return widget.configProductColumns!;
                                                            }
                                                            return (isPlnPrabayarTab || _isTopupGameFiltered) ? 1 : 2;
                                                          }(),
                                                          crossAxisSpacing: 10,
                                                          mainAxisSpacing: 10,
                                                          mainAxisExtent: () {
                                                            final cfgLayout = widget.configProductLayout?.toLowerCase();
                                                            final isList = cfgLayout == 'list' || isPlnPrabayarTab || _isTopupGameFiltered;
                                                            if (isPlnPrabayarTab) return 100.0;
                                                            if (_isTopupGameFiltered) return 124.0;
                                                            if (isList) return 100.0;
                                                            return 148.0;
                                                          }(),
                                                        ),
                                                        itemBuilder: (_, i) {
                                                          final p = Map<String, dynamic>.from(_products[i]);
                                                          final isPromo = p['_is_promo_pre'] ?? _isPromoProduct(p);
                                                          final originalPrice = p['_original_price_pre'] ?? _originalPrice(p);
                                                          final promoPrice = p['_promo_price_pre'] ?? _promoPrice(p);
                                                          final rewardCoins = p['_reward_coins_pre'] ?? _extractRewardCoins(p);
                                                          final promoLabel = p['_promo_label_pre'] ?? _promoRemainingLabel(p);
                                                          final isSelected = (_isEmoney || (_isPln && _plnTabIndex == 0)) &&
                                                              _selectedProduct != null &&
                                                              _selectedProduct!['buyer_sku_code'] == p['buyer_sku_code'];
                                                          final providerLogoAsset = p['_logo_asset_pre'] ??
                                                              (_isCellularCategory ? _pulsaProviderLogoAsset(p) : '');

                                                          return Material(
                                                            color: Colors.white,
                                                            borderRadius: BorderRadius.circular(12),
                                                            elevation: 16,
                                                            shadowColor: Colors.black.withValues(alpha: 0.18),
                                                            child: Ink(
                                                              decoration: BoxDecoration(
                                                                color: Colors.white,
                                                                borderRadius: BorderRadius.circular(12),
                                                                border: Border.all(
                                                                  color: isSelected
                                                                      ? accent.withValues(alpha: 0.35)
                                                                      : Colors.transparent,
                                                                ),
                                                              ),
                                                              child: InkWell(
                                                                borderRadius: BorderRadius.circular(12),
                                                                onTap: () => _onProductSelected(p),
                                                                child: Padding(
                                                                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                                                                  child: Stack(
                                                                    children: [
                                                                      if (providerLogoAsset.isNotEmpty)
                                                                        Positioned(
                                                                          right: 6,
                                                                          bottom: 2,
                                                                          child: Opacity(
                                                                            opacity: 0.30,
                                                                            child: Image.asset(
                                                                              providerLogoAsset,
                                                                              width: 72,
                                                                              height: 72,
                                                                              fit: BoxFit.contain,
                                                                            ),
                                                                          ),
                                                                        ),
                                                                      Row(
                                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                                        children: [
                                                                          Expanded(
                                                                            child: Column(
                                                                              crossAxisAlignment: CrossAxisAlignment.start,
                                                                              mainAxisSize: MainAxisSize.min,
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
                                                                                if (isPromo) const SizedBox(height: 2),
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
                                                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                                                                                    promoLabel,
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
                                                          );
                                                        },
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                    // ── Grey Footer Button ─────────────────────────────────
                                    if (isPlnPrabayarTab)
                                      Container(
                                        padding: const EdgeInsets.all(20),
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
                                            onPressed: (canContinuePlnPrabayar && !_isValidatingRecipient)
                                                ? _continuePlnPrabayar
                                                : null,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: accent,
                                              disabledBackgroundColor: accent.withValues(alpha: 0.35),
                                              foregroundColor: Colors.white,
                                              elevation: 0,
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
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
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
      showToast(msg: 'Masukan Nomor HP terlebih dahulu');
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
      showToast(msg: 'Minimal nominal Rp 10.000');
      return;
    }
    if (amount > 10000000) {
      showToast(msg: 'Maksimal nominal Rp 10.000.000');
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
          // Visibility(maintainState: true) (bukan ternary/Stack) menjaga
          // kedua subtree tetap ter-mount tanpa memaksa GridView shimmer
          // melalui dry-layout (Stack/IndexedStack memanggil computeDryLayout
          // pada children non-positioned, yang selalu gagal untuk viewport
          // scroll seperti GridView). Ternary lepas-pasang widget tepat di
          // bawah kursor saat data produk datang async, memicu assertion
          // '_debugDuringDeviceUpdate' di MouseTracker (desktop).
          child: Column(
            children: [
              Visibility(
                visible: _isLoadingProducts,
                maintainState: true,
                child: _buildShimmerProducts(),
              ),
              Visibility(
                visible: !_isLoadingProducts,
                maintainState: true,
                child: _buildCustomAmountSection(
                    textPrimary, textSecondary, accent, quickAmounts),
              ),
            ],
          ),
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
    return Padding(
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
                onPressed: () => Future.microtask(_backToEwalletList),
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
        // Visibility(maintainState: true) (bukan ternary/Stack) menjaga
        // kedua subtree tetap ter-mount tanpa memaksa GridView shimmer
        // melalui dry-layout (Stack/IndexedStack memanggil computeDryLayout
        // pada children non-positioned, yang selalu gagal untuk viewport
        // scroll seperti GridView). Ternary lepas-pasang widget tepat di
        // bawah kursor saat data produk datang async, memicu assertion
        // '_debugDuringDeviceUpdate' di MouseTracker (desktop).
        Visibility(
          visible: _isLoadingProducts,
          maintainState: true,
          child: _buildShimmerProducts(),
        ),
        Visibility(
          visible: !_isLoadingProducts,
          maintainState: true,
          child: _buildCustomAmountSection(
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
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
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
          // Defer: setState sync di sini melepas InkWell ini mid-pointer-dispatch,
          // memicu assertion '_debugDuringDeviceUpdate' di desktop.
          onTap: () => Future.microtask(() => _onEwalletBrandTap(brandName)),
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
                                errorBuilder: (_, __, ___) => Icon(
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
      showToast(msg: 'Masukkan PIN 4 digit');
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

        if (isDesktop(context)) {
          TransactionSuccessDialog.show(
            context: context,
            subtitle: '${widget.productName} berhasil dibayar',
            orderId: (tx['order_id'] ?? '-').toString(),
            rows: [
              MapEntry('ID Pelanggan', widget.customerNo),
              MapEntry('Nama', widget.customerName),
              MapEntry('Produk', widget.productName),
            ],
            totalLabel: _formatPrice(widget.amount),
            onClose: () {
              // Tutup dialog sukses (root navigator) lalu halaman PIN ini
              // sendiri (local navigator), balik ke form transaksi.
              Navigator.of(context, rootNavigator: true).pop();
              Navigator.of(context).pop();
            },
          );
          return;
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
        showToast(msg: response['message'] ?? 'Pembayaran gagal');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      showToast(
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
      appBar: isDesktopPopup(context) ? null : AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: DesktopTitleWrapper(child: const Text(
          'Konfirmasi Pembayaran',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Gilroy Bold',
            fontSize: 17,
          ),
        ))
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
      showToast(msg: 'Nama penerima belum terverifikasi');
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
    final borderColor = notifire.getIsDark ? grey600 : grey200;

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
      backgroundColor: notifire.getprimerycolor,
      appBar: isDesktopPopup(context) ? null : AppBar(
        backgroundColor: notifire.getprimerycolor,
        elevation: 0,
        foregroundColor: textPrimary,
        title: Text(
          'Detail Transaksi',
          style: TextStyle(color: textPrimary, fontFamily: 'Gilroy Bold', fontSize: 16),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: borderColor),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 126),
        child: AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _paymentRow('Nama Produk', productName, textSecondary, textPrimary),
              const SizedBox(height: AppSpacing.sm),
              if (isPlnDetail) ...[
                _paymentRow('Nama Pelanggan', apiCustomerName, textSecondary, textPrimary),
                const SizedBox(height: AppSpacing.sm),
                _paymentRow('IDPEL', apiCustomerNo, textSecondary, textPrimary),
                const SizedBox(height: AppSpacing.sm),
                _paymentRow('TARIF/DAYA', apiTarifDaya, textSecondary, textPrimary),
              ] else if (widget.gameInquiryData != null) ...[
                _paymentRow('ID Player', widget.customerId, textSecondary, textPrimary),
                if ((widget.gameInquiryData!['username'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _paymentRow('Username', widget.gameInquiryData!['username'].toString(), textSecondary, textPrimary),
                ],
                if ((widget.gameInquiryData!['region'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _paymentRow('Region', widget.gameInquiryData!['region'].toString(), textSecondary, textPrimary),
                ],
              ] else
                _paymentRow('Nomor Handphone', widget.customerId, textSecondary, textPrimary),
              const SizedBox(height: AppSpacing.sm),
              _paymentRow('Harga', widget.formatPrice(price), textSecondary, textPrimary),
              const SizedBox(height: AppSpacing.sm),
              _paymentRow(
                'Biaya Admin',
                adminFee <= 0 ? 'Gratis!' : widget.formatPrice(adminFee),
                textSecondary,
                textPrimary,
              ),
              const SizedBox(height: AppSpacing.sm),
              Divider(height: 1, color: borderColor),
              const SizedBox(height: AppSpacing.sm),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: AppSpacing.md),
                decoration: BoxDecoration(
                  color: primaryBlue50,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Row(
                  children: [
                    Text(
                      'Total Pembayaran',
                      style: TextStyle(color: textPrimary, fontFamily: 'Gilroy Bold', fontSize: 13),
                    ),
                    const Spacer(),
                    Text(
                      widget.formatPrice(total),
                      style: const TextStyle(color: primaryBlue500, fontFamily: 'Gilroy Bold', fontSize: 17),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _recipientSection(notifire),
            ],
          ),
        ),
      ),
      bottomNavigationBar: widget.showBottomAction
          ? Container(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.md + MediaQuery.of(context).padding.bottom,
              ),
              decoration: BoxDecoration(
                color: cardBg,
                border: Border(top: BorderSide(color: borderColor)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        'Total Pembayaran',
                        style: TextStyle(color: textSecondary, fontFamily: 'Gilroy Medium', fontSize: 13),
                      ),
                      const Spacer(),
                      Text(
                        widget.formatPrice(total),
                        style: const TextStyle(color: primaryBlue500, fontFamily: 'Gilroy Bold', fontSize: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppButton.success(
                    expand: true,
                    label: 'Bayar Sekarang',
                    onPressed: _handleConfirm,
                  ),
                ],
              ),
            )
          : null,
    );
  }

  Widget _paymentRow(String label, String value, Color textSecondary, Color textPrimary) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: textSecondary, fontFamily: 'Gilroy Medium', fontSize: 13),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(color: textPrimary, fontFamily: 'Gilroy Bold', fontSize: 13),
          ),
        ),
      ],
    );
  }

  Widget _recipientSection(ColorNotifire notifire) {
    if (!widget.showRecipientHint && widget.recipientName == null) {
      return const SizedBox.shrink();
    }

    if (!widget.requireRecipientName) {
      return const SizedBox.shrink();
    }

    if (_recipientName != null) {
      return AppAlert(
        tone: AppAlertTone.success,
        title: 'Nama Penerima Terverifikasi',
        description: _recipientName,
      );
    }

    return const AppAlert(
      tone: AppAlertTone.error,
      title: 'Nama penerima tidak tersedia',
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
