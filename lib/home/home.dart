import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:modipay/widgets/desktop_title_wrapper.dart';
import 'package:modipay/promo/promo_screen.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:modipay/home/notifications.dart';
import 'package:modipay/home/ppob/ppob_all_services_screen.dart';
import 'package:modipay/home/ppob/nfc_toll_scan_screen.dart';
import 'package:modipay/home/ppob/ppob_emoney_brand_screen.dart';
import 'package:modipay/home/ppob/ppob_menu_route.dart';
import 'package:modipay/home/ppob/bpjs_screen.dart';
import 'package:modipay/home/ppob/pdam_screen.dart';
import 'package:modipay/home/ppob/ppob_postpaid_screen.dart';
import 'package:modipay/home/ppob/ppob_product_screen.dart';
import 'package:modipay/home/ppob/ppob_topup_game_list_screen.dart';
import 'package:modipay/home/request/request.dart';
import 'package:modipay/home/seealltransaction.dart';
import 'package:modipay/home/transaction_detail.dart';
import 'package:modipay/providers/auth_provider.dart';
import 'package:modipay/services/api_service.dart';
import 'package:modipay/utils/color.dart';
import 'package:modipay/utils/colornotifire.dart';
import 'package:modipay/utils/media.dart';
import 'package:modipay/utils/responsive.dart';
import 'package:modipay/utils/string.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:modipay/utils/transaction_helpers.dart';
import 'package:modipay/design/design.dart';

import 'transfer/bank_transfer_screen.dart';
import 'transfer/sendmoney.dart';
import 'limit/limit_screen.dart';
import 'topup/topup_channel_screen.dart';
import 'qris/qris_merchant_screen.dart';
import 'qris/qris_merchant_register_screen.dart';
import 'qris/qris_scan_screen.dart';
import '../login/login_router.dart';
import '../profile/helpsupport.dart';
import '../profile/profile.dart' as profile_page;

class Home extends StatefulWidget {
  const Home({Key? key}) : super(key: key);

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  late ColorNotifire notifire;

  getdarkmodepreviousstate() async {
    final prefs = await SharedPreferences.getInstance();
    bool? previusstate = prefs.getBool("setIsDark");
    if (previusstate == null) {
      notifire.setIsDark = false;
    } else {
      notifire.setIsDark = previusstate;
    }
  }

  List<Map<String, dynamic>> _transactions = [];
  List<Map<String, dynamic>> _topups = [];
  List<Map<String, dynamic>> _apiBanners = [];
  List<dynamic> _promoProducts = [];
  bool _loadingTransactions = true;
  bool _isRefreshing = false;
  late PageController _bannerController;
  Timer? _bannerTimer;
  int _bannerPage = 0;
  late PageController _promoController;
  Timer? _promoTimer;
  int _promoPage = 0;
  int _unreadNotificationCount = 0;

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 11) return 'Selamat Pagi,';
    if (hour < 15) return 'Selamat Siang,';
    if (hour < 18) return 'Selamat Sore,';
    return 'Selamat Malam,';
  }

  Color _levelColor(String level) {
    switch (level.toLowerCase()) {
      case 'gold':
        return const Color(0xFFD4A017);
      case 'platinum':
        return const Color(0xFF8C9EAF);
      default:
        return const Color(0xFFCD7F32);
    }
  }

  @override
  void initState() {
    super.initState();
    _bannerController = PageController();
    // viewportFraction <1 agar kartu kiri/kanan terpotong (peek), kartu tengah
    // fokus. Mulai di tengah list virtual untuk infinite-scroll dua arah.
    _promoController = PageController(viewportFraction: 1.0, initialPage: 0);
    _startBannerTimer();
    _startPromoTimer();
    _loadCachedData();
    _loadAllData();
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _promoTimer?.cancel();
    _bannerController.dispose();
    _promoController.dispose();
    super.dispose();
  }

  void _startPromoTimer() {
    _promoTimer?.cancel();
    _promoTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (_promoController.hasClients && _promoProducts.isNotEmpty) {
        _promoController.nextPage(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void _startBannerTimer() {
    _bannerTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      final count = _bannerList.length;
      if (_bannerController.hasClients && count > 0) {
        _bannerPage = (_bannerPage + 1) % count;
        _bannerController.animateToPage(
          _bannerPage,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  Future<void> _loadCachedData() async {
    final prefs = await SharedPreferences.getInstance();
    // Load cached menu
    final menuJson = prefs.getString('cache_ppob_menu_v2');
    if (menuJson != null) {
      try {
        final data = Map<String, dynamic>.from(jsonDecode(menuJson));
        _applyMenuData(data);
      } catch (_) {}
    }
    // Load cached promo
    final promoJson = prefs.getString('cache_promo_products');
    if (promoJson != null) {
      try {
        final products = jsonDecode(promoJson) as List;
        if (mounted && products.isNotEmpty) {
          setState(() => _promoProducts = products);
        }
      } catch (_) {}
    }
    // Load cached banners
    final bannerJson = prefs.getString('cache_banners');
    if (bannerJson != null) {
      try {
        final banners = List<Map<String, dynamic>>.from(
          (jsonDecode(bannerJson) as List).map((e) => Map<String, dynamic>.from(e)),
        );
        if (mounted && banners.isNotEmpty) {
          setState(() => _apiBanners = banners);
        }
      } catch (_) {}
    }
  }

  Future<void> _loadNotificationCount() async {
    try {
      final response = await ApiService.getNotifications();
      if (response['data'] != null) {
        final rawList = response['data'] as List? ?? [];
        final unread = rawList.where((e) {
          final isRead = e['is_read'];
          return isRead == false || isRead == 0 || isRead == '0';
        }).length;
        if (mounted) {
          setState(() {
            _unreadNotificationCount = unread;
          });
        }
      }
    } catch (_) {}
  }

  List<Map<String, dynamic>> get _bannerList {
    if (_apiBanners.isNotEmpty) return _apiBanners;
    return [
      {'title': 'Promo Pulsa', 'description': 'Diskon hingga 5% untuk semua operator', 'color_start': '#0D47A1', 'color_end': '#1E88E5'},
      {'title': 'Cashback PLN', 'description': 'Cashback 2% token listrik & pascabayar', 'color_start': '#F59E0B', 'color_end': '#FBBF24'},
      {'title': 'Transfer Gratis', 'description': 'Gratis biaya transfer antar bank', 'color_start': '#22C55E', 'color_end': '#4ADE80'},
    ];
  }

  Future<void> _loadAllData() async {
    await Future.wait([
      _loadTransactions(),
      _loadTopups(),
      _loadBanners(),
      _loadMenu(),
      _loadPromoProducts(),
      _loadNotificationCount(),
    ]);
  }

  Future<void> _loadTransactions() async {
    try {
      final response = await ApiService.getTransactions();
      if (response.containsKey('data') && mounted) {
        setState(() {
          _transactions = List<Map<String, dynamic>>.from(response['data']);
          _loadingTransactions = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingTransactions = false);
    }
  }

  Future<void> _loadTopups() async {
    try {
      final topups = await ApiService.getRecentTopups();
      if (mounted) {
        setState(() {
          _topups = topups;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadBanners() async {
    try {
      final banners = await ApiService.getBanners();
      if (mounted && banners.isNotEmpty) {
        setState(() => _apiBanners = banners);
        final prefs = await SharedPreferences.getInstance();
        prefs.setString('cache_banners', jsonEncode(banners));
      }
    } catch (_) {}
  }

  Future<void> _loadPromoProducts() async {
    try {
      final products = await ApiService.getPromoProducts();
      if (mounted && products.isNotEmpty) {
        setState(() => _promoProducts = products);
        final prefs = await SharedPreferences.getInstance();
        prefs.setString('cache_promo_products', jsonEncode(products));
      }
    } catch (_) {}
  }

  /// Combined activity list: topups + completed transactions (no duplicates)
  List<Map<String, dynamic>> get _activityItems {
    // Collect transaction order_ids to avoid duplicate completed topups
    final txOrderIds = _transactions
        .map((t) => t['order_id']?.toString() ?? '')
        .toSet();

    final topupItems = _topups
        .where((t) {
          // Skip completed topups that already appear as transactions
          if (t['status'] == 'completed') {
            return !txOrderIds.contains(t['reference_id']?.toString() ?? '');
          }
          return true;
        })
        .map((t) {
          final status = t['status'] ?? 'pending';
          String statusLabel;
          switch (status) {
            case 'pending':
              statusLabel = 'Menunggu';
              break;
            case 'completed':
              statusLabel = '';
              break;
            case 'expired':
              statusLabel = 'Kedaluwarsa';
              break;
            default:
              statusLabel = status;
          }
          return {
            'name': 'Top Up via QRIS',
            'amount': t['amount']?.toString() ?? '0',
            'type': 'income',
            'category': 'topup',
            'order_id': t['reference_id'] ?? '',
            'created_at': t['created_at'],
            'is_pending': status == 'pending',
            'is_expired': status == 'expired',
            'status_label': statusLabel,
            'status': status,
          };
        })
        .toList();

    final completed = _transactions.map((t) {
      final txStatus = t['status']?.toString() ?? 'completed';
      String txStatusLabel;
      switch (txStatus) {
        case 'pending':
          txStatusLabel = 'Menunggu';
          break;
        case 'failed':
          txStatusLabel = 'Gagal';
          break;
        default:
          txStatusLabel = '';
      }
      return {
        ...t,
        'is_pending': txStatus == 'pending',
        'status_label': txStatusLabel,
      };
    }).toList();
    return [...topupItems, ...completed];
  }

  Future<void> _onRefresh() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    await Future.wait([
      auth.fetchProfile(),
      _loadTransactions(),
      _loadTopups(),
      _loadNotificationCount(),
      ApiService.checkPendingTopups(),
      ApiService.checkPendingPpob(),
    ]);
    if (mounted) setState(() => _isRefreshing = false);
  }

  void _navigateAndRefresh(Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => screen),
    ).then((_) => _onRefresh());
  }

  /// Entry point untuk semua alur TRANSAKSI (beli pulsa/listrik/dll, isi
  /// saldo, transfer, scan QRIS). Di desktop, layar transaksi dibuka sebagai
  /// popup/modal mengambang di atas dashboard — bukan pindah halaman penuh
  /// — sesuai desain "Vivid Enterprise". Layar mobile yang sama dipakai
  /// 100% tanpa modifikasi, hanya dibungkus MediaQuery berukuran ponsel agar
  /// proporsi layout (yang dihitung dari screenWidth/screenHeight) tetap benar.
  void _openTransaction(Widget screen, {BuildContext? customContext}) {
    final ctx = customContext ?? context;
    if (!isDesktop(ctx)) {
      _navigateAndRefresh(screen);
      return;
    }

    final isAlreadyInPopup = customContext != null && Theme.of(customContext).appBarTheme.elevation == 0.007;
    if (isAlreadyInPopup) {
      Navigator.push(customContext, MaterialPageRoute(builder: (_) => screen));
      return;
    }

    final screenSize = MediaQuery.of(context).size;
    final modalWidth = 460.0;
    final modalHeight = (screenSize.height * 0.88).clamp(560.0, 840.0);

    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.45),
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Material(
                  color: Colors.white,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => Navigator.of(dialogContext).pop(),
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.close_rounded, size: 20, color: desktopTextPrimary),
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: modalWidth,
                height: modalHeight,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: MediaQuery(
                    data: MediaQuery.of(context).copyWith(size: Size(modalWidth, modalHeight)),
                    child: Theme(
                      data: Theme.of(context).copyWith(
                        appBarTheme: Theme.of(context).appBarTheme.copyWith(
                          elevation: 0.007,
                        ),
                      ),
                      // Navigator bersarang: agar layar lanjutan yang di-push dari
                      // dalam alur transaksi (mis. konfirmasi, struk) tetap berada
                      // di dalam kotak popup ini, bukan keluar jadi halaman penuh.
                      child: Navigator(
                        onGenerateRoute: (settings) => MaterialPageRoute(builder: (_) => screen),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ).then((_) => _onRefresh());
  }

  void _showTransferOptions() {
    // Transfer sesama pengguna (peer) tidak boleh untuk hierarchy_level 'agent'
    // — transfer saldo antar agent hanya boleh master → agent (via Kelola Agen).
    final auth = Provider.of<AuthProvider>(context, listen: false);
    AppBottomSheet.show(
      context: context,
      title: 'Pilih Metode Transfer',
      builder: (context) {
        return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Transfer ke rekening bank hanya untuk akun yang sudah
              // diaktifkan admin (transfer_verified). Selaras dengan guard
              // server-side di BankTransferController.
              if (auth.transferVerified)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE3F2FD),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.account_balance_rounded, color: Color(0xFF1E88E5)),
                  ),
                  title: const Text(
                    'Transfer ke Rekening Bank',
                    style: TextStyle(fontFamily: 'Gilroy Bold', fontSize: 15),
                  ),
                  subtitle: const Text(
                    'Kirim saldo ke berbagai rekening bank di Indonesia',
                    style: TextStyle(fontFamily: 'Gilroy Medium', fontSize: 12, color: Colors.grey),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                  onTap: () {
                    Navigator.pop(context);
                    _openTransaction(const BankTransferScreen());
                  },
                ),
              // Transfer sesama pengguna (peer) disembunyikan untuk agen.
              if (auth.transferVerified && !auth.isAgent)
                const Divider(height: 24, thickness: 1, color: Color(0xFFF3F4F6)),
              if (!auth.isAgent)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.people_alt_rounded, color: Color(0xFF43A047)),
                  ),
                  title: const Text(
                    'Transfer Sesama Modipay',
                    style: TextStyle(fontFamily: 'Gilroy Bold', fontSize: 15),
                  ),
                  subtitle: const Text(
                    'Kirim saldo instan ke sesama pengguna Modipay',
                    style: TextStyle(fontFamily: 'Gilroy Medium', fontSize: 12, color: Colors.grey),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                  onTap: () {
                    Navigator.pop(context);
                    _openTransaction(const SendMoney());
                  },
                ),
              // Tidak ada metode transfer yang tersedia untuk akun ini.
              if (!auth.transferVerified && auth.isAgent)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Belum ada metode transfer yang aktif untuk akun Anda. '
                    'Silakan hubungi admin untuk mengaktifkan.',
                    style: TextStyle(
                      fontFamily: 'Gilroy Medium',
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              const SizedBox(height: 12),
            ],
          );
      },
    );
  }

  String _formatBalance(String balance) {
    final number = double.tryParse(balance) ?? 0;
    final formatter = NumberFormat('#,###', 'id_ID');
    return 'Rp ${formatter.format(number.toInt())}';
  }

  // Home grid PPOB menu items — fully loaded from backend API
  List<Map<String, dynamic>> _pembelianItems = [];
  List<Map<String, dynamic>> _pembayaranItems = [];
  List<Map<String, dynamic>> _keuanganItems = [];
  List<Map<String, dynamic>> _topupGameItems = [];
  List<Map<String, dynamic>> _lainnyaItems = [];

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
    'extension': Icons.extension,
    'shield': Icons.shield,
    'sports_soccer': Icons.sports_soccer,
    'games': Icons.games,
    'play_circle': Icons.play_circle,
    'videocam': Icons.videocam,
    'music_note': Icons.music_note,
    'movie': Icons.movie,
    'send': Icons.send,
    'music_video': Icons.music_video,
    'live_tv': Icons.live_tv,
    'phone': Icons.phone,
  };

  Future<void> _loadMenu() async {
    try {
      final data = await ApiService.getPpobMenu();
      if (!mounted || data.isEmpty) return;
      _applyMenuData(data);
      final prefs = await SharedPreferences.getInstance();
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
        // NOTE: jangan timpa lagi inquiryType/initialBrand/routeType dari `m`
        // karena `normalizePpobMenuItem` sudah meng-handle passthrough +
        // override khusus (mis. shortcut TopUp Game → routeType
        // 'topup_game_list'). Override di sini akan membatalkan logika
        // tersebut bila admin menyetel field-field ini dengan nilai keliru.
        return normalized;
      }).toList();
    }

    setState(() {
      _pembelianItems  = parseGroup(data['pembelian']  as List? ?? [], 'prepaid');
      _pembayaranItems = parseGroup(data['pembayaran'] as List? ?? [], 'pasca');
      _keuanganItems   = parseGroup(data['keuangan']   as List? ?? [], 'prepaid');
      _topupGameItems  = parseGroup(data['topup_game'] as List? ?? [], 'prepaid');
      _lainnyaItems    = parseGroup(data['lainnya']    as List? ?? [], 'prepaid');
    });
  }

  List transaction = [
    "images/starbuckscoffee.png",
    "images/spotify.png",
    "images/netflix.png"
  ];
  bool selection = true;
  bool _prepaidExpanded = false;
  bool _postpaidExpanded = false;

  @override
  Widget build(BuildContext context) {
    height = MediaQuery.of(context).size.height;
    width = MediaQuery.of(context).size.width;
    notifire = Provider.of<ColorNotifire>(context, listen: true);
    final auth = Provider.of<AuthProvider>(context);
    if (isDesktop(context)) {
      return _buildDesktopHome(context, auth);
    }
    return Scaffold(
      backgroundColor: const Color(0xFF182974),
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(color: const Color(0xFF182974)),
          ),
          Positioned(
            top: -80,
            left: -36,
            right: -36,
            child: Container(
              height: 230,
              decoration: const BoxDecoration(
                color: Color(0xFF2A5B9C),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.elliptical(240, 120),
                  bottomRight: Radius.elliptical(260, 130),
                ),
              ),
            ),
          ),
          Positioned(
            top: 72,
            left: 82,
            right: -132,
            child: Container(
              height: 108,
              decoration: const BoxDecoration(
                color: Color(0xFF3567A9),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.elliptical(150, 80),
                  bottomLeft: Radius.elliptical(170, 90),
                  bottomRight: Radius.elliptical(210, 90),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: height * 0.445,
            bottom: 0,
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFFFFFFFF),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(32),
                  topRight: Radius.circular(32),
                ),
              ),
            ),
          ),
      SafeArea(
        bottom: false,
        child: NotificationListener<OverscrollIndicatorNotification>(
          onNotification: (overscroll) {
            overscroll.disallowIndicator();
            return true;
          },
          child: RefreshIndicator(
            onRefresh: _onRefresh,
            color: Colors.white,
            backgroundColor: notifire.getbluecolor,
            edgeOffset: 0,
            displacement: 20,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
          // ── HEADER ──
          Padding(
            padding: EdgeInsets.only(left: width / 20, right: width / 20, bottom: 12),
              child: Column(
                children: [
                    // ─ Greeting row ─
                    Row(
                      children: [
                        // Level badge (small circle)
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _levelColor(auth.userLevel).withOpacity(0.25),
                            border: Border.all(color: _levelColor(auth.userLevel).withOpacity(0.6), width: 1),
                          ),
                          child: Icon(Icons.workspace_premium, size: 14, color: _levelColor(auth.userLevel)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _getGreeting(),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontFamily: 'Gilroy Medium',
                                ),
                              ),
                              Text(
                                auth.userName,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontFamily: 'Gilroy Bold',
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        // Coins badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.monetization_on, color: Color(0xFFFFC107), size: 14),
                              const SizedBox(width: 4),
                              Text(
                                '${auth.userCoins}',
                                style: TextStyle(
                                  color: notifire.getdarkscolor,
                                  fontSize: 11,
                                  fontFamily: 'Gilroy Bold',
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => _navigateAndRefresh(const Notificationindex(CustomStrings.notification)),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.notifications_none_rounded,
                                  color: notifire.getdarkscolor,
                                  size: 20,
                                ),
                              ),
                              if (_unreadNotificationCount > 0)
                                Positioned(
                                  top: -2,
                                  right: -2,
                                  child: Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: const BoxDecoration(
                                      color: Color(0xffFF3B30),
                                      shape: BoxShape.circle,
                                    ),
                                    constraints: const BoxConstraints(
                                      minWidth: 14,
                                      minHeight: 14,
                                    ),
                                    child: Text(
                                      '$_unreadNotificationCount',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 8,
                                        fontFamily: 'Gilroy Bold',
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // ─ Compact balance card ─
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              // Modipay Cash
                              Expanded(
                                child: Row(
                                  children: [
                                    Container(
                                      width: 30,
                                      height: 30,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFEF3C7),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(Icons.account_balance_wallet, color: Color(0xFFF59E0B), size: 15),
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Saldo ',
                                            style: TextStyle(
                                              color: Color(0xFF9CA3AF),
                                              fontSize: 10,
                                              fontFamily: 'Gilroy Medium',
                                            ),
                                          ),
                                          Text(
                                            selection ? _formatBalance(auth.userBalance) : 'Rp ••••••',
                                            style: const TextStyle(
                                              color: Color(0xFF111827),
                                              fontSize: 14,
                                              fontFamily: 'Gilroy Bold',
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Eye toggle
                              GestureDetector(
                                onTap: () => setState(() => selection = !selection),
                                behavior: HitTestBehavior.opaque,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 6),
                                  child: Icon(
                                    selection ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                    color: const Color(0xFF9CA3AF),
                                    size: 16,
                                  ),
                                ),
                              ),
                              // Vertical divider
                              Container(width: 1, height: 32, color: const Color(0xFFF3F4F6)),
                              const SizedBox(width: 10),
                              // QRIS balance
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    if (auth.qrisMerchantActive) {
                                      _navigateAndRefresh(const QrisMerchantScreen());
                                    } else {
                                      _navigateAndRefresh(const QrisMerchantRegisterScreen());
                                    }
                                  },
                                  behavior: HitTestBehavior.opaque,
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 30,
                                        height: 30,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFDBEAFE),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(Icons.qr_code, color: Color(0xFF1E88E5), size: 15),
                                      ),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Saldo QRIS',
                                              style: TextStyle(
                                                color: Color(0xFF9CA3AF),
                                                fontSize: 10,
                                                fontFamily: 'Gilroy Medium',
                                              ),
                                            ),
                                            Text(
                                              auth.qrisMerchantActive
                                                  ? (selection ? _formatBalance(auth.qrisBalance) : 'Rp ••••••')
                                                  : 'Aktifkan →',
                                              style: TextStyle(
                                                color: auth.qrisMerchantActive ? const Color(0xFF111827) : const Color(0xFF1E88E5),
                                                fontSize: auth.qrisMerchantActive ? 14 : 12,
                                                fontFamily: 'Gilroy Bold',
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400, size: 18),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Divider(height: 1, color: const Color(0xFFF3F4F6)),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildCardAction(
                                icon: Icons.add_circle_rounded,
                                label: 'Isi Saldo',
                                color: const Color(0xFF1E88E5),
                                onTap: () => _navigateAndRefresh(const TopupChannelScreen()),
                              ),
                              _buildCardAction(
                                icon: Icons.swap_horiz_rounded,
                                label: 'Transfer',
                                color: const Color(0xFF10B981),
                                onTap: () => _showTransferOptions(),
                              ),
                              _buildCardAction(
                                icon: Icons.credit_card_rounded,
                                label: 'Limit',
                                color: const Color(0xFFF59E0B),
                                onTap: () => _navigateAndRefresh(const LimitScreen()),
                              ),
                              _buildCardAction(
                                icon: Icons.headset_mic_rounded,
                                label: 'Bantuan',
                                color: const Color(0xFF8B5CF6),
                                onTap: () async {
                                  final uri = Uri.parse('whatsapp://send?phone=6285777160669');
                                  try {
                                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                                  } catch (_) {
                                    // Fallback ke link web jika WhatsApp tidak terinstall
                                    final webUri = Uri.parse('https://wa.me/6285777160669');
                                    await launchUrl(webUri, mode: LaunchMode.externalApplication);
                                  }
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

                // ── Promo Products (grid) ──
                if (_promoProducts.isNotEmpty) ...[
                  _buildPromoGrid(),
                  SizedBox(height: height / 40),
                ],

                // ── Pembelian ──
                if (_pembelianDisplayItems.isNotEmpty) ...[
                  _buildServiceSection('Pembelian', _pembelianDisplayItems, 0,
                    onMoreTap: _pembelianDisplayItems.length > 7 ? () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => _PpobOverflowScreen(
                        sectionTitle: 'Pembelian',
                        items: _pembelianDisplayItems,
                        onItemTap: (item, localContext) => _navigateToItem(item, customContext: localContext),
                        hasPromo: _hasPromoForItem,
                        colorOffset: 0,
                      )),
                    ) : null,
                  ),
                  SizedBox(height: height / 40),
                ],

                // ── BANNER CAROUSEL ──
                SizedBox(
                  height: height / 6.5,
                  child: PageView.builder(
                    controller: _bannerController,
                    onPageChanged: (i) => setState(() => _bannerPage = i),
                    itemCount: _bannerList.length,
                    itemBuilder: (context, index) {
                      final b = _bannerList[index];
                      Color c1 = const Color(0xFF0D47A1);
                      Color c2 = const Color(0xFF1E88E5);
                      try {
                        c1 = Color(int.parse((b['color_start'] as String).replaceFirst('#', '0xFF')));
                        c2 = Color(int.parse((b['color_end'] as String).replaceFirst('#', '0xFF')));
                      } catch (_) {}
                      final imageUrl = b['image_url'] as String?;
                      return Container(
                        margin: EdgeInsets.symmetric(horizontal: width / 20),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          gradient: LinearGradient(
                            colors: [c1, c2],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              if (imageUrl != null && imageUrl.isNotEmpty)
                                CachedNetworkImage(
                                  imageUrl: imageUrl,
                                  fit: BoxFit.cover,
                                  fadeInDuration: Duration.zero,
                                  fadeOutDuration: Duration.zero,
                                  errorWidget: (_, __, ___) => const SizedBox(),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                // Dots indicator
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_bannerList.length, (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    height: 6,
                    width: _bannerPage == i ? 18 : 6,
                    decoration: BoxDecoration(
                      color: _bannerPage == i ? notifire.getbluecolor : Colors.grey.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  )),
                ),

                SizedBox(height: height / 40),

                // ── Pembayaran ──
                if (_pembayaranDisplayItems.isNotEmpty) ...[
                  _buildServiceSection('Pembayaran', _pembayaranDisplayItems, 2,
                    onMoreTap: _pembayaranDisplayItems.length > 7 ? () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => _PpobOverflowScreen(
                        sectionTitle: 'Pembayaran',
                        items: _pembayaranDisplayItems,
                        onItemTap: (item, localContext) => _navigateToItem(item, customContext: localContext),
                        hasPromo: _hasPromoForItem,
                        colorOffset: 2,
                      )),
                    ) : null,
                  ),
                  SizedBox(height: height / 30),
                ],

                // ── Keuangan ──
                if (_keuanganItems.isNotEmpty) ...[
                  _buildServiceSection('Keuangan', _keuanganItems, 4),
                  SizedBox(height: height / 30),
                ],

                // ── Top Up Game ──
                if (_topupGameItems.isNotEmpty) ...[
                  _buildServiceSection('Top Up Game', _topupGameItems, 0),
                  SizedBox(height: height / 30),
                ],

                // ── Lainnya ──
                if (_lainnyaItems.isNotEmpty) ...[
                  _buildServiceSection('Lainnya', _lainnyaItems, 2),
                  SizedBox(height: height / 30),
                ],

                SizedBox(height: height / 15),
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

  List<Map<String, dynamic>> get _pembelianDisplayItems => _pembelianItems;
  List<Map<String, dynamic>> get _pembayaranDisplayItems => _pembayaranItems;

  // Normalisasi kategori dari Loketbayar/Digiflazz (mis. 'PAKET DATA' →
  // 'Paket Data') agar cocok dengan map kategori backend & label UI.
  String _prettifyPpobCategory(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return s;
    const map = {
      'paket data': 'Paket Data',
      'pulsa': 'Pulsa',
      'token pln': 'Token PLN',
      'pln pasca': 'PLN Pascabayar',
      'pln pascabayar': 'PLN Pascabayar',
      'paket telpon': 'Paket Telpon',
      'paket sms': 'Paket SMS',
      'masa aktif': 'Masa Aktif',
      'topup game': 'TopUp Game',
      'top up game': 'TopUp Game',
      'voucher': 'Voucher',
      'e-money': 'E-Money',
      'e-wallet': 'E-Wallet',
    };
    final lower = s.toLowerCase();
    if (map.containsKey(lower)) return map[lower]!;
    return lower
        .split(' ')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  Widget _buildCardAction({
    IconData? icon,
    String? svgAsset,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final iconSize = screenWidth * 0.09;
    final fontSize = screenWidth * 0.025;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: iconSize,
            height: iconSize,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(iconSize * 0.28),
            ),
            child: Center(
              child: svgAsset != null
                  ? SvgPicture.asset(
                      svgAsset,
                      width: iconSize * 0.55,
                      height: iconSize * 0.55,
                      fit: BoxFit.contain,
                    )
                  : Icon(icon, color: color, size: iconSize * 0.55),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: TextStyle(
              color: const Color(0xFF374151),
              fontSize: fontSize,
              fontFamily: 'Gilroy Medium',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPromoCard(Map<String, dynamic> p, NumberFormat currencyFormat) {
    final originalPrice = p['original_price'];
    final promoPrice = p['price'];
    final productName = p['product_name'] ?? '';
    final category = (p['category'] ?? '').toString().toLowerCase();
    final promoEnd = p['promo_end'] as String?;
    Color catColor;
    switch (category) {
      case 'pulsa': catColor = const Color(0xFFE91E63); break;
      case 'data': catColor = const Color(0xFF00BCD4); break;
      case 'pln': catColor = const Color(0xFFFF9800); break;
      case 'e-money': catColor = const Color(0xFF4CAF50); break;
      case 'games': catColor = const Color(0xFF9C27B0); break;
      default: catColor = const Color(0xFF1E88E5);
    }
    return GestureDetector(
      onTap: () {
        final rawCat = (p['category'] ?? '').toString();
        final niceCat = _prettifyPpobCategory(rawCat);
        _navigateAndRefresh(PPOBProductScreen(
          category: niceCat,
          title: niceCat,
          cmd: p['cmd'] ?? 'prepaid',
          initialBrand: (p['brand'] ?? p['operator_name'])?.toString(),
        ));
      },
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(height: 2, color: catColor),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 4, 10, 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          height: 15,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            child: Text(
                              productName,
                              style: TextStyle(
                                fontFamily: 'Gilroy Bold',
                                color: const Color(0xFF111827),
                                fontSize: height / 72,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              'Rp ${currencyFormat.format((promoPrice as num).toInt())}',
                              style: TextStyle(
                                color: Colors.red,
                                fontFamily: 'Gilroy Bold',
                                fontSize: height / 66,
                              ),
                            ),
                            if (originalPrice != null) ...[
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  'Rp ${currencyFormat.format((originalPrice as num).toInt())}',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontFamily: 'Gilroy Medium',
                                    fontSize: height / 82,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                  overflow: TextOverflow.fade,
                                  softWrap: false,
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (promoEnd != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            _formatPromoEnd(promoEnd),
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontFamily: 'Gilroy Medium',
                              fontSize: height / 84,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                width: 58,
                height: 20,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF416C), Color(0xFFFF4B2B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'PROMO',
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'Gilroy Bold',
                    fontSize: 9,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPromoGrid() {
    final currencyFormat = NumberFormat('#,###', 'id_ID');
    final productCount = _promoProducts.length;
    return Container(
      margin: EdgeInsets.only(left: width / 20, right: width / 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.zero,
            child: Row(
              children: [
                Icon(Icons.local_offer_rounded, color: Colors.red, size: 18),
                const SizedBox(width: 6),
                Text('Promo',
                    style: TextStyle(
                        fontFamily: 'Gilroy Bold',
                        color: Colors.white,
                        fontSize: height / 48)),
              ],
            ),
          ),
          SizedBox(height: height / 70),
          // Bleed sedikit ke kiri/kanan supaya kartu tetangga ikut terlihat
          // (peek). margin horizontal di Container parent diimbangi negatif.
          SizedBox(
            height: height / 11,
            child: PageView.builder(
              controller: _promoController,
              onPageChanged: (i) => setState(() => _promoPage = i),
              padEnds: false,
              itemCount: ((productCount + 1) ~/ 2) * 1000,
              itemBuilder: (context, index) {
                final pageStart = (index * 2) % productCount;
                final p1 = Map<String, dynamic>.from(
                    _promoProducts[pageStart] as Map);
                final secondIdx = (pageStart + 1) % productCount;
                final hasSecond = pageStart + 1 < productCount || productCount > 1;
                final p2 = hasSecond
                    ? Map<String, dynamic>.from(_promoProducts[secondIdx] as Map)
                    : null;

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: _buildPromoCard(p1, currencyFormat),
                        ),
                      ),
                      Expanded(
                        child: p2 != null
                            ? Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: _buildPromoCard(p2, currencyFormat),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              (() {
                final pages = (productCount + 1) ~/ 2;
                return pages > 8 ? 8 : pages;
              })(),
              (i) {
                final pages = (productCount + 1) ~/ 2;
                final active = (_promoPage % pages) == i;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  height: 5,
                  width: active ? 16 : 5,
                  decoration: BoxDecoration(
                    color: active ? Colors.red : Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatPromoEnd(String dateStr) {
    try {
      final dt = parseDateTime(dateStr);
      final now = DateTime.now();
      final diff = dt.difference(now);
      if (diff.isNegative) return 'Promo sudah berakhir';
      final daysLeft = diff.inDays + ((diff.inHours % 24) > 0 || diff.inMinutes > 0 ? 1 : 0);
      if (daysLeft >= 1) {
        return 'Sisa $daysLeft hari promo';
      }
      return 'Sisa kurang dari 1 hari promo';
    } catch (_) {
      return '';
    }
  }

  String _normalizeCategoryKey(String input) {
    return input.toLowerCase().replaceAll(RegExp(r'[\s\-_]+'), '');
  }

  Set<String> get _promoCategoryKeys {
    return _promoProducts
        .map((p) => (p['category'] ?? '').toString())
        .where((c) => c.trim().isNotEmpty)
        .map(_normalizeCategoryKey)
        .toSet();
  }

  bool _hasPromoForGame(String brand) {
    final key = brand.toLowerCase().replaceAll(RegExp(r'[\s\-_]+'), '');
    for (final p in _promoProducts) {
      final cat = (p['category'] ?? '').toString().toLowerCase();
      if (!cat.contains('game') && !cat.contains('topup')) continue;
      final b = (p['brand'] ?? p['operator_name'] ?? '')
          .toString()
          .toLowerCase()
          .replaceAll(RegExp(r'[\s\-_]+'), '');
      if (b == key || b.contains(key) || key.contains(b)) return true;
    }
    return false;
  }

  bool _hasPromoForItem(Map<String, dynamic> item) {
    final raw = (item['category'] ?? '').toString().trim();
    if (raw.isEmpty) return false;
    final key = _normalizeCategoryKey(raw);
    if (_promoCategoryKeys.contains(key)) return true;
    // Toleransi mismatch nama kategori antara menu vs produk promo
    // (mis. menu "Token PLN" vs promo product category "PLN").
    for (final k in _promoCategoryKeys) {
      if (k.isEmpty) continue;
      if (k.contains(key) || key.contains(k)) return true;
    }
    return false;
  }

  void _navigateToItem(Map<String, dynamic> item, {BuildContext? customContext}) {
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
    } else if (routeType == 'nfc_toll') {
      _openTransaction(const NfcTollScanScreen(), customContext: customContext);
    } else if (routeType == 'bank_transfer') {
      _openTransaction(const BankTransferScreen(), customContext: customContext);
    } else if (routeType == 'qris_payment') {
      _openTransaction(const QrisScanScreen(), customContext: customContext);
    } else if (routeType == 'topup_game_list') {
      // Daftar provider game yang dijamin tampil (tidak bergantung pada
      // konfigurasi menu admin). Kategori/brand di-set untuk filter produk
      // backend, dan `searchKeyword` dipakai untuk filter nama produk
      // di sisi klien jika backend mengembalikan campuran.
      // Backend Loketbayar pakai category='TOPUP GAME' (single category),
      // tiap game dibedakan via field `operator_name` yang dikirim ke API
      // sebagai parameter `brand`.
      // Operator yang tersedia di DB: FREE FIRE, MOBILE LEGEND, HOK,
      // MAGIC CHESS, ROBLOX, PUBG MOBILE.
      final hardcodedGames = <Map<String, dynamic>>[
        {
          'name': 'Free Fire',
          'category': 'TopUp Game',
          'brand': 'FREE FIRE',
          'cmd': 'prepaid',
          'inquirySku': '',
          'gameCode': 'freefire',
          'isPromo': _hasPromoForGame('FREE FIRE'),
        },
        {
          'name': 'Mobile Legend',
          'category': 'TopUp Game',
          'brand': 'MOBILE LEGEND',
          'cmd': 'prepaid',
          'inquirySku': 'MLU',
          'gameCode': 'mobilelegend',
          'isPromo': _hasPromoForGame('MOBILE LEGEND'),
        },
        {
          'name': 'Honor of Kings',
          'category': 'TopUp Game',
          'brand': 'HOK',
          'cmd': 'prepaid',
          'inquirySku': '',
          'gameCode': '',
          'isPromo': _hasPromoForGame('HOK'),
        },
        {
          'name': 'Magic Chess',
          'category': 'TopUp Game',
          'brand': 'MAGIC CHESS',
          'cmd': 'prepaid',
          'inquirySku': '',
          'gameCode': '',
          'isPromo': _hasPromoForGame('MAGIC CHESS'),
        },
        {
          'name': 'Roblox',
          'category': 'TopUp Game',
          'brand': 'ROBLOX',
          'cmd': 'prepaid',
          'inquirySku': '',
          'gameCode': '',
          'isPromo': _hasPromoForGame('ROBLOX'),
        },
        {
          'name': 'PUBG Mobile',
          'category': 'TopUp Game',
          'brand': 'PUBG MOBILE',
          'cmd': 'prepaid',
          'inquirySku': '',
          'gameCode': '',
          'isPromo': _hasPromoForGame('PUBG MOBILE'),
        },
      ];
      _openTransaction(PPOBTopUpGameListScreen(
        items: hardcodedGames,
        title: (item['name'] ?? 'TopUp Game').toString().replaceAll('\n', ' '),
      ), customContext: customContext);
    } else if (routeType == 'postpaid') {
      // PDAM menggunakan screen khusus dengan pilihan kota
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
        // ─── UI config dari admin panel ─────────────────
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

  Widget _buildServiceSection(String title, List<Map<String, dynamic>> items, int colorOffset, {VoidCallback? onMoreTap}) {
    final iconColors = [
      const Color(0xFF1E88E5), const Color(0xFF43A047), const Color(0xFFFF9800), const Color(0xFFE53935),
      const Color(0xFF8E24AA), const Color(0xFF00ACC1), const Color(0xFFFF7043), const Color(0xFF5C6BC0),
    ];
    return Container(
      margin: EdgeInsets.symmetric(horizontal: width / 20),
      padding: EdgeInsets.fromLTRB(width / 25, width / 30, width / 25, width / 40),
      decoration: BoxDecoration(
        color: notifire.getdarkwhitecolor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.16),
            blurRadius: 24,
            spreadRadius: 2,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(title, style: TextStyle(fontFamily: 'Gilroy Bold', color: notifire.getdarkscolor, fontSize: height / 48)),
            ],
          ),
          SizedBox(height: height / 60),
          GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisExtent: height / 8.8,
              crossAxisSpacing: 4,
              mainAxisSpacing: 8,
            ),
            itemCount: (onMoreTap != null && items.length > 7) ? 8 : items.length,
            itemBuilder: (context, index) {
              // Last slot becomes "Lainnya" when there are overflow items
              if (onMoreTap != null && items.length > 7 && index == 7) {
                return _PressableMenuButton(
                  icon: Icons.grid_view_rounded,
                  name: 'Lainnya',
                  iconColor: const Color(0xFF1E88E5),
                  cardColor: notifire.getdarkwhitecolor,
                  textColor: notifire.getdarkscolor,
                  textSize: height / 68,
                  onTap: onMoreTap,
                );
              }
              final item = items[index];
              final iColor = item['color'] != null
                  ? Color(int.parse((item['color'] as String).replaceFirst('#', '0xFF')))
                  : iconColors[(index + colorOffset) % iconColors.length];
              return _PressableMenuButton(
                icon: item['icon'] as IconData,
                iconUrl: item['iconUrl'] as String?,
                name: item['name'] as String,
                iconColor: iColor,
                cardColor: notifire.getdarkwhitecolor,
                textColor: notifire.getdarkscolor,
                textSize: height / 68,
                showPromoBadge: _hasPromoForItem(item),
                onTap: () => _navigateToItem(item),
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Desktop layout (sidebar + topbar, gaya dashboard.jpeg) ───────────────

  Widget _buildDesktopHome(BuildContext context, AuthProvider auth) {
    final recentActivity = List<Map<String, dynamic>>.from(_activityItems)
      ..sort((a, b) => parseDateTime(b['created_at']).compareTo(parseDateTime(a['created_at'])));
    final recent = recentActivity.take(5).toList();

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
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(flex: 5, child: _buildDesktopBalanceCard(auth)),
                              const SizedBox(width: 20),
                              Expanded(flex: 4, child: _buildDesktopStatusCard()),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _buildDesktopServiceCard(
                                title: 'Prepaid',
                                subtitle: 'Isi ulang instan, kapan saja dan di mana saja',
                                items: _pembelianDisplayItems,
                                colorOffset: 0,
                                sectionTitleForOverflow: 'Pembelian',
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: _buildDesktopServiceCard(
                                title: 'Postpaid',
                                subtitle: 'Bayar tagihan bulanan dengan mudah',
                                items: _pembayaranDisplayItems,
                                colorOffset: 2,
                                sectionTitleForOverflow: 'Pembayaran',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 7, child: _buildDesktopTransactionTable(recent)),
                            const SizedBox(width: 20),
                            Expanded(flex: 3, child: _buildDesktopHelpCard()),
                          ],
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
                    fontWeight: FontWeight.w500,
                    fontSize: 13.5,
                    color: active ? Colors.white : Colors.white.withOpacity(0.6),
                  ),
                ),
              ),
              if (expandable)
                Icon(expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, size: 18, color: Colors.white.withOpacity(0.6)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _desktopSidebarSubItems(List<Map<String, dynamic>> items) {
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(left: 44, bottom: 6),
        child: Text('Belum ada layanan', style: GoogleFonts.hankenGrotesk(fontWeight: FontWeight.w500, fontSize: 12, color: Colors.white.withOpacity(0.6))),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(left: 44, right: 8, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: items.take(6).map((item) {
          return InkWell(
            onTap: () => _navigateToItem(item),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                item['name'] as String? ?? '',
                style: GoogleFonts.hankenGrotesk(fontWeight: FontWeight.w500, fontSize: 12.5, color: Colors.white.withOpacity(0.6)),
              ),
            ),
          );
        }).toList(),
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
                  _desktopSidebarItem(icon: Icons.home_rounded, label: 'Beranda', active: true, onTap: _onRefresh),
                  _desktopSidebarItem(
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'Saldo',
                    onTap: () => _openTransaction(const TopupChannelScreen()),
                  ),
                  _desktopSidebarItem(
                    icon: Icons.sim_card_outlined,
                    label: 'Prepaid',
                    expandable: true,
                    expanded: _prepaidExpanded,
                    onTap: () => setState(() => _prepaidExpanded = !_prepaidExpanded),
                  ),
                  if (_prepaidExpanded) _desktopSidebarSubItems(_pembelianDisplayItems),
                  _desktopSidebarItem(
                    icon: Icons.receipt_long_outlined,
                    label: 'Postpaid',
                    expandable: true,
                    expanded: _postpaidExpanded,
                    onTap: () => setState(() => _postpaidExpanded = !_postpaidExpanded),
                  ),
                  if (_postpaidExpanded) _desktopSidebarSubItems(_pembayaranDisplayItems),
                  _desktopSidebarItem(
                    icon: Icons.local_offer_outlined,
                    label: 'Promo',
                    onTap: () => _navigateAndRefresh(const PromoScreen()),
                  ),
                  _desktopSidebarItem(
                    icon: Icons.history_rounded,
                    label: 'Riwayat Transaksi',
                    onTap: () => _navigateAndRefresh(const Seealltransaction()),
                  ),
                  _desktopSidebarItem(
                    icon: Icons.headset_mic_outlined,
                    label: 'Bantuan / CS',
                    onTap: () => _navigateAndRefresh(const HelpSupport('Bantuan / CS')),
                  ),
                  _desktopSidebarItem(
                    icon: Icons.notifications_none_rounded,
                    label: 'Notifikasi',
                    onTap: () => _navigateAndRefresh(const Notificationindex(CustomStrings.notification)),
                  ),
                  _desktopSidebarItem(
                    icon: Icons.person_outline_rounded,
                    label: 'Akun Saya',
                    onTap: () => _navigateAndRefresh(const profile_page.Profile()),
                  ),
                  _desktopSidebarItem(
                    icon: Icons.settings_outlined,
                    label: 'Pengaturan',
                    onTap: () => _navigateAndRefresh(const profile_page.Profile()),
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

  Widget _buildDesktopTopbar(AuthProvider auth) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: desktopBorder))),
      child: Row(
        children: [
          Text('Beranda', style: GoogleFonts.hankenGrotesk(fontWeight: FontWeight.w700, fontSize: 18, color: desktopTextPrimary)),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: desktopTextSecondary, size: 20),
            onPressed: _onRefresh,
            tooltip: 'Refresh',
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: desktopAccentBlue.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.headset_mic_outlined, size: 16, color: desktopAccentBlue),
                const SizedBox(width: 6),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('CS Online', style: GoogleFonts.hankenGrotesk(fontWeight: FontWeight.w700, fontSize: 11, color: desktopTextPrimary)),
                    Text('08:00 - 22:00', style: GoogleFonts.hankenGrotesk(fontWeight: FontWeight.w500, fontSize: 9, color: desktopTextSecondary)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          GestureDetector(
            onTap: () => _navigateAndRefresh(const Notificationindex(CustomStrings.notification)),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(color: desktopSurfacePage, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.notifications_none_rounded, color: desktopTextSecondary),
                ),
                if (_unreadNotificationCount > 0)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(color: Color(0xffFF3B30), shape: BoxShape.circle),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        '$_unreadNotificationCount',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.hankenGrotesk(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 9,),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          GestureDetector(
            onTap: () => _navigateAndRefresh(const profile_page.Profile()),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: desktopAccentBlue.withOpacity(0.15),
                  child: Text(
                    auth.userName.isNotEmpty ? auth.userName[0].toUpperCase() : 'U',
                    style: GoogleFonts.hankenGrotesk(fontWeight: FontWeight.w700, color: desktopAccentBlue),
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(auth.userName, style: GoogleFonts.hankenGrotesk(fontWeight: FontWeight.w700, fontSize: 13, color: desktopTextPrimary)),
                    Text(auth.userLevel.toUpperCase(), style: GoogleFonts.hankenGrotesk(fontWeight: FontWeight.w500, fontSize: 10, color: desktopTextSecondary)),
                  ],
                ),
                const SizedBox(width: 4),
                const Icon(Icons.keyboard_arrow_down_rounded, color: desktopTextSecondary, size: 18),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopBalanceCard(AuthProvider auth) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [desktopBalanceGradStart, desktopBalanceGradEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Saldo Anda', style: GoogleFonts.hankenGrotesk(fontWeight: FontWeight.w500, color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          selection ? _formatBalance(auth.userBalance) : 'Rp ••••••',
                          style: GoogleFonts.hankenGrotesk(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 26),
                        ),
                        const SizedBox(width: 10),
                        GestureDetector(
                          onTap: () => setState(() => selection = !selection),
                          child: Icon(
                            selection ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            color: Colors.white70,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 24),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: () => _openTransaction(const TopupChannelScreen()),
                icon: const Icon(Icons.add_circle_outline, size: 18),
                label: const Text('Isi Saldo'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: desktopBalanceGradEnd,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () => _showTransferOptions(),
                icon: const Icon(Icons.send_rounded, size: 16, color: Colors.white),
                label: const Text('Transfer Saldo', style: TextStyle(color: Colors.white)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white54),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopStatusCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('MODITEKH2H', style: GoogleFonts.hankenGrotesk(fontWeight: FontWeight.w700, fontSize: 13, color: desktopAccentBlue)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text('Transaksi sedang lancar', style: GoogleFonts.hankenGrotesk(fontWeight: FontWeight.w700, fontSize: 15, color: desktopTextPrimary)),
                        const SizedBox(width: 6),
                        const Icon(Icons.check_circle, color: Color(0xFF22C55E), size: 16),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sistem berjalan normal dan semua layanan dapat digunakan dengan baik.',
                      style: GoogleFonts.hankenGrotesk(fontWeight: FontWeight.w500, fontSize: 12, color: desktopTextSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    OutlinedButton(
                      onPressed: () => _navigateAndRefresh(const HelpSupport('Status Layanan')),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: desktopBorder),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      child: Text('Lihat Status Layanan', style: GoogleFonts.hankenGrotesk(fontWeight: FontWeight.w700, fontSize: 12, color: desktopAccentBlue)),
                    ),
                    const SizedBox(width: 16),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(color: desktopAccentBlue, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(color: desktopTextSecondary.withOpacity(0.3), shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(color: desktopTextSecondary.withOpacity(0.3), shape: BoxShape.circle),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                'https://lh3.googleusercontent.com/aida-public/AB6AXuBQdt6tQHKUwtPmQh5PrrpEx7tR5yH8v3FeH3rvgSRa4pFFaWLiyJB6eu8xIN253pbAwDYVInuj_U8GFqV9RrOME-Q9cXjqws82x4lDbE1TIKCXkquIulmvMzuEXTxgi__RBo0wC4R078i_ryLiU32dB8fHS7oF6CGNYrBlNlAq3wY8Gj8_gIz2fo_dzN7uAo9DGlolnPvuxs6qUxjcjL4ZPAFjHeauvI2MKfTAo6UHdAKxqqiRNZfIyN15bwMia3zVEbiT3YrmlZKC',
                fit: BoxFit.cover,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopServiceCard({
    required String title,
    required String subtitle,
    required List<Map<String, dynamic>> items,
    required int colorOffset,
    required String sectionTitleForOverflow,
  }) {
    final iconColors = [
      const Color(0xFF1E88E5), const Color(0xFF43A047), const Color(0xFFFF9800), const Color(0xFFE53935),
      const Color(0xFF8E24AA), const Color(0xFF00ACC1), const Color(0xFFFF7043), const Color(0xFF5C6BC0),
    ];
    final shown = items.take(5).toList();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: GoogleFonts.hankenGrotesk(fontWeight: FontWeight.w700, fontSize: 15, color: desktopTextPrimary)),
                    Text(subtitle, style: GoogleFonts.hankenGrotesk(fontWeight: FontWeight.w500, fontSize: 11, color: desktopTextSecondary)),
                  ],
                ),
              ),
              if (items.length > 5)
                GestureDetector(
                  onTap: () => _openTransaction(
                    _PpobOverflowScreen(
                      sectionTitle: sectionTitleForOverflow,
                      items: items,
                      onItemTap: (item, localContext) => _navigateToItem(item, customContext: localContext),
                      hasPromo: _hasPromoForItem,
                      colorOffset: colorOffset,
                    ),
                  ),
                  child: Text('Lihat Semua', style: GoogleFonts.hankenGrotesk(fontWeight: FontWeight.w700, fontSize: 12, color: desktopAccentBlue)),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (shown.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text('Belum ada layanan', style: GoogleFonts.hankenGrotesk(fontWeight: FontWeight.w500, fontSize: 12, color: desktopTextSecondary)),
            )
          else
            Wrap(
              spacing: 12,
              runSpacing: 16,
              children: List.generate(shown.length, (i) {
                final item = shown[i];
                final color = item['color'] != null
                    ? Color(int.parse((item['color'] as String).replaceFirst('#', '0xFF')))
                    : iconColors[(i + colorOffset) % iconColors.length];
                return SizedBox(
                  width: 76,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _navigateToItem(item),
                    child: Column(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(14)),
                          child: item['iconUrl'] != null
                              ? Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: (item['iconUrl'] as String).toLowerCase().endsWith('.svg')
                                      ? SvgPicture.network(
                                          item['iconUrl'] as String,
                                          fit: BoxFit.contain,
                                          placeholderBuilder: (_) => Icon(item['icon'] as IconData, color: color, size: 24),
                                        )
                                      : CachedNetworkImage(
                                          imageUrl: item['iconUrl'] as String,
                                          fit: BoxFit.contain,
                                          errorWidget: (_, __, ___) => Icon(item['icon'] as IconData, color: color, size: 24),
                                        ),
                                )
                              : Icon(item['icon'] as IconData, color: color, size: 24),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          item['name'] as String? ?? '',
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.hankenGrotesk(fontWeight: FontWeight.w500, fontSize: 11, color: desktopTextSecondary),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
        ],
      ),
    );
  }

  String _pickFirstNonEmpty(List<dynamic> values) {
    for (final v in values) {
      final s = v?.toString().trim() ?? '';
      if (s.isNotEmpty) return s;
    }
    return '-';
  }

  Widget _buildDesktopTransactionTable(List<Map<String, dynamic>> items) {
    final df = DateFormat('d MMM yyyy HH:mm', 'id_ID');
    final currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    Color statusBg(String status) {
      switch (status) {
        case 'pending':
          return desktopWarningAmber.withOpacity(0.12);
        case 'failed':
          return desktopErrorRed.withOpacity(0.1);
        case 'expired':
          return desktopSurfacePage;
        default:
          return desktopSuccessBg;
      }
    }

    Color statusFg(String status) {
      switch (status) {
        case 'pending':
          return desktopWarningAmber;
        case 'failed':
          return desktopErrorRed;
        case 'expired':
          return desktopTextSecondary;
        default:
          return desktopSuccessFg;
      }
    }

    String statusLabel(Map<String, dynamic> item) {
      final custom = (item['status_label'] ?? '').toString();
      if (custom.isNotEmpty) return custom;
      return 'Berhasil';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Riwayat Transaksi Terakhir', style: GoogleFonts.hankenGrotesk(fontWeight: FontWeight.w700, fontSize: 15, color: desktopTextPrimary)),
              ),
              GestureDetector(
                onTap: () => _navigateAndRefresh(const Seealltransaction()),
                child: Text('Lihat Semua', style: GoogleFonts.hankenGrotesk(fontWeight: FontWeight.w700, fontSize: 12, color: desktopAccentBlue)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('Belum ada transaksi', style: GoogleFonts.hankenGrotesk(fontWeight: FontWeight.w500, color: desktopTextSecondary))),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Expanded(flex: 3, child: Text('Tanggal', style: GoogleFonts.hankenGrotesk(fontWeight: FontWeight.w700, fontSize: 11, color: desktopTextSecondary))),
                  Expanded(flex: 4, child: Text('Produk', style: GoogleFonts.hankenGrotesk(fontWeight: FontWeight.w700, fontSize: 11, color: desktopTextSecondary))),
                  Expanded(flex: 3, child: Text('Nomor Tujuan', style: GoogleFonts.hankenGrotesk(fontWeight: FontWeight.w700, fontSize: 11, color: desktopTextSecondary))),
                  Expanded(flex: 2, child: Text('Status', style: GoogleFonts.hankenGrotesk(fontWeight: FontWeight.w700, fontSize: 11, color: desktopTextSecondary))),
                  Expanded(flex: 2, child: Text('Nominal', textAlign: TextAlign.right, style: GoogleFonts.hankenGrotesk(fontWeight: FontWeight.w700, fontSize: 11, color: desktopTextSecondary))),
                  const SizedBox(width: 20),
                ],
              ),
            ),
            Divider(height: 1, color: desktopBorder),
            ...items.map((item) {
              final name = (item['name'] ?? item['product_name'] ?? '-').toString();
              final target = _pickFirstNonEmpty([item['customer_no'], item['customer_id'], item['target'], item['order_id']]);
              final amount = effectiveTransactionTotal(item);
              final status = statusLabel(item);
              final statusKey = item['is_pending'] == true
                  ? 'pending'
                  : item['is_expired'] == true
                      ? 'expired'
                      : (item['status'] ?? 'completed').toString();
              return InkWell(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TransactionDetail(data: item))),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          df.format(parseDateTime(item['created_at'])),
                          style: GoogleFonts.hankenGrotesk(fontWeight: FontWeight.w500, fontSize: 12, color: desktopTextSecondary),
                        ),
                      ),
                      Expanded(
                        flex: 4,
                        child: Row(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(color: desktopAccentBlue.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
                              child: const Icon(Icons.receipt_long, size: 14, color: desktopAccentBlue),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.hankenGrotesk(fontWeight: FontWeight.w500, fontSize: 12, color: desktopTextPrimary),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(target, style: GoogleFonts.hankenGrotesk(fontWeight: FontWeight.w500, fontSize: 12, color: desktopTextSecondary)),
                      ),
                      Expanded(
                        flex: 2,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: statusBg(statusKey), borderRadius: BorderRadius.circular(8)),
                            child: Text(status, style: GoogleFonts.hankenGrotesk(fontWeight: FontWeight.w700, fontSize: 10.5, color: statusFg(statusKey))),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          currency.format(amount),
                          textAlign: TextAlign.right,
                          style: GoogleFonts.hankenGrotesk(fontWeight: FontWeight.w700, fontSize: 12, color: desktopTextPrimary),
                        ),
                      ),
                      const SizedBox(width: 20, child: Icon(Icons.chevron_right_rounded, size: 18, color: desktopBorder)),
                    ],
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _desktopHelpChannelRow({
    required IconData icon,
    required String title,
    required String subtitle,
    Color? subtitleColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: desktopAccentBlue.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 16, color: desktopAccentBlue),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.hankenGrotesk(fontWeight: FontWeight.w700, fontSize: 12.5, color: desktopTextPrimary)),
                Text(subtitle, style: GoogleFonts.hankenGrotesk(fontWeight: FontWeight.w500, fontSize: 10.5, color: subtitleColor ?? desktopTextSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openWhatsapp() async {
    final uri = Uri.parse('whatsapp://send?phone=6285777160669');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      await launchUrl(Uri.parse('https://wa.me/6285777160669'), mode: LaunchMode.externalApplication);
    }
  }

  Widget _buildDesktopHelpCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Butuh Bantuan?', style: GoogleFonts.hankenGrotesk(fontWeight: FontWeight.w700, fontSize: 15, color: desktopTextPrimary)),
          const SizedBox(height: 4),
          Text(
            'Tim CS kami siap membantu kebutuhan transaksi Anda.',
            style: GoogleFonts.hankenGrotesk(fontWeight: FontWeight.w500, fontSize: 11, color: desktopTextSecondary),
          ),
          const SizedBox(height: 16),
          _desktopHelpChannelRow(
            icon: Icons.chat_bubble_outline_rounded,
            title: 'Live Chat',
            subtitle: 'CS Online',
            subtitleColor: const Color(0xFF22C55E),
            onTap: () => _navigateAndRefresh(const HelpSupport('Bantuan / CS')),
          ),
          const SizedBox(height: 12),
          _desktopHelpChannelRow(
            icon: Icons.message_outlined,
            title: 'WhatsApp',
            subtitle: '08:00 - 22:00',
            onTap: _openWhatsapp,
          ),
          const SizedBox(height: 12),
          _desktopHelpChannelRow(
            icon: Icons.email_outlined,
            title: 'Email',
            subtitle: 'support@moditekh2h.com',
            onTap: () => launchUrl(Uri.parse('mailto:support@moditekh2h.com')),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _navigateAndRefresh(const HelpSupport('Bantuan / CS')),
              icon: const Icon(Icons.headset_mic_rounded, size: 18),
              label: const Text('Hubungi CS'),
              style: ElevatedButton.styleFrom(
                backgroundColor: desktopPrimaryBtn,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
      Fluttertoast.showToast(msg: 'Kode referral belum tersedia untuk akun Anda');
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
        child: Text(code, style: GoogleFonts.hankenGrotesk(fontWeight: FontWeight.w700, fontSize: 20)),
      ),
      secondaryActionText: 'Tutup',
      primaryActionText: 'Salin',
    );
    if (copy == true) {
      await Clipboard.setData(ClipboardData(text: code));
      Fluttertoast.showToast(msg: 'Kode referral disalin');
    }
  }

}

// ── Physical-press menu button ──────────────────────────────────────────────
class _PressableMenuButton extends StatefulWidget {
  final IconData icon;
  final String? iconUrl;
  final String name;
  final Color iconColor;
  final Color cardColor;
  final Color textColor;
  final double textSize;
  final bool showPromoBadge;
  final VoidCallback onTap;

  const _PressableMenuButton({
    required this.icon,
    this.iconUrl,
    required this.name,
    required this.iconColor,
    required this.cardColor,
    required this.textColor,
    required this.textSize,
    this.showPromoBadge = false,
    required this.onTap,
  });

  @override
  State<_PressableMenuButton> createState() => _PressableMenuButtonState();
}

class _PressableMenuButtonState extends State<_PressableMenuButton> {
  bool _pressed = false;

  Widget _buildButtonShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade200,
      highlightColor: Colors.grey.shade100,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          const SizedBox(height: 5),
          SizedBox(
            height: 30,
            child: Center(
              child: Container(
                width: 38,
                height: 10,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButton(Widget iconWidget) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) async {
        await Future.delayed(const Duration(milliseconds: 180));
        if (mounted) setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          AnimatedScale(
            scale: _pressed ? 0.88 : 1.0,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeInOut,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: _pressed
                    ? widget.cardColor.withOpacity(0.85)
                    : widget.cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: _pressed
                    ? []
                    : [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.10),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                border: Border.all(
                  color: widget.iconColor.withOpacity(0.18),
                  width: 1.2,
                ),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Center(child: iconWidget),
                  if (widget.showPromoBadge)
                    Positioned(
                      right: -6,
                      top: -6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE11D48),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.12),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Text(
                          'PROMO',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontFamily: 'Gilroy Bold',
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 5),
          SizedBox(
            height: 30,
            child: Text(
              widget.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Gilroy Medium',
                color: widget.textColor,
                fontSize: widget.textSize,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.iconUrl;
    final fallback = Icon(widget.icon, color: widget.iconColor, size: 26);

    if (url == null || url.isEmpty) {
      return _buildButton(fallback);
    }

    if (url.toLowerCase().endsWith('.svg')) {
      // SvgPicture.network dipakai di semua platform (termasuk web, di mana
      // dart:io.File tidak tersedia) agar tidak perlu cabang kode per-platform.
      return _buildButton(SvgPicture.network(
        url,
        width: 28,
        height: 28,
        fit: BoxFit.contain,
        placeholderBuilder: (_) => fallback,
      ));
    }

    return CachedNetworkImage(
      imageUrl: url,
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      placeholder: (_, __) => _buildButtonShimmer(),
      errorWidget: (_, __, ___) => _buildButton(fallback),
      imageBuilder: (context, imageProvider) => _buildButton(
        Image(image: imageProvider, width: 28, height: 28, fit: BoxFit.contain),
      ),
    );
  }
}

class _PpobOverflowScreen extends StatelessWidget {
  final String sectionTitle;
  final List<Map<String, dynamic>> items;
  final void Function(Map<String, dynamic>, BuildContext) onItemTap;
  final bool Function(Map<String, dynamic>) hasPromo;
  final int colorOffset;

  const _PpobOverflowScreen({
    required this.sectionTitle,
    required this.items,
    required this.onItemTap,
    required this.hasPromo,
    this.colorOffset = 0,
  });

  @override
  Widget build(BuildContext context) {
    final notifire = Provider.of<ColorNotifire>(context);
    final size = MediaQuery.of(context).size;
    final height = size.height;
    final width = size.width;
    const iconColors = [
      Color(0xFF1E88E5), Color(0xFF43A047), Color(0xFFFF9800), Color(0xFFE53935),
      Color(0xFF8E24AA), Color(0xFF00ACC1), Color(0xFFFF7043), Color(0xFF5C6BC0),
    ];

    return Scaffold(
      backgroundColor: notifire.getbackcolor,
      appBar: AppBar(
        backgroundColor: notifire.getbackcolor,
        elevation: 0,
        leading: DesktopLeadingWrapper(child: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: notifire.getdarkscolor, size: 20),
          onPressed: () => Navigator.pop(context),
        )),
        title: DesktopTitleWrapper(child: Text(
          'Semua $sectionTitle',
          style: TextStyle(fontFamily: 'Gilroy Bold', color: notifire.getdarkscolor, fontSize: height / 46),
        )),
      ),
      body: GridView.builder(
        padding: EdgeInsets.symmetric(horizontal: width / 20, vertical: width / 20),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisExtent: height / 8.8,
          crossAxisSpacing: 4,
          mainAxisSpacing: 8,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          final iColor = item['color'] != null
              ? Color(int.parse((item['color'] as String).replaceFirst('#', '0xFF')))
              : iconColors[(index + colorOffset) % iconColors.length];
          return _PressableMenuButton(
            icon: item['icon'] as IconData,
            iconUrl: item['iconUrl'] as String?,
            name: item['name'] as String,
            iconColor: iColor,
            cardColor: notifire.getdarkwhitecolor,
            textColor: notifire.getdarkscolor,
            textSize: height / 68,
            showPromoBadge: hasPromo(item),
            onTap: () => onItemTap(item, context),
          );
        },
      ),
    );
  }
}

/// Abstract diagonal lines drawn on the header background
class _AbstractLinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.07)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    // Diagonal lines from top-right
    canvas.drawLine(Offset(size.width * 0.6, 0), Offset(size.width, size.height * 0.7), paint);
    canvas.drawLine(Offset(size.width * 0.75, 0), Offset(size.width, size.height * 0.35), paint);
    canvas.drawLine(Offset(size.width * 0.45, 0), Offset(size.width * 0.85, size.height), paint);

    // Thicker accent lines
    paint
      ..strokeWidth = 2.5
      ..color = Colors.white.withOpacity(0.05);
    canvas.drawLine(Offset(size.width * 0.3, 0), Offset(size.width * 0.7, size.height), paint);
    canvas.drawLine(Offset(size.width * 0.85, 0), Offset(size.width, size.height * 0.55), paint);

    // Curved abstract shape
    final curvePaint = Paint()
      ..color = Colors.white.withOpacity(0.04)
      ..strokeWidth = 40
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..moveTo(0, size.height * 0.6)
      ..quadraticBezierTo(size.width * 0.4, size.height * 0.2, size.width, size.height * 0.5);
    canvas.drawPath(path, curvePaint);

    // Small circle accents
    final circlePaint = Paint()
      ..color = Colors.white.withOpacity(0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(Offset(size.width * 0.15, size.height * 0.3), 30, circlePaint);
    canvas.drawCircle(Offset(size.width * 0.9, size.height * 0.15), 18, circlePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
