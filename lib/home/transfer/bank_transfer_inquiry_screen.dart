import 'package:flutter/material.dart';
import 'package:modipay/widgets/desktop_title_wrapper.dart';

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../services/biometric_service.dart';
import '../../utils/colornotifire.dart';
import '../../utils/media.dart';
import 'bank_transfer_receipt_screen.dart';

class BankTransferInquiryScreen extends StatefulWidget {
  final String bankCode;
  final String bankName;
  final String accountNumber;
  final double amount;
  final double admin;
  final double total;
  final double providerTotal;
  final String namaPenerima;
  final String refId;
  final String kodeProduk;
  final String? notes;

  const BankTransferInquiryScreen({
    Key? key,
    required this.bankCode,
    required this.bankName,
    required this.accountNumber,
    required this.amount,
    required this.admin,
    required this.total,
    required this.providerTotal,
    required this.namaPenerima,
    required this.refId,
    required this.kodeProduk,
    this.notes,
  }) : super(key: key);

  @override
  State<BankTransferInquiryScreen> createState() =>
      _BankTransferInquiryScreenState();
}

class _BankTransferInquiryScreenState extends State<BankTransferInquiryScreen> {
  late ColorNotifire notifire;
  final _pinController = TextEditingController();
  final _currencyFormat = NumberFormat('#,###', 'id_ID');

  bool _isSubmitting = false;
  bool _biometricAvailable = false;
  bool _showPinInSheet = false;
  bool _usedBiometric = false;

  double get _total => widget.total;
  String get _accountName => widget.namaPenerima;

  @override
  void initState() {
    super.initState();
    _checkBiometric();
  }

  Future<void> _checkBiometric() async {
    final available = await BiometricService.isAvailable();
    final enabled = await BiometricService.isEnabled();
    if (mounted) setState(() => _biometricAvailable = available && enabled);
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  void _onConfirmPressed() {
    _pinController.clear();
    _showPinInSheet = false;
    _usedBiometric = false;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.pinRequired) {
      _submitTransferDirect();
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _buildPinSheet(ctx),
    );
  }

  Future<void> _handleBiometricInSheet(BuildContext ctx) async {
    final success = await BiometricService.authenticate(
      reason: 'Konfirmasi transfer bank',
    );
    if (success && mounted) {
      _usedBiometric = true;
      _submitTransfer(ctx, bypassPin: true);
    }
  }

  Future<void> _submitTransfer(BuildContext ctx, {bool bypassPin = false}) async {
    if (!bypassPin && _pinController.text.length != 4) {
      _showSnackBar('Masukkan 4 digit PIN');
      return;
    }

    setState(() => _isSubmitting = true);
    final stopwatch = Stopwatch()..start();

    try {
      final response = await ApiService.bankTransferPayment(
        kodeProduk: widget.kodeProduk,
        accountNumber: widget.accountNumber,
        refId: widget.refId,
        nominal: widget.total,
        bankName: widget.bankName,
        accountName: _accountName,
        amount: widget.amount,
        admin: widget.admin,
        providerTotal: widget.providerTotal,
        pin: bypassPin ? '' : _pinController.text,
        notes: widget.notes,
        biometricAuth: _usedBiometric,
      );

      stopwatch.stop();
      if (mounted) {
        Navigator.pop(ctx); // close bottom sheet
        if (response.containsKey('message') &&
            response['message'] == 'Transfer berhasil') {
          Provider.of<AuthProvider>(context, listen: false).fetchProfile();
          _goToReceipt(stopwatch.elapsedMilliseconds);
        } else {
          _showSnackBar(response['message'] ?? 'Transfer gagal');
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(ctx);
        _showSnackBar(
            ApiService.userFriendlyMessage(e, fallback: 'Transfer gagal'));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _submitTransferDirect() async {
    setState(() => _isSubmitting = true);
    final stopwatch = Stopwatch()..start();
    try {
      final response = await ApiService.bankTransferPayment(
        kodeProduk: widget.kodeProduk,
        accountNumber: widget.accountNumber,
        refId: widget.refId,
        nominal: widget.total,
        bankName: widget.bankName,
        accountName: _accountName,
        amount: widget.amount,
        admin: widget.admin,
        providerTotal: widget.providerTotal,
        pin: '',
        notes: widget.notes,
      );
      stopwatch.stop();
      if (mounted) {
        if (response.containsKey('message') &&
            response['message'] == 'Transfer berhasil') {
          Provider.of<AuthProvider>(context, listen: false).fetchProfile();
          _goToReceipt(stopwatch.elapsedMilliseconds);
        } else {
          _showSnackBar(response['message'] ?? 'Transfer gagal');
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(
            ApiService.userFriendlyMessage(e, fallback: 'Transfer gagal'));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _goToReceipt(int processingMs) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => BankTransferReceiptScreen(
          amount: widget.amount,
          admin: widget.admin,
          total: widget.total,
          receiverName: _accountName,
          accountNumber: widget.accountNumber,
          bankName: widget.bankName,
          transactionTime: DateTime.now(),
          referenceNumber: widget.refId.isNotEmpty ? widget.refId : 'TRF${DateTime.now().millisecondsSinceEpoch}',
          status: 'success',
        ),
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
    notifire = Provider.of<ColorNotifire>(context, listen: true);

    return Scaffold(
      backgroundColor: notifire.gettabwhitecolor,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 16, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.arrow_back, color: notifire.getdarkscolor),
                  ),
                  Text(
                    'Konfirmasi Transfer',
                    style: TextStyle(
                      color: notifire.getdarkscolor,
                      fontFamily: 'Gilroy Bold',
                      fontSize: 17,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(width / 20, 8, width / 20, 20),
              child: Column(
                children: [
                          // ── Detail card ──
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: Colors.grey.withOpacity(0.1)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.03),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                _detailRow('Bank Tujuan', widget.bankName),
                                _divider(),
                                _detailRow(
                                    'Nomor Rekening', widget.accountNumber),
                                _divider(),
                                _detailRow('Atas Nama', _accountName),
                                _divider(),
                                _detailRow(
                                  'Jumlah Transfer',
                                  'Rp ${_currencyFormat.format(widget.amount.toInt())}',
                                ),
                                _divider(),
                                _detailRow(
                                  'Admin',
                                  'Rp ${_currencyFormat.format(widget.admin.toInt())}',
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  width: double.infinity,
                                  height: 1,
                                  color: Colors.grey.withOpacity(0.15),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Total',
                                      style: TextStyle(
                                        color: notifire.getdarkscolor,
                                        fontFamily: 'Gilroy Bold',
                                        fontSize: 16,
                                      ),
                                    ),
                                    Text(
                                      'Rp ${_currencyFormat.format(_total.toInt())}',
                                      style: TextStyle(
                                        color: notifire.getbluecolor,
                                        fontFamily: 'Gilroy Bold',
                                        fontSize: 18,
                                      ),
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

                  // ── Bottom button ──
                  Container(
                    padding: EdgeInsets.fromLTRB(
                      width / 20,
                      16,
                      width / 20,
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
                        onPressed: _isSubmitting ? null : _onConfirmPressed,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: notifire.getbluecolor,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2),
                              )
                            : const Text(
                                'Konfirmasi',
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

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[500],
              fontFamily: 'Gilroy Medium',
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: notifire.getdarkscolor,
                fontFamily: 'Gilroy Medium',
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Divider(
      height: 1,
      color: Colors.grey.withOpacity(0.08),
    );
  }

  Widget _buildPinSheet(BuildContext ctx) {
    return StatefulBuilder(
      builder: (ctx, setSheetState) {
        return Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            top: 24,
            left: 24,
            right: 24,
          ),
          decoration: BoxDecoration(
            color: notifire.getprimerycolor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Masukkan PIN',
                style: TextStyle(
                  color: notifire.getdarkscolor,
                  fontFamily: 'Gilroy Bold',
                  fontSize: height / 42,
                ),
              ),
              const SizedBox(height: 24),
              if (_biometricAvailable && !_showPinInSheet) ...[
                GestureDetector(
                  onTap:
                      _isSubmitting ? null : () => _handleBiometricInSheet(ctx),
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: notifire.getbluecolor.withOpacity(0.1),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: notifire.getbluecolor.withOpacity(0.4),
                          width: 2),
                    ),
                    child: Icon(Icons.fingerprint,
                        color: notifire.getbluecolor, size: 40),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tekan untuk verifikasi',
                  style: TextStyle(
                    color: notifire.getdarkgreycolor,
                    fontFamily: 'Gilroy Medium',
                    fontSize: 12,
                  ),
                ),
                if (_isSubmitting) ...[
                  const SizedBox(height: 16),
                  CircularProgressIndicator(color: notifire.getbluecolor),
                ],
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () => setSheetState(() => _showPinInSheet = true),
                  child: Text(
                    'Gunakan PIN',
                    style: TextStyle(
                      color: notifire.getdarkgreycolor.withOpacity(0.7),
                      fontFamily: 'Gilroy Medium',
                      fontSize: 13,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ] else ...[
                TextField(
                  controller: _pinController,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  obscureText: true,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: notifire.getdarkscolor,
                    fontFamily: 'Gilroy Bold',
                    fontSize: height / 30,
                    letterSpacing: 12,
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '____',
                    hintStyle: TextStyle(
                      color: Colors.grey.withOpacity(0.4),
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
                      borderSide:
                          BorderSide(color: notifire.getbluecolor, width: 2),
                    ),
                  ),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
                const SizedBox(height: 8),
                Text(
                  'Masukkan 4 digit PIN',
                  style: TextStyle(
                    color: notifire.getdarkgreycolor,
                    fontFamily: 'Gilroy Medium',
                    fontSize: height / 58,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed:
                        _isSubmitting ? null : () => _submitTransfer(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: notifire.getbluecolor,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : Text(
                            'Konfirmasi Transfer',
                            style: TextStyle(
                              color: Colors.white,
                              fontFamily: 'Gilroy Bold',
                              fontSize: height / 50,
                            ),
                          ),
                  ),
                ),
                if (_biometricAvailable && _showPinInSheet) ...[
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () => setSheetState(() => _showPinInSheet = false),
                    child: Text(
                      'Gunakan Sidik Jari / Face ID',
                      style: TextStyle(
                        color: notifire.getdarkgreycolor.withOpacity(0.7),
                        fontFamily: 'Gilroy Medium',
                        fontSize: 13,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ],
              SizedBox(height: MediaQuery.of(ctx).padding.bottom + 16),
            ],
          ),
        );
      },
    );
  }
}
