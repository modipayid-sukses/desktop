import 'package:flutter/material.dart';
import 'package:modipay/widgets/desktop_title_wrapper.dart';

import 'package:modipay/home/transaction_detail.dart';
import 'package:modipay/services/api_service.dart';
import 'package:modipay/utils/transaction_helpers.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/colornotifire.dart';
import '../utils/media.dart';
import 'package:shimmer/shimmer.dart';

class Analytics extends StatefulWidget {
  const Analytics({Key? key}) : super(key: key);

  @override
  State<Analytics> createState() => _AnalyticsState();
}

class _AnalyticsState extends State<Analytics> {
  late ColorNotifire notifire;

  getdarkmodepreviousstate() async {
    final prefs = await SharedPreferences.getInstance();
    bool? previusstate = prefs.getBool("setIsDark");
    if (previusstate == null) {
      notifire.setIsDark = false;
    } else {
      notifire.setIsDark = previusstate;
    }
  }

  List<Map<String, dynamic>> _transactions = [];
  List<Map<String, dynamic>> _topups = [];
  bool _loadingTransactions = true;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
    _loadTopups();
  }

  Future<void> _loadTransactions() async {
    try {
      final response = await ApiService.getTransactions();
      if (response.containsKey('data') && mounted) {
        setState(() {
          _transactions = List<Map<String, dynamic>>.from(response['data']);
          _loadingTransactions = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingTransactions = false);
    }
  }

  Future<void> _loadTopups() async {
    try {
      final topups = await ApiService.getRecentTopups();
      if (mounted) setState(() => _topups = topups);
    } catch (_) {}
  }

  List<Map<String, dynamic>> get _activityItems {
    final txOrderIds = _transactions.map((t) => t['order_id']?.toString() ?? '').toSet();
    final topupItems = _topups.where((t) {
      if (t['status'] == 'completed') return !txOrderIds.contains(t['reference_id']?.toString() ?? '');
      return true;
    }).map((t) {
      final status = t['status'] ?? 'pending';
      return {
        'name': 'Top Up via QRIS',
        'amount': t['amount']?.toString() ?? '0',
        'type': 'income',
        'category': 'topup',
        'order_id': t['reference_id'] ?? '',
        'created_at': t['created_at'],
        'is_pending': status == 'pending',
        'status_label': status == 'pending' ? 'Menunggu' : (status == 'expired' ? 'Kedaluwarsa' : ''),
        'status': status,
      };
    }).toList();
    final completed = _transactions.map((t) {
      final txStatus = t['status']?.toString() ?? 'completed';
      return {
        ...t,
        'is_pending': txStatus == 'pending',
        'status_label': txStatus == 'pending' ? 'Menunggu' : (txStatus == 'failed' ? 'Gagal' : ''),
      };
    }).toList();
    return [...topupItems, ...completed];
  }

  IconData _iconForCategory(String category, bool isIncome) {
    switch (category.toLowerCase()) {
      case 'topup': return Icons.account_balance_wallet;
      case 'transfer': return isIncome ? Icons.call_received : Icons.call_made;
      case 'pulsa': return Icons.phone_android;
      case 'data': return Icons.wifi;
      case 'pln': return Icons.flash_on;
      case 'e-money': return Icons.account_balance_wallet;
      case 'games': return Icons.sports_esports;
      case 'pascabayar': return Icons.receipt_long;
      case 'withdraw': return Icons.money_off;
      default: return isIncome ? Icons.arrow_downward : Icons.arrow_upward;
    }
  }

  Color _colorForCategory(String category, bool isIncome) {
    switch (category.toLowerCase()) {
      case 'topup': return const Color(0xff1565C0);
      case 'transfer': return isIncome ? Colors.green : Colors.orange;
      case 'pulsa': return const Color(0xffE91E63);
      case 'data': return const Color(0xff00BCD4);
      case 'pln': return const Color(0xffFF9800);
      case 'e-money': return const Color(0xff4CAF50);
      case 'games': return const Color(0xff9C27B0);
      case 'withdraw': return Colors.red;
      default: return isIncome ? Colors.green : Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    notifire = Provider.of<ColorNotifire>(context, listen: true);
    final items = _activityItems;
    return Scaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: DesktopTitleWrapper(child: Text(
          'Riwayat Transaksi',
          style: TextStyle(
              color: Colors.white,
              fontSize: height / 40,
              fontFamily: 'Gilroy Bold'),
        ))
      ),
      extendBodyBehindAppBar: true,
      backgroundColor: const Color(0xFFF9FAFB),
      body: Stack(
        children: [
          Container(
            height: MediaQuery.of(context).padding.top + 100,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0D47A1), Color(0xFF1E88E5)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          SafeArea(
            child: _loadingTransactions && _topups.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    child: Shimmer.fromColors(
                      baseColor: Colors.grey.shade300,
                      highlightColor: Colors.grey.shade100,
                      child: Column(
                        children: List.generate(4, (_) => Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Container(
                            height: 72,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          )),

                        ),
                      ),
                    )
                : items.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.receipt_long_rounded, size: 64, color: Colors.grey.withOpacity(0.3)),
                            const SizedBox(height: 12),
                            Text(
                              'Belum ada transaksi',
                              style: TextStyle(
                                color: Colors.grey.shade400,
                                fontFamily: 'Gilroy Medium',
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        color: Colors.white,
                        backgroundColor: const Color(0xFF1E88E5),
                        onRefresh: () async {
                          await Future.wait([_loadTransactions(), _loadTopups()]);
                        },
                        child: ListView.builder(
                          padding: EdgeInsets.fromLTRB(width / 20, height / 60, width / 20, height / 10),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final tx = items[index];
                      final isPending = tx['is_pending'] == true;
                      final statusLabel = tx['status_label']?.toString() ?? '';
                      final isExpired = statusLabel == 'Kedaluwarsa';
                      final isFailed = statusLabel == 'Gagal';
                      final isIncome = tx['type'] == 'income';
                      final amount = effectiveTransactionTotal(Map<String, dynamic>.from(tx));
                      final formatter = NumberFormat('#,###', 'id_ID');
                      final amountStr = (isPending || isExpired || isFailed)
                          ? 'Rp ${formatter.format(amount.toInt())}'
                          : (isIncome
                              ? '+Rp ${formatter.format(amount.toInt())}'
                              : '-Rp ${formatter.format(amount.toInt())}');
                      final dateStr = tx['created_at'] != null
                          ? DateFormat('d MMM yyyy . HH:mm')
                              .format(parseDateTime(tx['created_at']))
                          : '';
                      final statusColor = isFailed
                          ? Colors.red
                          : isExpired
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
                        child: Padding(
                          padding: EdgeInsets.only(bottom: height / 100),
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: width / 30, vertical: height / 70),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(
                                color: statusColor != null
                                    ? statusColor.withOpacity(0.3)
                                    : Colors.grey.withOpacity(0.12),
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  height: height / 16,
                                  width: height / 16,
                                  decoration: BoxDecoration(
                                    color: (statusColor ?? _colorForCategory(tx['category'] ?? '', isIncome))
                                        .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Center(
                                    child: Icon(
                                      isFailed
                                          ? Icons.error_outline_rounded
                                          : isPending
                                              ? Icons.hourglass_top_rounded
                                              : isExpired
                                                  ? Icons.timer_off_rounded
                                                  : _iconForCategory(tx['category'] ?? '', isIncome),
                                      color: statusColor ?? _colorForCategory(tx['category'] ?? '', isIncome),
                                      size: height / 30,
                                    ),
                                  ),
                                ),
                                SizedBox(width: width / 30),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        tx['name'] ?? '',
                                        style: TextStyle(
                                          fontFamily: 'Gilroy Bold',
                                          color: const Color(0xFF111827),
                                          fontSize: height / 55,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        dateStr,
                                        style: TextStyle(
                                          fontFamily: 'Gilroy Medium',
                                          color: Colors.grey.withOpacity(0.7),
                                          fontSize: height / 65,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      amountStr,
                                      style: TextStyle(
                                        fontFamily: 'Gilroy Bold',
                                        color: statusColor ?? (isIncome ? Colors.green : Colors.red),
                                        fontSize: height / 50,
                                      ),
                                    ),
                                    if (statusLabel.isNotEmpty) ...[
                                      const SizedBox(height: 3),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: (statusColor ?? Colors.grey).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          statusLabel,
                                          style: TextStyle(
                                            fontFamily: 'Gilroy Bold',
                                            color: statusColor ?? Colors.grey,
                                            fontSize: height / 65,
                                          ),
                                        ),
                                      ),
                                    ],
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
          ),
        ],
      ),
    );
  }
}
