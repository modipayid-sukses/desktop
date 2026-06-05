import 'dart:async';
import 'package:flutter/material.dart';
import 'package:modipay/home/ppob/ppob_product_screen.dart';
import 'package:modipay/services/api_service.dart';
import 'package:modipay/utils/colornotifire.dart';
import 'package:modipay/utils/media.dart';
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

  @override
  void initState() {
    super.initState();
    _loadDarkMode();
    _loadPromos();
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
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PPOBProductScreen(
              category: category,
              title: brand.isNotEmpty ? brand : category,
              cmd: p['cmd'] ?? 'prepaid',
              initialBrand: brand.isNotEmpty ? brand : null,
            ),
          ),
        );
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
                          style: const TextStyle(
                            color: Color(0xFF111827),
                            fontSize: 14,
                            fontFamily: 'Gilroy Bold',
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$brand • $category',
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
}
