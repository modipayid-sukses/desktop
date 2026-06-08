import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:modipay/providers/auth_provider.dart';
import 'package:modipay/services/api_service.dart';
import 'package:modipay/services/biometric_service.dart';
import 'package:modipay/utils/button.dart';
import 'package:modipay/utils/colornotifire.dart';
import 'package:modipay/utils/media.dart';
import 'package:modipay/widgets/transaction_receipt.dart';
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
    if (mounted) {
      setState(() {
        _biometricAvailable = available && enabled;
        // If biometric is available, default to show biometric UI
        if (_biometricAvailable) {
          _showPin = false;
        } else {
          _showPin = true;
        }
      });
    }
  }

  Future<void> _handleBiometric() async {
    final success = await BiometricService.authenticate(
      reason: 'Konfirmasi transfer ke ${widget.receiverName}',
    );
    if (success && mounted) {
      _usedBiometric = true;
      _submit(bypassPin: true);
    }
  }

  Future<void> _submit({bool bypassPin = false}) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!bypassPin && auth.pinRequired && _pin.length != 4) {
      return;
    }
    setState(() => _isLoading = true);
    final stopwatch = Stopwatch()..start();
    try {
      final response = await ApiService.transfer(
        widget.receiverId,
        widget.amount,
        _pin,
        notes: widget.notes,
        biometricAuth: _usedBiometric,
      );
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
          setState(() {
            _pin = ''; // Clear PIN on error
          });
          Fluttertoast.showToast(msg: response['message'] ?? 'Transfer gagal');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _pin = '';
        });
        Fluttertoast.showToast(msg: 'Kesalahan koneksi');
      }
    }
  }

  void _onKeyTap(String key) {
    if (_pin.length < 4) {
      setState(() {
        _pin += key;
      });
      if (_pin.length == 4) {
        _submit();
      }
    }
  }

  void _onBackspace() {
    if (_pin.isNotEmpty) {
      setState(() {
        _pin = _pin.substring(0, _pin.length - 1);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    notifire = Provider.of<ColorNotifire>(context, listen: true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final needPin = auth.pinRequired;

    return Scaffold(
      backgroundColor: notifire.getprimerycolor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: notifire.getprimerycolor,
        iconTheme: IconThemeData(color: notifire.getdarkscolor),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),
            if (_biometricAvailable && !_showPin)
              _buildBiometricUI()
            else
              _buildPinUI(),
            
            const Spacer(),
            
            if (_showPin || !_biometricAvailable)
              _buildKeyboard()
            else if (_biometricAvailable && !_showPin)
              Padding(
                padding: const EdgeInsets.only(bottom: 40),
                child: TextButton(
                  onPressed: () => setState(() => _showPin = true),
                  child: Text(
                    'Gunakan PIN',
                    style: TextStyle(
                      color: notifire.getbluecolor,
                      fontFamily: 'Gilroy Bold',
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBiometricUI() {
    return Column(
      children: [
        Text(
          'Konfirmasi',
          style: TextStyle(
            color: notifire.getdarkscolor,
            fontFamily: 'Gilroy Bold',
            fontSize: 24,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Verifikasi identitas Anda untuk transfer ke\n${widget.receiverName}',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.grey,
            fontFamily: 'Gilroy Medium',
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 60),
        GestureDetector(
          onTap: _isLoading ? null : _handleBiometric,
          child: Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: notifire.getbluecolor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.fingerprint,
              color: notifire.getbluecolor,
              size: 50,
            ),
          ),
        ),
        const SizedBox(height: 24),
        if (_isLoading)
          const CircularProgressIndicator()
        else
          Text(
            'Sentuh sensor untuk verifikasi',
            style: TextStyle(
              color: notifire.getdarkscolor,
              fontFamily: 'Gilroy Medium',
              fontSize: 14,
            ),
          ),
      ],
    );
  }

  Widget _buildPinUI() {
    return Column(
      children: [
        Text(
          'Masukkan PIN',
          style: TextStyle(
            color: notifire.getdarkscolor,
            fontFamily: 'Gilroy Bold',
            fontSize: 24,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Masukkan 4 digit PIN keamanan Anda',
          style: TextStyle(
            color: Colors.grey,
            fontFamily: 'Gilroy Medium',
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 60),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(4, (index) => _buildPinDot(index)),
        ),
        if (_isLoading) ...[
          const SizedBox(height: 40),
          const CircularProgressIndicator(),
        ],
      ],
    );
  }

  Widget _buildPinDot(int index) {
    bool isActive = _pin.length > index;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isActive ? notifire.getbluecolor : Colors.grey.withOpacity(0.2),
        border: Border.all(
          color: isActive ? notifire.getbluecolor : Colors.grey.withOpacity(0.2),
          width: 1,
        ),
      ),
    );
  }

  Widget _buildKeyboard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
      child: Column(
        children: [
          _buildKeyboardRow(['1', '2', '3']),
          const SizedBox(height: 20),
          _buildKeyboardRow(['4', '5', '6']),
          const SizedBox(height: 20),
          _buildKeyboardRow(['7', '8', '9']),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _biometricAvailable 
                ? _buildKeyItem(
                    icon: Icons.fingerprint, 
                    onTap: () => setState(() => _showPin = false)
                  )
                : const SizedBox(width: 60),
              _buildKeyItem(text: '0', onTap: () => _onKeyTap('0')),
              _buildKeyItem(icon: Icons.backspace_outlined, onTap: _onBackspace),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKeyboardRow(List<String> keys) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: keys.map((key) => _buildKeyItem(text: key, onTap: () => _onKeyTap(key))).toList(),
    );
  }

  Widget _buildKeyItem({String? text, IconData? icon, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: _isLoading ? null : onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 60,
        height: 60,
        child: Center(
          child: text != null
              ? Text(
                  text,
                  style: TextStyle(
                    color: notifire.getdarkscolor,
                    fontFamily: 'Gilroy Bold',
                    fontSize: 24,
                  ),
                )
              : Icon(
                  icon,
                  color: notifire.getdarkscolor,
                  size: 24,
                ),
        ),
      ),
    );
  }
}
