import 'package:flutter/material.dart';

class PPOBPlnForm extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final int plnTabIndex;
  final Function(int) onPlnTabChanged;
  final List<dynamic> products;
  final Map<String, dynamic>? selectedProduct;
  final Function(Map<String, dynamic>) onProductSelected;
  final Map<String, dynamic>? inquiryResult;
  final bool isInquiring;
  final VoidCallback onInquiryPressed;
  final String Function(dynamic) formatPrice;
  final Widget Function() buildShimmerProducts;

  const PPOBPlnForm({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.plnTabIndex,
    required this.onPlnTabChanged,
    required this.products,
    required this.selectedProduct,
    required this.onProductSelected,
    required this.inquiryResult,
    required this.isInquiring,
    required this.onInquiryPressed,
    required this.formatPrice,
    required this.buildShimmerProducts,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tab PLN Prabayar vs Pascabayar
        // Input ID Pelanggan PLN
        // Panel Cek Tagihan untuk Pasca
        // Grid Nominal Token untuk Prabayar
      ],
    );
  }
}
