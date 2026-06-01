import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../services/biometric_service.dart';
import '../../utils/colornotifire.dart';
import '../../utils/media.dart';

class BayarTagihanScreen extends StatefulWidget {
  final double totalTagihan;
  final double serviceFee;

  const BayarTagihanScreen({
    Key? key,
    required this.totalTagihan,
    this.serviceFee = 0,
  }) : super(key: key);

  @override
  State<BayarTagihanScreen> createState() => _BayarTagihanScreenState();
}

class _BayarTagihanScreenState extends State<BayarTagihanScreen> {
  final _currencyFormat = NumberFormat('#,###', 'id_ID');
  final _pinController = TextEditingController();
  String _selectedMethod = 'saldo';
  double _serviceFee = 0;
  bool _isSubmitting = false;
  bool _biometricAvailable = false;

  final List<Map<String, dynamic>> _paymentMethods = [
    {
      'id': 'saldo',
      'name': 'Saldo',
      'desc': 'Bayar langsung dari saldo',
      'icon': Icons.account_balance_wallet_rounded,
    },
    {
      'id': 'qris',
      'name': 'QRIS',
      'desc': 'Scan QR code untuk pembayaran',
      'icon': Icons.qr_code_2_rounded,
    },
  ];

  @override
  void initState() {
    super.initState();
    _serviceFee = widget.serviceFee;
    if (_serviceFee == 0) _fetchServiceFee();
    _checkBiometric();
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _checkBiometric() async {
    final available = await BiometricService.isAvailable();
    final enabled = await BiometricService.isEnabled();
    if (mounted) setState(() => _biometricAvailable = available && enabled);
  }

  Future<void> _fetchServiceFee() async {
    try {
      final response = await ApiService.getMerchantLimitDetail();
      if (!mounted) return;
      if (response['status'] == 'active') {
        final fee = (response['data']?['service_fee'] ?? 0).toDouble();
        if (fee > 0) setState(() => _serviceFee = fee);
      }
    } catch (_) {}
  }

  double get _total => widget.totalTagihan + _serviceFee;

  void _onPayPressed() {
    if (_selectedMethod == 'saldo') {
      // Check balance first
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final balance = double.tryParse(auth.userBalance) ?? 0;
      if (balance < _total) {
        _showSnackBar(
            'Saldo tidak mencukupi. Saldo Anda Rp ${_currencyFormat.format(balance.toInt())}');
        return;
      }

      // Show PIN confirmation
      final auth2 = Provider.of<AuthProvider>(context, listen: false);
      if (!auth2.pinRequired) {
        _payWithSaldo(pin: '', biometric: false);
        return;
      }
      _showPinSheet();
    } else {
      // QRIS - generate QR and navigate to QRIS screen
      _payWithQris();
    }
  }

  Future<void> _payWithQris() async {
    setState(() => _isSubmitting = true);
    try {
      final response = await ApiService.payLimitBill(method: 'qris');
      if (!mounted) return;
      setState(() => _isSubmitting = false);

      if (response['status'] == 'success' && response['data'] != null) {
        final data = response['data'] as Map<String, dynamic>;
        final qrContent = data['qr_content']?.toString() ?? '';
        final topupId = data['topup_id'] is int
            ? data['topup_id'] as int
            : int.tryParse(data['topup_id']?.toString() ?? '');
        final expired = (data['expired'] is num)
            ? (data['expired'] as num).toInt()
            : int.tryParse(data['expired']?.toString() ?? '') ?? 900;
        final amount = (data['amount'] is num) ? (data['amount'] as num).toInt() : _total.toInt();

        if (qrContent.isEmpty || topupId == null) {
          _showSnackBar('Gagal generate QRIS');
          return;
        }

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => _LimitQrisScreen(
              qrContent: qrContent,
              topupId: topupId,
              amount: amount,
              expiredSeconds: expired,
            ),
          ),
        ).then((_) {
          // Refresh after returning from QRIS screen
          if (mounted) Navigator.pop(context, true);
        });
      } else {
        _showSnackBar(response['message'] ?? 'Gagal generate QRIS');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        _showSnackBar(ApiService.userFriendlyMessage(e, fallback: 'Gagal generate QRIS'));
      }
    }
  }

  void _showPinSheet() {
    _pinController.clear();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _buildPinSheet(ctx),
    );
  }

  Future<void> _payWithSaldo({required String pin, required bool biometric}) async {
    setState(() => _isSubmitting = true);
    try {
      final response = await ApiService.payLimitBill(
        method: 'saldo',
        pin: pin,
        biometricAuth: biometric,
      );

      if (!mounted) return;

      if (response['status'] == 'success') {
        Provider.of<AuthProvider>(context, listen: false).fetchProfile();
        _showSuccessDialog(response['data']?['balance']);
      } else {
        _showSnackBar(response['message'] ?? 'Pembayaran gagal');
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar(ApiService.userFriendlyMessage(e, fallback: 'Pembayaran gagal'));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSuccessDialog(dynamic newBalance) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_rounded,
                color: Color(0xFF10B981), size: 60),
            const SizedBox(height: 16),
            const Text('Pembayaran Berhasil',
                style: TextStyle(fontFamily: 'Gilroy Bold', fontSize: 18)),
            const SizedBox(height: 8),
            Text(
              'Tagihan Rp ${_currencyFormat.format(_total.toInt())} berhasil dibayar. Limit Anda akan segera pulih.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: 'Gilroy Medium',
                  fontSize: 14,
                  color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              child: const Text('OK',
                  style: TextStyle(fontFamily: 'Gilroy Bold', fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    height = MediaQuery.of(context).size.height;
    width = MediaQuery.of(context).size.width;
    final notifire = Provider.of<ColorNotifire>(context, listen: true);
    final blueColor = notifire.getbluecolor as Color;
    final auth = Provider.of<AuthProvider>(context);
    final balance = double.tryParse(auth.userBalance) ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Padding(
            padding: EdgeInsets.all(12),
            child: Icon(Icons.arrow_back, color: Color(0xFF1A1A1A)),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Bayar Tagihan',
          style: TextStyle(
            color: Color(0xFF1A1A1A),
            fontFamily: 'Gilroy Bold',
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Warning banner ──
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8E1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: const Color(0xFFF59E0B).withOpacity(0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_rounded,
                            color: Color(0xFFF59E0B), size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Segera selesaikan pembayaran agar limit Anda tetap aktif.',
                            style: TextStyle(
                              color: Colors.grey[800],
                              fontFamily: 'Gilroy Medium',
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Tagihan card ──
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border:
                          Border.all(color: Colors.black.withOpacity(0.08)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Tagihan',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontFamily: 'Gilroy Medium',
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Rp ${_currencyFormat.format(widget.totalTagihan.toInt())}',
                          style: const TextStyle(
                            color: Color(0xFF1A1A1A),
                            fontFamily: 'Gilroy Bold',
                            fontSize: 28,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Divider(
                            height: 1,
                            color: Colors.grey.withOpacity(0.15)),
                        const SizedBox(height: 16),
                        const Text(
                          'Rincian',
                          style: TextStyle(
                            color: Color(0xFF1A1A1A),
                            fontFamily: 'Gilroy Bold',
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 14),
                        _rincianRow(
                          'Penggunaan Limit',
                          'Rp ${_currencyFormat.format(widget.totalTagihan.toInt())}',
                        ),
                        const SizedBox(height: 10),
                        _rincianRow(
                          'Biaya Layanan',
                          'Rp ${_currencyFormat.format(_serviceFee.toInt())}',
                        ),
                        const SizedBox(height: 14),
                        Divider(
                            height: 1,
                            color: Colors.grey.withOpacity(0.15)),
                        const SizedBox(height: 14),
                        _rincianRow(
                          'Total',
                          'Rp ${_currencyFormat.format(_total.toInt())}',
                          bold: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Pilih Metode Pembayaran ──
                  const Text(
                    'Pilih Metode Pembayaran',
                    style: TextStyle(
                      color: Color(0xFF1A1A1A),
                      fontFamily: 'Gilroy Bold',
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 12),

                  ..._paymentMethods.map((method) {
                    final isSelected = _selectedMethod == method['id'];
                    final isSaldo = method['id'] == 'saldo';
                    return GestureDetector(
                      onTap: () =>
                          setState(() => _selectedMethod = method['id']),
                      child: Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected
                                ? blueColor
                                : Colors.black.withOpacity(0.08),
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              method['icon'] as IconData,
                              color: blueColor,
                              size: 24,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    method['name'],
                                    style: const TextStyle(
                                      color: Color(0xFF1A1A1A),
                                      fontFamily: 'Gilroy Bold',
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    isSaldo
                                        ? 'Saldo: Rp ${_currencyFormat.format(balance.toInt())}'
                                        : method['desc'],
                                    style: TextStyle(
                                      color: isSaldo && balance < _total
                                          ? Colors.red[400]
                                          : Colors.grey[500],
                                      fontFamily: 'Gilroy Medium',
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isSelected)
                              Icon(Icons.check_circle_rounded,
                                  color: blueColor, size: 22)
                            else
                              Icon(Icons.radio_button_off_rounded,
                                  color: Colors.grey[300], size: 22),
                          ],
                        ),
                      ),
                    );
                  }),

                  // Saldo warning
                  if (_selectedMethod == 'saldo' && balance < _total)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFEBEE),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber_rounded,
                              color: Colors.red[400], size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Saldo tidak mencukupi. Silahkan isi saldo terlebih dahulu.',
                              style: TextStyle(
                                color: Colors.red[700],
                                fontFamily: 'Gilroy Medium',
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),

          // ── Bottom button ──
          Container(
            padding: EdgeInsets.fromLTRB(
              20,
              16,
              20,
              MediaQuery.of(context).padding.bottom + 20,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _onPayPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: blueColor,
                  disabledBackgroundColor: Colors.grey[300],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text(
                        'Lanjutkan Pembayaran',
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: 'Gilroy Bold',
                          fontSize: 16,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rincianRow(String label, String value, {bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: bold ? const Color(0xFF1A1A1A) : Colors.grey[600],
            fontFamily: bold ? 'Gilroy Bold' : 'Gilroy Medium',
            fontSize: 14,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: const Color(0xFF1A1A1A),
            fontFamily: bold ? 'Gilroy Bold' : 'Gilroy Medium',
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildPinSheet(BuildContext ctx) {
    bool usedBiometric = false;
    return StatefulBuilder(
      builder: (ctx, setSheetState) {
        final notifire = Provider.of<ColorNotifire>(ctx, listen: false);
        return Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            top: 24,
            left: 24,
            right: 24,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Konfirmasi Pembayaran',
                style: TextStyle(
                    fontFamily: 'Gilroy Bold', fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                'Rp ${_currencyFormat.format(_total.toInt())}',
                style: TextStyle(
                  color: notifire.getbluecolor,
                  fontFamily: 'Gilroy Bold',
                  fontSize: 24,
                ),
              ),
              const SizedBox(height: 24),
              if (_biometricAvailable) ...[
                GestureDetector(
                  onTap: _isSubmitting
                      ? null
                      : () async {
                          final success =
                              await BiometricService.authenticate(
                            reason: 'Konfirmasi bayar tagihan',
                          );
                          if (success && mounted) {
                            Navigator.pop(ctx);
                            _payWithSaldo(pin: '', biometric: true);
                          }
                        },
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: notifire.getbluecolor.withOpacity(0.1),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color:
                              notifire.getbluecolor.withOpacity(0.4),
                          width: 2),
                    ),
                    child: Icon(Icons.fingerprint,
                        color: notifire.getbluecolor, size: 40),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'atau masukkan PIN',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontFamily: 'Gilroy Medium',
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              TextField(
                controller: _pinController,
                keyboardType: TextInputType.number,
                maxLength: 4,
                obscureText: true,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Gilroy Bold',
                  fontSize: height / 30,
                  letterSpacing: 12,
                ),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '____',
                  hintStyle: TextStyle(
                    color: Colors.grey[300],
                    fontFamily: 'Gilroy Bold',
                    fontSize: height / 30,
                    letterSpacing: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: Colors.grey.withOpacity(0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color: notifire.getbluecolor, width: 2),
                  ),
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSubmitting
                      ? null
                      : () {
                          if (_pinController.text.length != 4) {
                            _showSnackBar('Masukkan 4 digit PIN');
                            return;
                          }
                          Navigator.pop(ctx);
                          _payWithSaldo(
                              pin: _pinController.text,
                              biometric: false);
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: notifire.getbluecolor,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Bayar Sekarang',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Gilroy Bold',
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              SizedBox(
                  height: MediaQuery.of(ctx).padding.bottom + 16),
            ],
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// QRIS Screen for Limit Bill Payment
// ═══════════════════════════════════════════════════════════════════════════

class _LimitQrisScreen extends StatefulWidget {
  final String qrContent;
  final int topupId;
  final int amount;
  final int expiredSeconds;

  const _LimitQrisScreen({
    required this.qrContent,
    required this.topupId,
    required this.amount,
    this.expiredSeconds = 900,
  });

  @override
  State<_LimitQrisScreen> createState() => _LimitQrisScreenState();
}

class _LimitQrisScreenState extends State<_LimitQrisScreen> {
  final _currencyFormat = NumberFormat('#,###', 'id_ID');
  Timer? _countdownTimer;
  Timer? _pollTimer;
  int _remainingSeconds = 900;
  bool _isPaid = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.expiredSeconds;
    _startCountdown();
    _startPolling();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pollTimer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _remainingSeconds--);
      if (_remainingSeconds <= 0) {
        _countdownTimer?.cancel();
        _pollTimer?.cancel();
        if (!_isPaid) {
          setState(() => _error = 'QRIS sudah expired');
        }
      }
    });
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!mounted || _isPaid) return;

      try {
        final response = await ApiService.checkTopupStatus(widget.topupId);
        final status = (response['trx_status'] ?? '').toString();

        if (status == 'PAID' && mounted) {
          _pollTimer?.cancel();
          _countdownTimer?.cancel();
          setState(() => _isPaid = true);
          Provider.of<AuthProvider>(context, listen: false).fetchProfile();
          _showSuccessDialog();
        } else if (status == 'EXPIRED' && mounted) {
          _pollTimer?.cancel();
          _countdownTimer?.cancel();
          setState(() => _error = 'QRIS sudah expired');
        }
      } catch (_) {}
    });
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 60),
            const SizedBox(height: 16),
            const Text('Pembayaran Berhasil', style: TextStyle(fontFamily: 'Gilroy Bold', fontSize: 18)),
            const SizedBox(height: 8),
            Text(
              'Tagihan limit sebesar Rp ${_currencyFormat.format(widget.amount)} berhasil dibayar',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Gilroy Medium', fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pop(true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF040f85),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Kembali', style: TextStyle(color: Colors.white, fontFamily: 'Gilroy Bold')),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final blueColor = const Color(0xFF040f85);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1A1A1A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Bayar Tagihan via QRIS',
          style: TextStyle(color: Color(0xFF1A1A1A), fontFamily: 'Gilroy Bold', fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline_rounded, size: 60, color: Color(0xFFD32F2F)),
                  const SizedBox(height: 16),
                  Text(_error!, style: const TextStyle(fontFamily: 'Gilroy Medium', fontSize: 16, color: Color(0xFFD32F2F))),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(backgroundColor: blueColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: const Text('Kembali', style: TextStyle(color: Colors.white, fontFamily: 'Gilroy Bold')),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  // Amount
                  Text(
                    'Total Tagihan',
                    style: TextStyle(fontFamily: 'Gilroy Medium', fontSize: 14, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Rp ${_currencyFormat.format(widget.amount)}',
                    style: const TextStyle(fontFamily: 'Gilroy Bold', fontSize: 28, color: Color(0xFF1A1A1A)),
                  ),
                  const SizedBox(height: 24),
                  // QR Code
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: Column(
                      children: [
                        QrImageView(
                          data: widget.qrContent,
                          version: QrVersions.auto,
                          size: 220,
                          gapless: true,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Scan QR code di atas untuk membayar',
                          style: TextStyle(fontFamily: 'Gilroy Medium', fontSize: 13, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Countdown
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: _remainingSeconds < 60 ? const Color(0xFFFFEBEE) : const Color(0xFFF5F7FA),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _remainingSeconds < 60 ? const Color(0xFFD32F2F).withValues(alpha: 0.3) : Colors.grey.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.timer_outlined, size: 20, color: _remainingSeconds < 60 ? const Color(0xFFD32F2F) : Colors.grey[600]),
                        const SizedBox(width: 8),
                        Text(
                          'Berlaku ${_formatTime(_remainingSeconds)}',
                          style: TextStyle(
                            fontFamily: 'Gilroy Bold',
                            fontSize: 15,
                            color: _remainingSeconds < 60 ? const Color(0xFFD32F2F) : const Color(0xFF1A1A1A),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_isPaid)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 22),
                          SizedBox(width: 8),
                          Text('Pembayaran berhasil!', style: TextStyle(fontFamily: 'Gilroy Bold', fontSize: 15, color: Color(0xFF10B981))),
                        ],
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
