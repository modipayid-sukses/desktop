import 'package:flutter/material.dart';
import 'package:modipay/services/api_service.dart';
import 'package:modipay/home/transaction_detail.dart';
import 'package:modipay/utils/transaction_helpers.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';

import '../utils/colornotifire.dart';
import '../utils/media.dart';
import '../utils/string.dart';

class Seealltransaction extends StatefulWidget {
  const Seealltransaction({Key? key}) : super(key: key);

  @override
  State<Seealltransaction> createState() => _SeealltransactionState();
}

class _SeealltransactionState extends State<Seealltransaction> {
  late ColorNotifire notifire;
  List<Map<String, dynamic>> _transactions = [];
  List<Map<String, dynamic>> _topups = [];
  bool _isLoading = true;
  int _currentPage = 1;
  int _lastPage = 1;
  bool _loadingMore = false;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  DateTime? _selectedDate;

  String _selectedType = 'Semua';
  static const List<Map<String, String>> _typeFilters = [
    {'label': 'Semua', 'value': 'all'},
    {'label': 'Top Up', 'value': 'topup'},
    {'label': 'Pembayaran', 'value': 'payment'},
    {'label': 'Penarikan', 'value': 'withdraw'},
    {'label': 'Lainnya', 'value': 'other'},
  ];

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
    _loadAllData();
    _scrollController.addListener(_onScroll);
  }

  Future<void> _loadAllData() async {
    await Future.wait([
      _loadTransactions(),
      _loadTopups(),
    ]);
  }

  Future<void> _loadTopups() async {
    try {
      final topups = await ApiService.getRecentTopups();
      if (mounted) {
        setState(() => _topups = topups);
      }
    } catch (_) {}
  }

  List<Map<String, dynamic>> get _activityItems {
    final txOrderIds = _transactions
        .map((t) => t['order_id']?.toString() ?? '')
        .toSet();

    final topupItems = _topups
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
            case 'completed':
              statusLabel = '';
              break;
            case 'expired':
              statusLabel = 'Kedaluwarsa';
              break;
            default:
              statusLabel = status;
          }
          return {
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

    final completed = _transactions.map((t) {
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
      return {
        ...t,
        'is_pending': txStatus == 'pending',
        'is_expired': false,
        'status_label': txStatusLabel,
      };
    }).toList();

    final all = [...topupItems, ...completed];
    all.sort((a, b) {
      final aDate = (DateTime.tryParse(a['created_at']?.toString() ?? '') ?? DateTime(2000)).toLocal();
      final bDate = (DateTime.tryParse(b['created_at']?.toString() ?? '') ?? DateTime(2000)).toLocal();
      return bDate.compareTo(aDate);
    });
    return all;
  }

  Map<String, List<Map<String, dynamic>>> get _groupedByDate {
    final items = _searchedItems.where((tx) {
      if (_selectedType == 'Semua' || _selectedType == 'all') return true;
      final cat = (tx['category'] ?? '').toString().toLowerCase();
      if (_selectedType == 'topup') return cat.contains('topup');
      if (_selectedType == 'payment') return cat.contains('bayar') || cat.contains('payment');
      if (_selectedType == 'withdraw') return cat.contains('withdraw') || cat.contains('tarik');
      return !cat.contains('topup') && !cat.contains('bayar') && !cat.contains('withdraw');
    }).where((tx) {
      if (_selectedDate == null) return true;
      final date = DateTime.tryParse((tx['created_at'] ?? '').toString());
      if (date == null) return false;
      return _isSameDate(date.toLocal(), _selectedDate!);
    }).toList();
    final grouped = <String, List<Map<String, dynamic>>>{};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    for (final tx in items) {
      var date = DateTime.tryParse(tx['created_at'] ?? '');
      if (date == null) continue;
      date = date.toLocal();
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
    return grouped;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _searchedItems {
    if (_searchQuery.isEmpty) return _activityItems;
    final q = _searchQuery.toLowerCase();
    return _activityItems.where((tx) {
      final name = (tx['name'] ?? '').toString().toLowerCase();
      final category = (tx['category'] ?? '').toString().toLowerCase();
      final amount = (tx['amount'] ?? '').toString();
      final description = (tx['description'] ?? '').toString().toLowerCase();
        final note = (tx['note'] ?? '').toString().toLowerCase();
      final orderId = (tx['order_id'] ?? '').toString().toLowerCase();
        return name.contains(q) || category.contains(q) || amount.contains(q) || description.contains(q) || note.contains(q) || orderId.contains(q);
    }).toList();
  }

  bool _isSameDate(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }

  Future<void> _pickDateFilter() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
      helpText: 'Pilih tanggal transaksi',
      cancelText: 'Batal',
      confirmText: 'Pilih',
    );

    if (!mounted || picked == null) return;
    setState(() => _selectedDate = picked);
  }

  void _clearDateFilter() {
    if (_selectedDate == null) return;
    setState(() => _selectedDate = null);
  }

  String _formatSelectedDate(DateTime date) {
    return DateFormat('d MMM yyyy', 'id_ID').format(date);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_loadingMore &&
        _currentPage < _lastPage) {
      _loadMore();
    }
  }

  Future<void> _loadTransactions() async {
    try {
      final response = await ApiService.getTransactions(page: 1);
      if (mounted) {
        setState(() {
          _transactions = List<Map<String, dynamic>>.from(response['data'] ?? []);
          _currentPage = response['current_page'] ?? 1;
          _lastPage = response['last_page'] ?? 1;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMore() async {
    setState(() => _loadingMore = true);
    try {
      final response = await ApiService.getTransactions(page: _currentPage + 1);
      if (mounted) {
        setState(() {
          _transactions.addAll(List<Map<String, dynamic>>.from(response['data'] ?? []));
          _currentPage = response['current_page'] ?? _currentPage;
          _lastPage = response['last_page'] ?? _lastPage;
          _loadingMore = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _onRefresh() async {
    await ApiService.checkPendingTopups();
    setState(() {
      _currentPage = 1;
      _lastPage = 1;
    });
    await Future.wait([
      _loadTransactions(),
      _loadTopups(),
    ]);
  }

  String _formatAmount(double amount) {
    final formatter = NumberFormat('#,###', 'id_ID');
    return formatter.format(amount.toInt());
  }

  @override
  Widget build(BuildContext context) {
    notifire = Provider.of<ColorNotifire>(context, listen: true);
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: Row(
                children: [
                  Text('Semua Transaksi',
                      style: TextStyle(
                        fontFamily: 'Gilroy Bold',
                        fontSize: 22,
                        color: notifire.getdarkscolor,
                      )),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.filter_alt_rounded, color: Color(0xFF0D47A1)),
                    onPressed: _pickDateFilter,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
              child: Text(
                'Riwayat aktivitas keuangan Anda',
                style: TextStyle(
                  fontFamily: 'Gilroy Medium',
                  fontSize: 13,
                  color: notifire.getdarkgreycolor.withOpacity(0.7),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.withOpacity(0.2)),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _searchQuery = v),
                  style: TextStyle(
                    fontFamily: 'Gilroy Medium',
                    color: notifire.getdarkscolor,
                    fontSize: 15,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Cari nominal, kategori, nama...'
                        ,
                    hintStyle: TextStyle(
                      fontFamily: 'Gilroy Medium',
                      color: notifire.getdarkgreycolor.withOpacity(0.5),
                      fontSize: 15,
                    ),
                    prefixIcon: Icon(Icons.search_rounded, color: notifire.getdarkgreycolor.withOpacity(0.5), size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? GestureDetector(
                            onTap: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                            child: Icon(Icons.close_rounded, color: notifire.getdarkgreycolor.withOpacity(0.5), size: 18),
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _typeFilters.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final filter = _typeFilters[i];
                    final selected = _selectedType == filter['label'];
                    return ChoiceChip(
                      label: Text(filter['label']!),
                      selected: selected,
                      onSelected: (_) => setState(() => _selectedType = filter['label']!),
                      selectedColor: const Color(0xFF0D47A1),
                      backgroundColor: notifire.getprimerydarkcolor,
                      labelStyle: TextStyle(
                        color: selected ? Colors.white : notifire.getdarkscolor,
                        fontFamily: selected ? 'Gilroy Bold' : 'Gilroy Medium',
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    );
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickDateFilter,
                      icon: const Icon(Icons.date_range_rounded, size: 18),
                      label: Text(
                        _selectedDate == null
                            ? 'Filter Tanggal'
                            : _formatSelectedDate(_selectedDate!),
                        style: const TextStyle(
                          fontFamily: 'Gilroy Medium',
                          fontSize: 13,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0D47A1),
                        backgroundColor: Colors.white,
                        side: const BorderSide(color: Color(0xFFD9E3F0)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        minimumSize: const Size.fromHeight(44),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (_selectedDate != null)
                    SizedBox(
                      height: 44,
                      child: TextButton(
                        onPressed: _clearDateFilter,
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF0D47A1),
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: Color(0xFFD9E3F0)),
                          ),
                        ),
                        child: const Text(
                          'Hapus',
                          style: TextStyle(
                            fontFamily: 'Gilroy Medium',
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _isLoading
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                  : _groupedByDate.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            SizedBox(height: MediaQuery.of(context).size.height / 4),
                            Center(
                              child: Column(
                                children: [
                                  Icon(Icons.receipt_long_rounded, size: 64, color: Colors.grey.withOpacity(0.2)),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Belum ada transaksi',
                                    style: TextStyle(
                                      fontFamily: 'Gilroy Medium',
                                      color: notifire.getdarkgreycolor.withOpacity(0.7),
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Mulai transaksi pertama Anda!',
                                    style: TextStyle(
                                      fontFamily: 'Gilroy Medium',
                                      color: notifire.getdarkgreycolor.withOpacity(0.5),
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      : RefreshIndicator(
                          onRefresh: _onRefresh,
                          color: const Color(0xFF0D47A1),
                          child: ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.only(bottom: 16),
                            itemCount: _groupedByDate.length + (_loadingMore ? 1 : 0),
                            itemBuilder: (context, idx) {
                              if (_loadingMore && idx == _groupedByDate.length) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                  child: Shimmer.fromColors(
                                    baseColor: Colors.grey.shade300,
                                    highlightColor: Colors.grey.shade100,
                                    child: Column(
                                      children: List.generate(2, (_) => Padding(
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
                                );
                              }
                              final dateLabel = _groupedByDate.keys.elementAt(idx);
                              final txs = _groupedByDate[dateLabel]!;
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
                                    child: Text(
                                      dateLabel,
                                      style: TextStyle(
                                        fontFamily: 'Gilroy Bold',
                                        fontSize: 15,
                                        color: notifire.getdarkscolor.withOpacity(0.85),
                                      ),
                                    ),
                                  ),
                                  ...txs.map((tx) => _buildTransactionItem(tx)).toList(),
                                ],
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionItem(Map<String, dynamic> tx) {
    final isPending = tx['is_pending'] == true;
    final isExpired = tx['is_expired'] == true;
    final statusLabel = tx['status_label']?.toString() ?? '';
    final isIncome = tx['type'] == 'income';
    final amount = effectiveTransactionTotal(tx);
    final amountStr = (isPending || isExpired)
        ? 'Rp ${_formatAmount(amount)}'
        : (isIncome
            ? '+Rp ${_formatAmount(amount)}'
            : '-Rp ${_formatAmount(amount)}');
    final dateStr = tx['created_at'] != null
        ? DateFormat('d MMM yyyy • HH:mm', 'id_ID')
            .format(DateTime.parse(tx['created_at']).toLocal())
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: statusColor != null
                  ? statusColor.withOpacity(0.4)
                  : Colors.grey.withOpacity(0.18),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                height: 44,
                width: 44,
                decoration: BoxDecoration(
                  color: statusColor != null
                      ? statusColor.withOpacity(0.1)
                      : notifire.gettabwhitecolor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Icon(
                    isPending
                        ? Icons.hourglass_top_rounded
                        : isExpired
                            ? Icons.timer_off_rounded
                            : _iconForCategory(category, isIncome),
                    color: statusColor ?? _colorForCategory(category, isIncome),
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      tx['name'] ?? '',
                      style: TextStyle(
                        fontFamily: "Gilroy Bold",
                        color: notifire.getdarkscolor,
                        fontSize: 15,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dateStr,
                      style: TextStyle(
                        fontFamily: "Gilroy Medium",
                        color: notifire.getdarkgreycolor.withOpacity(0.7),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    amountStr,
                    style: TextStyle(
                      fontFamily: "Gilroy Bold",
                      color: statusColor ?? (isIncome ? Colors.green : Colors.red),
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (statusLabel.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: (statusColor ?? Colors.grey).withOpacity(0.13),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          fontFamily: "Gilroy Bold",
                          color: statusColor ?? Colors.grey,
                          fontSize: 11,
                        ),
                      ),
                    )
                  else
                    Text(
                      category.isNotEmpty ? category : '',
                      style: TextStyle(
                        fontFamily: "Gilroy Medium",
                        color: notifire.getdarkgreycolor.withOpacity(0.6),
                        fontSize: 11,
                      ),
                    ),
                  if (tx['note'] != null && tx['note'].toString().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.sticky_note_2_rounded, size: 11, color: const Color(0xFFF9A825)),
                          const SizedBox(width: 3),
                          Text(
                            'Catatan',
                            style: TextStyle(
                              fontFamily: 'Gilroy Medium',
                              fontSize: 10,
                              color: const Color(0xFFF9A825),
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
  }

  IconData _iconForCategory(String category, bool isIncome) {
    final cat = category.toLowerCase();
    if (cat.contains('topup')) return Icons.account_balance_wallet_rounded;
    if (cat.contains('pln')) return Icons.flash_on_rounded;
    if (cat.contains('pulsa')) return Icons.phone_android_rounded;
    if (cat.contains('payment') || cat.contains('bayar')) return Icons.receipt_long_rounded;
    if (cat.contains('withdraw') || cat.contains('tarik')) return Icons.arrow_downward_rounded;
    if (cat.contains('games')) return Icons.sports_esports_rounded;
    if (cat.contains('voucher')) return Icons.card_giftcard_rounded;
    if (cat.contains('qris')) return Icons.qr_code_2_rounded;
    return isIncome ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded;
  }

  Color _colorForCategory(String category, bool isIncome) {
    final cat = category.toLowerCase();
    if (cat.contains('topup')) return const Color(0xFF0D47A1);
    if (cat.contains('pln')) return const Color(0xFFFF9800);
    if (cat.contains('pulsa')) return const Color(0xFFE91E63);
    if (cat.contains('payment') || cat.contains('bayar')) return const Color(0xFF1E88E5);
    if (cat.contains('withdraw') || cat.contains('tarik')) return Colors.red;
    if (cat.contains('games')) return const Color(0xFF9C27B0);
    if (cat.contains('voucher')) return const Color(0xFFFF5722);
    if (cat.contains('qris')) return const Color(0xFF00BCD4);
    return isIncome ? Colors.green : Colors.red;
  }
}
