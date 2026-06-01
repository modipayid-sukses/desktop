import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'ppob_menu_route.dart';
import 'ppob_product_screen.dart';
import 'ppob_postpaid_screen.dart';

class _PromoOutlinePainter extends CustomPainter {
  final double progress;
  _PromoOutlinePainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    const r = 14.0;
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(2, 2, size.width - 4, size.height - 4),
        const Radius.circular(r),
      ));

    final metrics = path.computeMetrics().first;
    final total = metrics.length;
    const segFrac = 0.55;
    final segLen = total * segFrac;
    final start = (progress * total) % total;
    final end = start + segLen;

    final Path seg;
    if (end <= total) {
      seg = metrics.extractPath(start, end);
    } else {
      seg = Path()
        ..addPath(metrics.extractPath(start, total), Offset.zero)
        ..addPath(metrics.extractPath(0, end - total), Offset.zero);
    }

    canvas.drawPath(
      seg,
      Paint()
        ..color = const Color(0xFFE53935).withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawPath(
      seg,
      Paint()
        ..color = const Color(0xFFE53935)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_PromoOutlinePainter old) => old.progress != progress;
}

class _PromoOutlineCard extends StatefulWidget {
  final Widget child;
  const _PromoOutlineCard({required this.child});

  @override
  State<_PromoOutlineCard> createState() => _PromoOutlineCardState();
}

class _PromoOutlineCardState extends State<_PromoOutlineCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) => CustomPaint(
        foregroundPainter: _PromoOutlinePainter(_ctrl.value),
        child: child,
      ),
      child: widget.child,
    );
  }
}

class _PromoBadge extends StatelessWidget {
  const _PromoBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFF6B6B),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(14),
          bottomLeft: Radius.circular(8),
        ),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      child: const Text(
        'PROMO',
        style: TextStyle(
          fontFamily: 'Gilroy Bold',
          fontSize: 10,
          color: Colors.white,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

/// Halaman daftar game (TopUp Game) yang menampilkan brand-brand game seperti
/// Free Fire, Mobile Legend, FC Mobile, HoK, Roblox, Magic Chess, dst.
///
/// Items diambil dari grup `topup_game` yang sudah di-normalize via
/// [normalizePpobMenuItem]. Tap salah satu item akan membuka
/// [PPOBProductScreen] dengan brand/kategori game yang sesuai.
class PPOBTopUpGameListScreen extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final String title;

  const PPOBTopUpGameListScreen({
    super.key,
    required this.items,
    this.title = 'TopUp Game',
  });

  void _onItemTap(BuildContext context, Map<String, dynamic> item) {
    final routeType = resolvePpobRouteType(item);
    if (routeType == 'postpaid') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PPOBPostpaidScreen(
            brand: item['brand'],
            title: (item['name'] ?? '').toString().replaceAll('\n', ' '),
          ),
        ),
      );
    } else {
      final category = (item['category'] as String?)?.trim() ?? '';
      final cmd = (item['cmd'] as String?)?.trim() ?? 'prepaid';
      final name = (item['name'] ?? '').toString().replaceAll('\n', ' ');
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PPOBProductScreen(
            category: category.isNotEmpty ? category : name,
            title: name,
            cmd: cmd,
            inquiryType: item['inquiryType'] as String?,
            initialBrand:
                (item['initialBrand'] ?? item['brand']) as String?,
            productTypeFilter: item['product_type_filter'] as String?,
            productNameFilter: item['searchKeyword'] as String?,
            configInquirySku: (item['inquirySku'] as String?)?.trim(),
            configInquiryProvider: (item['gameCode'] as String?)?.trim(),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const headerBlue = Color(0xFF3F6FB4);
    const pageBg = Color(0xFFFAFAFA);

    return Scaffold(
      backgroundColor: pageBg,
      body: Column(
        children: [
          // Header biru
          Container(
            color: headerBlue,
            padding: EdgeInsets.fromLTRB(
              12,
              MediaQuery.of(context).padding.top + 8,
              12,
              16,
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                Expanded(
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'Gilroy Bold',
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? const Center(
                    child: Text(
                      'Belum ada game tersedia',
                      style: TextStyle(
                        fontFamily: 'Gilroy Medium',
                        color: Colors.black54,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final item = items[i];
                      final name =
                          (item['name'] ?? '').toString().replaceAll('\n', ' ');
                      final iconUrl = item['iconUrl'] as String?;
                      final iconData = item['icon'];
                      final isPromo = (item['isPromo'] as bool?) ?? false;
                      final card = Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        elevation: isPromo ? 0 : 1,
                        shadowColor: Colors.black.withValues(alpha: 0.06),
                        child: Stack(
                          children: [
                            InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () => _onItemTap(context, item),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 12),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F4F9),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      alignment: Alignment.center,
                                      child: iconUrl != null && iconUrl.isNotEmpty
                                          ? ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              child: CachedNetworkImage(
                                                imageUrl: iconUrl,
                                                width: 36,
                                                height: 36,
                                                fit: BoxFit.contain,
                                                fadeInDuration: Duration.zero,
                                                errorWidget: (_, __, ___) => Icon(
                                                  iconData is IconData
                                                      ? iconData
                                                      : Icons.sports_esports,
                                                  color: headerBlue,
                                                  size: 24,
                                                ),
                                              ),
                                            )
                                          : Icon(
                                              iconData is IconData
                                                  ? iconData
                                                  : Icons.sports_esports,
                                              color: headerBlue,
                                              size: 24,
                                            ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Text(
                                        name,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontFamily: 'Gilroy Bold',
                                          fontSize: 14,
                                          color: Color(0xFF1A1A1A),
                                        ),
                                      ),
                                    ),
                                    const Icon(
                                      Icons.chevron_right,
                                      color: Color(0xFF8A99A8),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (isPromo)
                              const Positioned(
                                top: 0,
                                right: 0,
                                child: _PromoBadge(),
                              ),
                          ],
                        ),
                      );
                      return isPromo ? _PromoOutlineCard(child: card) : card;
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
