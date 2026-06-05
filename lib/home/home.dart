import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_svg/flutter_svg.dart';
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
import 'package:modipay/utils/colornotifire.dart';
import 'package:modipay/utils/media.dart';
import 'package:modipay/utils/string.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:modipay/utils/transaction_helpers.dart';

import 'transfer/bank_transfer_screen.dart';
import 'limit/limit_screen.dart';
import 'topup/topup_channel_screen.dart';
import 'qris/qris_merchant_screen.dart';
import 'qris/qris_merchant_register_screen.dart';
import 'qris/qris_scan_screen.dart';

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
            'status_label': statusLabel,
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

  @override
  Widget build(BuildContext context) {
    height = MediaQuery.of(context).size.height;
    width = MediaQuery.of(context).size.width;
    notifire = Provider.of<ColorNotifire>(context, listen: true);
    final auth = Provider.of<AuthProvider>(context);
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
                                onTap: () => _navigateAndRefresh(const BankTransferScreen()),
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
                        onItemTap: _navigateToItem,
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
                        onItemTap: _navigateToItem,
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

  void _navigateToItem(Map<String, dynamic> item) {
    // BPJS selalu pakai layar khusus (daftar produk dari admin panel).
    final brandLowerForBpjs = (item['brand'] ?? '').toString().toLowerCase();
    final categoryLowerForBpjs = (item['category'] ?? '').toString().toLowerCase();
    final nameLowerForBpjs = (item['name'] ?? '').toString().toLowerCase();
    if (brandLowerForBpjs.contains('bpjs') ||
        categoryLowerForBpjs.contains('bpjs') ||
        nameLowerForBpjs.contains('bpjs')) {
      _navigateAndRefresh(const BpjsScreen());
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
      _navigateAndRefresh(const PdamScreen());
      return;
    }

    final routeType = resolvePpobRouteType(item);
    if (routeType == 'all_services') {
      _navigateAndRefresh(const PPOBAllServicesScreen());
    } else if (routeType == 'nfc_toll') {
      _navigateAndRefresh(const NfcTollScanScreen());
    } else if (routeType == 'bank_transfer') {
      _navigateAndRefresh(const BankTransferScreen());
    } else if (routeType == 'qris_payment') {
      _navigateAndRefresh(const QrisScanScreen());
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
      _navigateAndRefresh(PPOBTopUpGameListScreen(
        items: hardcodedGames,
        title: (item['name'] ?? 'TopUp Game').toString().replaceAll('\n', ' '),
      ));
    } else if (routeType == 'postpaid') {
      // PDAM menggunakan screen khusus dengan pilihan kota
      final brandLower = (item['brand'] ?? '').toString().toLowerCase();
      if (brandLower.contains('pdam')) {
        _navigateAndRefresh(const PdamScreen());
      } else {
        _navigateAndRefresh(PPOBPostpaidScreen(brand: item['brand'], title: item['name']));
      }
    } else if (routeType == 'emoney_brand') {
      final cat = (item['category'] as String?)?.trim();
      final filter = (item['productTypeFilter'] ??
              item['product_type_filter'] ??
              item['product_type']) as String?;
      _navigateAndRefresh(PPOBEmoneyBrandScreen(
        category: (cat == null || cat.isEmpty) ? 'E-Wallet' : cat,
        title: 'Pilih ${item['name'] ?? cat ?? 'E-Wallet'}',
        productTypeFilter: filter,
      ));
    } else {
      final category = (item['category'] as String?)?.trim() ?? '';
      final cmd = (item['cmd'] as String?)?.trim() ?? 'prepaid';
      _navigateAndRefresh(PPOBProductScreen(
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
      ));
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
      return StreamBuilder<FileResponse>(
        stream: DefaultCacheManager().getFileStream(url, withProgress: false),
        builder: (context, snapshot) {
          if (snapshot.data is FileInfo) {
            return _buildButton(SvgPicture.file(
              io.File((snapshot.data as FileInfo).file.path),
              width: 28,
              height: 28,
              fit: BoxFit.contain,
            ));
          }
          if (snapshot.hasError) return _buildButton(fallback);
          return _buildButtonShimmer();
        },
      );
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
  final void Function(Map<String, dynamic>) onItemTap;
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
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: notifire.getdarkscolor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Semua $sectionTitle',
          style: TextStyle(fontFamily: 'Gilroy Bold', color: notifire.getdarkscolor, fontSize: height / 46),
        ),
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
            onTap: () => onItemTap(item),
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
