import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../services/api_service.dart';
import '../utils/color.dart';
import '../utils/colornotifire.dart';
import '../utils/media.dart';
import '../utils/responsive.dart';
import '../utils/transaction_helpers.dart';
import '../widgets/desktop_title_wrapper.dart';

enum _ReportPeriod { today, week, month, all, custom }

class LaporanScreen extends StatefulWidget {
  const LaporanScreen({Key? key}) : super(key: key);

  @override
  State<LaporanScreen> createState() => _LaporanScreenState();
}

class _LaporanScreenState extends State<LaporanScreen> {
  late ColorNotifire notifire;

  static const _accent = Color(0xFF20467A);

  bool _isLoading = true;
  bool _hasError = false;
  List<Map<String, dynamic>> _items = [];

  _ReportPeriod _period = _ReportPeriod.today;
  DateTimeRange? _customRange;

  final _currencyFormat = NumberFormat('#,###', 'id_ID');

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      final transactions = <Map<String, dynamic>>[];
      var page = 1;
      var lastPage = 1;
      do {
        final response = await ApiService.getTransactions(page: page);
        transactions.addAll(List<Map<String, dynamic>>.from(response['data'] ?? []));
        lastPage = response['last_page'] ?? 1;
        page++;
      } while (page <= lastPage && page <= 50);

      final topups = await ApiService.getRecentTopups();

      final txOrderIds = transactions.map((t) => t['order_id']?.toString() ?? '').toSet();
      final topupItems = topups.where((t) {
        if (t['status'] == 'completed') {
          return !txOrderIds.contains(t['reference_id']?.toString() ?? '');
        }
        return true;
      }).map((t) {
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
          'name': 'Top Up / Setoran',
          'amount': t['amount']?.toString() ?? '0',
          'type': 'income',
          'category': 'topup',
          'order_id': t['reference_id'] ?? '',
          'created_at': t['created_at'],
          'status_label': statusLabel,
        };
      }).toList();

      final completedTx = transactions.map((t) {
        final txStatus = t['status']?.toString() ?? 'completed';
        String statusLabel;
        switch (txStatus) {
          case 'pending':
            statusLabel = 'Menunggu';
            break;
          case 'failed':
            statusLabel = 'Gagal';
            break;
          default:
            statusLabel = '';
        }
        return <String, dynamic>{
          ...t,
          'status_label': statusLabel,
        };
      }).toList();

      final all = [...topupItems, ...completedTx];
      all.sort((a, b) => parseDateTime(b['created_at']).compareTo(parseDateTime(a['created_at'])));

      if (mounted) {
        setState(() {
          _items = all;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    }
  }

  bool _isSuccess(Map<String, dynamic> item) =>
      (item['status_label'] ?? '').toString().isEmpty;

  bool _isSameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _inSelectedPeriod(DateTime date) {
    final now = DateTime.now();
    switch (_period) {
      case _ReportPeriod.today:
        return _isSameDate(date, now);
      case _ReportPeriod.week:
        final start = DateTime(now.year, now.month, now.day)
            .subtract(const Duration(days: 6));
        return !date.isBefore(start);
      case _ReportPeriod.month:
        return date.year == now.year && date.month == now.month;
      case _ReportPeriod.all:
        return true;
      case _ReportPeriod.custom:
        if (_customRange == null) return true;
        final d = DateTime(date.year, date.month, date.day);
        final start = DateTime(_customRange!.start.year, _customRange!.start.month, _customRange!.start.day);
        final end = DateTime(_customRange!.end.year, _customRange!.end.month, _customRange!.end.day);
        return !d.isBefore(start) && !d.isAfter(end);
    }
  }

  List<Map<String, dynamic>> get _filteredItems =>
      _items.where((tx) => _inSelectedPeriod(parseDateTime(tx['created_at']))).toList();

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      initialDateRange: _customRange ??
          DateTimeRange(start: now.subtract(const Duration(days: 7)), end: now),
      helpText: 'Pilih Rentang Tanggal',
      cancelText: 'Batal',
      confirmText: 'Pilih',
    );
    if (picked != null) {
      setState(() {
        _customRange = picked;
        _period = _ReportPeriod.custom;
      });
    }
  }

  String _formatCurrency(double v) => 'Rp ${_currencyFormat.format(v.round())}';

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

  @override
  Widget build(BuildContext context) {
    notifire = Provider.of<ColorNotifire>(context, listen: true);
    final items = _filteredItems;

    double totalPenjualan = 0;
    double totalSetoran = 0;
    int successCount = 0;
    int failedCount = 0;
    int pendingCount = 0;

    for (final tx in items) {
      if (_isSuccess(tx)) {
        successCount++;
        final amount = effectiveTransactionTotal(tx);
        final category = (tx['category'] ?? '').toString().toLowerCase();
        if (category.contains('topup')) {
          totalSetoran += amount;
        } else {
          totalPenjualan += amount;
        }
      } else if (tx['status_label'] == 'Gagal') {
        failedCount++;
      } else {
        pendingCount++;
      }
    }

    final totalOverall = totalPenjualan + totalSetoran;

    if (isDesktop(context)) {
      return _buildDesktopLayout(
        context,
        items: items,
        totalPenjualan: totalPenjualan,
        totalSetoran: totalSetoran,
        totalOverall: totalOverall,
        successCount: successCount,
        failedCount: failedCount,
        pendingCount: pendingCount,
      );
    }

    return _buildMobileLayout(
      context,
      items: items,
      totalPenjualan: totalPenjualan,
      totalSetoran: totalSetoran,
      totalOverall: totalOverall,
      successCount: successCount,
      failedCount: failedCount,
      pendingCount: pendingCount,
    );
  }

  // ------------------------- mobile layout -------------------------

  Widget _buildMobileLayout(
    BuildContext context, {
    required List<Map<String, dynamic>> items,
    required double totalPenjualan,
    required double totalSetoran,
    required double totalOverall,
    required int successCount,
    required int failedCount,
    required int pendingCount,
  }) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF3F6FB),
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Icon(Icons.arrow_back, color: notifire.getdarkscolor),
        ),
        title: DesktopTitleWrapper(
          child: Text(
            'Laporan',
            style: TextStyle(
              color: notifire.getdarkscolor,
              fontSize: height / 42,
              fontFamily: 'Gilroy Bold',
            ),
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Muat Ulang',
            icon: Icon(Icons.refresh_rounded, color: notifire.getdarkscolor),
            onPressed: _isLoading ? null : _loadReport,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadReport,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_hasError)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          'Gagal memuat sebagian data laporan.',
                          style: TextStyle(fontFamily: 'Gilroy Medium', color: Colors.red.shade400, fontSize: 12),
                        ),
                      ),
                    _buildPeriodSelector(),
                    const SizedBox(height: 16),
                    _buildHighlightCards(totalOverall, successCount),
                    const SizedBox(height: 12),
                    _buildBreakdownCard(totalPenjualan, totalSetoran, failedCount, pendingCount),
                    const SizedBox(height: 20),
                    Text(
                      'Rincian Transaksi',
                      style: TextStyle(
                        fontFamily: 'Gilroy Bold',
                        fontSize: 15,
                        color: notifire.getdarkscolor,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (items.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.receipt_long_rounded, size: 48, color: Colors.grey.withOpacity(0.3)),
                              const SizedBox(height: 12),
                              Text(
                                'Tidak ada transaksi pada periode ini',
                                style: TextStyle(fontFamily: 'Gilroy Medium', color: notifire.getdarkgreycolor),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ...items.map(_buildTransactionRow),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _periodChip(String label, _ReportPeriod value) {
    final selected = _period == value;
    return GestureDetector(
      onTap: () => setState(() => _period = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? _accent : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? _accent : const Color(0xFFD9E3F0)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: selected ? 'Gilroy Bold' : 'Gilroy Medium',
            fontSize: 12.5,
            color: selected ? Colors.white : const Color(0xFF44506A),
          ),
        ),
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _periodChip('Hari Ini', _ReportPeriod.today),
          const SizedBox(width: 8),
          _periodChip('7 Hari', _ReportPeriod.week),
          const SizedBox(width: 8),
          _periodChip('Bulan Ini', _ReportPeriod.month),
          const SizedBox(width: 8),
          _periodChip('Semua', _ReportPeriod.all),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _pickCustomRange,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: _period == _ReportPeriod.custom ? _accent : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _period == _ReportPeriod.custom ? _accent : const Color(0xFFD9E3F0),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.date_range_rounded,
                    size: 14,
                    color: _period == _ReportPeriod.custom ? Colors.white : const Color(0xFF44506A),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _period == _ReportPeriod.custom && _customRange != null
                        ? '${DateFormat('d/M').format(_customRange!.start)} - ${DateFormat('d/M').format(_customRange!.end)}'
                        : 'Pilih Tanggal',
                    style: TextStyle(
                      fontFamily: _period == _ReportPeriod.custom ? 'Gilroy Bold' : 'Gilroy Medium',
                      fontSize: 12.5,
                      color: _period == _ReportPeriod.custom ? Colors.white : const Color(0xFF44506A),
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

  Widget _highlightCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Gilroy Bold',
                fontSize: 17,
                color: notifire.getdarkscolor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontFamily: 'Gilroy Medium',
                fontSize: 11.5,
                color: notifire.getdarkgreycolor.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHighlightCards(double totalOverall, int successCount) {
    return Row(
      children: [
        _highlightCard(
          title: 'Total Penjualan/Setoran',
          value: _formatCurrency(totalOverall),
          icon: Icons.payments_rounded,
          color: const Color(0xFF2E7D32),
        ),
        const SizedBox(width: 12),
        _highlightCard(
          title: 'Jumlah Transaksi Sukses',
          value: '$successCount',
          icon: Icons.check_circle_rounded,
          color: _accent,
        ),
      ],
    );
  }

  Widget _breakdownRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Gilroy Medium',
              fontSize: 13,
              color: notifire.getdarkgreycolor,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Gilroy Bold',
              fontSize: 13,
              color: valueColor ?? notifire.getdarkscolor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownCard(double totalPenjualan, double totalSetoran, int failedCount, int pendingCount) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          _breakdownRow('Total Penjualan', _formatCurrency(totalPenjualan)),
          const Divider(height: 1),
          _breakdownRow('Total Setoran', _formatCurrency(totalSetoran)),
          const Divider(height: 1),
          _breakdownRow('Transaksi Menunggu', '$pendingCount', valueColor: Colors.orange),
          const Divider(height: 1),
          _breakdownRow('Transaksi Gagal', '$failedCount', valueColor: Colors.red),
        ],
      ),
    );
  }

  Widget _buildTransactionRow(Map<String, dynamic> tx) {
    final statusLabel = (tx['status_label'] ?? '').toString();
    final isSuccess = statusLabel.isEmpty;
    final isFailed = statusLabel == 'Gagal';
    final statusColor = isSuccess
        ? const Color(0xFF2E7D32)
        : (isFailed ? Colors.red : Colors.orange);
    final isIncome = tx['type'] == 'income';
    final category = (tx['category'] ?? '').toString();
    final amount = effectiveTransactionTotal(tx);
    final dateStr = tx['created_at'] != null
        ? DateFormat('d MMM yyyy • HH:mm', 'id_ID').format(parseDateTime(tx['created_at']))
        : '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              height: 40,
              width: 40,
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_iconForCategory(category, isIncome), color: statusColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tx['name'] ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontFamily: 'Gilroy Bold', fontSize: 13.5, color: notifire.getdarkscolor),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    dateStr,
                    style: TextStyle(fontFamily: 'Gilroy Medium', fontSize: 11, color: notifire.getdarkgreycolor.withOpacity(0.7)),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatCurrency(amount),
                  style: TextStyle(fontFamily: 'Gilroy Bold', fontSize: 13, color: notifire.getdarkscolor),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isSuccess ? 'Sukses' : statusLabel,
                    style: TextStyle(fontFamily: 'Gilroy Bold', fontSize: 10, color: statusColor),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------- desktop layout -------------------------
  //
  // Meniru gaya "Riwayat Transaksi" (lihat _buildDesktopTableCard di
  // seealltransaction.dart): header + subjudul, kartu ringkasan putih,
  // lalu satu kartu tabel putih berisi filter periode & daftar transaksi
  // bergaya tabel, memakai token warna/typografi desktop yang sama.

  Widget _buildDesktopLayout(
    BuildContext context, {
    required List<Map<String, dynamic>> items,
    required double totalPenjualan,
    required double totalSetoran,
    required double totalOverall,
    required int successCount,
    required int failedCount,
    required int pendingCount,
  }) {
    return Scaffold(
      backgroundColor: desktopSurfacePage,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Laporan',
                  style: GoogleFonts.hankenGrotesk(
                    fontWeight: FontWeight.w700,
                    fontSize: 22,
                    color: desktopTextPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: desktopTextSecondary, size: 20),
                  onPressed: _isLoading ? null : _loadReport,
                  tooltip: 'Refresh',
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Ringkasan penjualan, setoran, dan transaksi Anda',
              style: GoogleFonts.hankenGrotesk(fontSize: 13, color: desktopTextSecondary),
            ),
            const SizedBox(height: 20),
            if (_hasError)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'Gagal memuat sebagian data laporan.',
                  style: GoogleFonts.hankenGrotesk(color: desktopErrorRed, fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
              ),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _desktopHighlightCard(
                    title: 'Total Penjualan/Setoran',
                    value: _formatCurrency(totalOverall),
                    icon: Icons.payments_rounded,
                    color: desktopSuccessFg,
                  ),
                  const SizedBox(width: 16),
                  _desktopHighlightCard(
                    title: 'Jumlah Transaksi Sukses',
                    value: '$successCount',
                    icon: Icons.check_circle_rounded,
                    color: desktopAccentBlue,
                  ),
                  const SizedBox(width: 16),
                  _desktopHighlightCard(
                    title: 'Total Penjualan',
                    value: _formatCurrency(totalPenjualan),
                    icon: Icons.storefront_rounded,
                    color: desktopPrimaryBtn,
                  ),
                  const SizedBox(width: 16),
                  _desktopHighlightCard(
                    title: 'Total Setoran',
                    value: _formatCurrency(totalSetoran),
                    icon: Icons.account_balance_wallet_rounded,
                    color: desktopWarningAmber,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildDesktopTableCard(items, failedCount, pendingCount),
            ],
          ],
        ),
      ),
    );
  }

  Widget _desktopHighlightCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 14),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.hankenGrotesk(fontWeight: FontWeight.w700, fontSize: 18, color: desktopTextPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: GoogleFonts.hankenGrotesk(fontWeight: FontWeight.w500, fontSize: 12, color: desktopTextSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _desktopPeriodChip(String label, _ReportPeriod value) {
    final selected = _period == value;
    return GestureDetector(
      onTap: () => setState(() => _period = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? desktopPrimaryBtn : desktopSurfacePage,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? Colors.transparent : desktopBorder.withOpacity(0.4)),
        ),
        child: Text(
          label,
          style: GoogleFonts.hankenGrotesk(
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 12.5,
            color: selected ? Colors.white : desktopTextSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopTableCard(List<Map<String, dynamic>> items, int failedCount, int pendingCount) {
    final df = DateFormat('d MMM yyyy HH:mm', 'id_ID');
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
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _desktopPeriodChip('Hari Ini', _ReportPeriod.today),
              _desktopPeriodChip('7 Hari', _ReportPeriod.week),
              _desktopPeriodChip('Bulan Ini', _ReportPeriod.month),
              _desktopPeriodChip('Semua', _ReportPeriod.all),
              OutlinedButton.icon(
                onPressed: _pickCustomRange,
                icon: const Icon(Icons.date_range_rounded, size: 16),
                label: Text(
                  _period == _ReportPeriod.custom && _customRange != null
                      ? '${DateFormat('d/M').format(_customRange!.start)} - ${DateFormat('d/M').format(_customRange!.end)}'
                      : 'Pilih Tanggal',
                  style: GoogleFonts.hankenGrotesk(fontWeight: FontWeight.w600, fontSize: 12.5),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: desktopPrimaryBtn,
                  backgroundColor: Colors.white,
                  side: BorderSide(color: desktopBorder.withOpacity(0.8)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Menunggu: $pendingCount   •   Gagal: $failedCount',
                style: GoogleFonts.hankenGrotesk(fontWeight: FontWeight.w500, fontSize: 12, color: desktopTextSecondary),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.receipt_long_rounded, size: 56, color: desktopTextSecondary.withOpacity(0.2)),
                    const SizedBox(height: 16),
                    Text(
                      'Tidak ada transaksi pada periode ini',
                      style: GoogleFonts.hankenGrotesk(fontWeight: FontWeight.w700, color: desktopTextSecondary, fontSize: 15),
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
                    child: Text('Tanggal',
                        style: GoogleFonts.hankenGrotesk(fontWeight: FontWeight.w700, fontSize: 12, color: desktopTextSecondary)),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text('Produk',
                        style: GoogleFonts.hankenGrotesk(fontWeight: FontWeight.w700, fontSize: 12, color: desktopTextSecondary)),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text('Status',
                        style: GoogleFonts.hankenGrotesk(fontWeight: FontWeight.w700, fontSize: 12, color: desktopTextSecondary)),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Nominal',
                      textAlign: TextAlign.right,
                      style: GoogleFonts.hankenGrotesk(fontWeight: FontWeight.w700, fontSize: 12, color: desktopTextSecondary),
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: desktopBorder.withOpacity(0.5)),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              itemBuilder: (context, idx) {
                final item = items[idx];
                final statusLabel = (item['status_label'] ?? '').toString();
                final isSuccess = statusLabel.isEmpty;
                final isFailed = statusLabel == 'Gagal';
                final statusBg = isSuccess
                    ? desktopSuccessBg
                    : (isFailed ? desktopErrorRed.withOpacity(0.1) : desktopWarningAmber.withOpacity(0.12));
                final statusFg = isSuccess ? desktopSuccessFg : (isFailed ? desktopErrorRed : desktopWarningAmber);
                final isIncome = item['type'] == 'income';
                final category = (item['category'] ?? '').toString();
                final amount = effectiveTransactionTotal(item);
                final amountStr = (isSuccess)
                    ? (isIncome ? '+${_formatCurrency(amount)}' : '-${_formatCurrency(amount)}')
                    : _formatCurrency(amount);

                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: desktopBorder.withOpacity(0.2), width: 1)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          item['created_at'] != null ? df.format(parseDateTime(item['created_at'])) : '-',
                          style: GoogleFonts.hankenGrotesk(fontWeight: FontWeight.w500, fontSize: 13, color: desktopTextSecondary),
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
                              child: Icon(_iconForCategory(category, isIncome), size: 14, color: desktopAccentBlue),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                (item['name'] ?? '').toString(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.hankenGrotesk(fontWeight: FontWeight.w600, fontSize: 13, color: desktopTextPrimary),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(6)),
                            child: Text(
                              isSuccess ? 'Berhasil' : statusLabel,
                              style: GoogleFonts.hankenGrotesk(fontWeight: FontWeight.w700, fontSize: 10.5, color: statusFg),
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
                            color: isSuccess ? (isIncome ? desktopSuccessFg : desktopErrorRed) : desktopTextSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
