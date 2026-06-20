import 'package:cached_network_image/cached_network_image.dart';
import 'package:modipay/widgets/desktop_title_wrapper.dart';
import '../../utils/responsive.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/api_service.dart';
import '../../utils/colornotifire.dart';
import '../../utils/media.dart';
import 'ppob_product_screen.dart';

class PPOBEmoneyBrandScreen extends StatefulWidget {
  /// Kategori PPOB yang akan diquery brand-nya. Default `E-Wallet`.
  final String category;

  /// Judul AppBar. Default mengikuti kategori.
  final String? title;

  /// product_type filter opsional (mis. `e_wallet`).
  final String? productTypeFilter;

  const PPOBEmoneyBrandScreen({
    super.key,
    this.category = 'E-Wallet',
    this.title,
    this.productTypeFilter,
  });

  @override
  State<PPOBEmoneyBrandScreen> createState() => _PPOBEmoneyBrandScreenState();
}

class _PPOBEmoneyBrandScreenState extends State<PPOBEmoneyBrandScreen> {
  late ColorNotifire notifire;
  List<String> _brands = [];
  bool _isLoading = true;

  // Public base URL for R2 object access.
  // If you use a custom domain, replace this value.
    static const String _r2PublicBaseUrl =
      'https://pub-804a2df5e9c84f6f91f4a9b383f8ffe6.r2.dev/product_image';

  static const Map<String, _BrandStyle> _brandStyles = {
    'GOPAY': _BrandStyle(
      Icons.account_balance_wallet,
      Color(0xFF00AED6),
      objectKey: 'GOPAY.webp',
    ),
    'GO PAY': _BrandStyle(
      Icons.account_balance_wallet,
      Color(0xFF00AED6),
      objectKey: 'GOPAY.webp',
    ),
    'DANA': _BrandStyle(
      Icons.chat_bubble,
      Color(0xFF108EE9),
      objectKey: 'DANA.webp',
    ),
    'OVO': _BrandStyle(Icons.circle_outlined, Color(0xFF4C3494)),
    'LINKAJA': _BrandStyle(
      Icons.link,
      Color(0xFFE42313),
      objectKey: 'LINKAJA.webp',
    ),
    'SHOPEE PAY': _BrandStyle(
      Icons.shopping_bag,
      Color(0xFFEE4D2D),
      objectKey: 'SHOPEEPAY.webp',
    ),
    'SHOPEEPAY': _BrandStyle(
      Icons.shopping_bag,
      Color(0xFFEE4D2D),
      objectKey: 'SHOPEEPAY.webp',
    ),
    'I.SAKU': _BrandStyle(
      Icons.info_outline,
      Color(0xFF00B0F0),
      objectKey: 'ISAKU.webp',
    ),
    'ISAKU': _BrandStyle(
      Icons.info_outline,
      Color(0xFF00B0F0),
      objectKey: 'ISAKU.webp',
    ),
    'SAKUKU': _BrandStyle(Icons.attach_money, Color(0xFF0066B3)),
    'DOKU': _BrandStyle(
      Icons.payments,
      Color(0xFFE74C3C),
      objectKey: 'DOKU.webp',
    ),
    'ASTRAPAY': _BrandStyle(Icons.account_balance, Color(0xFFE67E22)),
    'GRAB': _BrandStyle(Icons.two_wheeler, Color(0xFF00B14F)),
    'GRAB DRIVER': _BrandStyle(Icons.two_wheeler, Color(0xFF00B14F)),
    'MAXIM DRIVER': _BrandStyle(Icons.two_wheeler, Color(0xFFFF6B00)),
    'MAXIM': _BrandStyle(Icons.two_wheeler, Color(0xFFFF6B00)),
  };

  static const _BrandStyle _defaultStyle =
      _BrandStyle(Icons.account_balance_wallet, Color(0xFF4CAF50));

  @override
  void initState() {
    super.initState();
    _loadDarkMode();
    _loadBrands();
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

  Future<void> _loadBrands() async {
    try {
      final brands = await ApiService.getPpobBrands(
        cmd: 'prepaid',
        category: widget.category,
        productTypeFilter: widget.productTypeFilter,
      );
      if (mounted) {
        setState(() {
          _brands = brands.map((b) => b.toString()).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  _BrandStyle _styleFor(String brand) {
    final upper = brand.toUpperCase();

    if (upper.contains('GOPAY') || upper.contains('GO PAY')) {
      return _brandStyles['GOPAY']!;
    }
    if (upper.contains('DANA')) {
      return _brandStyles['DANA']!;
    }
    if (upper.contains('OVO')) {
      return _brandStyles['OVO']!;
    }
    if (upper.contains('LINKAJA') || upper.contains('LINK AJA')) {
      return _brandStyles['LINKAJA']!;
    }
    if (upper.contains('SHOPEE')) {
      return _brandStyles['SHOPEEPAY']!;
    }
    if (upper.contains('I.SAKU') || upper.contains('ISAKU')) {
      return _brandStyles['ISAKU']!;
    }
    if (upper.contains('SAKUKU')) {
      return _brandStyles['SAKUKU']!;
    }
    if (upper.contains('DOKU')) {
      return _brandStyles['DOKU']!;
    }

    return _brandStyles[upper] ?? _defaultStyle;
  }

  String _buildLogoUrl(String objectKey) {
    return '$_r2PublicBaseUrl/$objectKey';
  }

  void _onBrandTap(String brand) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PPOBProductScreen(
          category: widget.category,
          title: brand,
          cmd: 'prepaid',
          inquiryType: 'emoney',
          initialBrand: brand,
          productTypeFilter: widget.productTypeFilter,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    notifire = Provider.of<ColorNotifire>(context, listen: true);
    final accent = notifire.getbluecolor;
    final textPrimary = notifire.getdarkscolor;
    final textSecondary = notifire.getdarkgreycolor;

    return Scaffold(
      backgroundColor: notifire.getprimerycolor,
      appBar: isDesktopPopup(context) ? null : AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.transparent,
        iconTheme: IconThemeData(color: textPrimary),
        title: DesktopTitleWrapper(child: Text(
          widget.title ?? 'Pilih ${widget.category}',
          style: TextStyle(
            color: textPrimary,
            fontFamily: 'Gilroy Bold',
            fontSize: 18,
          ),
        ))
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: notifire.gettabwhitecolor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: textSecondary.withValues(alpha: 0.14)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          height: 38,
                          width: 38,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.account_balance_wallet_rounded,
                            color: accent,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Layanan ${widget.category}',
                                style: TextStyle(
                                  color: textPrimary,
                                  fontFamily: 'Gilroy Bold',
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Pilih brand untuk lanjut ke input nomor dan nominal.',
                                style: TextStyle(
                                  color: textSecondary,
                                  fontFamily: 'Gilroy Medium',
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Text(
                        'Daftar Brand',
                        style: TextStyle(
                          color: textPrimary,
                          fontFamily: 'Gilroy Bold',
                          fontSize: 15,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${_brands.length} tersedia',
                        style: TextStyle(
                          color: textSecondary,
                          fontFamily: 'Gilroy Medium',
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: _brands.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.account_balance_wallet_outlined,
                                size: height / 10,
                                color: textSecondary.withValues(alpha: 0.3),
                              ),
                              SizedBox(height: height / 50),
                              Text(
                                'Belum ada layanan ${widget.category}',
                                style: TextStyle(
                                  color: textSecondary,
                                  fontFamily: 'Gilroy Medium',
                                  fontSize: height / 50,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                          physics: const ClampingScrollPhysics(),
                          itemCount: _brands.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (_, index) => _buildBrandRow(_brands[index]),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildBrandRow(String brand) {
    final style = _styleFor(brand);
    return InkWell(
      onTap: () => _onBrandTap(brand),
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        decoration: BoxDecoration(
          color: notifire.gettabwhitecolor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: notifire.getdarkgreycolor.withValues(alpha: 0.14)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: style.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: style.objectKey == null
                    ? Icon(
                        style.icon,
                        color: style.color,
                        size: 20,
                      )
                    : Padding(
                        padding: const EdgeInsets.all(4),
                        child: CachedNetworkImage(
                          imageUrl: _buildLogoUrl(style.objectKey!),
                          fit: BoxFit.contain,
                          fadeInDuration: Duration.zero,
                          errorWidget: (_, __, ___) => Icon(
                            style.icon,
                            color: style.color,
                            size: 20,
                          ),
                        ),
                      ),
              ),
              SizedBox(width: width / 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      brand,
                      style: TextStyle(
                        color: notifire.getdarkscolor,
                        fontFamily: 'Gilroy Bold',
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Lanjut isi nomor dan pilih nominal',
                      style: TextStyle(
                        color: notifire.getdarkgreycolor,
                        fontFamily: 'Gilroy Medium',
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: notifire.getdarkgreycolor.withValues(alpha: 0.45),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrandStyle {
  final IconData icon;
  final Color color;
  final String? objectKey;
  const _BrandStyle(this.icon, this.color, {this.objectKey});
}
