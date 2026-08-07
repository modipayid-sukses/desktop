import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:modipay/promo/promo_screen.dart';
import 'package:modipay/services/api_service.dart';
import 'package:modipay/home/transaction_detail.dart';
import 'package:modipay/utils/transaction_helpers.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:modipay/utils/color.dart';
import 'package:modipay/utils/responsive.dart';
import 'package:modipay/providers/auth_provider.dart';
import 'package:modipay/home/notifications.dart';
import 'package:modipay/profile/helpsupport.dart';
import 'package:modipay/profile/profile.dart' as profile_page;
import 'package:modipay/login/login_router.dart';
import 'package:modipay/home/ppob/ppob_menu_route.dart';
import 'package:modipay/design/design.dart';
import 'package:modipay/home/ppob/bpjs_screen.dart';
import 'package:modipay/home/ppob/pdam_screen.dart';
import 'package:modipay/home/ppob/ppob_all_services_screen.dart';
import 'package:modipay/home/transfer/bank_transfer_screen.dart';
import 'package:modipay/home/qris/qris_scan_screen.dart';
import 'package:modipay/home/ppob/ppob_topup_game_list_screen.dart';
import 'package:modipay/home/ppob/ppob_postpaid_screen.dart';
import 'package:modipay/home/ppob/ppob_emoney_brand_screen.dart';
import 'package:modipay/home/ppob/ppob_product_screen.dart';
import 'package:modipay/home/topup/topup_channel_screen.dart';
import 'package:modipay/utils/toast.dart';

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
  int _uiPage = 1;
  int? _apiTotal;
  static const int _pageSize = 10;

  String _selectedType = 'Semua';
  bool _prepaidExpanded = false;
  bool _postpaidExpanded = false;
  List<Map<String, dynamic>> _pembelianItems = [];
  List<Map<String, dynamic>> _pembayaranItems = [];
  int _unreadNotificationCount = 0;

  // Layar transaksi aktif di desktop, dirender di content pane (di samping
  // sidebar) bukan sebagai Dialog mengambang — lihat _openTransaction.
  Widget? _desktopActiveScreen;
  // Key stabil agar Navigator bersarang tidak kehilangan stack rute saat
  // parent rebuild selagi alur transaksi berlangsung di beberapa layar.
  GlobalKey<NavigatorState>? _contentNavKey;
  // Menu sidebar desktop yang sedang aktif/disorot. 'riwayat' adalah
  // konteks "rumah" untuk halaman ini — diset balik tiap content pane ditutup.
  String _activeDesktopMenu = 'riwayat';
  String? _activeSubMenuName;
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
    _loadMenu();
    _loadNotificationCount();
    _scrollController.addListener(_onScroll);
  }

  Future<void> _loadNotificationCount() async {
    try {
      final response = await ApiService.getNotifications();
      if (response['data'] != null) {
        final rawList = response['data'] as List? ?? [];
        final unread = rawList.where((e) {
          final isRead = e['is_read'];
          return isRead == false || isRead == 0 || isRead == '0';
        }).length;
        if (mounted) {
          setState(() {
            _unreadNotificationCount = unread;
          });
        }
      }
    } catch (_) {}
  }

  static const Map<String, IconData> _iconMap = {
    'phone_android': Icons.phone_android,
    'signal_cellular_alt': Icons.signal_cellular_alt,
    'electric_bolt': Icons.electric_bolt,
    'account_balance_wallet': Icons.account_balance_wallet,
    'sim_card': Icons.sim_card,
    'sports_esports': Icons.sports_esports,
    'electrical_services': Icons.electrical_services,
    'health_and_safety': Icons.health_and_safety,
    'wifi': Icons.wifi,
    'grid_view_rounded': Icons.grid_view_rounded,
    'tv': Icons.tv,
    'credit_card': Icons.credit_card,
    'receipt_long': Icons.receipt_long,
    'message': Icons.message,
    'card_giftcard': Icons.card_giftcard,
    'flash_on': Icons.flash_on,
    'payments': Icons.payments,
    'water_drop': Icons.water_drop,
    'local_gas_station': Icons.local_gas_station,
    'swap_horiz': Icons.swap_horiz,
    'phone_in_talk': Icons.phone_in_talk,
    'language': Icons.language,
    'account_balance': Icons.account_balance,
    'two_wheeler': Icons.two_wheeler,
    'directions_car': Icons.directions_car,
    'local_fire_department': Icons.local_fire_department,
    'diamond': Icons.diamond,
    'extension': Icons.extension,
    'shield': Icons.shield,
    'sports_soccer': Icons.sports_soccer,
    'games': Icons.games,
    'play_circle': Icons.play_circle,
    'videocam': Icons.videocam,
    'music_note': Icons.music_note,
    'movie': Icons.movie,
    'send': Icons.send,
    'music_video': Icons.music_video,
    'live_tv': Icons.live_tv,
    'phone': Icons.phone,
  };

  Future<void> _loadMenu() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final menuJson = prefs.getString('cache_ppob_menu_v2');
      if (menuJson != null) {
        final data = Map<String, dynamic>.from(jsonDecode(menuJson));
        _applyMenuData(data);
      }
      final data = await ApiService.getPpobMenu();
      if (!mounted || data.isEmpty) return;
      _applyMenuData(data);
      prefs.setString('cache_ppob_menu_v2', jsonEncode(data));
    } catch (_) {}
  }

  void _applyMenuData(Map<String, dynamic> data) {
    List<Map<String, dynamic>> parseGroup(List items, String defaultCmd) {
      return items.map((c) {
        final m = Map<String, dynamic>.from(c);
        final normalized = normalizePpobMenuItem(m, defaultCmd: defaultCmd);
        normalized['icon'] = _iconMap[m['icon']] ?? Icons.apps;
        final rawUrl = m['icon_url'] as String?;
        normalized['iconUrl'] = (rawUrl != null && rawUrl.startsWith('/'))
            ? '${ApiService.baseUrl.replaceFirst('/api', '')}$rawUrl'
            : rawUrl;
        return normalized;
      }).where((item) => !isHiddenPpobMenuItem(item)).toList();
    }

    if (mounted) {
      setState(() {
        _pembelianItems  = parseGroup(data['pembelian']  as List? ?? [], 'prepaid');
        _pembayaranItems = parseGroup(data['pembayaran'] as List? ?? [], 'pasca');
        reclassifyPostpaidItems(_pembelianItems, _pembayaranItems);
      });
    }
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
            'status': status,
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
      final aDate = parseDateTime(a['created_at']);
      final bDate = parseDateTime(b['created_at']);
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
      final date = parseDateTime(tx['created_at']);
      return _isSameDate(date, _selectedDate!);
    }).toList();
    final grouped = <String, List<Map<String, dynamic>>>{};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    for (final tx in items) {
      final date = parseDateTime(tx['created_at']);
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
    setState(() {
      _selectedDate = picked;
      _uiPage = 1;
    });
  }

  void _clearDateFilter() {
    if (_selectedDate == null) return;
    setState(() {
      _selectedDate = null;
      _uiPage = 1;
    });
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

  int? _parseTotal(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  Future<void> _loadTransactions() async {
    try {
      final response = await ApiService.getTransactions(page: 1);
      if (mounted) {
        setState(() {
          _transactions = List<Map<String, dynamic>>.from(response['data'] ?? []);
          _currentPage = response['current_page'] ?? 1;
          _lastPage = response['last_page'] ?? 1;
          _apiTotal = _parseTotal(response['total']);
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _currentPage >= _lastPage) return;
    setState(() => _loadingMore = true);
    try {
      final response = await ApiService.getTransactions(page: _currentPage + 1);
      if (mounted) {
        setState(() {
          _transactions.addAll(List<Map<String, dynamic>>.from(response['data'] ?? []));
          _currentPage = response['current_page'] ?? _currentPage;
          _lastPage = response['last_page'] ?? _lastPage;
          _apiTotal = _parseTotal(response['total']) ?? _apiTotal;
          _loadingMore = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  /// Pastikan cukup data lokal untuk menampilkan [page] (10 item/halaman) di
  /// tabel desktop, memicu fetch halaman backend berikutnya bila perlu —
  /// lihat _goToUiPage di bagian layout desktop.
  void _ensureUiPageLoaded(int page) {
    final needed = page * _pageSize;
    if (needed > _filteredItems.length && _currentPage < _lastPage && !_loadingMore) {
      _loadMore();
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
    if (isDesktop(context)) {
      return _buildDesktopLayout(context);
    }
    return _buildMobileLayout(context);
  }

  Widget _buildMobileLayout(BuildContext context) {
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
            .format(parseDateTime(tx['created_at']))
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

  // ── DESKTOP LAYOUT METHODS ──

  String _pickFirstNonEmpty(List<dynamic> candidates) {
    for (final c in candidates) {
      final s = c?.toString() ?? '';
      if (s.isNotEmpty) return s;
    }
    return '-';
  }

  List<Map<String, dynamic>> get _filteredItems {
    return _searchedItems.where((tx) {
      final selectedValue = _typeFilters.firstWhere(
        (f) => f['label'] == _selectedType,
        orElse: () => {'value': 'all'},
      )['value'];
      
      if (selectedValue == 'all') return true;
      final cat = (tx['category'] ?? '').toString().toLowerCase();
      if (selectedValue == 'topup') return cat.contains('topup');
      if (selectedValue == 'payment') return cat.contains('bayar') || cat.contains('payment');
      if (selectedValue == 'withdraw') return cat.contains('withdraw') || cat.contains('tarik');
      return !cat.contains('topup') && !cat.contains('bayar') && !cat.contains('withdraw');
    }).where((tx) {
      if (_selectedDate == null) return true;
      final date = parseDateTime(tx['created_at']);
      return _isSameDate(date, _selectedDate!);
    }).toList();
  }

  Widget _buildDesktopLayout(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final df = DateFormat('d MMM yyyy HH:mm', 'id_ID');
    final currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    Color statusBg(String status) {
      switch (status) {
        case 'pending':
          return desktopWarningAmber.withOpacity(0.12);
        case 'failed':
          return desktopErrorRed.withOpacity(0.1);
        case 'expired':
          return desktopSurfacePage;
        default:
          return desktopSuccessBg;
      }
    }

    Color statusFg(String status) {
      switch (status) {
        case 'pending':
          return desktopWarningAmber;
        case 'failed':
          return desktopErrorRed;
        case 'expired':
          return desktopTextSecondary;
        default:
          return desktopSuccessFg;
      }
    }

    String statusLabel(Map<String, dynamic> item) {
      final custom = (item['status_label'] ?? '').toString();
      if (custom.isNotEmpty) return custom;
      return 'Berhasil';
    }

    return Scaffold(
      backgroundColor: desktopSurfacePage,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDesktopSidebar(auth),
          Expanded(
            child: Column(
              children: [
                _buildDesktopTopbar(auth),
                Expanded(
                  child: _desktopActiveScreen != null
                      ? _buildDesktopContentPane(_desktopActiveScreen!)
                      : SingleChildScrollView(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(28),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                            Row(
                              children: [
                                Text(
                                  'Riwayat Transaksi',
                                  style: GoogleFonts.hankenGrotesk(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 22,
                                    color: desktopTextPrimary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.refresh_rounded, color: desktopTextSecondary, size: 20),
                                  onPressed: _loadAllData,
                                  tooltip: 'Refresh',
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Riwayat aktivitas keuangan Anda',
                              style: GoogleFonts.hankenGrotesk(
                                fontSize: 13,
                                color: desktopTextSecondary,
                              ),
                            ),
                            const SizedBox(height: 20),
                            _buildDesktopTableCard(df, currency, statusBg, statusFg, statusLabel),
                          ],
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

  Widget _buildDesktopTableCard(
    DateFormat df,
    NumberFormat currency,
    Color Function(String) statusBg,
    Color Function(String) statusFg,
    String Function(Map<String, dynamic>) statusLabel,
  ) {
    final filtered = _filteredItems;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter Row
          Row(
            children: [
              // Search Input
              Container(
                width: 280,
                height: 40,
                decoration: BoxDecoration(
                  color: desktopSurfacePage,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: desktopBorder.withOpacity(0.5)),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() {
                    _searchQuery = v;
                    _uiPage = 1;
                  }),
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 13.5,
                    color: desktopTextPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Cari nominal, kategori, nama...',
                    hintStyle: GoogleFonts.hankenGrotesk(
                      fontSize: 13.5,
                      color: desktopTextSecondary.withOpacity(0.5),
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: desktopTextSecondary.withOpacity(0.5),
                      size: 18,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? GestureDetector(
                            onTap: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                            child: Icon(
                              Icons.close_rounded,
                              color: desktopTextSecondary.withOpacity(0.5),
                              size: 16,
                            ),
                          )
                        : null,
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Category filter chips
              Expanded(
                child: SizedBox(
                  height: 32,
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
                        onSelected: (_) => setState(() {
                          _selectedType = filter['label']!;
                          _uiPage = 1;
                        }),
                        selectedColor: desktopPrimaryBtn,
                        backgroundColor: desktopSurfacePage,
                        labelStyle: GoogleFonts.hankenGrotesk(
                          color: selected ? Colors.white : desktopTextSecondary,
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                          fontSize: 12.5,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: selected ? Colors.transparent : desktopBorder.withOpacity(0.3),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Date picker
              OutlinedButton.icon(
                onPressed: _pickDateFilter,
                icon: const Icon(Icons.date_range_rounded, size: 16),
                label: Text(
                  _selectedDate == null
                      ? 'Filter Tanggal'
                      : _formatSelectedDate(_selectedDate!),
                  style: GoogleFonts.hankenGrotesk(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: desktopPrimaryBtn,
                  backgroundColor: Colors.white,
                  side: BorderSide(color: desktopBorder.withOpacity(0.8)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
              if (_selectedDate != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _clearDateFilter,
                  icon: const Icon(Icons.clear_rounded, color: desktopErrorRed, size: 18),
                  style: IconButton.styleFrom(
                    backgroundColor: desktopSurfacePage,
                    padding: const EdgeInsets.all(8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 20),
          // Data Table
          if (_isLoading)
            _buildDesktopTableShimmer()
          else if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.receipt_long_rounded,
                      size: 64,
                      color: desktopTextSecondary.withOpacity(0.2),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Belum ada transaksi',
                      style: GoogleFonts.hankenGrotesk(
                        fontWeight: FontWeight.w700,
                        color: desktopTextSecondary,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tidak ada transaksi yang cocok dengan filter pencarian Anda.',
                      style: GoogleFonts.hankenGrotesk(
                        fontWeight: FontWeight.w500,
                        color: desktopTextSecondary.withOpacity(0.6),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Tanggal',
                      style: GoogleFonts.hankenGrotesk(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: desktopTextSecondary,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      'Produk',
                      style: GoogleFonts.hankenGrotesk(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: desktopTextSecondary,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Nomor Tujuan',
                      style: GoogleFonts.hankenGrotesk(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: desktopTextSecondary,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Kasir',
                      style: GoogleFonts.hankenGrotesk(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: desktopTextSecondary,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Status',
                      style: GoogleFonts.hankenGrotesk(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: desktopTextSecondary,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Nominal',
                      textAlign: TextAlign.right,
                      style: GoogleFonts.hankenGrotesk(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: desktopTextSecondary,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Saldo Akhir',
                      textAlign: TextAlign.right,
                      style: GoogleFonts.hankenGrotesk(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: desktopTextSecondary,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 44,
                    child: Text(
                      'Aksi',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.hankenGrotesk(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: desktopTextSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: desktopBorder.withOpacity(0.5)),
            Builder(builder: (context) {
              final totalPages = filtered.isEmpty ? 1 : (filtered.length / _pageSize).ceil();
              final effectivePage = _uiPage.clamp(1, totalPages);
              final pageStart = (effectivePage - 1) * _pageSize;
              final pageEnd = (pageStart + _pageSize).clamp(0, filtered.length);
              final pagedItems = filtered.sublist(pageStart.clamp(0, filtered.length), pageEnd);
              return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: pagedItems.length,
              itemBuilder: (context, idx) {
                final item = pagedItems[idx];
                final name = (item['name'] ?? item['product_name'] ?? '-').toString();
                final target = _pickFirstNonEmpty([item['customer_no'], item['customer_id'], item['target'], item['order_id']]);
                final kasir = _pickFirstNonEmpty([item['cashier_name'], item['kasir_name'], item['kasir'], item['cashier']]);
                final saldoAkhirRaw = item['balance_after'] ?? item['ending_balance'] ?? item['saldo_akhir'] ?? item['balance'];
                final saldoAkhirVal = saldoAkhirRaw is num
                    ? saldoAkhirRaw.toDouble()
                    : double.tryParse(saldoAkhirRaw?.toString() ?? '');
                final saldoAkhirStr = saldoAkhirVal != null ? currency.format(saldoAkhirVal) : '-';
                final amount = effectiveTransactionTotal(item);
                final status = statusLabel(item);
                final statusKey = item['is_pending'] == true
                    ? 'pending'
                    : item['is_expired'] == true
                        ? 'expired'
                        : (item['status'] ?? 'completed').toString();
                
                final isIncome = item['type'] == 'income';
                final amountStr = (statusKey == 'pending' || statusKey == 'expired')
                    ? currency.format(amount)
                    : (isIncome
                        ? '+${currency.format(amount)}'
                        : '-${currency.format(amount)}');

                return InkWell(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TransactionDetail(data: item),
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: desktopBorder.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(
                            df.format(parseDateTime(item['created_at'])),
                            style: GoogleFonts.hankenGrotesk(
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                              color: desktopTextSecondary,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Row(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: desktopAccentBlue.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  statusKey == 'pending'
                                      ? Icons.hourglass_top_rounded
                                      : statusKey == 'expired'
                                          ? Icons.timer_off_rounded
                                          : _iconForCategory(item['category'] ?? '', isIncome),
                                  size: 14,
                                  color: desktopAccentBlue,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.hankenGrotesk(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: desktopTextPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            target,
                            style: GoogleFonts.hankenGrotesk(
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                              color: desktopTextSecondary,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            kasir,
                            style: GoogleFonts.hankenGrotesk(
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                              color: desktopTextSecondary,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: statusBg(statusKey),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                status,
                                style: GoogleFonts.hankenGrotesk(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 10.5,
                                  color: statusFg(statusKey),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            amountStr,
                            textAlign: TextAlign.right,
                            style: GoogleFonts.hankenGrotesk(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: statusKey == 'pending'
                                  ? desktopWarningAmber
                                  : statusKey == 'expired'
                                      ? desktopTextSecondary
                                      : (isIncome ? desktopSuccessFg : desktopErrorRed),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            saldoAkhirStr,
                            textAlign: TextAlign.right,
                            style: GoogleFonts.hankenGrotesk(
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                              color: desktopTextSecondary,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 44,
                          child: statusKey == 'failed'
                              ? Center(
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(20),
                                    onTap: _loadAllData,
                                    child: Padding(
                                      padding: const EdgeInsets.all(4),
                                      child: Icon(
                                        Icons.refresh_rounded,
                                        size: 18,
                                        color: desktopAccentBlue,
                                      ),
                                    ),
                                  ),
                                )
                              : const Center(
                                  child: Icon(
                                    Icons.chevron_right_rounded,
                                    size: 18,
                                    color: desktopBorder,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                );
              },
              );
            }),
            if (_loadingMore)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            _buildPaginationFooter(filtered.length),
          ],
        ],
      ),
    );
  }

  Widget _buildPaginationFooter(int totalFiltered) {
    final noFilters = _selectedType == 'Semua' && _searchQuery.isEmpty && _selectedDate == null;
    final displayTotal = (noFilters && _apiTotal != null && _apiTotal! > totalFiltered)
        ? _apiTotal!
        : totalFiltered;
    final totalPages = totalFiltered == 0 ? 1 : (displayTotal / _pageSize).ceil();
    final page = _uiPage.clamp(1, totalPages);
    final start = totalFiltered == 0 ? 0 : (page - 1) * _pageSize + 1;
    final end = (page * _pageSize).clamp(0, totalFiltered);

    void goTo(int p) {
      final clamped = p.clamp(1, totalPages);
      setState(() => _uiPage = clamped);
      _ensureUiPageLoaded(clamped);
    }

    final pageNumbers = _buildPageNumberList(page, totalPages);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          totalFiltered == 0
              ? 'Tidak ada transaksi'
              : 'Menampilkan $start-$end dari $displayTotal transaksi',
          style: GoogleFonts.hankenGrotesk(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: desktopTextSecondary,
          ),
        ),
        if (totalPages > 1)
          Row(
            children: [
              _paginationArrow(Icons.chevron_left_rounded, page > 1, () => goTo(page - 1)),
              const SizedBox(width: 6),
              ...pageNumbers.map((p) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: p == null
                        ? SizedBox(
                            width: 28,
                            child: Center(
                              child: Text(
                                '...',
                                style: GoogleFonts.hankenGrotesk(
                                  color: desktopTextSecondary,
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                          )
                        : _pageNumberButton(p, p == page, () => goTo(p)),
                  )),
              const SizedBox(width: 6),
              _paginationArrow(Icons.chevron_right_rounded, page < totalPages, () => goTo(page + 1)),
            ],
          ),
      ],
    );
  }

  List<int?> _buildPageNumberList(int current, int total) {
    if (total <= 7) {
      return List.generate(total, (i) => i + 1);
    }
    final pages = <int>{1, total, current};
    if (current - 1 >= 1) pages.add(current - 1);
    if (current + 1 <= total) pages.add(current + 1);
    final sorted = pages.toList()..sort();
    final result = <int?>[];
    for (int i = 0; i < sorted.length; i++) {
      if (i > 0 && sorted[i] - sorted[i - 1] > 1) {
        result.add(null);
      }
      result.add(sorted[i]);
    }
    return result;
  }

  Widget _paginationArrow(IconData icon, bool enabled, VoidCallback onTap) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          border: Border.all(color: desktopBorder.withOpacity(0.6)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 18, color: enabled ? desktopTextPrimary : desktopBorder),
      ),
    );
  }

  Widget _pageNumberButton(int page, bool active, VoidCallback onTap) {
    return InkWell(
      onTap: active ? null : onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? desktopPrimaryBtn : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: active ? null : Border.all(color: desktopBorder.withOpacity(0.4)),
        ),
        child: Text(
          '$page',
          style: GoogleFonts.hankenGrotesk(
            fontWeight: FontWeight.w700,
            fontSize: 12.5,
            color: active ? Colors.white : desktopTextPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopTableShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Column(
        children: List.generate(4, (_) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        )),
      ),
    );
  }

  Widget _desktopSidebarItem({
    required IconData icon,
    required String label,
    bool active = false,
    bool expandable = false,
    bool expanded = false,
    VoidCallback? onTap,
  }) {
    return Material(
      color: active ? desktopPrimaryBtn : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            children: [
              Icon(icon, size: 19, color: active ? Colors.white : Colors.white.withOpacity(0.6)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.hankenGrotesk(
                    fontWeight: FontWeight.w500,
                    fontSize: 13.5,
                    color: active ? Colors.white : Colors.white.withOpacity(0.6),
                  ),
                ),
              ),
              if (expandable)
                Icon(expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, size: 18, color: Colors.white.withOpacity(0.6)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _desktopSidebarSubItems(List<Map<String, dynamic>> items) {
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(left: 44, bottom: 6),
        child: Text(
          'Belum ada layanan',
          style: GoogleFonts.hankenGrotesk(
            fontWeight: FontWeight.w500,
            fontSize: 12,
            color: Colors.white.withOpacity(0.6),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(left: 44, right: 8, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: items.take(6).map((item) {
          final isSubActive = _activeSubMenuName == item['name'];
          return InkWell(
            onTap: () => _navigateToItem(item),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                item['name'] as String? ?? '',
                style: GoogleFonts.hankenGrotesk(
                  fontWeight: isSubActive ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 12.5,
                  color: isSubActive ? Colors.white : Colors.white.withOpacity(0.6),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDesktopSidebar(AuthProvider auth) {
    return Container(
      width: 260,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [desktopNavyStart, desktopNavyEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MODITEKH2H',
                  style: GoogleFonts.hankenGrotesk(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'PPOB Solution',
                  style: GoogleFonts.hankenGrotesk(
                    color: Colors.white.withOpacity(0.6),
                    fontWeight: FontWeight.w500,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _desktopSidebarItem(
                    icon: Icons.home_rounded,
                    label: 'Beranda',
                    active: false,
                    onTap: () => Navigator.pop(context),
                  ),
                  _desktopSidebarItem(
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'Saldo',
                    active: _activeDesktopMenu == 'saldo',
                    onTap: () => _openTransaction(const TopupChannelScreen(), menuKey: 'saldo'),
                  ),
                  _desktopSidebarItem(
                    icon: Icons.sim_card_outlined,
                    label: 'Prepaid',
                    expandable: true,
                    expanded: _prepaidExpanded,
                    active: _activeDesktopMenu == 'prepaid',
                    onTap: () => setState(() => _prepaidExpanded = !_prepaidExpanded),
                  ),
                  if (_prepaidExpanded) _desktopSidebarSubItems(_pembelianItems),
                  _desktopSidebarItem(
                    icon: Icons.receipt_long_outlined,
                    label: 'Postpaid',
                    expandable: true,
                    expanded: _postpaidExpanded,
                    active: _activeDesktopMenu == 'postpaid',
                    onTap: () => setState(() => _postpaidExpanded = !_postpaidExpanded),
                  ),
                  if (_postpaidExpanded) _desktopSidebarSubItems(_pembayaranItems),
                  _desktopSidebarItem(
                    icon: Icons.local_offer_outlined,
                    label: 'Promo',
                    onTap: () => WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) return;
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PromoScreen(),
                        ),
                      );
                    }),
                  ),
                  _desktopSidebarItem(
                    icon: Icons.history_rounded,
                    label: 'Riwayat Transaksi',
                    active: _activeDesktopMenu == 'riwayat',
                    onTap: _desktopActiveScreen != null ? _closeDesktopActiveScreen : _loadAllData,
                  ),
                  _desktopSidebarItem(
                    icon: Icons.headset_mic_outlined,
                    label: 'Bantuan / CS',
                    active: _activeDesktopMenu == 'bantuan',
                    onTap: () => _openTransaction(const HelpSupport('Bantuan / CS'), menuKey: 'bantuan'),
                  ),
                  _desktopSidebarItem(
                    icon: Icons.notifications_none_rounded,
                    label: 'Notifikasi',
                    active: _activeDesktopMenu == 'notifikasi',
                    onTap: () => _openTransaction(const Notificationindex(CustomStrings.notification), menuKey: 'notifikasi'),
                  ),
                  _desktopSidebarItem(
                    icon: Icons.person_outline_rounded,
                    label: 'Akun Saya',
                    active: _activeDesktopMenu == 'akun',
                    onTap: () => _openTransaction(const profile_page.Profile(), menuKey: 'akun'),
                  ),
                  _desktopSidebarItem(
                    icon: Icons.logout_rounded,
                    label: 'Keluar',
                    onTap: () => _confirmDesktopLogout(auth),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ajak Teman, Dapat Komisi!', style: GoogleFonts.hankenGrotesk(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 12.5)),
                  const SizedBox(height: 4),
                  Text(
                    'Dapatkan komisi setiap transaksi dari teman yang kamu ajak.',
                    style: GoogleFonts.hankenGrotesk(fontWeight: FontWeight.w500, color: Colors.white.withOpacity(0.7), fontSize: 10.5),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _showDesktopReferralDialog(auth),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: desktopAccentBlue,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text('Ajukan Sekarang', style: GoogleFonts.hankenGrotesk(fontWeight: FontWeight.w700, fontSize: 12)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getDesktopTopbarTitle() {
    if (_desktopActiveScreen == null) {
      return 'Riwayat Transaksi';
    }
    switch (_activeDesktopMenu) {
      case 'saldo':
        return 'Saldo';
      case 'prepaid':
        return 'Prepaid';
      case 'postpaid':
        return 'Postpaid';
      case 'promo':
        return 'Promo';
      case 'riwayat':
        return 'Riwayat Transaksi';
      case 'bantuan':
        return 'Bantuan / CS';
      case 'notifikasi':
        return 'Notifikasi';
      case 'akun':
        return 'Akun Saya';
      default:
        return 'Riwayat Transaksi';
    }
  }

  Widget _buildDesktopTopbar(AuthProvider auth) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: desktopBorder))),
      child: Row(
        children: [
          Text(_getDesktopTopbarTitle(), style: GoogleFonts.hankenGrotesk(fontWeight: FontWeight.w700, fontSize: 18, color: desktopTextPrimary)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: desktopAccentBlue.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.headset_mic_outlined, size: 16, color: desktopAccentBlue),
                const SizedBox(width: 6),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('CS Online', style: GoogleFonts.hankenGrotesk(fontWeight: FontWeight.w700, fontSize: 11, color: desktopTextPrimary)),
                    Text('08:00 - 22:00', style: GoogleFonts.hankenGrotesk(fontWeight: FontWeight.w500, fontSize: 9, color: desktopTextSecondary)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          GestureDetector(
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const Notificationindex(CustomStrings.notification),
                ),
              );
            },
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(color: desktopSurfacePage, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.notifications_none_rounded, color: desktopTextSecondary),
                ),
                if (_unreadNotificationCount > 0)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(color: Color(0xffFF3B30), shape: BoxShape.circle),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        '$_unreadNotificationCount',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.hankenGrotesk(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 9,),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          GestureDetector(
            onTap: () => _openTransaction(const profile_page.Profile(), menuKey: 'akun'),
            child: Row(
              children: [
                ClipOval(
                  child: Container(
                    width: 36,
                    height: 36,
                    color: desktopAccentBlue.withOpacity(0.15),
                    child: auth.userAvatar != null && auth.userAvatar!.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: ApiService.avatarUrl(auth.userAvatar),
                            cacheKey: auth.userAvatar,
                            fit: BoxFit.cover,
                            fadeInDuration: Duration.zero,
                            errorWidget: (_, __, ___) => Center(
                              child: Text(
                                auth.userName.isNotEmpty ? auth.userName[0].toUpperCase() : 'U',
                                style: GoogleFonts.hankenGrotesk(fontWeight: FontWeight.w700, color: desktopAccentBlue),
                              ),
                            ),
                          )
                        : Center(
                            child: Text(
                              auth.userName.isNotEmpty ? auth.userName[0].toUpperCase() : 'U',
                              style: GoogleFonts.hankenGrotesk(fontWeight: FontWeight.w700, color: desktopAccentBlue),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(auth.userName, style: GoogleFonts.hankenGrotesk(fontWeight: FontWeight.w700, fontSize: 13, color: desktopTextPrimary)),
                    Text(auth.userLevel.toUpperCase(), style: GoogleFonts.hankenGrotesk(fontWeight: FontWeight.w500, fontSize: 10, color: desktopTextSecondary)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Sama seperti di home.dart: layar lama (mobile-only layout) dirender
  // mobile-emulated 460px lebar; layar yang sudah punya layout desktop
  // dua-kolom sendiri (mis. PPOBProductScreen) perlu ukuran window asli.
  bool _wideDesktopActiveScreen = false;

  void _openTransaction(Widget screen, {String? menuKey, bool wideDesktop = false}) {
    // Tunda ke frame berikutnya agar tidak menghapus widget yang sedang
    // di-hover mouse di tengah pemrosesan pointer event (lihat fix serupa
    // di home.dart _openTransaction untuk detail bug MouseTracker-nya).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _contentNavKey = GlobalKey<NavigatorState>();
        _desktopActiveScreen = screen;
        _wideDesktopActiveScreen = wideDesktop;
        if (menuKey != null) {
          _activeDesktopMenu = menuKey;
          _activeSubMenuName = null;
        }
      });
    });
  }

  void _closeDesktopActiveScreen() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _desktopActiveScreen = null;
        _contentNavKey = null;
        _wideDesktopActiveScreen = false;
        _activeDesktopMenu = 'riwayat';
        _activeSubMenuName = null;
      });
      _onRefresh();
    });
  }

  /// Content pane yang menampung layar transaksi aktif, ditampilkan di
  /// tempat dashboard biasa berada (sidebar & topbar tetap utuh di
  /// sekelilingnya). Navigator bersarang: agar layar lanjutan yang di-push
  /// dari dalam alur transaksi (mis. konfirmasi, struk) tetap berada di
  /// dalam pane ini, bukan keluar jadi halaman penuh.
  Widget _buildDesktopContentPane(Widget screen) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextButton.icon(
            onPressed: _closeDesktopActiveScreen,
            icon: const Icon(Icons.arrow_back_rounded, size: 18, color: desktopTextSecondary),
            label: const Text(
              'Kembali',
              style: TextStyle(fontFamily: 'Gilroy Bold', fontSize: 13, color: desktopTextSecondary),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              foregroundColor: desktopTextSecondary,
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: _wideDesktopActiveScreen
                ? Theme(
                    data: Theme.of(context).copyWith(
                      appBarTheme: Theme.of(context).appBarTheme.copyWith(
                        elevation: 0,
                        scrolledUnderElevation: 0,
                        shadowColor: const Color(0xFF000007),
                      ),
                    ),
                    child: Navigator(
                      key: _contentNavKey,
                      onGenerateRoute: (settings) => MaterialPageRoute(builder: (_) => screen),
                    ),
                  )
                : Center(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        const modalWidth = 460.0;
                        final modalHeight = constraints.maxHeight;
                        return SizedBox(
                          width: modalWidth,
                          height: modalHeight,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: MediaQuery(
                              data: MediaQuery.of(context).copyWith(size: Size(modalWidth, modalHeight)),
                              child: Theme(
                                data: Theme.of(context).copyWith(
                                  appBarTheme: Theme.of(context).appBarTheme.copyWith(
                                    elevation: 0,
                                    scrolledUnderElevation: 0,
                                    shadowColor: const Color(0xFF000007),
                                  ),
                                ),
                                child: Navigator(
                                  key: _contentNavKey,
                                  onGenerateRoute: (settings) => MaterialPageRoute(builder: (_) => screen),
                                ),
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

  Future<void> _confirmDesktopLogout(AuthProvider auth) async {
    final confirmed = await AppDialog.confirm(
      context: context,
      title: 'Keluar',
      description: 'Apakah Anda yakin ingin keluar dari akun ini?',
      confirmText: 'Keluar',
      cancelText: 'Batal',
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;
    await auth.logout();
    if (!mounted) return;
    final loginScreen = await resolveLoginScreen();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => loginScreen), (route) => false);
  }

  Future<void> _showDesktopReferralDialog(AuthProvider auth) async {
    final code = auth.referralCode;
    if (code == null || code.isEmpty) {
      showToast(msg: 'Kode referral belum tersedia untuk akun Anda');
      return;
    }
    final copy = await AppDialog.show(
      context: context,
      title: 'Kode Referral Anda',
      body: Container(
        width: double.infinity,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        decoration: BoxDecoration(
          color: primaryBlue50,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Text(code, style: const TextStyle(fontFamily: 'Gilroy Bold', fontSize: 20)),
      ),
      secondaryActionText: 'Tutup',
      primaryActionText: 'Salin',
    );
    if (copy == true) {
      await Clipboard.setData(ClipboardData(text: code));
      showToast(msg: 'Kode referral disalin');
    }
  }

  void _navigateToItem(Map<String, dynamic> item) {
    final cmd = (item['cmd'] ?? '').toString().toLowerCase();
    // 'pasca' adalah konvensi cmd untuk item Postpaid di seluruh app (lihat
    // reclassifyPostpaidItems, parseGroup(pembayaran, 'pasca')) — cek string
    // 'postpaid' saja tidak menangkap nama seperti "PLN Pasca"/"PLN Pascabayar".
    final isPostpaid = cmd == 'postpaid' ||
        cmd == 'pasca' ||
        resolvePpobRouteType(item) == 'postpaid' ||
        (item['category'] ?? '').toString().toLowerCase().contains('postpaid') ||
        (item['category'] ?? '').toString().toLowerCase().contains('pasca') ||
        (item['name'] ?? '').toString().toLowerCase().contains('postpaid') ||
        (item['name'] ?? '').toString().toLowerCase().contains('pasca') ||
        (item['brand'] ?? '').toString().toLowerCase().contains('bpjs') ||
        (item['brand'] ?? '').toString().toLowerCase().contains('pdam');

    setState(() {
      _activeSubMenuName = item['name'] as String?;
      if (isPostpaid) {
        _activeDesktopMenu = 'postpaid';
        _postpaidExpanded = true;
      } else {
        _activeDesktopMenu = 'prepaid';
        _prepaidExpanded = true;
      }
    });
    final brandLowerForBpjs = (item['brand'] ?? '').toString().toLowerCase();
    final categoryLowerForBpjs = (item['category'] ?? '').toString().toLowerCase();
    final nameLowerForBpjs = (item['name'] ?? '').toString().toLowerCase();
    if (brandLowerForBpjs.contains('bpjs') ||
        categoryLowerForBpjs.contains('bpjs') ||
        nameLowerForBpjs.contains('bpjs')) {
      _openTransaction(const BpjsScreen());
      return;
    }

    final brandLowerForPdam = (item['brand'] ?? '').toString().toLowerCase();
    final categoryLowerForPdam = (item['category'] ?? '').toString().toLowerCase();
    final nameLowerForPdam = (item['name'] ?? '').toString().toLowerCase();
    if (brandLowerForPdam.contains('pdam') ||
        categoryLowerForPdam.contains('pdam') ||
        nameLowerForPdam.contains('pdam')) {
      _openTransaction(const PdamScreen());
      return;
    }

    final routeType = resolvePpobRouteType(item);
    if (routeType == 'all_services') {
      _openTransaction(const PPOBAllServicesScreen());
    } else if (routeType == 'bank_transfer') {
      _openTransaction(const BankTransferScreen());
    } else if (routeType == 'qris_payment') {
      _openTransaction(const QrisScanScreen());
    } else if (routeType == 'topup_game_list') {
      final hardcodedGames = <Map<String, dynamic>>[
        {
          'name': 'Free Fire',
          'category': 'TopUp Game',
          'brand': 'FREE FIRE',
          'cmd': 'prepaid',
          'inquirySku': '',
          'gameCode': 'freefire',
          'isPromo': false,
        },
        {
          'name': 'Mobile Legend',
          'category': 'TopUp Game',
          'brand': 'MOBILE LEGEND',
          'cmd': 'prepaid',
          'inquirySku': 'MLU',
          'gameCode': 'mobilelegend',
          'isPromo': false,
        },
        {
          'name': 'Honor of Kings',
          'category': 'TopUp Game',
          'brand': 'HOK',
          'cmd': 'prepaid',
          'inquirySku': '',
          'gameCode': '',
          'isPromo': false,
        },
        {
          'name': 'Magic Chess',
          'category': 'TopUp Game',
          'brand': 'MAGIC CHESS',
          'cmd': 'prepaid',
          'inquirySku': '',
          'gameCode': '',
          'isPromo': false,
        },
        {
          'name': 'Roblox',
          'category': 'TopUp Game',
          'brand': 'ROBLOX',
          'cmd': 'prepaid',
          'inquirySku': '',
          'gameCode': '',
          'isPromo': false,
        },
        {
          'name': 'PUBG Mobile',
          'category': 'TopUp Game',
          'brand': 'PUBG MOBILE',
          'cmd': 'prepaid',
          'inquirySku': '',
          'gameCode': '',
          'isPromo': false,
        },
      ];
      _openTransaction(PPOBTopUpGameListScreen(
        items: hardcodedGames,
        title: (item['name'] ?? 'TopUp Game').toString().replaceAll('\n', ' '),
      ));
    } else if (routeType == 'postpaid') {
      final brandLower = (item['brand'] ?? '').toString().toLowerCase();
      if (brandLower.contains('pdam')) {
        _openTransaction(const PdamScreen());
      } else {
        _openTransaction(PPOBPostpaidScreen(
          brand: (item['brand'] ?? item['category'] ?? '').toString(),
          title: (item['name'] ?? '').toString(),
        ));
      }
    } else if (routeType == 'emoney_brand') {
      final cat = (item['category'] as String?)?.trim();
      final filter = (item['productTypeFilter'] ??
              item['product_type_filter'] ??
              item['product_type']) as String?;
      _openTransaction(PPOBEmoneyBrandScreen(
        category: (cat == null || cat.isEmpty) ? 'E-Wallet' : cat,
        title: 'Pilih ${item['name'] ?? cat ?? 'E-Wallet'}',
        productTypeFilter: filter,
      ));
    } else {
      final category = (item['category'] as String?)?.trim() ?? '';
      final cmd = (item['cmd'] as String?)?.trim() ?? 'prepaid';
      _openTransaction(PPOBProductScreen(
        category: category.isNotEmpty ? category : (item['name'] as String? ?? ''),
        title: item['name'] as String? ?? '',
        cmd: cmd,
        inquiryType: item['inquiryType'] as String?,
        initialBrand: item['initialBrand'] as String?,
        productTypeFilter: item['product_type_filter'] as String?,
        configInputLabel: item['input_label'] as String?,
        configInputHint: item['input_hint'] as String?,
        configInputKeyboard: item['input_keyboard'] as String?,
        configInputMinLength: (item['input_min_length'] as num?)?.toInt(),
        configInputMaxLength: (item['input_max_length'] as num?)?.toInt(),
        configProductLayout: item['product_layout'] as String?,
        configProductColumns: (item['product_columns'] as num?)?.toInt(),
        configShowBrandTabs: item['show_brand_tabs'] as bool?,
        configAutoDetectBrand: item['auto_detect_brand'] as bool?,
        configInquirySku: item['inquiry_sku'] as String?,
        configInquiryProvider: item['inquiry_provider'] as String?,
      ), wideDesktop: true);
    }
  }

}
