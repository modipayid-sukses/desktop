import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../utils/colornotifire.dart';
import '../../utils/media.dart';
import 'nfc_toll_scan_screen.dart';
import 'bpjs_screen.dart';
import 'pdam_screen.dart';
import 'ppob_emoney_brand_screen.dart';
import 'ppob_menu_route.dart';
import '../transfer/bank_transfer_screen.dart';
import 'ppob_postpaid_screen.dart';
import 'ppob_product_screen.dart';

class PPOBAllServicesScreen extends StatefulWidget {
  const PPOBAllServicesScreen({Key? key}) : super(key: key);

  @override
  State<PPOBAllServicesScreen> createState() => _PPOBAllServicesScreenState();
}

class _PPOBAllServicesScreenState extends State<PPOBAllServicesScreen> {
  late ColorNotifire notifire;

  static const Map<String, IconData> _iconMap = {
    'phone_android': Icons.phone_android,
    'signal_cellular_alt': Icons.signal_cellular_alt,
    'electric_bolt': Icons.electric_bolt,
    'account_balance_wallet': Icons.account_balance_wallet,
    'card_giftcard': Icons.card_giftcard,
    'sports_esports': Icons.sports_esports,
    'electrical_services': Icons.electrical_services,
    'water_drop': Icons.water_drop,
    'wifi': Icons.wifi,
    'account_balance': Icons.account_balance,
    'health_and_safety': Icons.health_and_safety,
    'tv': Icons.tv,
    'home_work': Icons.home_work,
    'local_fire_department': Icons.local_fire_department,
    'message': Icons.message,
    'swap_horiz': Icons.swap_horiz,
    'directions_car': Icons.directions_car,
    'credit_card': Icons.credit_card,
    'toll': Icons.toll,
    'videocam': Icons.videocam,
    'music_note': Icons.music_note,
    'movie': Icons.movie,
    'send': Icons.send,
    'music_video': Icons.music_video,
    'live_tv': Icons.live_tv,
    'phone': Icons.phone,
    'games': Icons.sports_esports,
    'shopping_bag': Icons.shopping_bag,
    'language': Icons.language,
    'play_circle': Icons.play_circle,
    'headphones': Icons.headphones,
    'subscriptions': Icons.subscriptions,
    'confirmation_number': Icons.confirmation_number,
  };

  // 5 groups loaded from cache
  List<Map<String, dynamic>> _pembelianItems = [];
  List<Map<String, dynamic>> _pembayaranItems = [];
  List<Map<String, dynamic>> _keuanganItems = [];
  List<Map<String, dynamic>> _topupGameItems = [];
  List<Map<String, dynamic>> _lainnyaItems = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final menuJson = prefs.getString('cache_ppob_menu');
    if (menuJson != null) {
      try {
        final data = Map<String, dynamic>.from(jsonDecode(menuJson));
        List<Map<String, dynamic>> parseGroup(List items, String defaultCmd) {
          return items.map((c) {
            final m = Map<String, dynamic>.from(c);
            final normalized = normalizePpobMenuItem(
              m,
              defaultCmd: defaultCmd,
              flattenName: true,
            );
            normalized['icon'] = _iconMap[m['icon']] ?? Icons.apps;
            if (m['inquiry_type'] != null) normalized['inquiryType'] = m['inquiry_type'];
            if (m['initial_brand'] != null) normalized['initialBrand'] = m['initial_brand'];
            if (m['route_type'] != null) normalized['routeType'] = m['route_type'];
            return normalized;
          }).toList();
        }
        if (!mounted) return;
        setState(() {
          final pembelian = data['pembelian'] as List? ?? [];
          if (pembelian.isNotEmpty) _pembelianItems = parseGroup(pembelian, 'prepaid');
          final pembayaran = data['pembayaran'] as List? ?? [];
          if (pembayaran.isNotEmpty) _pembayaranItems = parseGroup(pembayaran, 'pasca');
          final keuangan = data['keuangan'] as List? ?? [];
          if (keuangan.isNotEmpty) _keuanganItems = parseGroup(keuangan, 'prepaid');
          final topupGame = data['topup_game'] as List? ?? [];
          if (topupGame.isNotEmpty) _topupGameItems = parseGroup(topupGame, 'prepaid');
          final lainnya = data['lainnya'] as List? ?? [];
          if (lainnya.isNotEmpty) _lainnyaItems = parseGroup(lainnya, 'prepaid');
        });
      } catch (_) {}
    }
    // dark mode
    bool? previusstate = (await SharedPreferences.getInstance()).getBool("setIsDark");
    if (previusstate != null) notifire.setIsDark = previusstate;
  }

  void _onCategoryTap(Map<String, dynamic> item) {
    // BPJS selalu pakai layar khusus (daftar produk dari admin panel).
    final brandLowerForBpjs = (item['brand'] ?? '').toString().toLowerCase();
    final categoryLowerForBpjs = (item['category'] ?? '').toString().toLowerCase();
    final nameLowerForBpjs = (item['name'] ?? '').toString().toLowerCase();
    if (brandLowerForBpjs.contains('bpjs') ||
        categoryLowerForBpjs.contains('bpjs') ||
        nameLowerForBpjs.contains('bpjs')) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const BpjsScreen()));
      return;
    }

    // PDAM selalu pakai layar khusus (daftar kota dari admin panel).
    final brandLowerForPdam = (item['brand'] ?? '').toString().toLowerCase();
    final categoryLowerForPdam = (item['category'] ?? '').toString().toLowerCase();
    final nameLowerForPdam = (item['name'] ?? '').toString().toLowerCase();
    if (brandLowerForPdam.contains('pdam') ||
        categoryLowerForPdam.contains('pdam') ||
        nameLowerForPdam.contains('pdam')) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const PdamScreen()));
      return;
    }

    final routeType = resolvePpobRouteType(item);

    if (routeType == 'nfc_toll') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const NfcTollScanScreen()));
    } else if (routeType == 'bank_transfer') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const BankTransferScreen()));
    } else if (routeType == 'postpaid') {
      final brandLower = (item['brand'] ?? '').toString().toLowerCase();
      if (brandLower.contains('pdam')) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const PdamScreen()));
      } else {
        Navigator.push(context, MaterialPageRoute(builder: (_) => PPOBPostpaidScreen(
          brand: item['brand'] ?? '',
          title: item['name'].toString().replaceAll('\n', ' '),
        )));
      }
    } else if (routeType == 'emoney_brand') {
      final cat = (item['category'] as String?)?.trim();
      final filter = (item['productTypeFilter'] ??
              item['product_type_filter'] ??
              item['product_type']) as String?;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PPOBEmoneyBrandScreen(
            category: (cat == null || cat.isEmpty) ? 'E-Money' : cat,
            title: 'Pilih ${item['name'] ?? cat ?? 'E-Money'}',
            productTypeFilter: filter,
          ),
        ),
      );
    } else {
      Navigator.push(context, MaterialPageRoute(builder: (_) => PPOBProductScreen(
        category: item['category'] ?? '',
        title: item['name'].toString().replaceAll('\n', ' '),
        cmd: item['cmd'] ?? 'prepaid',
        inquiryType: item['inquiryType'],
        initialBrand: item['initialBrand'],
        productTypeFilter: item['product_type_filter'] as String?,
      )));
    }
  }

  @override
  Widget build(BuildContext context) {
    notifire = Provider.of<ColorNotifire>(context, listen: true);
    return Scaffold(
      backgroundColor: notifire.getprimerycolor,
      body: Column(
        children: [
          SizedBox(height: height / 20),
          // App Bar
          Padding(
            padding: EdgeInsets.symmetric(horizontal: width / 20),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Icon(Icons.arrow_back, color: notifire.getdarkscolor),
                ),
                const Spacer(),
                Text(
                  'Semua Layanan',
                  style: TextStyle(
                    color: notifire.getdarkscolor,
                    fontSize: height / 40,
                    fontFamily: 'Gilroy Bold',
                  ),
                ),
                const Spacer(),
                SizedBox(width: height / 25),
              ],
            ),
          ),
          SizedBox(height: height / 40),

          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: width / 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_pembelianItems.isNotEmpty) ...[
                    _sectionHeader('Pembelian', Icons.shopping_cart_outlined),
                    SizedBox(height: height / 60),
                    _buildGrid(_pembelianItems),
                    SizedBox(height: height / 30),
                  ],
                  if (_pembayaranItems.isNotEmpty) ...[
                    _sectionHeader('Pembayaran', Icons.receipt_long_outlined),
                    SizedBox(height: height / 60),
                    _buildGrid(_pembayaranItems),
                    SizedBox(height: height / 30),
                  ],
                  if (_keuanganItems.isNotEmpty) ...[
                    _sectionHeader('Keuangan', Icons.account_balance_outlined),
                    SizedBox(height: height / 60),
                    _buildGrid(_keuanganItems),
                    SizedBox(height: height / 30),
                  ],
                  if (_topupGameItems.isNotEmpty) ...[
                    _sectionHeader('TopUp Game', Icons.sports_esports_outlined),
                    SizedBox(height: height / 60),
                    _buildGrid(_topupGameItems),
                    SizedBox(height: height / 30),
                  ],
                  if (_lainnyaItems.isNotEmpty) ...[
                    _sectionHeader('Lainnya', Icons.more_horiz),
                    SizedBox(height: height / 60),
                    _buildGrid(_lainnyaItems),
                    SizedBox(height: height / 30),
                  ],
                  SizedBox(height: height / 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: notifire.getbluecolor, size: height / 35),
        SizedBox(width: width / 40),
        Text(
          title,
          style: TextStyle(
            color: notifire.getdarkscolor,
            fontFamily: 'Gilroy Bold',
            fontSize: height / 42,
          ),
        ),
      ],
    );
  }

  Widget _buildGrid(List<Map<String, dynamic>> items) {
    final allColors = [
      const Color(0xFF1E88E5),
      const Color(0xFF43A047),
      const Color(0xFFFF9800),
      const Color(0xFFE53935),
      const Color(0xFF8E24AA),
      const Color(0xFF00ACC1),
      const Color(0xFFFF7043),
      const Color(0xFF5C6BC0),
      const Color(0xFF26A69A),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: width / 30,
        mainAxisSpacing: height / 40,
        childAspectRatio: 0.7,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final iColor = item['color'] != null
            ? Color(int.parse((item['color'] as String).replaceFirst('#', '0xFF')))
            : allColors[index % allColors.length];
        return _AllServicesMenuButton(
          icon: item['icon'] as IconData,
          name: item['name'] as String,
          iconColor: iColor,
          cardColor: notifire.getdarkwhitecolor,
          textColor: notifire.getdarkscolor,
          textSize: height / 65,
          onTap: () => _onCategoryTap(item),
        );
      },
    );
  }
}

// ── Pressable menu button for Semua Layanan ─────────────────────────────────
class _AllServicesMenuButton extends StatefulWidget {
  final IconData icon;
  final String name;
  final Color iconColor;
  final Color cardColor;
  final Color textColor;
  final double textSize;
  final VoidCallback onTap;

  const _AllServicesMenuButton({
    required this.icon,
    required this.name,
    required this.iconColor,
    required this.cardColor,
    required this.textColor,
    required this.textSize,
    required this.onTap,
  });

  @override
  State<_AllServicesMenuButton> createState() => _AllServicesMenuButtonState();
}

class _AllServicesMenuButtonState extends State<_AllServicesMenuButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
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
              child: Center(
                child: Icon(widget.icon, color: widget.iconColor, size: 26),
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
}
