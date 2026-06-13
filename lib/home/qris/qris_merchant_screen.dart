import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../services/tts_service.dart';
import '../../utils/colornotifire.dart';
import '../../utils/media.dart';

/// Parse server datetime string as UTC → local.
DateTime _parseServerDt(String s) {
  final dt = DateTime.parse(s);
  if (dt.isUtc) return dt.toLocal();
  // Server sends "2026-04-08 10:00:00" without Z — treat as UTC
  return DateTime.utc(dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second).toLocal();
}

class QrisMerchantScreen extends StatefulWidget {
  const QrisMerchantScreen({Key? key}) : super(key: key);

  @override
  State<QrisMerchantScreen> createState() => _QrisMerchantScreenState();
}

class _QrisMerchantScreenState extends State<QrisMerchantScreen> {
  late ColorNotifire notifire;
  final _currencyFormat = NumberFormat('#,###', 'id_ID');
  List<Map<String, dynamic>> _transactions = [];
  bool _isLoading = true;
  Map<String, dynamic>? _merchantInfo;
  String _selectedFilter = 'Semua';
  Timer? _pollTimer;
  String? _pendingRefId;

  @override
  void initState() {
    super.initState();
    _loadDarkMode();
    _loadData();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadDarkMode() async {
    final prefs = await SharedPreferences.getInstance();
    bool? prev = prefs.getBool("setIsDark");
    if (prev != null) notifire.setIsDark = prev;
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        ApiService.getQrisMerchantStatus(),
        ApiService.getQrisTransactions(),
      ]);

      if (!mounted) return;

      final statusRes = results[0];
      final txRes = results[1];

      final oldCompletedIds = _transactions
          .where((t) => t['status'] == 'completed')
          .map((t) => t['id'])
          .toSet();

      setState(() {
        if (statusRes['status'] == 'success') {
          _merchantInfo = statusRes['data'];
        }
        if (txRes['status'] == 'success' && txRes['data'] != null) {
          _transactions = List<Map<String, dynamic>>.from(txRes['data']);
        }
        _isLoading = false;
      });

      // Check for newly completed payments → announce via TTS and go directly to receipt
      final newCompleted = _transactions.where(
        (t) => t['status'] == 'completed' && !oldCompletedIds.contains(t['id']),
      );
      if (newCompleted.isNotEmpty && oldCompletedIds.isNotEmpty) {
        for (final tx in newCompleted) {
          TtsService.instance.speak(_buildPaymentVoiceMessage(tx));
        }
        _showReceiptScreen(newCompleted.first);
      }

      // Also refresh profile to get latest qris_balance
      Provider.of<AuthProvider>(context, listen: false).fetchProfile();
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredTransactions {
    if (_selectedFilter == 'Semua') return _transactions;
    final statusMap = {
      'Berhasil': 'completed',
      'Menunggu': 'pending',
      'Gagal': 'failed',
      'Kedaluwarsa': 'expired',
    };
    final status = statusMap[_selectedFilter];
    return _transactions.where((t) => t['status'] == status).toList();
  }

  String _formatCurrency(dynamic amount) {
    double a = 0;
    if (amount is int) a = amount.toDouble();
    else if (amount is double) a = amount;
    else if (amount is String) a = double.tryParse(amount) ?? 0;
    return 'Rp ${_currencyFormat.format(a.toInt())}';
  }

  // Announced amount adds a 0.3% admin fee when the transfer exceeds Rp 500.000.
  String _buildPaymentVoiceMessage(Map<String, dynamic> tx) {
    final payer = tx['payer_name'] ?? 'Pelanggan';

    double amount = 0;
    final rawAmount = tx['amount'];
    if (rawAmount is int) amount = rawAmount.toDouble();
    else if (rawAmount is double) amount = rawAmount;
    else if (rawAmount is String) amount = double.tryParse(rawAmount) ?? 0;

    double total = amount;
    if (amount > 500000) {
      total += amount * 0.003;
    }
    final totalRounded = total.round();

    return 'Pembayaran dari $payer sebesar $totalRounded rupiah telah kamu terima. '
        'Terima kasih sudah menggunakan modipay';
  }

  void _showCreatePayment() {
    final amountController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: EdgeInsets.only(
          left: 24, right: 24, top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Buat Pembayaran QRIS',
              style: TextStyle(color: Color(0xFF111827), fontFamily: 'Gilroy Bold', fontSize: 18),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Color(0xFF111827), fontFamily: 'Gilroy Bold', fontSize: 24),
              textAlign: TextAlign.center,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                hintText: '0',
                hintStyle: TextStyle(color: Colors.grey.shade300, fontFamily: 'Gilroy Bold', fontSize: 24),
                prefixText: 'Rp ',
                prefixStyle: const TextStyle(color: Color(0xFF111827), fontFamily: 'Gilroy Bold', fontSize: 24),
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFF0D47A1)),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Minimal Rp 1.000',
              style: TextStyle(color: Colors.grey.shade500, fontFamily: 'Gilroy Medium', fontSize: 12),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () async {
                  final amount = int.tryParse(amountController.text) ?? 0;
                  if (amount < 1000) {
                    Fluttertoast.showToast(msg: 'Minimal Rp 1.000');
                    return;
                  }
                  Navigator.pop(ctx);
                  _createPayment(amount);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D47A1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: const Text('Buat QRIS', style: TextStyle(color: Colors.white, fontFamily: 'Gilroy Bold', fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createPayment(int amount) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: Color(0xFF0D47A1))),
    );

    try {
      final res = await ApiService.createQrisPayment(amount);
      if (!mounted) return;
      Navigator.pop(context); // close loading

      if (res['status'] == 'success' && res['data'] != null) {
        final data = res['data'];
        _showQrisDialog(data);
      } else {
        Fluttertoast.showToast(msg: res['message'] ?? 'Gagal membuat QRIS');
      }
    } catch (_) {
      if (mounted) Navigator.pop(context);
      Fluttertoast.showToast(msg: 'Kesalahan koneksi');
    }
  }

  void _showQrisDialog(Map<String, dynamic> data) {
    final qrisString = data['qris_string'] ?? '';
    final amount = data['amount'] ?? 0;
    final refId = data['reference_id'] ?? '';
    final expiresAt = data['expires_at'];

    _pendingRefId = refId;
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _pollPaymentStatus());

    DateTime? expiry;
    if (expiresAt != null) {
      try { expiry = _parseServerDt(expiresAt); } catch (_) {}
    }
    expiry ??= DateTime.now().add(const Duration(minutes: 15));

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _QrisPaymentDialog(
        qrisString: qrisString,
        amount: amount,
        refId: refId,
        expiry: expiry!,
        formatCurrency: _formatCurrency,
        onClose: () {
          _pollTimer?.cancel();
          _pendingRefId = null;
          Navigator.pop(ctx);
          _loadData();
        },
      ),
    );
  }

  Future<void> _pollPaymentStatus() async {
    if (_pendingRefId == null || !mounted) return;
    try {
      final res = await ApiService.getQrisTransactions();
      if (!mounted || res['status'] != 'success' || res['data'] == null) return;
      final txList = List<Map<String, dynamic>>.from(res['data']);
      final tx = txList.firstWhere(
        (t) => t['reference_id'] == _pendingRefId,
        orElse: () => {},
      );
      if (tx.isNotEmpty && tx['status'] == 'completed') {
        _pollTimer?.cancel();
        _pendingRefId = null;
        if (Navigator.canPop(context)) Navigator.pop(context);
        await _loadData();
      }
    } catch (_) {}
  }

  void _showReceiptScreen(Map<String, dynamic> tx) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _QrisReceiptScreen(
          tx: tx,
          merchantName: _merchantInfo?['merchant']?['business_name'] ?? 'Merchant',
          formatCurrency: _formatCurrency,
        ),
      ),
    );
  }

  void _showWithdraw() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final qrisBalance = double.tryParse(auth.qrisBalance) ?? 0;
    final amountController = TextEditingController();
    final pinControllers = List.generate(4, (_) => TextEditingController());
    final pinFocusNodes = List.generate(4, (_) => FocusNode());
    bool showPin = false;
    bool isProcessing = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.only(
            left: 24, right: 24, top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                showPin ? 'Masukkan PIN' : 'Tarik ke Saldo Utama',
                style: const TextStyle(color: Color(0xFF111827), fontFamily: 'Gilroy Bold', fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                'Saldo QRIS: ${_formatCurrency(qrisBalance)}',
                style: TextStyle(color: Colors.grey.shade500, fontFamily: 'Gilroy Medium', fontSize: 14),
              ),
              const SizedBox(height: 20),

              if (!showPin) ...[
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Color(0xFF111827), fontFamily: 'Gilroy Bold', fontSize: 22),
                  textAlign: TextAlign.center,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    hintText: '0',
                    hintStyle: TextStyle(color: Colors.grey.shade300, fontFamily: 'Gilroy Bold', fontSize: 22),
                    prefixText: 'Rp ',
                    prefixStyle: const TextStyle(color: Color(0xFF111827), fontFamily: 'Gilroy Bold', fontSize: 22),
                    filled: true,
                    fillColor: const Color(0xFFF9FAFB),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade200)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade200)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF0D47A1))),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      final amount = double.tryParse(amountController.text) ?? 0;
                      if (amount < 1000) {
                        Fluttertoast.showToast(msg: 'Minimal Rp 1.000');
                        return;
                      }
                      if (amount > qrisBalance) {
                        Fluttertoast.showToast(msg: 'Saldo QRIS tidak mencukupi');
                        return;
                      }
                      if (!auth.pinRequired) {
                        setSheetState(() => isProcessing = true);
                        ApiService.withdrawQrisBalance(amount: amount, pin: '').then((res) {
                          Navigator.pop(ctx);
                          if (res.containsKey('balance')) {
                            Provider.of<AuthProvider>(context, listen: false).fetchProfile();
                            _loadData();
                            Fluttertoast.showToast(msg: 'Penarikan berhasil');
                          } else {
                            Fluttertoast.showToast(msg: res['message'] ?? 'Penarikan gagal');
                          }
                        }).catchError((_) {
                          Navigator.pop(ctx);
                          Fluttertoast.showToast(msg: 'Kesalahan koneksi');
                        });
                        return;
                      }
                      setSheetState(() => showPin = true);
                      WidgetsBinding.instance.addPostFrameCallback((_) => pinFocusNodes[0].requestFocus());
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D47A1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: const Text('Lanjutkan', style: TextStyle(color: Colors.white, fontFamily: 'Gilroy Bold', fontSize: 16)),
                  ),
                ),
              ],

              if (showPin) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (i) => Container(
                    width: 52, height: 56,
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: pinControllers[i].text.isNotEmpty ? const Color(0xFF0D47A1) : Colors.grey.shade200,
                        width: 1.5,
                      ),
                    ),
                    child: TextField(
                      controller: pinControllers[i],
                      focusNode: pinFocusNodes[i],
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      maxLength: 1,
                      obscureText: true,
                      style: const TextStyle(color: Color(0xFF111827), fontFamily: 'Gilroy Bold', fontSize: 20),
                      decoration: const InputDecoration(counterText: '', border: InputBorder.none),
                      onChanged: (val) {
                        if (val.isNotEmpty && i < 3) {
                          pinFocusNodes[i + 1].requestFocus();
                        } else if (val.isEmpty && i > 0) {
                          pinFocusNodes[i - 1].requestFocus();
                        }
                        setSheetState(() {});
                        final pin = pinControllers.map((c) => c.text).join();
                        if (pin.length == 4 && !isProcessing) {
                          setSheetState(() => isProcessing = true);
                          final amount = double.tryParse(amountController.text) ?? 0;
                          ApiService.withdrawQrisBalance(amount: amount, pin: pin).then((res) {
                            Navigator.pop(ctx);
                            if (res.containsKey('balance')) {
                              Provider.of<AuthProvider>(context, listen: false).fetchProfile();
                              _loadData();
                              Fluttertoast.showToast(msg: 'Penarikan berhasil');
                            } else {
                              Fluttertoast.showToast(msg: res['message'] ?? 'Penarikan gagal');
                            }
                          }).catchError((_) {
                            Navigator.pop(ctx);
                            Fluttertoast.showToast(msg: 'Kesalahan koneksi');
                          });
                        }
                      },
                    ),
                  )),
                ),
                if (isProcessing) ...[
                  const SizedBox(height: 20),
                  const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF0D47A1))),
                ],
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    setSheetState(() {
                      showPin = false;
                      for (final c in pinControllers) c.clear();
                    });
                  },
                  child: Text('Kembali', style: TextStyle(color: Colors.grey.shade500, fontFamily: 'Gilroy Medium', fontSize: 15)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    notifire = Provider.of<ColorNotifire>(context, listen: true);
    final auth = Provider.of<AuthProvider>(context);
    final qrisBalance = double.tryParse(auth.qrisBalance) ?? 0;
    final businessName = _merchantInfo?['merchant']?['business_name'] ?? 'Merchant';
    final filters = ['Semua', 'Berhasil', 'Menunggu', 'Gagal'];

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: Stack(
        children: [
          // Header gradient
          Container(
            height: MediaQuery.of(context).padding.top + 180,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0D47A1), Color(0xFF42A5F5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                // Top bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('QRIS Merchant', style: TextStyle(color: Colors.white, fontFamily: 'Gilroy Bold', fontSize: 18)),
                            Text(businessName, style: TextStyle(color: Colors.white.withOpacity(0.7), fontFamily: 'Gilroy Medium', fontSize: 12)),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: _loadData,
                        child: Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
                        ),
                      ),
                    ],
                  ),
                ),
                // Balance card
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Saldo QRIS', style: TextStyle(color: Colors.grey.shade500, fontFamily: 'Gilroy Medium', fontSize: 13)),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _formatCurrency(qrisBalance),
                          style: const TextStyle(color: Color(0xFF111827), fontFamily: 'Gilroy Bold', fontSize: 28),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _actionButton(
                              icon: Icons.qr_code_rounded,
                              label: 'Terima',
                              color: const Color(0xFF0D47A1),
                              onTap: _showCreatePayment,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _actionButton(
                              icon: Icons.account_balance_wallet_outlined,
                              label: 'Tarik Saldo',
                              color: const Color(0xFFF59E0B),
                              onTap: _showWithdraw,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Filter chips
                SizedBox(
                  height: 38,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: filters.length,
                    itemBuilder: (context, index) {
                      final f = filters[index];
                      final isSelected = f == _selectedFilter;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedFilter = f),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFF0D47A1) : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected ? Colors.transparent : Colors.grey.shade200,
                              ),
                            ),
                            child: Text(
                              f,
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.grey.shade600,
                                fontSize: 12,
                                fontFamily: isSelected ? 'Gilroy Bold' : 'Gilroy Medium',
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                // Transactions
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFF0D47A1)))
                      : _filteredTransactions.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey.shade300),
                                  const SizedBox(height: 12),
                                  Text('Belum ada transaksi', style: TextStyle(color: Colors.grey.shade400, fontSize: 16, fontFamily: 'Gilroy Medium')),
                                ],
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _loadData,
                              color: const Color(0xFF0D47A1),
                              child: ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                itemCount: _filteredTransactions.length,
                                itemBuilder: (context, index) => _buildTransactionItem(_filteredTransactions[index]),
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

  Widget _actionButton({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: color, fontFamily: 'Gilroy Bold', fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionItem(Map<String, dynamic> tx) {
    final status = tx['status'] ?? 'pending';
    final amount = tx['amount'];
    final createdAt = tx['created_at'] ?? '';
    final payer = tx['payer_name'] ?? 'Pelanggan';

    Color statusColor;
    String statusLabel;
    IconData statusIcon;
    switch (status) {
      case 'completed':
        statusColor = const Color(0xFF43A047);
        statusLabel = 'Berhasil';
        statusIcon = Icons.check_circle_rounded;
        break;
      case 'pending':
        statusColor = const Color(0xFFFF9800);
        statusLabel = 'Menunggu';
        statusIcon = Icons.hourglass_top_rounded;
        break;
      case 'expired':
        statusColor = Colors.grey;
        statusLabel = 'Kedaluwarsa';
        statusIcon = Icons.timer_off_rounded;
        break;
      default:
        statusColor = Colors.red;
        statusLabel = 'Gagal';
        statusIcon = Icons.cancel_rounded;
    }

    String dateStr = '';
    try {
      final dt = _parseServerDt(createdAt);
      dateStr = DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(dt);
    } catch (_) {}

    final note = tx['note']?.toString();

    return GestureDetector(
      onTap: () => _showReceiptScreen(tx),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48, height: 48,
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(statusIcon, color: statusColor, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(payer, style: const TextStyle(color: Color(0xFF111827), fontFamily: 'Gilroy Bold', fontSize: 14)),
                            const SizedBox(height: 2),
                            Text(dateStr, style: TextStyle(color: Colors.grey.shade500, fontFamily: 'Gilroy Medium', fontSize: 11)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(_formatCurrency(amount), style: const TextStyle(color: Color(0xFF111827), fontFamily: 'Gilroy Bold', fontSize: 14)),
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(statusLabel, style: TextStyle(color: statusColor, fontFamily: 'Gilroy Bold', fontSize: 10)),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (note != null && note.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF8E1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.sticky_note_2_outlined, size: 14, color: Color(0xFFFF8F00)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              note,
                              style: const TextStyle(color: Color(0xFF795548), fontFamily: 'Gilroy Medium', fontSize: 11),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

}

// ════════════════════════════════════════════════════════════════
//  QR Payment Dialog with countdown timer
// ════════════════════════════════════════════════════════════════

class _QrisPaymentDialog extends StatefulWidget {
  final String qrisString;
  final dynamic amount;
  final String refId;
  final DateTime expiry;
  final String Function(dynamic) formatCurrency;
  final VoidCallback onClose;

  const _QrisPaymentDialog({
    required this.qrisString,
    required this.amount,
    required this.refId,
    required this.expiry,
    required this.formatCurrency,
    required this.onClose,
  });

  @override
  State<_QrisPaymentDialog> createState() => _QrisPaymentDialogState();
}

class _QrisPaymentDialogState extends State<_QrisPaymentDialog> {
  Timer? _countdownTimer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _updateRemaining();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) => _updateRemaining());
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _updateRemaining() {
    final diff = widget.expiry.difference(DateTime.now());
    if (!mounted) return;
    setState(() {
      _remaining = diff.isNegative ? Duration.zero : diff;
    });
    if (diff.isNegative) _countdownTimer?.cancel();
  }

  String get _timerText {
    if (_remaining == Duration.zero) return 'Kedaluwarsa';
    final m = _remaining.inMinutes.toString().padLeft(2, '0');
    final s = (_remaining.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final isExpired = _remaining == Duration.zero;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Pembayaran QRIS', style: TextStyle(color: Color(0xFF111827), fontFamily: 'Gilroy Bold', fontSize: 18)),
            const SizedBox(height: 4),
            Text(widget.formatCurrency(widget.amount), style: const TextStyle(color: Color(0xFF0D47A1), fontFamily: 'Gilroy Bold', fontSize: 24)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isExpired ? Colors.red.withOpacity(0.1) : const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isExpired ? Icons.timer_off_rounded : Icons.timer_outlined,
                    color: isExpired ? Colors.red : const Color(0xFFFF9800),
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _timerText,
                    style: TextStyle(
                      color: isExpired ? Colors.red : const Color(0xFFFF9800),
                      fontFamily: 'Gilroy Bold',
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (widget.qrisString.isNotEmpty && !isExpired)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade100),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    QrImageView(
                      data: widget.qrisString,
                      version: QrVersions.auto,
                      size: 200,
                      backgroundColor: Colors.white,
                    ),
                    const SizedBox(height: 8),
                    Image.asset(
                      'images/nobu_logo.png',
                      height: 80,
                      fit: BoxFit.contain,
                    ),
                  ],
                ),
              ),
            if (isExpired)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  children: [
                    Icon(Icons.timer_off_rounded, size: 48, color: Colors.grey.shade400),
                    const SizedBox(height: 8),
                    Text('QR sudah kedaluwarsa', style: TextStyle(color: Colors.grey.shade500, fontFamily: 'Gilroy Medium', fontSize: 14)),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            if (!isExpired)
              Text(
                'Minta pelanggan scan QR ini untuk membayar',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade500, fontFamily: 'Gilroy Medium', fontSize: 13),
              ),
            const SizedBox(height: 8),
            Text('Ref: ${widget.refId}', style: TextStyle(color: Colors.grey.shade400, fontFamily: 'Gilroy Medium', fontSize: 11)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: widget.onClose,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D47A1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: const Text('Tutup', style: TextStyle(color: Colors.white, fontFamily: 'Gilroy Bold', fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  QRIS Receipt Screen (full page, shareable)
// ════════════════════════════════════════════════════════════════

class _QrisReceiptScreen extends StatefulWidget {
  final Map<String, dynamic> tx;
  final String merchantName;
  final String Function(dynamic) formatCurrency;

  const _QrisReceiptScreen({
    required this.tx,
    required this.merchantName,
    required this.formatCurrency,
  });

  @override
  State<_QrisReceiptScreen> createState() => _QrisReceiptScreenState();
}

class _QrisReceiptScreenState extends State<_QrisReceiptScreen> {
  final GlobalKey _receiptKey = GlobalKey();
  bool _sharing = false;
  final _dateFormat = DateFormat('dd MMM yyyy, HH:mm:ss', 'id_ID');
  late TextEditingController _noteController;
  String? _note;
  bool _savingNote = false;

  @override
  void initState() {
    super.initState();
    _note = widget.tx['note']?.toString();
    _noteController = TextEditingController(text: _note ?? '');
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _saveNote(String note) async {
    final txId = widget.tx['id'];
    if (txId == null) return;
    setState(() => _savingNote = true);
    try {
      final res = await ApiService.updateQrisNote(
        transactionId: txId is int ? txId : int.parse(txId.toString()),
        note: note.trim().isEmpty ? null : note.trim(),
      );
      if (mounted && res['status'] == 'success') {
        setState(() {
          _note = note.trim().isEmpty ? null : note.trim();
          widget.tx['note'] = _note;
        });
        Fluttertoast.showToast(msg: 'Note disimpan');
      }
    } catch (_) {
      if (mounted) Fluttertoast.showToast(msg: 'Gagal menyimpan note');
    } finally {
      if (mounted) setState(() => _savingNote = false);
    }
  }

  void _showNoteDialog() {
    _noteController.text = _note ?? '';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Catatan', style: TextStyle(fontFamily: 'Gilroy Bold', fontSize: 18)),
        content: TextField(
          controller: _noteController,
          maxLines: 4,
          maxLength: 500,
          decoration: InputDecoration(
            hintText: 'Contoh: Hutang pulsa 10rb',
            hintStyle: TextStyle(color: Colors.grey.shade400, fontFamily: 'Gilroy Medium', fontSize: 13),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF0D47A1)),
            ),
          ),
          style: const TextStyle(fontFamily: 'Gilroy Medium', fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Batal', style: TextStyle(color: Colors.grey.shade500, fontFamily: 'Gilroy Medium')),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _saveNote(_noteController.text);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D47A1),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: const Text('Simpan', style: TextStyle(color: Colors.white, fontFamily: 'Gilroy Bold')),
          ),
        ],
      ),
    );
  }

  Future<Uint8List?> _captureReceipt() async {
    try {
      final boundary = _receiptKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  Future<void> _shareReceipt() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final bytes = await _captureReceipt();
      if (bytes == null) return;
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/qris_receipt_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path)], text: 'Bukti Transaksi QRIS — Modipay');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal membagikan struk')));
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _downloadReceipt() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final bytes = await _captureReceipt();
      if (bytes == null) return;
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/qris_receipt_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes);
      if (mounted) {
        Fluttertoast.showToast(msg: 'Struk disimpan');
        await Share.shareXFiles([XFile(file.path)]);
      }
    } catch (_) {
      if (mounted) Fluttertoast.showToast(msg: 'Gagal menyimpan struk');
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tx = widget.tx;
    final status = tx['status'] ?? 'pending';
    final amount = tx['amount'];
    final payer = tx['payer_name'] ?? 'Pelanggan';
    final refId = tx['reference_id'] ?? '-';
    final onixId = tx['onixpayz_id'] ?? '-';
    final qrisString = tx['qris_string'] ?? '';
    final createdAt = tx['created_at'];
    final expiresAt = tx['expires_at'];
    final paidAt = tx['paid_at'];

    final isSuccess = status == 'completed';
    final isPending = status == 'pending';
    final isExpired = status == 'expired';

    Color statusColor;
    String statusLabel;
    IconData statusIcon;
    if (isSuccess) {
      statusColor = const Color(0xFF43A047);
      statusLabel = 'Berhasil';
      statusIcon = Icons.check_circle_rounded;
    } else if (isPending) {
      statusColor = const Color(0xFFFF9800);
      statusLabel = 'Menunggu';
      statusIcon = Icons.hourglass_top_rounded;
    } else if (isExpired) {
      statusColor = Colors.grey;
      statusLabel = 'Kedaluwarsa';
      statusIcon = Icons.timer_off_rounded;
    } else {
      statusColor = Colors.red;
      statusLabel = 'Gagal';
      statusIcon = Icons.cancel_rounded;
    }

    String createdStr = '-';
    if (createdAt != null) {
      try { createdStr = _dateFormat.format(_parseServerDt(createdAt)); } catch (_) {}
    }
    String paidStr = '-';
    if (paidAt != null) {
      try { paidStr = _dateFormat.format(_parseServerDt(paidAt)); } catch (_) {}
    }
    String expiresStr = '-';
    String? remainingStr;
    if (expiresAt != null) {
      try {
        final expDt = _parseServerDt(expiresAt);
        expiresStr = _dateFormat.format(expDt);
        if (isPending) {
          final diff = expDt.difference(DateTime.now());
          if (diff.isNegative) {
            remainingStr = 'Sudah kedaluwarsa';
          } else {
            remainingStr = '${diff.inMinutes} menit ${diff.inSeconds % 60} detik tersisa';
          }
        }
      } catch (_) {}
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back_rounded, color: Color(0xFF333333), size: 24),
                  ),
                  const Expanded(
                    child: Text(
                      'Detail Transaksi QRIS',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontFamily: 'Gilroy Bold', fontSize: 18, color: Color(0xFF333333)),
                    ),
                  ),
                  if (isSuccess || isPending)
                    GestureDetector(
                      onTap: _sharing ? null : _shareReceipt,
                      child: _sharing
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0D47A1)))
                          : const Icon(Icons.share_rounded, color: Color(0xFF0D47A1), size: 24),
                    )
                  else
                    const SizedBox(width: 24),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    // Receipt card (capturable)
                    RepaintBoundary(
                      key: _receiptKey,
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 2)),
                          ],
                        ),
                        child: Column(
                          children: [
                            const SizedBox(height: 28),
                            // Status icon
                            Container(
                              width: 64, height: 64,
                              decoration: BoxDecoration(color: statusColor.withOpacity(0.1), shape: BoxShape.circle),
                              child: Icon(statusIcon, color: statusColor, size: 36),
                            ),
                            const SizedBox(height: 16),
                            // Status badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                              decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                              child: Text(statusLabel, style: TextStyle(color: statusColor, fontFamily: 'Gilroy Bold', fontSize: 14)),
                            ),
                            const SizedBox(height: 16),
                            // Amount
                            Text(widget.formatCurrency(amount), style: const TextStyle(color: Color(0xFF222222), fontFamily: 'Gilroy Bold', fontSize: 28)),
                            const SizedBox(height: 8),
                            Text(widget.merchantName, style: TextStyle(color: Colors.grey.shade500, fontFamily: 'Gilroy Medium', fontSize: 13)),
                            const SizedBox(height: 24),

                            // QR code for pending transactions
                            if (isPending && qrisString.isNotEmpty && remainingStr != 'Sudah kedaluwarsa') ...[
                              Container(
                                margin: const EdgeInsets.symmetric(horizontal: 24),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF9FAFB),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.grey.shade200),
                                ),
                                child: Column(
                                  children: [
                                    QrImageView(data: qrisString, version: QrVersions.auto, size: 180, backgroundColor: Colors.white),
                                    const SizedBox(height: 8),
                                    Image.asset(
                                      'images/nobu_logo.png',
                                      height: 35,
                                      fit: BoxFit.contain,
                                    ),
                                    const SizedBox(height: 12),
                                    Text('Scan QR untuk membayar', style: TextStyle(color: Colors.grey.shade500, fontFamily: 'Gilroy Medium', fontSize: 12)),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],

                            // Remaining timer
                            if (remainingStr != null)
                              Container(
                                margin: const EdgeInsets.symmetric(horizontal: 24),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: remainingStr == 'Sudah kedaluwarsa' ? Colors.red.withOpacity(0.1) : const Color(0xFFFFF3E0),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      remainingStr == 'Sudah kedaluwarsa' ? Icons.timer_off_rounded : Icons.timer_outlined,
                                      color: remainingStr == 'Sudah kedaluwarsa' ? Colors.red : const Color(0xFFFF9800),
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(remainingStr!, style: TextStyle(
                                      color: remainingStr == 'Sudah kedaluwarsa' ? Colors.red : const Color(0xFFFF9800),
                                      fontFamily: 'Gilroy Medium', fontSize: 13,
                                    )),
                                  ],
                                ),
                              ),

                            // Dashed divider
                            const SizedBox(height: 20),
                            _buildDashedDivider(),
                            const SizedBox(height: 20),

                            // Detail rows
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              child: Column(
                                children: [
                                  _buildDetailRow('Pelanggan', payer),
                                  _buildDetailRow('Dibuat', createdStr),
                                  if (isSuccess) _buildDetailRow('Dibayar', paidStr),
                                  _buildDetailRow('Kedaluwarsa', expiresStr),
                                  _buildDetailRow('Metode', 'QRIS'),
                                  _buildDetailRow('No. Referensi', refId),
                                  if (onixId != '-' && onixId.isNotEmpty)
                                    _buildDetailRow('ID Pembayaran', onixId),
                                  _buildDetailRow('Status', statusLabel, valueColor: statusColor),
                                  if (_note != null && _note!.isNotEmpty)
                                    _buildDetailRow('Catatan', _note!),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            _buildDashedDivider(),
                            const SizedBox(height: 16),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              child: Text(
                                'Terimakasih telah bertransaksi di ${widget.merchantName}, struk ini sebagai tanda bukti transaksi anda',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontFamily: 'Gilroy Medium',
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Note edit button
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: OutlinedButton.icon(
                        onPressed: _savingNote ? null : _showNoteDialog,
                        icon: _savingNote
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0D47A1)))
                            : Icon(_note != null && _note!.isNotEmpty ? Icons.edit_note_rounded : Icons.note_add_rounded, size: 20),
                        label: Text(
                          _note != null && _note!.isNotEmpty ? 'Edit Catatan' : 'Tambah Catatan',
                          style: const TextStyle(fontFamily: 'Gilroy Bold', fontSize: 14),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF0D47A1),
                          side: BorderSide(color: const Color(0xFF0D47A1).withOpacity(0.3)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Action buttons
                    if (isSuccess || isPending) ...[
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 50,
                              child: OutlinedButton.icon(
                                onPressed: _sharing ? null : _downloadReceipt,
                                icon: const Icon(Icons.download_rounded, size: 20),
                                label: const Text('Simpan', style: TextStyle(fontFamily: 'Gilroy Bold', fontSize: 15)),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF0D47A1),
                                  side: const BorderSide(color: Color(0xFF0D47A1)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SizedBox(
                              height: 50,
                              child: ElevatedButton.icon(
                                onPressed: _sharing ? null : _shareReceipt,
                                icon: const Icon(Icons.share_rounded, size: 20, color: Colors.white),
                                label: const Text('Bagikan', style: TextStyle(fontFamily: 'Gilroy Bold', fontSize: 15, color: Colors.white)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0D47A1),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  elevation: 0,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: (isSuccess || isPending) ? Colors.grey.shade200 : const Color(0xFF0D47A1),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: Text('Kembali', style: TextStyle(
                          fontFamily: 'Gilroy Bold', fontSize: 15,
                          color: (isSuccess || isPending) ? const Color(0xFF333333) : Colors.white,
                        )),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: const TextStyle(fontFamily: 'Gilroy Medium', fontSize: 13, color: Color(0xFF999999))),
          ),
          Expanded(
            child: Text(value, textAlign: TextAlign.right, style: TextStyle(fontFamily: 'Gilroy Bold', fontSize: 13, color: valueColor ?? const Color(0xFF333333))),
          ),
        ],
      ),
    );
  }

  Widget _buildDashedDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const dashWidth = 6.0;
          const dashSpace = 4.0;
          final dashCount = (constraints.maxWidth / (dashWidth + dashSpace)).floor();
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(dashCount, (_) {
              return SizedBox(
                width: dashWidth + dashSpace,
                child: Center(child: Container(width: dashWidth, height: 1, color: const Color(0xFFE0E0E0))),
              );
            }),
          );
        },
      ),
    );
  }
}
