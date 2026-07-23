import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

class PurchaseReceipt extends StatelessWidget {
  // Store/Merchant information
  final String? merchantName;
  final String? merchantIcon; // URL or asset path
  final String? merchantAddress;
  final String? merchantPhone;

  // Transaction information
  final String referenceNo;
  final DateTime transactionTime;

  // Transaction items
  final List<Map<String, dynamic>> items; // [{name, quantity, price}, ...]

  // Totals
  final int totalQuantity;
  final double totalPrice;
  final double amountPaid;
  final double? change; // balikan

  // Optional
  final String? category;
  final String? notes;
  final String? paymentMethod;
  final String? thankYouMessage;

  // Game/PPOB specific fields
  final String? customerName; // Username/player name
  final String? region;
  final double? nominal;
  final String? serialNumber; // SN / Provider Ref

  const PurchaseReceipt({
    Key? key,
    this.merchantName,
    this.merchantIcon,
    this.merchantAddress,
    this.merchantPhone,
    required this.referenceNo,
    required this.transactionTime,
    required this.items,
    required this.totalQuantity,
    required this.totalPrice,
    required this.amountPaid,
    this.change,
    this.category,
    this.notes,
    this.paymentMethod,
    this.thankYouMessage,
    this.customerName,
    this.region,
    this.nominal,
    this.serialNumber,
  }) : super(key: key);

  String _formatCurrency(double amount) {
    final formatter = NumberFormat('#,###', 'id_ID');
    return 'Rp ${formatter.format(amount.toInt())}';
  }

  String _formatDate(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) {
      final normalized = value.replaceAll(',', '').trim();
      return double.tryParse(normalized) ?? 0.0;
    }
    return 0.0;
  }

  String _formatTime(DateTime time) {
    return DateFormat('HH:mm:ss').format(time);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // ════════════════════════════════════════════════════════════
          // HEADER - Merchant Information
          // ════════════════════════════════════════════════════════════
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              children: [
                // Logo/Icon
                if (merchantIcon != null)
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: const Color(0xFFF5F5F5),
                    child: merchantIcon!.startsWith('images/')
                        ? Image.asset(merchantIcon!, width: 48, height: 48)
                        : CachedNetworkImage(
                            imageUrl: merchantIcon!,
                            width: 48,
                            height: 48,
                            fadeInDuration: Duration.zero,
                            errorWidget: (_, __, ___) => const Icon(Icons.shopping_bag, size: 32, color: Color(0xFF999999)),
                          ),
                  )
                else
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: const Color(0xFFF5F5F5),
                    child: Icon(Icons.shopping_bag, size: 32, color: const Color(0xFF999999)),
                  ),
                const SizedBox(height: 12),

                // Merchant Name
                if (merchantName != null)
                  Text(
                    merchantName!,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.courierPrime(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF333333),
                    ),
                  ),

                // Merchant Address
                if (merchantAddress != null && merchantAddress!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      merchantAddress!,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.courierPrime(
                        fontSize: 12,
                        color: const Color(0xFF666666),
                      ),
                    ),
                  ),

                // Merchant Phone
                if (merchantPhone != null && merchantPhone!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      merchantPhone!,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.courierPrime(
                        fontSize: 12,
                        color: const Color(0xFF666666),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Dashed divider
          _buildDashedDivider(),

          // ════════════════════════════════════════════════════════════
          // TRANSACTION INFO
          // ════════════════════════════════════════════════════════════
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDate(transactionTime),
                      style: GoogleFonts.courierPrime(
                        fontSize: 13,
                        color: const Color(0xFF757575),
                      ),
                    ),
                    Text(
                      _formatTime(transactionTime),
                      style: GoogleFonts.courierPrime(
                        fontSize: 13,
                        color: const Color(0xFF757575),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'No. Referensi',
                      style: GoogleFonts.courierPrime(
                        fontSize: 12,
                        color: const Color(0xFF999999),
                      ),
                    ),
                    Text(
                      referenceNo,
                      style: GoogleFonts.courierPrime(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF333333),
                      ),
                    ),
                  ],
                ),
                if (serialNumber != null && serialNumber!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'SN',
                        style: GoogleFonts.courierPrime(
                          fontSize: 12,
                          color: const Color(0xFF999999),
                        ),
                      ),
                      Flexible(
                        child: Text(
                          serialNumber!,
                          style: GoogleFonts.courierPrime(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF333333),
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                ],
                if (customerName != null && customerName!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Username',
                        style: GoogleFonts.courierPrime(
                          fontSize: 12,
                          color: const Color(0xFF999999),
                        ),
                      ),
                      Text(
                        customerName!,
                        style: GoogleFonts.courierPrime(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF333333),
                        ),
                      ),
                    ],
                  ),
                ],
                if (region != null && region!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Region',
                        style: GoogleFonts.courierPrime(
                          fontSize: 12,
                          color: const Color(0xFF999999),
                        ),
                      ),
                      Text(
                        region!,
                        style: GoogleFonts.courierPrime(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF333333),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Dashed divider
          _buildDashedDivider(),

          // ════════════════════════════════════════════════════════════
          // ITEMS LIST
          // ════════════════════════════════════════════════════════════
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Column(
              children: items.map((item) {
                final name = item['name'] ?? '-';
                final quantity = item['quantity'] ?? 1;
                final price = item['price'] ?? 0.0;
                final priceNum = _toDouble(price);
                final itemTotal = priceNum * (quantity is int ? quantity : int.tryParse(quantity.toString()) ?? 1);

                return Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: GoogleFonts.courierPrime(
                              fontSize: 13,
                              color: const Color(0xFF333333),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${quantity}x',
                          style: GoogleFonts.courierPrime(
                            fontSize: 12,
                            color: const Color(0xFF757575),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _formatCurrency(itemTotal),
                          textAlign: TextAlign.right,
                          style: GoogleFonts.courierPrime(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF333333),
                          ),
                        ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Divider(
                        height: 1,
                        color: Color(0xFFF0F0F0),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),

          // Dashed divider
          _buildDashedDivider(),

          // ════════════════════════════════════════════════════════════
          // TOTALS
          // ════════════════════════════════════════════════════════════
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Column(
              children: [
                // Total Quantity
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total QTY',
                      style: GoogleFonts.courierPrime(
                        fontSize: 12,
                        color: const Color(0xFF757575),
                      ),
                    ),
                    Text(
                      '$totalQuantity',
                      style: GoogleFonts.courierPrime(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF333333),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Total Price
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total',
                      style: GoogleFonts.courierPrime(
                        fontSize: 12,
                        color: const Color(0xFF757575),
                      ),
                    ),
                    Text(
                      _formatCurrency(totalPrice),
                      style: GoogleFonts.courierPrime(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF333333),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Amount Paid
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Bayar',
                      style: GoogleFonts.courierPrime(
                        fontSize: 12,
                        color: const Color(0xFF757575),
                      ),
                    ),
                    Text(
                      paymentMethod != null ? '$paymentMethod\n${_formatCurrency(amountPaid)}' : _formatCurrency(amountPaid),
                      textAlign: TextAlign.right,
                      style: GoogleFonts.courierPrime(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF333333),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Change (if available)
                if (change != null && change! > 0)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Kembali',
                        style: GoogleFonts.courierPrime(
                          fontSize: 12,
                          color: const Color(0xFF757575),
                        ),
                      ),
                      Text(
                        _formatCurrency(change!),
                        style: GoogleFonts.courierPrime(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF333333),
                        ),
                      ),
                    ],
                  ),

                // Notes
                if (notes != null && notes!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Catatan',
                        style: GoogleFonts.courierPrime(
                          fontSize: 12,
                          color: const Color(0xFF757575),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          notes!,
                          textAlign: TextAlign.right,
                          style: GoogleFonts.courierPrime(
                            fontSize: 12,
                            color: const Color(0xFF757575),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Dashed divider
          _buildDashedDivider(),

          // ════════════════════════════════════════════════════════════
          // FOOTER
          // ════════════════════════════════════════════════════════════
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              children: [
                Text(
                  (thankYouMessage != null && thankYouMessage!.trim().isNotEmpty)
                      ? thankYouMessage!.trim()
                      : 'Terimakasih telah berbelanja',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.courierPrime(
                    fontSize: 13,
                    color: const Color(0xFF333333),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Struk ini sebagai bukti transaksi anda',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.courierPrime(
                    fontSize: 11,
                    color: const Color(0xFF999999),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashedDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final dashWidth = 6.0;
          final dashSpace = 4.0;
          final dashCount = (constraints.maxWidth / (dashWidth + dashSpace)).floor();
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(dashCount, (_) {
              return SizedBox(
                width: dashWidth + dashSpace,
                child: Center(
                  child: Container(
                    width: dashWidth,
                    height: 1,
                    color: const Color(0xFFE0E0E0),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}
