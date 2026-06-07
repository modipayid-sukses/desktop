import 'package:flutter/material.dart';

class PPOBPostpaidForm extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String categoryHint;
  final String labelText;
  final bool isInquiring;
  final Map<String, dynamic>? inquiryResult;
  final String? inquiryError;
  final VoidCallback onInquiryPressed;
  final Function(dynamic) formatPrice;

  const PPOBPostpaidForm({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.categoryHint,
    required this.labelText,
    required this.isInquiring,
    required this.inquiryResult,
    required this.inquiryError,
    required this.onInquiryPressed,
    required this.formatPrice,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Input ID Pelanggan / Nomor Kontrak
        // Info Hint per kategori (Contoh: BPJS 0001...)
        // Tombol Inquiry (Cek Tagihan)
        // Detail Tagihan (Nama Pelanggan, Nominal, Admin Fee, dll) jika inquiry sukses
      ],
    );
  }
}
