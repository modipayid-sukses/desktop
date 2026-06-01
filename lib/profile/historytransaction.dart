import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:gobank/services/api_service.dart';
import 'package:gobank/home/transaction_detail.dart';
import 'package:gobank/utils/media.dart';
import 'package:gobank/utils/string.dart';
import 'package:gobank/utils/transaction_helpers.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';

import '../utils/colornotifire.dart';

class HistoryTransaction extends StatefulWidget {
  const HistoryTransaction({Key? key}) : super(key: key);

  @override
  State<HistoryTransaction> createState() => _HistoryTransactionState();
}

class _HistoryTransactionState extends State<HistoryTransaction> {
  late ColorNotifire notifire;
  Map<String, List<Map<String, dynamic>>> _grouped = {};
  bool _isLoading = true;

  getdarkmodepreviousstate() async {
    final prefs = await SharedPreferences.getInstance();
    bool? previusstate = prefs.getBool("setIsDark");
    if (previusstate == null) {
      notifire.setIsDark = false;
    } else {
      notifire.setIsDark = previusstate;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    try {
      final results = await Future.wait([
        ApiService.getTransactions(),
        ApiService.getRecentTopups(),
      ]);

      final txResponse = results[0] as Map<String, dynamic>;
      final topups = results[1] as List<Map<String, dynamic>>;
      final txList = List<Map<String, dynamic>>.from(txResponse['data'] ?? []);

      // Merge topups with transactions (avoid duplicates)
      final txOrderIds = txList.map((t) => t['order_id']?.toString() ?? '').toSet();
      final topupItems = topups
          .where((t) {
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
              case 'expired':
                statusLabel = 'Kedaluwarsa';
                break;
              default:
                statusLabel = '';
            }
            return <String, dynamic>{
              'name': 'Top Up via QRIS',
              'amount': t['amount']?.toString() ?? '0',
              'type': 'income',
              'category': 'topup',
              'order_id': t['reference_id'] ?? '',
              'created_at': t['created_at'],
              'is_pending': status == 'pending',
              'is_expired': status == 'expired',
              'status_label': statusLabel,
            };
          })
          .toList();

      final completedTx = txList.map((t) {
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
        return <String, dynamic>{
          ...t,
          'is_pending': txStatus == 'pending',
          'is_expired': false,
          'status_label': txStatusLabel,
        };
      }).toList();

      final allItems = [...topupItems, ...completedTx];
      allItems.sort((a, b) {
        final aDate = DateTime.tryParse(a['created_at']?.toString() ?? '') ?? DateTime(2000);
        final bDate = DateTime.tryParse(b['created_at']?.toString() ?? '') ?? DateTime(2000);
        return bDate.compareTo(aDate);
      });

      // Group by date
      final grouped = <String, List<Map<String, dynamic>>>{};
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));

      for (final tx in allItems) {
        final date = DateTime.tryParse(tx['created_at'] ?? '');
        if (date == null) continue;
        final d = DateTime(date.year, date.month, date.day);
        String label;
        if (d == today) {
          label = 'Hari ini';
        } else if (d == yesterday) {
          label = 'Kemarin';
        } else {
          label = DateFormat('d MMMM yyyy', 'id_ID').format(d);
        }
        grouped.putIfAbsent(label, () => []);
        grouped[label]!.add(tx);
      }

      if (mounted) {
        setState(() {
          _grouped = grouped;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatAmount(double amount) {
    final formatter = NumberFormat('#,###', 'id_ID');
    return 'Rp ${formatter.format(amount.toInt())}';
  }

  double _effectiveTotal(Map<String, dynamic> tx) => effectiveTransactionTotal(tx);

  @override
  Widget build(BuildContext context) {
    notifire = Provider.of<ColorNotifire>(context, listen: true);
    return Scaffold(
      backgroundColor: notifire.getprimerycolor,
      body: Stack(
        children: [
          SizedBox(
            height: height,
            width: width,
            child: Image.asset("images/background.png", fit: BoxFit.cover),
          ),
          SafeArea(
            child: Column(
              children: [
                // App bar
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: width / 20),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Icon(Icons.arrow_back, color: notifire.getdarkscolor),
                      ),
                      const Spacer(),
                      SizedBox(width: width / 30),
                      Text(
                        CustomStrings.recenttransaction,
                        style: TextStyle(
                            color: notifire.getdarkscolor,
                            fontFamily: 'Gilroy Bold',
                            fontSize: height / 40),
                      ),
                      const Spacer(),
                      const SizedBox(width: 24),
                    ],
                  ),
                ),
                SizedBox(height: height / 50),
                // Content
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
                                  height: 56,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                              )),

                            ),
                          ),
                        )
                      : _grouped.isEmpty
                          ? Center(
                              child: Text(
                                'Belum ada transaksi',
                                style: TextStyle(
                                    fontFamily: 'Gilroy Medium',
                                    color: notifire.getdarkgreycolor),
                              ),
                            )
                          : ListView(
                              padding: EdgeInsets.zero,
                              children: _grouped.entries.map((entry) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: width / 20, vertical: height / 80),
                                      child: Text(
                                        entry.key,
                                        style: TextStyle(
                                            color: notifire.getdarkscolor,
                                            fontFamily: 'Gilroy Bold',
                                            fontSize: height / 45),
                                      ),
                                    ),
                                    ...entry.value.map((tx) {
                                      final isPending = tx['is_pending'] == true;
                                      final isExpired = tx['is_expired'] == true;
                                      final statusLabel = tx['status_label']?.toString() ?? '';
                                      final isIncome = tx['type'] == 'income';
                                      // Total yang ditampilkan = nominal user + admin panel.
                                      // Kalau note berisi field nominal & admin yang valid,
                                      // pakai itu (dipakai untuk e-wallet bebas nominal &
                                      // produk yang admin-nya beda dari `tx['amount']`).
                                      final amount = _effectiveTotal(tx);
                                      final dateStr = tx['created_at'] != null
                                          ? DateFormat('HH:mm')
                                              .format(DateTime.parse(tx['created_at']))
                                          : '';
                                      final category = tx['category'] ?? '';
                                      final statusColor = isExpired
                                          ? Colors.grey
                                          : (isPending ? Colors.orange : null);
                                      return GestureDetector(
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => TransactionDetail(data: tx),
                                            ),
                                          );
                                        },
                                        child: Column(
                                        children: [
                                          Padding(
                                            padding: EdgeInsets.symmetric(
                                                horizontal: width / 20),
                                            child: Row(
                                              children: [
                                                Container(
                                                  height: height / 13,
                                                  width: width / 6.5,
                                                  decoration: BoxDecoration(
                                                    color: (statusColor
                                                            ?? _colorForCategory(category, isIncome))
                                                        .withOpacity(0.1),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: Icon(
                                                    isPending
                                                        ? Icons.hourglass_top_rounded
                                                        : isExpired
                                                            ? Icons.timer_off_rounded
                                                            : _iconForCategory(category, isIncome),
                                                    color: statusColor
                                                        ?? _colorForCategory(category, isIncome),
                                                    size: height / 30,
                                                  ),
                                                ),
                                                SizedBox(width: width / 35),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        tx['name'] ?? '',
                                                        style: TextStyle(
                                                            color: notifire.getdarkscolor,
                                                            fontSize: height / 48,
                                                            fontFamily: 'Gilroy Bold'),
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                      SizedBox(height: height / 150),
                                                      Row(
                                                        children: [
                                                          Flexible(
                                                            child: Text(
                                                              statusLabel.isNotEmpty
                                                                  ? '$statusLabel • $dateStr'
                                                                  : '$category • $dateStr',
                                                              style: TextStyle(
                                                                  color: statusColor ?? Colors.grey,
                                                                  fontSize: height / 55,
                                                                  fontFamily: 'Gilroy Medium'),
                                                              overflow: TextOverflow.ellipsis,
                                                            ),
                                                          ),
                                                          if ((tx['payment_source'] ?? 'saldo') == 'limit') ...[
                                                            const SizedBox(width: 6),
                                                            Container(
                                                              padding: const EdgeInsets.symmetric(
                                                                horizontal: 6, vertical: 1,
                                                              ),
                                                              decoration: BoxDecoration(
                                                                color: const Color(0xFFFFF3E0),
                                                                borderRadius: BorderRadius.circular(4),
                                                                border: Border.all(
                                                                  color: const Color(0xFFFFB74D),
                                                                  width: 0.8,
                                                                ),
                                                              ),
                                                              child: Text(
                                                                'LIMIT',
                                                                style: TextStyle(
                                                                  color: const Color(0xFFEF6C00),
                                                                  fontSize: height / 65,
                                                                  fontFamily: 'Gilroy Bold',
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                Column(
                                                  crossAxisAlignment: CrossAxisAlignment.end,
                                                  children: [
                                                    Text(
                                                      (isPending || isExpired)
                                                          ? _formatAmount(amount)
                                                          : '${isIncome ? '+' : '-'}${_formatAmount(amount)}',
                                                      style: TextStyle(
                                                          color: statusColor
                                                              ?? (isIncome ? Colors.green : Colors.red),
                                                          fontSize: height / 45,
                                                          fontFamily: 'Gilroy Bold'),
                                                    ),
                                                    if (statusLabel.isNotEmpty)
                                                      Container(
                                                        margin: const EdgeInsets.only(top: 4),
                                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                                        decoration: BoxDecoration(
                                                          color: (statusColor ?? Colors.grey).withOpacity(0.1),
                                                          borderRadius: BorderRadius.circular(4),
                                                        ),
                                                        child: Text(
                                                          statusLabel,
                                                          style: TextStyle(
                                                              color: statusColor ?? Colors.grey,
                                                              fontSize: height / 60,
                                                              fontFamily: 'Gilroy Bold'),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          Padding(
                                            padding: EdgeInsets.symmetric(
                                                horizontal: width / 20),
                                            child: Divider(
                                              color: Colors.grey.withOpacity(0.3),
                                              thickness: 1,
                                            ),
                                          ),
                                        ],
                                      ),
                                      );
                                    }),
                                  ],
                                );
                              }).toList(),
                            ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconForCategory(String category, bool isIncome) {
    final lower = category.toLowerCase();
    switch (lower) {
      case 'topup':
        return Icons.account_balance_wallet;
      case 'transfer':
        return isIncome ? Icons.call_received : Icons.call_made;
      case 'pulsa':
        return Icons.phone_android;
      case 'data':
        return Icons.wifi;
      case 'pln':
        return Icons.flash_on;
      case 'e-money':
        return Icons.account_balance_wallet;
      case 'games':
        return Icons.sports_esports;
      case 'pascabayar':
        return Icons.receipt_long;
      case 'tv':
        return Icons.tv;
      case 'voucher':
        return Icons.card_giftcard;
      case 'paket sms & telpon':
        return Icons.message;
      case 'withdraw':
        return Icons.money_off;
      default:
        return isIncome ? Icons.arrow_downward : Icons.arrow_upward;
    }
  }

  Color _colorForCategory(String category, bool isIncome) {
    final lower = category.toLowerCase();
    switch (lower) {
      case 'topup':
        return const Color(0xff1565C0);
      case 'transfer':
        return isIncome ? Colors.green : Colors.orange;
      case 'pulsa':
        return const Color(0xffE91E63);
      case 'data':
        return const Color(0xff00BCD4);
      case 'pln':
        return const Color(0xffFF9800);
      case 'e-money':
        return const Color(0xff4CAF50);
      case 'games':
        return const Color(0xff9C27B0);
      case 'pascabayar':
        return const Color(0xff795548);
      case 'tv':
        return const Color(0xff607D8B);
      case 'voucher':
        return const Color(0xffFF5722);
      case 'paket sms & telpon':
        return const Color(0xff3F51B5);
      case 'withdraw':
        return Colors.red;
      default:
        return isIncome ? Colors.green : Colors.red;
    }
  }
}
