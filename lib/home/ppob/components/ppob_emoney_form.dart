import 'package:flutter/material.dart';

class PPOBEmoneyForm extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final List<dynamic> products;
  final Map<String, dynamic>? selectedProduct;
  final Function(Map<String, dynamic>) onProductSelected;
  final TextEditingController customAmountController;
  final bool isCustomAmountMode;
  final Function(bool) onCustomAmountModeChanged;
  final String Function(dynamic) formatPrice;
  final Widget Function() buildShimmerProducts;

  const PPOBEmoneyForm({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.products,
    required this.selectedProduct,
    required this.onProductSelected,
    required this.customAmountController,
    required this.isCustomAmountMode,
    required this.onCustomAmountModeChanged,
    required this.formatPrice,
    required this.buildShimmerProducts,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Input nomor HP / kartu
        // Pilihan nominal prabayar (e-wallet / e-money)
        // Opsi nominal custom untuk produk dinamis
      ],
    );
  }
}
