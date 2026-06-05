import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../utils/colornotifire.dart';
import '../../utils/media.dart';
import 'bayar_tagihan_screen.dart';
import 'merchant_kyc_screen.dart';

class LimitScreen extends StatefulWidget {
  const LimitScreen({Key? key}) : super(key: key);

  @override
  State<LimitScreen> createState() => _LimitScreenState();
}

class _LimitScreenState extends State<LimitScreen> {
  String _kycStatus = 'loading';
  bool _isLoadingDetail = true;
  double _kreditLimit = 0;
  double _usedAmount = 0;
  double _availableAmount = 0;
  String _dueDate = '-';
  int _daysLeft = 0;
  double _serviceFee = 0;
  int _tabIndex = 0; // 0 = Detail, 1 = Riwayat

  // Riwayat
  List<Map<String, dynamic>> _history = [];
  bool _isLoadingHistory = false;

  @override
  void initState() {
    super.initState();
    _checkKycStatus();
  }

  Future<void> _checkKycStatus() async {
    // Panggil ketiga endpoint paralel sejak awal. Kalau status bukan
    // 'approved', detail/history diabaikan (tidak ditampilkan). Total
    // waktu shimmer = max(t1, t2, t3) bukan t1 + t2 + t3.
    try {
      final results = await Future.wait([
        ApiService.getMerchantKycStatus(),
        ApiService.getMerchantLimitDetail(),
        ApiService.getLimitHistory(),
      ]);
      if (!mounted) return;

      final statusResp = results[0];
      final detailResp = results[1];
      final historyResp = results[2];

      final status = statusResp['status'] ?? 'none';
      setState(() => _kycStatus = status);

      // Detail
      if (detailResp['status'] == 'active') {
        final data = detailResp['data'] ?? {};
        setState(() {
          _kreditLimit = (data['kredit_limit'] ?? 0).toDouble();
          _usedAmount = (data['used_amount'] ?? 0).toDouble();
          _availableAmount = (data['available_amount'] ?? 0).toDouble();
          _dueDate = data['due_date'] ?? '-';
          _daysLeft = data['days_left'] ?? 0;
          _serviceFee = (data['service_fee'] ?? 0).toDouble();
        });
      }
      setState(() => _isLoadingDetail = false);

      // History
      final histData = historyResp['data'];
      final List<Map<String, dynamic>> items = [];
      if (histData is List) {
        for (final item in histData) {
          if (item is Map) {
            items.add(Map<String, dynamic>.from(item));
          }
        }
      }
      setState(() {
        _history = items;
        _isLoadingHistory = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _kycStatus = 'none';
          _isLoadingDetail = false;
          _isLoadingHistory = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    height = MediaQuery.of(context).size.height;
    width = MediaQuery.of(context).size.width;
    final notifire = Provider.of<ColorNotifire>(context, listen: true);
    final auth = Provider.of<AuthProvider>(context);
    final currencyFormat = NumberFormat('#,###', 'id_ID');
    final blueColor = notifire.getbluecolor as Color;
    final kreditVerified = auth.kreditVerified;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: _kycStatus == 'loading'
          ? _buildShimmer()
          : (!kreditVerified && _kycStatus == 'approved')
              ? _buildDeactivatedView(context, blueColor)
              : (!kreditVerified && _kycStatus != 'approved')
                  ? _buildNotVerifiedView(context, blueColor)
                  : _isLoadingDetail
                      ? _buildShimmer()
                      : _buildMainView(currencyFormat, blueColor),
    );
  }

  Widget _buildMainView(NumberFormat currencyFormat, Color blueColor) {
    final availablePercent = _kreditLimit > 0 ? _availableAmount / _kreditLimit : 1.0;
    final now = DateTime.now();
    final periode = 'Periode ${DateFormat('MMMM yyyy', 'id_ID').format(now)}';

    return Column(
      children: [
        // ── Blue Header ──
        Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            color: Color(0xFF040f85),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(24),
              bottomRight: Radius.circular(24),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // AppBar row
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Icon(Icons.chevron_left_rounded, color: Colors.white, size: 28),
                      ),
                      const Expanded(
                        child: Text(
                          'Detail Limit',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontFamily: 'Gilroy Bold',
                            fontSize: 18,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _showFiturInfo(context, blueColor),
                        child: const Icon(Icons.info_outline_rounded, color: Colors.white70, size: 22),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Total Limit
                  const Text(
                    'Total Limit',
                    style: TextStyle(color: Colors.white60, fontFamily: 'Gilroy Medium', fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Rp ${currencyFormat.format(_kreditLimit.toInt())}',
                    style: const TextStyle(color: Colors.white, fontFamily: 'Gilroy Bold', fontSize: 28),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    periode,
                    style: const TextStyle(color: Colors.white54, fontFamily: 'Gilroy Medium', fontSize: 12),
                  ),
                  const SizedBox(height: 18),
                  // Terpakai / Tersisa boxes
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Terpakai', style: TextStyle(color: Colors.white60, fontFamily: 'Gilroy Medium', fontSize: 11)),
                              const SizedBox(height: 4),
                              Text(
                                'Rp ${currencyFormat.format(_usedAmount.toInt())}',
                                style: const TextStyle(color: Colors.white, fontFamily: 'Gilroy Bold', fontSize: 16),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Tersisa', style: TextStyle(color: Colors.white60, fontFamily: 'Gilroy Medium', fontSize: 11)),
                              const SizedBox(height: 4),
                              Text(
                                'Rp ${currencyFormat.format(_availableAmount.toInt())}',
                                style: const TextStyle(color: Colors.white, fontFamily: 'Gilroy Bold', fontSize: 16),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Progress bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      height: 8,
                      child: LinearProgressIndicator(
                        value: availablePercent,
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // ── Tabs ──
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Row(
            children: [
              _buildTab('Detail', 0),
              const SizedBox(width: 12),
              _buildTab('Riwayat', 1),
            ],
          ),
        ),

        // ── Tab Content ──
        Expanded(
          child: _tabIndex == 0
              ? _buildDetailTab(currencyFormat, blueColor)
              : _buildRiwayatTab(currencyFormat),
        ),
      ],
    );
  }

  Widget _buildTab(String label, int index) {
    final isActive = _tabIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _tabIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? Colors.grey.shade300 : Colors.grey.shade300,
          ),
          boxShadow: isActive
              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: isActive ? 'Gilroy Bold' : 'Gilroy Medium',
            fontSize: 14,
            color: isActive ? const Color(0xFF1A1A1A) : Colors.grey[500],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailTab(NumberFormat currencyFormat, Color blueColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        children: [
          // Informasi Tagihan
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Informasi Tagihan',
                  style: TextStyle(color: Color(0xFF1A1A1A), fontFamily: 'Gilroy Bold', fontSize: 16),
                ),
                const SizedBox(height: 16),
                _infoRow('Total Tagihan', 'Rp ${currencyFormat.format(_usedAmount.toInt())}'),
                const SizedBox(height: 12),
                _infoRow(
                  'Jatuh Tempo',
                  _daysLeft > 0 ? '$_dueDate ($_daysLeft hari)' : _dueDate,
                  valueColor: const Color(0xFFE65100),
                ),
                const SizedBox(height: 12),
                _infoRow('Status', 'Aktif', valueColor: const Color(0xFF10B981)),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Bayar Tagihan button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _usedAmount > 0
                  ? () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BayarTagihanScreen(
                            totalTagihan: _usedAmount,
                            serviceFee: _serviceFee,
                          ),
                        ),
                      );
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF040f85),
                disabledBackgroundColor: Colors.grey[300],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: Text(
                'Bayar Tagihan',
                style: TextStyle(
                  color: _usedAmount > 0 ? Colors.white : Colors.grey[500],
                  fontFamily: 'Gilroy Bold',
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Cara kerja
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF040f85).withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF040f85).withValues(alpha: 0.15)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: Color(0xFF040f85), size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Cara kerja sistem limit',
                      style: TextStyle(color: Color(0xFF1A1A1A), fontFamily: 'Gilroy Bold', fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _bulletPoint('Gunakan limit untuk bertransaksi'),
                const SizedBox(height: 8),
                _bulletPoint('Bayar tagihan sebelum jatuh tempo'),
                const SizedBox(height: 8),
                _bulletPoint('Limit akan pulih setelah pembayaran'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRiwayatTab(NumberFormat currencyFormat) {
    if (_isLoadingHistory) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_history.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_rounded, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text(
              'Belum ada riwayat transaksi limit',
              style: TextStyle(color: Colors.grey[500], fontFamily: 'Gilroy Medium', fontSize: 14),
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      itemCount: _history.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final item = _history[i];
        final name = (item['account_name'] ?? item['notes'] ?? '-').toString();
        final amount = (item['total'] is num)
            ? (item['total'] as num).toDouble()
            : double.tryParse(item['total']?.toString() ?? '0') ?? 0;
        final limitPaid = item['limit_paid'] == true || item['limit_paid'] == 1;
        final createdAt = item['created_at']?.toString() ?? '';
        String dateStr = '';
        try {
          final dt = DateTime.parse(createdAt).toLocal();
          dateStr = DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(dt);
        } catch (_) {
          dateStr = createdAt;
        }

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.12)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF040f85).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.receipt_rounded, color: Color(0xFF040f85), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(fontFamily: 'Gilroy Bold', fontSize: 13, color: Color(0xFF1A1A1A)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dateStr,
                      style: TextStyle(fontFamily: 'Gilroy Medium', fontSize: 11, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Rp ${currencyFormat.format(amount.toInt())}',
                    style: const TextStyle(fontFamily: 'Gilroy Bold', fontSize: 13, color: Color(0xFF1A1A1A)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    limitPaid ? 'Lunas' : 'Belum Bayar',
                    style: TextStyle(
                      fontFamily: 'Gilroy Medium',
                      fontSize: 11,
                      color: limitPaid ? const Color(0xFF10B981) : const Color(0xFFED9D00),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _infoRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[600], fontFamily: 'Gilroy Medium', fontSize: 14)),
        Text(value, style: TextStyle(color: valueColor ?? const Color(0xFF1A1A1A), fontFamily: 'Gilroy Bold', fontSize: 14)),
      ],
    );
  }

  Widget _bulletPoint(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: TextStyle(color: Colors.grey[700], fontFamily: 'Gilroy Medium', fontSize: 13, height: 1.3)),
        ),
      ],
    );
  }

  void _showFiturInfo(BuildContext context, Color blueColor) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          decoration: const BoxDecoration(
            color: Color(0xFFF5F7FA),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 24),
              const Text('FITUR UTAMA MODIPAY', style: TextStyle(color: Color(0xFF1A1A1A), fontFamily: 'Gilroy Bold', fontSize: 18, letterSpacing: 0.5)),
              const SizedBox(height: 24),
              _fiturItem(icon: Icons.autorenew_rounded, title: 'Rolling Limit', desc: 'Gunakan limit hingga batas maksimal, bayar, dan pakai lagi.', color: blueColor),
              _fiturItem(icon: Icons.bolt_rounded, title: 'Instant Repayment', desc: 'Bayar tagihan, limit langsung kembali secara instan.', color: blueColor),
              _fiturItem(icon: Icons.qr_code_2_rounded, title: 'QRIS Otomatis', desc: 'Pembayaran mudah dengan QRIS statis, terverifikasi otomatis.', color: blueColor),
              _fiturItem(icon: Icons.ac_unit_rounded, title: 'Auto Freeze', desc: 'Akun akan diblokir otomatis jika tagihan melewati jatuh tempo.', color: blueColor),
              _fiturItem(icon: Icons.lock_rounded, title: 'Deposit Lock', desc: 'Deposit aman dan terkunci sebagai jaminan.', color: blueColor),
              _fiturItem(icon: Icons.monitor_heart_rounded, title: 'Monitoring Real-time', desc: 'Pantau limit, tagihan, dan transaksi secara real-time.', color: blueColor),
            ],
          ),
        );
      },
    );
  }

  Widget _fiturItem({required IconData icon, required String title, required String desc, required Color color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 42, height: 42, decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 22)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Color(0xFF1A1A1A), fontFamily: 'Gilroy Bold', fontSize: 14)),
                const SizedBox(height: 3),
                Text(desc, style: TextStyle(color: Colors.grey[600], fontFamily: 'Gilroy Medium', fontSize: 13, height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmer() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Column(
            children: [
              Container(width: double.infinity, height: 200, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16))),
              const SizedBox(height: 16),
              Container(width: double.infinity, height: 140, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16))),
              const SizedBox(height: 20),
              Container(width: double.infinity, height: 52, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeactivatedView(BuildContext context, Color blueColor) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: width / 10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(width: 80, height: 80, decoration: const BoxDecoration(color: Color(0xFFFFEBEE), shape: BoxShape.circle), child: const Icon(Icons.block_rounded, color: Color(0xFFD32F2F), size: 40)),
            const SizedBox(height: 20),
            const Text('Fitur Limit Non-Aktif', style: TextStyle(color: Color(0xFF1A1A1A), fontFamily: 'Gilroy Bold', fontSize: 18)),
            const SizedBox(height: 10),
            Text('Maaf fitur limit anda non-aktif, silahkan hubungi admin.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[500], fontFamily: 'Gilroy Medium', fontSize: 14, height: 1.4)),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity, height: 48,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(side: BorderSide(color: blueColor), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: Text('Kembali', style: TextStyle(color: blueColor, fontFamily: 'Gilroy Bold', fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotVerifiedView(BuildContext context, Color blueColor) {
    if (_kycStatus == 'pending') {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: width / 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(width: 80, height: 80, decoration: const BoxDecoration(color: Color(0xFFFFF8E1), shape: BoxShape.circle), child: const Icon(Icons.hourglass_top_rounded, color: Color(0xFFF59E0B), size: 40)),
              const SizedBox(height: 20),
              const Text('Menunggu Verifikasi', style: TextStyle(color: Color(0xFF1A1A1A), fontFamily: 'Gilroy Bold', fontSize: 18)),
              const SizedBox(height: 10),
              Text('Pengajuan KYC Anda sedang dalam proses review. Mohon tunggu konfirmasi dari admin.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[500], fontFamily: 'Gilroy Medium', fontSize: 14, height: 1.4)),
              const SizedBox(height: 24),
              SizedBox(width: double.infinity, height: 48, child: OutlinedButton(onPressed: () => Navigator.pop(context), style: OutlinedButton.styleFrom(side: BorderSide(color: blueColor), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: Text('Kembali', style: TextStyle(color: blueColor, fontFamily: 'Gilroy Bold', fontSize: 15)))),
            ],
          ),
        ),
      );
    }

    if (_kycStatus == 'rejected') {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: width / 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(width: 80, height: 80, decoration: const BoxDecoration(color: Color(0xFFFFEBEE), shape: BoxShape.circle), child: const Icon(Icons.cancel_rounded, color: Color(0xFFD32F2F), size: 40)),
              const SizedBox(height: 20),
              const Text('Pengajuan Ditolak', style: TextStyle(color: Color(0xFF1A1A1A), fontFamily: 'Gilroy Bold', fontSize: 18)),
              const SizedBox(height: 10),
              Text('Pengajuan KYC Anda ditolak. Silahkan ajukan kembali dengan data yang benar.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[500], fontFamily: 'Gilroy Medium', fontSize: 14, height: 1.4)),
              const SizedBox(height: 24),
              SizedBox(width: double.infinity, height: 48, child: ElevatedButton(onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (_) => const MerchantKycScreen())); }, style: ElevatedButton.styleFrom(backgroundColor: blueColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0), child: const Text('Ajukan Kembali', style: TextStyle(color: Colors.white, fontFamily: 'Gilroy Bold', fontSize: 15)))),
              const SizedBox(height: 12),
              SizedBox(width: double.infinity, height: 48, child: OutlinedButton(onPressed: () => Navigator.pop(context), style: OutlinedButton.styleFrom(side: BorderSide(color: blueColor), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: Text('Kembali', style: TextStyle(color: blueColor, fontFamily: 'Gilroy Bold', fontSize: 15)))),
            ],
          ),
        ),
      );
    }

    // Default: none
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: width / 10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(width: 80, height: 80, decoration: BoxDecoration(color: Colors.grey[100], shape: BoxShape.circle), child: Icon(Icons.lock_outline_rounded, color: Colors.grey[400], size: 40)),
            const SizedBox(height: 20),
            const Text('Fitur Limit Belum Aktif', style: TextStyle(color: Color(0xFF1A1A1A), fontFamily: 'Gilroy Bold', fontSize: 18)),
            const SizedBox(height: 10),
            Text('Lengkapi verifikasi merchant untuk mengaktifkan fitur limit transaksi.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[500], fontFamily: 'Gilroy Medium', fontSize: 14, height: 1.4)),
            const SizedBox(height: 24),
            SizedBox(width: double.infinity, height: 48, child: ElevatedButton(onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (_) => const MerchantKycScreen())); }, style: ElevatedButton.styleFrom(backgroundColor: blueColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0), child: const Text('Verifikasi Sekarang', style: TextStyle(color: Colors.white, fontFamily: 'Gilroy Bold', fontSize: 15)))),
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, height: 48, child: OutlinedButton(onPressed: () => Navigator.pop(context), style: OutlinedButton.styleFrom(side: BorderSide(color: blueColor), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: Text('Kembali', style: TextStyle(color: blueColor, fontFamily: 'Gilroy Bold', fontSize: 15)))),
          ],
        ),
      ),
    );
  }
}
