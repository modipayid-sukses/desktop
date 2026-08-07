import 'dart:async';
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:modipay/utils/toast.dart';
import 'package:modipay/home/ppob/ppob_product_screen.dart';
import 'package:modipay/services/api_service.dart';
import 'package:modipay/utils/colornotifire.dart';
import 'package:modipay/utils/media.dart';
import 'package:modipay/utils/color.dart';
import 'package:modipay/utils/responsive.dart';
import 'package:modipay/utils/string.dart';
import 'package:modipay/providers/auth_provider.dart';
import 'package:modipay/home/home.dart';
import 'package:modipay/home/seealltransaction.dart';
import 'package:modipay/home/topup/topup_channel_screen.dart';
import 'package:modipay/profile/profile.dart' as profile_page;
import 'package:modipay/profile/helpsupport.dart';
import 'package:modipay/home/notifications.dart';
import 'package:modipay/design/design.dart';
import 'package:modipay/login/login_router.dart';
import 'package:modipay/widgets/desktop_title_wrapper.dart';
import 'package:modipay/home/ppob/ppob_menu_route.dart';
import 'package:modipay/home/ppob/bpjs_screen.dart';
import 'package:modipay/home/ppob/pdam_screen.dart';
import 'package:modipay/home/ppob/ppob_postpaid_screen.dart';
import 'package:modipay/home/ppob/ppob_emoney_brand_screen.dart';
import 'package:modipay/home/ppob/ppob_topup_game_list_screen.dart';
import 'package:modipay/home/ppob/ppob_all_services_screen.dart';
import 'package:modipay/home/transfer/bank_transfer_screen.dart';
import 'package:modipay/home/qris/qris_scan_screen.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';

class PromoScreen extends StatefulWidget {
  const PromoScreen({Key? key}) : super(key: key);

  @override
  State<PromoScreen> createState() => _PromoScreenState();
}

class _PromoScreenState extends State<PromoScreen> {
  late ColorNotifire notifire;
  List<dynamic> _promoProducts = [];
  bool _isLoading = true;
  String _selectedCategory = 'Semua';

  final _currencyFormat = NumberFormat('#,###', 'id_ID');

  // Layar transaksi aktif di desktop, dirender di content pane (di samping
  // sidebar) bukan sebagai Dialog mengambang — lihat _openTransaction.
  Widget? _desktopActiveScreen;
  // Key stabil agar Navigator bersarang tidak kehilangan stack rute saat
  // parent rebuild selagi alur transaksi berlangsung di beberapa layar.
  GlobalKey<NavigatorState>? _contentNavKey;
  // Menu sidebar desktop yang sedang aktif/disorot. 'promo' adalah konteks
  // "rumah" untuk halaman ini — diset balik tiap content pane ditutup.
  String _activeDesktopMenu = 'promo';
  String? _activeSubMenuName;

  @override
  void initState() {
    super.initState();
    _loadDarkMode();
    _loadPromos();
    _loadMenuConfig();
  }

  Future<void> _loadDarkMode() async {
    final prefs = await SharedPreferences.getInstance();
    bool? prev = prefs.getBool("setIsDark");
    if (prev == null) {
      notifire.setIsDark = false;
    } else {
      notifire.setIsDark = prev;
    }
  }

  Future<void> _loadPromos() async {
    setState(() => _isLoading = true);
    try {
      final products = await ApiService.getPromoProducts();
      if (mounted) {
        setState(() {
          _promoProducts = products;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<String> get _categories {
    final cats = <String>{'Semua'};
    for (final p in _promoProducts) {
      final cat = (p['category'] ?? '').toString();
      if (cat.isNotEmpty) cats.add(cat);
    }
    return cats.toList();
  }

  List<dynamic> get _filteredProducts {
    if (_selectedCategory == 'Semua') return _promoProducts;
    return _promoProducts
        .where((p) => (p['category'] ?? '').toString() == _selectedCategory)
        .toList();
  }

  String _formatPromoEnd(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = dt.difference(now);
      if (diff.isNegative) return 'Berakhir';
      if (diff.inDays > 0) return '${diff.inDays} hari lagi';
      if (diff.inHours > 0) return '${diff.inHours} jam lagi';
      return '${diff.inMinutes} menit lagi';
    } catch (_) {
      return '';
    }
  }

  int _discount(dynamic original, dynamic promo) {
    final o = (original as num?)?.toDouble() ?? 0;
    final p = (promo as num?)?.toDouble() ?? 0;
    if (o <= 0) return 0;
    return (((o - p) / o) * 100).round();
  }

  Color _categoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'pulsa': return const Color(0xFFE91E63);
      case 'data': return const Color(0xFF00BCD4);
      case 'pln': return const Color(0xFFFF9800);
      case 'e-money': return const Color(0xFF4CAF50);
      case 'games': return const Color(0xFF9C27B0);
      case 'voucher': return const Color(0xFFFF5722);
      default: return const Color(0xFF1E88E5);
    }
  }

  IconData _categoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'pulsa': return Icons.phone_android;
      case 'data': return Icons.wifi;
      case 'pln': return Icons.flash_on;
      case 'e-money': return Icons.account_balance_wallet;
      case 'games': return Icons.sports_esports;
      case 'voucher': return Icons.card_giftcard;
      default: return Icons.local_offer;
    }
  }

  @override
  Widget build(BuildContext context) {
    notifire = Provider.of<ColorNotifire>(context, listen: true);
    if (isDesktop(context)) {
      return _buildDesktopLayout(context);
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: Stack(
        children: [
          // Header gradient
          Container(
            height: MediaQuery.of(context).padding.top + 100,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFE53935), Color(0xFFFF7043)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                // Title
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.local_fire_department_rounded, color: Colors.white, size: 24),
                      const SizedBox(width: 8),
                      const Text(
                        'Promo Spesial',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontFamily: 'Gilroy Bold',
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: _loadPromos,
                        child: Icon(Icons.refresh_rounded, color: Colors.white.withOpacity(0.8), size: 22),
                      ),
                    ],
                  ),
                ),
                // Category chips
                SizedBox(
                  height: 38,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _categories.length,
                    itemBuilder: (context, index) {
                      final cat = _categories[index];
                      final isSelected = cat == _selectedCategory;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedCategory = cat),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.white : Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              cat,
                              style: TextStyle(
                                color: isSelected ? const Color(0xFFE53935) : Colors.white,
                                fontSize: 12,
                                fontFamily: isSelected ? 'Gilroy Bold' : 'Gilroy Medium',
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                // Products list
                Expanded(
                  child: _isLoading
                      ? Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          child: Shimmer.fromColors(
                            baseColor: Colors.grey.shade300,
                            highlightColor: Colors.grey.shade100,
                            child: Column(
                              children: List.generate(4, (_) => Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: Container(
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                              )),
                            ),
                          ),
                        )
                      : _filteredProducts.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.local_offer_outlined, size: 64, color: Colors.grey.shade300),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Belum ada promo',
                                    style: TextStyle(
                                      color: Colors.grey.shade400,
                                      fontSize: 16,
                                      fontFamily: 'Gilroy Medium',
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _loadPromos,
                              color: const Color(0xFFE53935),
                              child: ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                itemCount: _filteredProducts.length,
                                itemBuilder: (context, index) => _buildPromoItem(_filteredProducts[index]),
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

  Widget _buildPromoItem(dynamic product) {
    final p = Map<String, dynamic>.from(product);
    final productName = p['product_name'] ?? '';
    final category = (p['category'] ?? '').toString();
    final brand = (p['brand'] ?? '').toString();
    final originalPrice = p['original_price'];
    final promoPrice = p['price'];
    final promoEnd = p['promo_end'] as String?;
    final disc = _discount(originalPrice, promoPrice);
    final catColor = _categoryColor(category);

    return GestureDetector(
      onTap: () {
        // Lewat _navigateToItem (bukan push langsung) supaya promo mendarat
        // di layar yang SAMA dengan kalau user tap menu Prepaid/Postpaid
        // biasa (mis. promo "Paket Data" → Prepaid > Paket Data, promo
        // "Pulsa" → Prepaid > Pulsa), termasuk kasus khusus BPJS/PDAM/
        // e-wallet/postpaid yang route-nya berbeda dari produk biasa.
        _navigateToItem(<String, dynamic>{
          'name': productName,
          'category': category,
          'brand': brand,
          'cmd': p['cmd'] ?? 'prepaid',
          'inquiryType': p['inquiry_type'] ?? p['inquiryType'],
          'initialBrand': brand.isNotEmpty
              ? brand
              : (p['initial_brand'] ?? p['initialBrand']),
          'postpaid': p['is_postpaid'] == true || p['postpaid'] == true,
          'productTypeFilter': p['product_type_filter'] ?? p['product_type'],
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  // Icon with colored bg
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: catColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(_categoryIcon(category), color: catColor, size: 24),
                  ),
                  const SizedBox(width: 14),
                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          productName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF111827),
                            fontSize: 14,
                            fontFamily: 'Gilroy Bold',
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$brand • $category',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 11,
                            fontFamily: 'Gilroy Medium',
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            if (originalPrice != null) ...[
                              Text(
                                'Rp ${_currencyFormat.format((originalPrice as num).toInt())}',
                                style: TextStyle(
                                  color: Colors.grey.shade400,
                                  fontSize: 11,
                                  fontFamily: 'Gilroy Medium',
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Text(
                              'Rp ${_currencyFormat.format((promoPrice as num).toInt())}',
                              style: const TextStyle(
                                color: Color(0xFFE53935),
                                fontSize: 15,
                                fontFamily: 'Gilroy Bold',
                              ),
                            ),
                          ],
                        ),
                        if (promoEnd != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.access_time_rounded, size: 11, color: Colors.grey.shade400),
                              const SizedBox(width: 4),
                              Text(
                                _formatPromoEnd(promoEnd),
                                style: TextStyle(
                                  color: Colors.grey.shade400,
                                  fontSize: 10,
                                  fontFamily: 'Gilroy Medium',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Discount badge
            if (disc > 0)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: [Color(0xFFE53935), Color(0xFFFF7043)]),
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(16),
                      bottomLeft: Radius.circular(12),
                    ),
                  ),
                  child: Text(
                    '-$disc%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontFamily: 'Gilroy Bold',
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _pembelianItems = [];
  List<Map<String, dynamic>> _pembayaranItems = [];
  bool _prepaidExpanded = false;
  bool _postpaidExpanded = false;
  double height = 0;
  double width = 0;

  static const Map<String, IconData> _iconMap = {
    'phone_android': Icons.phone_android,
    'signal_cellular_alt': Icons.signal_cellular_alt,
    'electric_bolt': Icons.electric_bolt,
    'account_balance_wallet': Icons.account_balance_wallet,
    'sim_card': Icons.sim_card,
    'sports_esports': Icons.sports_esports,
    'electrical_services': Icons.electrical_services,
    'health_and_safety': Icons.health_and_safety,
    'wifi': Icons.wifi,
    'grid_view_rounded': Icons.grid_view_rounded,
    'tv': Icons.tv,
    'credit_card': Icons.credit_card,
    'receipt_long': Icons.receipt_long,
    'message': Icons.message,
    'card_giftcard': Icons.card_giftcard,
    'flash_on': Icons.flash_on,
    'payments': Icons.payments,
    'water_drop': Icons.water_drop,
    'local_gas_station': Icons.local_gas_station,
    'swap_horiz': Icons.swap_horiz,
    'phone_in_talk': Icons.phone_in_talk,
    'language': Icons.language,
    'account_balance': Icons.account_balance,
    'two_wheeler': Icons.two_wheeler,
    'directions_car': Icons.directions_car,
    'local_fire_department': Icons.local_fire_department,
    'diamond': Icons.diamond,
  };

  Future<void> _loadMenuConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('cache_ppob_menu_v2');
    if (cached != null) {
      try {
        _applyMenuData(jsonDecode(cached) as Map<String, dynamic>);
      } catch (_) {}
    }

    try {
      final data = await ApiService.getPpobMenu();
      _applyMenuData(data);
      prefs.setString('cache_ppob_menu_v2', jsonEncode(data));
    } catch (_) {}
  }

  void _applyMenuData(Map<String, dynamic> data) {
    List<Map<String, dynamic>> parseGroup(List items, String defaultCmd) {
      return items.map((c) {
        final m = Map<String, dynamic>.from(c);
        final normalized = normalizePpobMenuItem(m, defaultCmd: defaultCmd);
        normalized['icon'] = _iconMap[m['icon']] ?? Icons.apps;
        final rawUrl = m['icon_url'] as String?;
        normalized['iconUrl'] = (rawUrl != null && rawUrl.startsWith('/'))
            ? '${ApiService.baseUrl.replaceFirst('/api', '')}$rawUrl'
            : rawUrl;
        return normalized;
      }).where((item) => !isHiddenPpobMenuItem(item)).toList();
    }

    if (mounted) {
      setState(() {
        _pembelianItems  = parseGroup(data['pembelian']  as List? ?? [], 'prepaid');
        _pembayaranItems = parseGroup(data['pembayaran'] as List? ?? [], 'pasca');
        reclassifyPostpaidItems(_pembelianItems, _pembayaranItems);
      });
    }
  }

  void _navigateAndRefresh(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen)).then((_) => _loadPromos());
  }

  void _openTransaction(Widget screen, {BuildContext? customContext, String? menuKey}) {
    final ctx = customContext ?? context;
    if (!isDesktop(ctx)) {
      _navigateAndRefresh(screen);
      return;
    }

    final isAlreadyInContentPane = customContext != null && Theme.of(customContext).appBarTheme.shadowColor == const Color(0xFF000007);
    if (isAlreadyInContentPane) {
      Navigator.push(customContext, MaterialPageRoute(builder: (_) => screen));
      return;
    }

    // Tunda ke frame berikutnya agar tidak menghapus widget yang sedang
    // di-hover mouse di tengah pemrosesan pointer event (lihat fix serupa
    // di home.dart _openTransaction untuk detail bug MouseTracker-nya).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _contentNavKey = GlobalKey<NavigatorState>();
        _desktopActiveScreen = screen;
        if (menuKey != null) {
          _activeDesktopMenu = menuKey;
          _activeSubMenuName = null;
        }
      });
    });
  }

  void _closeDesktopActiveScreen() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _desktopActiveScreen = null;
        _contentNavKey = null;
        _activeDesktopMenu = 'promo';
        _activeSubMenuName = null;
      });
      _loadPromos();
    });
  }

  /// Content pane yang menampung layar transaksi aktif, ditampilkan di
  /// tempat dashboard biasa berada (sidebar & topbar tetap utuh di
  /// sekelilingnya). Navigator bersarang: agar layar lanjutan yang di-push
  /// dari dalam alur transaksi (mis. konfirmasi, struk) tetap berada di
  /// dalam pane ini, bukan keluar jadi halaman penuh.
  Widget _buildDesktopContentPane(Widget screen) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextButton.icon(
            onPressed: _closeDesktopActiveScreen,
            icon: const Icon(Icons.arrow_back_rounded, size: 18, color: desktopTextSecondary),
            label: const Text(
              'Kembali',
              style: TextStyle(fontFamily: 'Gilroy Bold', fontSize: 13, color: desktopTextSecondary),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              foregroundColor: desktopTextSecondary,
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: Center(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  const modalWidth = 460.0;
                  final modalHeight = constraints.maxHeight;
                  return SizedBox(
                    width: modalWidth,
                    height: modalHeight,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: MediaQuery(
                        data: MediaQuery.of(context).copyWith(size: Size(modalWidth, modalHeight)),
                        child: Theme(
                          data: Theme.of(context).copyWith(
                            appBarTheme: Theme.of(context).appBarTheme.copyWith(
                              elevation: 0,
                              scrolledUnderElevation: 0,
                              shadowColor: const Color(0xFF000007),
                            ),
                          ),
                          child: Navigator(
                            key: _contentNavKey,
                            onGenerateRoute: (settings) => MaterialPageRoute(builder: (_) => screen),
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
    );
  }

  Future<void> _confirmDesktopLogout(AuthProvider auth) async {
    final confirmed = await AppDialog.confirm(
      context: context,
      title: 'Keluar',
      description: 'Apakah Anda yakin ingin keluar dari akun ini?',
      confirmText: 'Keluar',
      cancelText: 'Batal',
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;
    await auth.logout();
    if (!mounted) return;
    final loginScreen = await resolveLoginScreen();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => loginScreen), (route) => false);
  }

  Future<void> _showDesktopReferralDialog(AuthProvider auth) async {
    final code = auth.referralCode;
    if (code == null || code.isEmpty) {
      showToast(msg: 'Kode referral belum tersedia untuk akun Anda');
      return;
    }
    final copy = await AppDialog.show(
      context: context,
      title: 'Kode Referral Anda',
      body: Container(
        width: double.infinity,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        decoration: BoxDecoration(
          color: primaryBlue50,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Text(code, style: const TextStyle(fontFamily: 'Gilroy Bold', fontSize: 20)),
      ),
      secondaryActionText: 'Tutup',
      primaryActionText: 'Salin',
    );
    if (copy == true) {
      await Clipboard.setData(ClipboardData(text: code));
      showToast(msg: 'Kode referral disalin');
    }
  }

  void _navigateToItem(Map<String, dynamic> item, {BuildContext? customContext}) {
    final cmd = (item['cmd'] ?? '').toString().toLowerCase();
    // 'pasca' adalah konvensi cmd untuk item Postpaid di seluruh app (lihat
    // reclassifyPostpaidItems, parseGroup(pembayaran, 'pasca')) — cek string
    // 'postpaid' saja tidak menangkap nama seperti "PLN Pasca"/"PLN Pascabayar".
    final isPostpaid = cmd == 'postpaid' ||
        cmd == 'pasca' ||
        resolvePpobRouteType(item) == 'postpaid' ||
        (item['category'] ?? '').toString().toLowerCase().contains('postpaid') ||
        (item['category'] ?? '').toString().toLowerCase().contains('pasca') ||
        (item['name'] ?? '').toString().toLowerCase().contains('postpaid') ||
        (item['name'] ?? '').toString().toLowerCase().contains('pasca') ||
        (item['brand'] ?? '').toString().toLowerCase().contains('bpjs') ||
        (item['brand'] ?? '').toString().toLowerCase().contains('pdam');

    setState(() {
      _activeSubMenuName = item['name'] as String?;
      if (isPostpaid) {
        _activeDesktopMenu = 'postpaid';
        _postpaidExpanded = true;
      } else {
        _activeDesktopMenu = 'prepaid';
        _prepaidExpanded = true;
      }
    });

    // BPJS selalu pakai layar khusus (daftar produk dari admin panel).
    final brandLowerForBpjs = (item['brand'] ?? '').toString().toLowerCase();
    final categoryLowerForBpjs = (item['category'] ?? '').toString().toLowerCase();
    final nameLowerForBpjs = (item['name'] ?? '').toString().toLowerCase();
    if (brandLowerForBpjs.contains('bpjs') ||
        categoryLowerForBpjs.contains('bpjs') ||
        nameLowerForBpjs.contains('bpjs')) {
      _openTransaction(const BpjsScreen(), customContext: customContext);
      return;
    }

    // PDAM selalu pakai layar khusus (daftar kota dari admin panel),
    // tidak peduli route_type / screen_type yang dikirim backend.
    final brandLowerForPdam = (item['brand'] ?? '').toString().toLowerCase();
    final categoryLowerForPdam = (item['category'] ?? '').toString().toLowerCase();
    final nameLowerForPdam = (item['name'] ?? '').toString().toLowerCase();
    if (brandLowerForPdam.contains('pdam') ||
        categoryLowerForPdam.contains('pdam') ||
        nameLowerForPdam.contains('pdam')) {
      _openTransaction(const PdamScreen(), customContext: customContext);
      return;
    }

    final routeType = resolvePpobRouteType(item);
    if (routeType == 'all_services') {
      _openTransaction(const PPOBAllServicesScreen(), customContext: customContext);
    } else if (routeType == 'bank_transfer') {
      _openTransaction(const BankTransferScreen(), customContext: customContext);
    } else if (routeType == 'qris_payment') {
      _openTransaction(const QrisScanScreen(), customContext: customContext);
    } else if (routeType == 'topup_game_list') {
      final hardcodedGames = <Map<String, dynamic>>[
        {
          'name': 'Free Fire',
          'category': 'TopUp Game',
          'brand': 'FREE FIRE',
          'cmd': 'prepaid',
          'inquirySku': '',
          'gameCode': 'freefire',
          'isPromo': false,
        },
        {
          'name': 'Mobile Legend',
          'category': 'TopUp Game',
          'brand': 'MOBILE LEGEND',
          'cmd': 'prepaid',
          'inquirySku': 'MLU',
          'gameCode': 'mobilelegend',
          'isPromo': false,
        },
        {
          'name': 'Honor of Kings',
          'category': 'TopUp Game',
          'brand': 'HOK',
          'cmd': 'prepaid',
          'inquirySku': '',
          'gameCode': '',
          'isPromo': false,
        },
        {
          'name': 'Magic Chess',
          'category': 'TopUp Game',
          'brand': 'MAGIC CHESS',
          'cmd': 'prepaid',
          'inquirySku': '',
          'gameCode': '',
          'isPromo': false,
        },
        {
          'name': 'Roblox',
          'category': 'TopUp Game',
          'brand': 'ROBLOX',
          'cmd': 'prepaid',
          'inquirySku': '',
          'gameCode': '',
          'isPromo': false,
        },
        {
          'name': 'PUBG Mobile',
          'category': 'TopUp Game',
          'brand': 'PUBG MOBILE',
          'cmd': 'prepaid',
          'inquirySku': '',
          'gameCode': '',
          'isPromo': false,
        },
      ];
      _openTransaction(PPOBTopUpGameListScreen(
        items: hardcodedGames,
        title: (item['name'] ?? 'TopUp Game').toString().replaceAll('\n', ' '),
      ), customContext: customContext);
    } else if (routeType == 'postpaid') {
      final brandLower = (item['brand'] ?? '').toString().toLowerCase();
      if (brandLower.contains('pdam')) {
        _openTransaction(const PdamScreen(), customContext: customContext);
      } else {
        _openTransaction(PPOBPostpaidScreen(
          brand: (item['brand'] ?? item['category'] ?? '').toString(),
          title: (item['name'] ?? '').toString(),
        ), customContext: customContext);
      }
    } else if (routeType == 'emoney_brand') {
      final cat = (item['category'] as String?)?.trim();
      final filter = (item['productTypeFilter'] ??
              item['product_type_filter'] ??
              item['product_type']) as String?;
      _openTransaction(PPOBEmoneyBrandScreen(
        category: (cat == null || cat.isEmpty) ? 'E-Wallet' : cat,
        title: 'Pilih ${item['name'] ?? cat ?? 'E-Wallet'}',
        productTypeFilter: filter,
      ), customContext: customContext);
    } else {
      final category = (item['category'] as String?)?.trim() ?? '';
      final cmd = (item['cmd'] as String?)?.trim() ?? 'prepaid';
      _openTransaction(PPOBProductScreen(
        category: category.isNotEmpty ? category : (item['name'] as String? ?? ''),
        title: item['name'] as String? ?? '',
        cmd: cmd,
        inquiryType: item['inquiryType'] as String?,
        initialBrand: item['initialBrand'] as String?,
        productTypeFilter: item['product_type_filter'] as String?,
        configInputLabel: item['input_label'] as String?,
        configInputHint: item['input_hint'] as String?,
        configInputKeyboard: item['input_keyboard'] as String?,
        configInputMinLength: (item['input_min_length'] as num?)?.toInt(),
        configInputMaxLength: (item['input_max_length'] as num?)?.toInt(),
        configProductLayout: item['product_layout'] as String?,
        configProductColumns: (item['product_columns'] as num?)?.toInt(),
        configShowBrandTabs: item['show_brand_tabs'] as bool?,
        configAutoDetectBrand: item['auto_detect_brand'] as bool?,
        configInquirySku: item['inquiry_sku'] as String?,
        configInquiryProvider: item['inquiry_provider'] as String?,
      ), customContext: customContext);
    }
  }

  Widget _buildDesktopLayout(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    height = MediaQuery.of(context).size.height;
    width = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: desktopSurfacePage,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDesktopSidebar(auth),
          Expanded(
            child: Column(
              children: [
                _buildDesktopTopbar(auth),
                Expanded(
                  child: _desktopActiveScreen != null
                      ? _buildDesktopContentPane(_desktopActiveScreen!)
                      : SingleChildScrollView(
                    padding: const EdgeInsets.all(28),
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 1280),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.local_fire_department_rounded, color: Color(0xFFE53935), size: 28),
                                const SizedBox(width: 10),
                                Text(
                                  'Promo Spesial',
                                  style: GoogleFonts.hankenGrotesk(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 22,
                                    color: desktopTextPrimary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.refresh_rounded, color: desktopTextSecondary, size: 20),
                                  onPressed: _loadPromos,
                                  tooltip: 'Refresh',
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Temukan harga promo produk terbaik kami',
                              style: GoogleFonts.hankenGrotesk(
                                fontSize: 13,
                                color: desktopTextSecondary,
                              ),
                            ),
                            const SizedBox(height: 20),
                            // Category chips row
                            SizedBox(
                              height: 38,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: _categories.length,
                                itemBuilder: (context, index) {
                                  final cat = _categories[index];
                                  final isSelected = cat == _selectedCategory;
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: GestureDetector(
                                      onTap: () => setState(() => _selectedCategory = cat),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: isSelected ? const Color(0xFF182974) : Colors.white,
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(color: Colors.grey.shade200),
                                        ),
                                        child: Text(
                                          cat,
                                          style: GoogleFonts.hankenGrotesk(
                                            color: isSelected ? Colors.white : const Color(0xFF182974),
                                            fontSize: 12,
                                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 20),
                            // Products list
                            _isLoading
                                ? Shimmer.fromColors(
                                    baseColor: Colors.grey.shade300,
                                    highlightColor: Colors.grey.shade100,
                                    child: Column(
                                      children: List.generate(4, (_) => Padding(
                                        padding: const EdgeInsets.only(bottom: 14),
                                        child: Container(
                                          height: 80,
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(14),
                                          ),
                                        ),
                                      )),
                                    ),
                                  )
                                : _filteredProducts.isEmpty
                                    ? Center(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const SizedBox(height: 60),
                                            Icon(Icons.local_offer_outlined, size: 64, color: Colors.grey.shade300),
                                            const SizedBox(height: 12),
                                            Text(
                                              'Belum ada promo',
                                              style: GoogleFonts.hankenGrotesk(
                                                color: Colors.grey.shade400,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    : GridView.builder(
                                        shrinkWrap: true,
                                        physics: const NeverScrollableScrollPhysics(),
                                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                                          maxCrossAxisExtent: 400,
                                          // 96 terlalu pendek saat baris "promo
                                          // berakhir" muncul — Column info bisa
                                          // overflow ~29px (lihat _buildPromoItem).
                                          mainAxisExtent: 128,
                                          crossAxisSpacing: 16,
                                          mainAxisSpacing: 16,
                                        ),
                                        itemCount: _filteredProducts.length,
                                        itemBuilder: (context, index) => _buildPromoItem(_filteredProducts[index]),
                                      ),
                          ],
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
    );
  }

  Widget _buildDesktopSidebar(AuthProvider auth) {
    return Container(
      width: 260,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [desktopNavyStart, desktopNavyEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MODITEKH2H',
                  style: GoogleFonts.hankenGrotesk(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'PPOB Solution',
                  style: GoogleFonts.hankenGrotesk(
                    color: Colors.white.withOpacity(0.6),
                    fontWeight: FontWeight.w500,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _desktopSidebarItem(
                    icon: Icons.home_rounded,
                    label: 'Beranda',
                    active: false,
                    onTap: () => Navigator.pop(context),
                  ),
                  _desktopSidebarItem(
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'Saldo',
                    active: _activeDesktopMenu == 'saldo',
                    onTap: () => _openTransaction(const TopupChannelScreen(), menuKey: 'saldo'),
                  ),
                  _desktopSidebarItem(
                    icon: Icons.sim_card_outlined,
                    label: 'Prepaid',
                    expandable: true,
                    expanded: _prepaidExpanded,
                    active: _activeDesktopMenu == 'prepaid',
                    onTap: () => setState(() => _prepaidExpanded = !_prepaidExpanded),
                  ),
                  if (_prepaidExpanded) _desktopSidebarSubItems(_pembelianItems),
                  _desktopSidebarItem(
                    icon: Icons.receipt_long_outlined,
                    label: 'Postpaid',
                    expandable: true,
                    expanded: _postpaidExpanded,
                    active: _activeDesktopMenu == 'postpaid',
                    onTap: () => setState(() => _postpaidExpanded = !_postpaidExpanded),
                  ),
                  if (_postpaidExpanded) _desktopSidebarSubItems(_pembayaranItems),
                  _desktopSidebarItem(
                    icon: Icons.local_offer_outlined,
                    label: 'Promo',
                    active: _activeDesktopMenu == 'promo',
                    onTap: _desktopActiveScreen != null ? _closeDesktopActiveScreen : _loadPromos,
                  ),
                  _desktopSidebarItem(
                    icon: Icons.history_rounded,
                    label: 'Riwayat Transaksi',
                    onTap: () => WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) return;
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const Seealltransaction(),
                        ),
                      );
                    }),
                  ),
                  _desktopSidebarItem(
                    icon: Icons.headset_mic_outlined,
                    label: 'Bantuan / CS',
                    active: _activeDesktopMenu == 'bantuan',
                    onTap: () => _openTransaction(const HelpSupport('Bantuan / CS'), menuKey: 'bantuan'),
                  ),
                  _desktopSidebarItem(
                    icon: Icons.notifications_none_rounded,
                    label: 'Notifikasi',
                    active: _activeDesktopMenu == 'notifikasi',
                    onTap: () => _openTransaction(const Notificationindex(CustomStrings.notification), menuKey: 'notifikasi'),
                  ),
                  _desktopSidebarItem(
                    icon: Icons.person_outline_rounded,
                    label: 'Akun Saya',
                    active: _activeDesktopMenu == 'akun',
                    onTap: () => _openTransaction(const profile_page.Profile(), menuKey: 'akun'),
                  ),
                  _desktopSidebarItem(
                    icon: Icons.logout_rounded,
                    label: 'Keluar',
                    onTap: () => _confirmDesktopLogout(auth),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ajak Teman, Dapat Komisi!', style: GoogleFonts.hankenGrotesk(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 12.5)),
                  const SizedBox(height: 4),
                  Text(
                    'Dapatkan komisi setiap transaksi dari teman yang kamu ajak.',
                    style: GoogleFonts.hankenGrotesk(fontWeight: FontWeight.w500, color: Colors.white.withOpacity(0.7), fontSize: 10.5),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _showDesktopReferralDialog(auth),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: desktopAccentBlue,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text('Ajukan Sekarang', style: GoogleFonts.hankenGrotesk(fontWeight: FontWeight.w700, fontSize: 12)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _desktopSidebarItem({
    required IconData icon,
    required String label,
    bool active = false,
    bool expandable = false,
    bool expanded = false,
    VoidCallback? onTap,
  }) {
    return Material(
      color: active ? desktopPrimaryBtn : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            children: [
              Icon(icon, size: 19, color: active ? Colors.white : Colors.white.withOpacity(0.6)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.hankenGrotesk(
                    color: active ? Colors.white : Colors.white.withOpacity(0.6),
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ),
              if (expandable)
                Icon(
                  expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                  size: 16,
                  color: Colors.white.withOpacity(0.6),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _desktopSidebarSubItems(List<Map<String, dynamic>> items) {
    return Padding(
      padding: const EdgeInsets.only(left: 36, top: 4, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: items.map((item) {
          final label = item['name'] as String? ?? '';
          final isSubActive = _activeSubMenuName == item['name'];
          return InkWell(
            onTap: () => _navigateToItem(item),
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              child: Text(
                label,
                style: GoogleFonts.hankenGrotesk(
                  color: isSubActive ? Colors.white : Colors.white.withOpacity(0.6),
                  fontWeight: isSubActive ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _getDesktopTopbarTitle() {
    if (_desktopActiveScreen == null) {
      return 'Promo';
    }
    switch (_activeDesktopMenu) {
      case 'saldo':
        return 'Saldo';
      case 'prepaid':
        return 'Prepaid';
      case 'postpaid':
        return 'Postpaid';
      case 'promo':
        return 'Promo';
      case 'riwayat':
        return 'Riwayat Transaksi';
      case 'bantuan':
        return 'Bantuan / CS';
      case 'notifikasi':
        return 'Notifikasi';
      case 'akun':
        return 'Akun Saya';
      default:
        return 'Promo';
    }
  }

  Widget _buildDesktopTopbar(AuthProvider auth) {
    return Container(
      height: 72,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Row(
        children: [
          Text(_getDesktopTopbarTitle(), style: GoogleFonts.hankenGrotesk(fontWeight: FontWeight.w700, fontSize: 18, color: desktopTextPrimary)),
          const Spacer(),
          InkWell(
            onTap: () => _openTransaction(const profile_page.Profile(), menuKey: 'akun'),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade200),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  ClipOval(
                    child: Container(
                      width: 28,
                      height: 28,
                      color: const Color(0xFF182974).withOpacity(0.1),
                      child: auth.userAvatar != null && auth.userAvatar!.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: ApiService.avatarUrl(auth.userAvatar),
                              cacheKey: auth.userAvatar,
                              fit: BoxFit.cover,
                              fadeInDuration: Duration.zero,
                              errorWidget: (_, __, ___) => Center(
                                child: Text(
                                  auth.userName.isNotEmpty ? auth.userName[0].toUpperCase() : 'U',
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF182974)),
                                ),
                              ),
                            )
                          : Center(
                              child: Text(
                                auth.userName.isNotEmpty ? auth.userName[0].toUpperCase() : 'U',
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF182974)),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(auth.userName, style: GoogleFonts.hankenGrotesk(fontWeight: FontWeight.w700, fontSize: 13, color: desktopTextPrimary)),
                      Text(auth.userLevel.toUpperCase(), style: GoogleFonts.hankenGrotesk(fontWeight: FontWeight.w500, fontSize: 10, color: desktopTextSecondary)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
