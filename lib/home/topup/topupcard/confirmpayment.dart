import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:gobank/providers/auth_provider.dart';
import 'package:gobank/services/app_exception.dart';
import 'package:gobank/services/api_service.dart';
import 'package:gobank/services/biometric_service.dart';
import 'package:gobank/home/transaction_detail.dart';

import '../topup_channel_screen.dart';
import 'package:provider/provider.dart';
import '../../../utils/colornotifire.dart';
import '../../../utils/media.dart';

class ConfirmPayment extends StatefulWidget {
  final double amount;
  final String bankName;
  final String type;
  final String? phoneNumber;
  final String? buyerSkuCode;
  final String? provider;
  final String? category;
  final String paymentSource;

  /// Loket Bayar ref_id from inquiry (required for custom amount e-wallet).
  final String? loketbayarRefId;

  /// Loket Bayar product code (e.g. 'DANA') for payment endpoint.
  final String? loketbayarKodeProduk;

  /// Nominal (total) from Loket Bayar inquiry to send in payment request.
  final int? loketbayarNominal;

  const ConfirmPayment({
    super.key,
    required this.amount,
    required this.bankName,
    required this.type,
    this.phoneNumber,
    this.buyerSkuCode,
    this.provider,
    this.category,
    this.paymentSource = 'saldo',
    this.loketbayarRefId,
    this.loketbayarKodeProduk,
    this.loketbayarNominal,
  });

  @override
  State<ConfirmPayment> createState() => _ConfirmPaymentState();
}

enum _ApiStatus { idle, loading, error }

class _ConfirmPaymentState extends State<ConfirmPayment> {
  late ColorNotifire notifire;
  bool _isLoading = false;
  String _pin = '';
  bool _biometricAvailable = false;
  bool _showPin = false;
  bool _usedBiometric = false;
  bool _biometricPromptTriggered = false;
  late String _paymentSource;
  
  // API request status tracking
  _ApiStatus _apiStatus = _ApiStatus.idle;
  String _statusMessage = '';

  bool get _isPpob => widget.buyerSkuCode != null && widget.buyerSkuCode!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _paymentSource = widget.paymentSource;
    _checkBiometric();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.pinRequired) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _handleConfirm());
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _checkBiometric() async {
    final available = await BiometricService.isAvailable();
    final enabled = await BiometricService.isEnabled();
    if (!mounted) return;
    setState(() => _biometricAvailable = available && enabled);
    _tryAutoBiometricPrompt();
  }

  void _tryAutoBiometricPrompt() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!mounted || _isLoading || _showPin || !auth.pinRequired) return;
    if (!_biometricAvailable || _biometricPromptTriggered) return;

    _biometricPromptTriggered = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _handleBiometric();
    });
  }

  Future<void> _handleBiometric() async {
    final success = await BiometricService.authenticate(
      reason: 'Konfirmasi pembayaran ${widget.bankName}',
    );
    debugPrint('[BIOMETRIC] confirmpayment: success=$success, mounted=$mounted');
    if (success && mounted) {
      _usedBiometric = true;
      _handleConfirm(bypassPin: true);
    }
  }

  void _appendPinDigit(String digit) {
    if (_isLoading || _pin.length >= 4) return;
    setState(() {
      _pin = '$_pin$digit';
    });
    if (_pin.length == 4) {
      _handleConfirm();
    }
  }

  void _removePinDigit() {
    if (_isLoading || _pin.isEmpty) return;
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
    });
  }

  void _clearPin() {
    if (_isLoading || _pin.isEmpty) return;
    setState(() => _pin = '');
  }

  void _setApiStatus(_ApiStatus status, {String message = ''}) {
    if (!mounted) return;
    setState(() {
      _apiStatus = status;
      _statusMessage = message;
    });
  }

  Future<void> _handleConfirm({bool bypassPin = false}) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!bypassPin && auth.pinRequired && _pin.length != 4) {
      Fluttertoast.showToast(msg: 'Masukkan PIN 4 digit');
      return;
    }
    if (widget.amount <= 0) {
      Fluttertoast.showToast(msg: 'Masukkan jumlah yang valid');
      return;
    }

    setState(() {
      _isLoading = true;
      _apiStatus = _ApiStatus.loading;
      _statusMessage = '';
    });
    final stopwatch = Stopwatch()..start();

    try {
      if (_isPpob) {
        await _handlePpobPurchase(stopwatch);
      } else {
        await _handleTopup(stopwatch);
      }
    } catch (e) {
      debugPrint('[BIOMETRIC] confirmpayment ERROR: $e');
      if (mounted) {
        final message = e is AppException
            ? e.message
            : ApiService.userFriendlyMessage(
                e,
                fallback: 'Kesalahan koneksi',
              );
        _setApiStatus(_ApiStatus.error, message: message);
        // Keep overlay showing for 2 seconds then hide
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<void> _handlePpobPurchase(Stopwatch stopwatch) async {
    debugPrint('[BIOMETRIC] confirmpayment._handlePpobPurchase: biometricAuth=$_usedBiometric, pin=${_pin.isEmpty ? "(empty)" : "****"}');

    final Map<String, dynamic> response;
    if (widget.provider == 'loketbayar') {
      // Produk dari Loket Bayar → gunakan controller Loket Bayar
      response = await ApiService.purchaseLoketbayar(
        kodeProduk: widget.loketbayarKodeProduk ?? widget.buyerSkuCode!,
        customerNo: widget.phoneNumber ?? '',
        nominal: widget.loketbayarNominal ?? widget.amount.toInt(),
        refId: widget.loketbayarRefId ?? '',
        pin: _pin,
        biometricAuth: _usedBiometric,
        paymentSource: _paymentSource,
        productName: widget.bankName,
      );
    } else {
      // Produk dari Digiflazz → gunakan controller Digiflazz
      response = await ApiService.purchasePpob(
        buyerSkuCode: widget.buyerSkuCode!,
        customerNo: widget.phoneNumber ?? '',
        pin: _pin,
        biometricAuth: _usedBiometric,
        provider: widget.provider,
        category: widget.category,
        paymentSource: _paymentSource,
        amount: widget.amount,
      );
    }
    stopwatch.stop();
    debugPrint('[BIOMETRIC] confirmpayment API response: $response');

    if (!mounted) return;

    if (response.containsKey('transaction')) {
      // Navigate ke TransactionDetail (halaman dari riwayat)
      if (!mounted) return;
      Provider.of<AuthProvider>(context, listen: false).updateBalance();
      final tx = response['transaction'] as Map<String, dynamic>? ?? {};
      final meta = response['meta'] is Map
          ? Map<String, dynamic>.from(response['meta'] as Map)
          : null;
      _goToTransactionDetail(tx, meta);
    } else {
      final errMsg = response['message'] ?? 'Pembelian gagal';
      _setApiStatus(_ApiStatus.error, message: errMsg);
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleTopup(Stopwatch stopwatch) async {
    // New flow: redirect to payment channel selection
    if (!mounted) return;
    setState(() => _isLoading = false);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const TopupChannelScreen(),
      ),
    );
  }

  void _goToTransactionDetail(Map<String, dynamic> tx, Map<String, dynamic>? meta) {
    // Prioritaskan `tx['note']` dari backend (yang sudah berisi admin
    // panel + nominal + customer_name yang benar). Hanya pakai `meta`
    // sebagai fallback kalau `tx` tidak punya note.
    final hasTxNote = tx['note'] != null && tx['note'].toString().isNotEmpty;
    final data = <String, dynamic>{
      ...tx,
      'amount': tx['amount'] ?? widget.amount,
      'phone_number': widget.phoneNumber,
      'customer_no': widget.phoneNumber,
      if (meta != null && meta.isNotEmpty) 'meta': meta,
      if (!hasTxNote && meta != null && meta.isNotEmpty)
        'note': jsonEncode(meta),
    };
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => TransactionDetail(data: data),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    notifire = Provider.of<ColorNotifire>(context, listen: true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final needPin = auth.pinRequired;
    height = MediaQuery.of(context).size.height;
    width = MediaQuery.of(context).size.width;

    final backgroundColor = notifire.getbackcolor;
    final surfaceColor = notifire.getwhite;
    final textPrimary = notifire.getdarkscolor;
    final textSecondary = notifire.getdarkgreycolor;
    final accent = notifire.getbluecolor;

    return Stack(
      children: [
        Scaffold(
          backgroundColor: backgroundColor,
          appBar: AppBar(
            iconTheme: IconThemeData(color: textPrimary),
            centerTitle: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: Text(
              'Konfirmasi Pembayaran',
              style: TextStyle(
                fontFamily: 'Gilroy Bold',
                fontSize: height / 42,
                color: textPrimary,
              ),
            ),
          ),
          body: needPin
              ? Stack(
                  children: [
                    Positioned.fill(
                      child: Container(color: backgroundColor),
                    ),
                    SafeArea(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: surfaceColor,
                                borderRadius: BorderRadius.circular(28),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x14000000),
                                    blurRadius: 24,
                                    offset: Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    _showPin || !_biometricAvailable
                                        ? 'Masukkan PIN'
                                        : 'Konfirmasi Pembayaran',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontFamily: 'Gilroy Bold',
                                      color: textPrimary,
                                      fontSize: height / 28,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _showPin || !_biometricAvailable
                                        ? 'Masukkan PIN untuk konfirmasi pembayaran'
                                        : 'Gunakan sidik jari atau Face ID untuk melanjutkan',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: textSecondary,
                                      fontFamily: 'Gilroy Medium',
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  if (!_showPin && _biometricAvailable)
                                    Column(
                                      children: [
                                        GestureDetector(
                                          onTap: _isLoading ? null : _handleBiometric,
                                          child: Container(
                                            width: 76,
                                            height: 76,
                                            decoration: BoxDecoration(
                                              color: accent,
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: accent.withValues(alpha: 0.20),
                                                  blurRadius: 18,
                                                  offset: const Offset(0, 8),
                                                ),
                                              ],
                                            ),
                                            child: const Icon(
                                              Icons.fingerprint_rounded,
                                              color: Colors.white,
                                              size: 42,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          'Tekan untuk verifikasi',
                                          style: TextStyle(
                                            color: textSecondary,
                                            fontFamily: 'Gilroy Medium',
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(height: 18),
                                        TextButton(
                                          onPressed: () => setState(() => _showPin = true),
                                          child: Text(
                                            'Gunakan PIN',
                                            style: TextStyle(
                                              color: accent,
                                              fontFamily: 'Gilroy Medium',
                                              fontSize: 13,
                                              decoration: TextDecoration.underline,
                                            ),
                                          ),
                                        ),
                                      ],
                                    )
                                  else ...[
                                    _buildPinDots(
                                      accent: accent,
                                      textSecondary: textSecondary,
                                    ),
                                    const SizedBox(height: 20),
                                    if (_biometricAvailable)
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: TextButton.icon(
                                          onPressed: () => setState(() => _showPin = false),
                                          icon: Icon(Icons.fingerprint_rounded, color: accent, size: 18),
                                          label: Text(
                                            'Gunakan Sidik Jari / Face ID',
                                            style: TextStyle(
                                              color: accent,
                                              fontFamily: 'Gilroy Medium',
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),
                            if ((_showPin || !_biometricAvailable) && !_isLoading)
                              Container(
                                padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
                                decoration: BoxDecoration(
                                  color: surfaceColor,
                                  borderRadius: BorderRadius.circular(28),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x0E000000),
                                      blurRadius: 18,
                                      offset: Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        _buildKeypadButton(
                                          label: '1',
                                          onTap: () => _appendPinDigit('1'),
                                          accent: accent,
                                          surfaceColor: surfaceColor,
                                          textPrimary: textPrimary,
                                        ),
                                        _buildKeypadButton(
                                          label: '2',
                                          onTap: () => _appendPinDigit('2'),
                                          accent: accent,
                                          surfaceColor: surfaceColor,
                                          textPrimary: textPrimary,
                                        ),
                                        _buildKeypadButton(
                                          label: '3',
                                          onTap: () => _appendPinDigit('3'),
                                          accent: accent,
                                          surfaceColor: surfaceColor,
                                          textPrimary: textPrimary,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 14),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        _buildKeypadButton(
                                          label: '4',
                                          onTap: () => _appendPinDigit('4'),
                                          accent: accent,
                                          surfaceColor: surfaceColor,
                                          textPrimary: textPrimary,
                                        ),
                                        _buildKeypadButton(
                                          label: '5',
                                          onTap: () => _appendPinDigit('5'),
                                          accent: accent,
                                          surfaceColor: surfaceColor,
                                          textPrimary: textPrimary,
                                        ),
                                        _buildKeypadButton(
                                          label: '6',
                                          onTap: () => _appendPinDigit('6'),
                                          accent: accent,
                                          surfaceColor: surfaceColor,
                                          textPrimary: textPrimary,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 14),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        _buildKeypadButton(
                                          label: '7',
                                          onTap: () => _appendPinDigit('7'),
                                          accent: accent,
                                          surfaceColor: surfaceColor,
                                          textPrimary: textPrimary,
                                        ),
                                        _buildKeypadButton(
                                          label: '8',
                                          onTap: () => _appendPinDigit('8'),
                                          accent: accent,
                                          surfaceColor: surfaceColor,
                                          textPrimary: textPrimary,
                                        ),
                                        _buildKeypadButton(
                                          label: '9',
                                          onTap: () => _appendPinDigit('9'),
                                          accent: accent,
                                          surfaceColor: surfaceColor,
                                          textPrimary: textPrimary,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 14),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        _buildKeypadButton(
                                          icon: Icons.close_rounded,
                                          onTap: _clearPin,
                                          accent: accent,
                                          surfaceColor: surfaceColor,
                                          textPrimary: textPrimary,
                                        ),
                                        _buildKeypadButton(
                                          label: '0',
                                          onTap: () => _appendPinDigit('0'),
                                          accent: accent,
                                          surfaceColor: surfaceColor,
                                          textPrimary: textPrimary,
                                        ),
                                        _buildKeypadButton(
                                          icon: Icons.backspace_outlined,
                                          onTap: _removePinDigit,
                                          accent: accent,
                                          surfaceColor: surfaceColor,
                                          textPrimary: textPrimary,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
              : Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_outline, size: 60, color: accent),
                      const SizedBox(height: 16),
                      Text(
                        'Memproses...',
                        style: TextStyle(
                          fontFamily: 'Gilroy Medium',
                          color: textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
        ),
        if (_isLoading)
          Positioned.fill(
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.28),
                  alignment: Alignment.center,
                  child: _buildApiStatusOverlay(
                    accent: accent,
                    backgroundColor: backgroundColor,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPinDots({
    required Color accent,
    required Color textSecondary,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(4, (index) {
            final filled = index < _pin.length;
            return Container(
              width: 18,
              height: 18,
              margin: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: filled ? accent : textSecondary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
            );
          }),
        ),
        const SizedBox(height: 10),
        Text(
          _pin.isEmpty ? 'Masukkan 4 digit PIN' : 'PIN: ${'*' * _pin.length}',
          style: TextStyle(
            color: textSecondary,
            fontFamily: 'Gilroy Medium',
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildKeypadButton({
    String? label,
    IconData? icon,
    required VoidCallback onTap,
    required Color accent,
    required Color surfaceColor,
    required Color textPrimary,
  }) {
    return SizedBox(
      width: 88,
      height: 58,
      child: Material(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: _isLoading ? null : onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: accent.withValues(alpha: 0.12)),
            ),
            child: Center(
              child: icon != null
                  ? Icon(icon, color: accent, size: 22)
                  : Text(
                      label ?? '',
                      style: TextStyle(
                        color: textPrimary,
                        fontFamily: 'Gilroy Medium',
                        fontSize: 20,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildApiStatusOverlay({
    required Color accent,
    required Color backgroundColor,
  }) {
    final isError = _apiStatus == _ApiStatus.error;

    return Container(
      width: 140,
      height: 140,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                strokeWidth: 4,
                color: accent,
              ),
            ),
            if (isError) ...[
              const Icon(
                Icons.error_rounded,
                size: 56,
                color: Color(0xFFFF3333),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  _statusMessage,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Gilroy Medium',
                    fontSize: 12,
                    color: Color(0xFFFF3333),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
