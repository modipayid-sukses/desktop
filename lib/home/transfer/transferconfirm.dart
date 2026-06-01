import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:gobank/providers/auth_provider.dart';
import 'package:gobank/services/api_service.dart';
import 'package:gobank/services/biometric_service.dart';
import 'package:gobank/utils/colornotifire.dart';
import 'package:gobank/utils/media.dart';
import 'package:gobank/widgets/transaction_receipt.dart';
import 'package:otp_text_field/otp_field.dart';
import 'package:otp_text_field/otp_field_style.dart';
import 'package:otp_text_field/style.dart';
import 'package:provider/provider.dart';

class TransferConfirm extends StatefulWidget {
  final int receiverId;
  final double amount;
  final String? notes;
  final String receiverName;

  const TransferConfirm({
    Key? key,
    required this.receiverId,
    required this.amount,
    this.notes,
    required this.receiverName,
  }) : super(key: key);

  @override
  State<TransferConfirm> createState() => _TransferConfirmState();
}

class _TransferConfirmState extends State<TransferConfirm> {
  late ColorNotifire notifire;
  String _pin = '';
  bool _isLoading = false;
  bool _biometricAvailable = false;
  bool _showPin = false;
  bool _usedBiometric = false;

  @override
  void initState() {
    super.initState();
    _checkBiometric();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.pinRequired) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _submit());
    }
  }

  Future<void> _checkBiometric() async {
    final available = await BiometricService.isAvailable();
    final enabled = await BiometricService.isEnabled();
    if (mounted) setState(() => _biometricAvailable = available && enabled);
  }

  Future<void> _handleBiometric() async {
    final success = await BiometricService.authenticate(
      reason: 'Konfirmasi transfer ke ${widget.receiverName}',
    );
    print('[BIOMETRIC] transferconfirm: success=$success, mounted=$mounted');
    if (success && mounted) {
      _usedBiometric = true;
      _submit(bypassPin: true);
    }
  }

  Future<void> _submit({bool bypassPin = false}) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!bypassPin && auth.pinRequired && _pin.length != 4) {
      Fluttertoast.showToast(msg: 'Masukkan PIN 4 digit Anda');
      return;
    }
    setState(() => _isLoading = true);
    final stopwatch = Stopwatch()..start();
    try {
      print('[BIOMETRIC] transferconfirm._submit: biometricAuth=$_usedBiometric, pin=${_pin.isEmpty ? "(empty)" : "****"}');
      final response = await ApiService.transfer(
        widget.receiverId,
        widget.amount,
        _pin.isEmpty ? '' : _pin,
        notes: widget.notes,
        biometricAuth: _usedBiometric,
      );
      print('[BIOMETRIC] transferconfirm API response: $response');
      stopwatch.stop();
      if (mounted) {
        setState(() => _isLoading = false);
        if (response.containsKey('transfer')) {
          Provider.of<AuthProvider>(context, listen: false).updateBalance();
          final tx = response['transfer'] as Map<String, dynamic>? ?? {};
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => TransactionReceipt(
                title: 'Transfer',
                status: tx['status'] ?? 'completed',
                amount: widget.amount,
                receiverName: widget.receiverName,
                notes: widget.notes,
                orderId: tx['order_id']?.toString(),
                transactionTime: DateTime.now(),
                processingMs: stopwatch.elapsedMilliseconds,
              ),
            ),
          );
        } else {
          Fluttertoast.showToast(msg: response['message'] ?? 'Transfer gagal');
        }
      }
    } catch (e) {
      print('[BIOMETRIC] transferconfirm ERROR: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        Fluttertoast.showToast(msg: 'Kesalahan koneksi');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    notifire = Provider.of<ColorNotifire>(context, listen: true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final needPin = auth.pinRequired;

    return Scaffold(
      backgroundColor: const Color(0xFF0D47A1),
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Konfirmasi Transfer',
          style: TextStyle(
            fontFamily: 'Gilroy Bold',
            fontSize: height / 40,
            color: Colors.white,
          ),
        ),
      ),
      body: needPin
          ? Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_biometricAvailable && !_showPin) ...[
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.fingerprint, color: Colors.white, size: 44),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Konfirmasi Transfer',
                        style: TextStyle(
                          fontFamily: 'Gilroy Bold',
                          fontSize: height / 30,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Gunakan sidik jari atau Face ID',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontFamily: 'Gilroy Medium',
                          fontSize: height / 60,
                        ),
                      ),
                      const SizedBox(height: 36),
                      GestureDetector(
                        onTap: _isLoading ? null : _handleBiometric,
                        child: Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withOpacity(0.4), width: 2),
                          ),
                          child: const Icon(Icons.fingerprint, color: Colors.white, size: 40),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Tekan untuk verifikasi',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontFamily: 'Gilroy Medium',
                          fontSize: 12,
                        ),
                      ),
                      if (_isLoading) ...[
                        const SizedBox(height: 24),
                        const CircularProgressIndicator(color: Colors.white),
                      ],
                      const SizedBox(height: 32),
                      GestureDetector(
                        onTap: () => setState(() => _showPin = true),
                        child: Text(
                          'Gunakan PIN',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontFamily: 'Gilroy Medium',
                            fontSize: 13,
                            decoration: TextDecoration.underline,
                            decorationColor: Colors.white.withOpacity(0.5),
                          ),
                        ),
                      ),
                    ] else ...[
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.lock_outline_rounded, color: Colors.white, size: 34),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Masukkan PIN',
                        style: TextStyle(
                          fontFamily: 'Gilroy Bold',
                          fontSize: height / 30,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Masukkan PIN untuk konfirmasi transfer',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontFamily: 'Gilroy Medium',
                          fontSize: height / 60,
                        ),
                      ),
                      const SizedBox(height: 36),
                      animatedBorders(),
                      const SizedBox(height: 24),
                      if (_isLoading)
                        const CircularProgressIndicator(color: Colors.white),
                      if (_biometricAvailable && _showPin) ...[
                        const SizedBox(height: 24),
                        GestureDetector(
                          onTap: () => setState(() => _showPin = false),
                          child: Text(
                            'Gunakan Sidik Jari / Face ID',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontFamily: 'Gilroy Medium',
                              fontSize: 13,
                              decoration: TextDecoration.underline,
                              decorationColor: Colors.white.withOpacity(0.5),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            )
          : Center(
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle_outline, size: 60, color: Colors.white),
                        const SizedBox(height: 16),
                        const Text('Memproses...', style: TextStyle(fontFamily: 'Gilroy Medium', color: Colors.white)),
                      ],
                    ),
            ),
    );
  }

  Widget animatedBorders() {
    return Container(
      color: notifire.getprimerycolor,
      height: height / 14,
      width: width / 1.2,
      child: OTPTextField(
          // controller: otpController,
          length: 4,
          width: MediaQuery.of(context).size.width,
          textFieldAlignment: MainAxisAlignment.spaceAround,
          otpFieldStyle: OtpFieldStyle(
            enabledBorderColor: Colors.grey.withOpacity(0.4),
            borderColor: Colors.grey.withOpacity(0.4),
          ),
          fieldWidth: 50,
          fieldStyle: FieldStyle.box,
          outlineBorderRadius: 15,
          style: TextStyle(fontSize: 17, color: notifire.getdarkscolor),
          onChanged: (pin) {
            _pin = pin;
          },
          onCompleted: (pin) {
            _pin = pin;
          }),
    );
  }
}
