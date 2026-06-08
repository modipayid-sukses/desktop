import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class PPOBCellularForm extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final List<dynamic> brands;
  final String? selectedBrand;
  final List<dynamic> products;
  final Map<String, dynamic>? selectedProduct;
  final bool showBrandTabs;
  final bool isPulsaPrefixDetected;
  final bool isInject;
  final Function(String) onBrandSelected;
  final Function(Map<String, dynamic>) onProductSelected;
  final VoidCallback onContactPickerPressed;
  final int pulsaTabIndex;
  final Function(int) onPulsaTabChanged;
  final String? Function(String) validator;
  final String Function(dynamic) formatPrice;
  final String Function(Map<String, dynamic>) productDescription;
  final Widget Function() buildShimmerProducts;
  final bool isLoadingProducts;
  final bool isPulsaTransferTab;
  final bool hasCustomerInput;
  final double Function(Map<String, dynamic>) originalPrice;
  final double Function(Map<String, dynamic>) promoPrice;
  final bool Function(Map<String, dynamic>) isPromoProduct;
  final int? Function(Map<String, dynamic>) extractRewardCoins;
  final String Function(Map<String, dynamic>) promoRemainingLabel;
  final String Function(Map<String, dynamic>) pulsaProviderLogoAsset;
  final Color accentColor;
  final Color textPrimary;
  final Color textSecondary;

  const PPOBCellularForm({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.brands,
    required this.selectedBrand,
    required this.products,
    required this.selectedProduct,
    required this.showBrandTabs,
    required this.isPulsaPrefixDetected,
    required this.isInject,
    required this.onBrandSelected,
    required this.onProductSelected,
    required this.onContactPickerPressed,
    required this.pulsaTabIndex,
    required this.onPulsaTabChanged,
    required this.validator,
    required this.formatPrice,
    required this.productDescription,
    required this.buildShimmerProducts,
    required this.isLoadingProducts,
    required this.isPulsaTransferTab,
    required this.hasCustomerInput,
    required this.originalPrice,
    required this.promoPrice,
    required this.isPromoProduct,
    required this.extractRewardCoins,
    required this.promoRemainingLabel,
    required this.pulsaProviderLogoAsset,
    required this.accentColor,
    required this.textPrimary,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    final shouldShowProducts = isPulsaPrefixDetected || isInject;

    return Column(
      children: [
        if (showBrandTabs && brands.isNotEmpty) ...[
          SizedBox(
            height: 42,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: brands.length,
              itemBuilder: (_, i) {
                final brand = brands[i].toString();
                final selected = selectedBrand == brand;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    selected: selected,
                    side: BorderSide.none,
                    selectedColor: accentColor.withOpacity(0.15),
                    backgroundColor: Colors.white,
                    labelStyle: TextStyle(
                      color: selected ? accentColor : textPrimary,
                      fontFamily: selected ? 'Gilroy Bold' : 'Gilroy Medium',
                    ),
                    label: Text(brand),
                    onSelected: (_) => onBrandSelected(brand),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
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
                              child: Lottie.asset('assets/lottie/empty_cart.json'),
                            ),
                          ],
                        )
                      : Text(
                          hasCustomerInput
                              ? 'Prefix nomor tidak terdeteksi'
                              : 'Harap masukan no.hp terlebih dahulu',
                          style: TextStyle(
                            color: textSecondary.withOpacity(0.6),
                            fontFamily: 'Gilroy Medium',
                            fontSize: 18,
                          ),
                        ),
                )
              : isLoadingProducts
                  ? buildShimmerProducts()
                  : products.isEmpty
                      ? Center(
                          child: Text(
                            'Belum ada produk tersedia',
                            style: TextStyle(
                              color: textSecondary,
                              fontFamily: 'Gilroy Medium',
                            ),
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          physics: const ClampingScrollPhysics(),
                          itemCount: products.length,
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            mainAxisExtent: 148,
                          ),
                          itemBuilder: (_, i) {
                            final p = Map<String, dynamic>.from(products[i]);
                            final isPromo = p['_is_promo_pre'] ?? isPromoProduct(p);
                            final origPrice = p['_original_price_pre'] ?? originalPrice(p);
                            final promPrice = p['_promo_price_pre'] ?? promoPrice(p);
                            final rewardCoins = p['_reward_coins_pre'] ?? extractRewardCoins(p);
                            final providerLogoAsset = p['_logo_asset_pre'] ?? pulsaProviderLogoAsset(p);
                            final promoLabel = p['_promo_label_pre'] ?? promoRemainingLabel(p);

                            return Material(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              elevation: 16,
                              shadowColor: Colors.black.withOpacity(0.08),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () => onProductSelected(p),
                                child: Padding(
                                  padding: const EdgeInsets.all(10),
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
                                                    formatPrice(origPrice),
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
                                                  formatPrice(isPromo ? promPrice : p['price']),
                                                  style: TextStyle(
                                                    color: isPromo
                                                        ? const Color(0xFFE53935)
                                                        : accentColor,
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
                                                    promoLabel,
                                                    style: const TextStyle(
                                                      color: Color(0xFFEF6C00),
                                                      fontFamily: 'Gilroy Medium',
                                                      fontSize: 10,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
        ),
      ],
    );
  }
}
