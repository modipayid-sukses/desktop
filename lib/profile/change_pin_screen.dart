import 'package:flutter/material.dart';
import 'package:modipay/widgets/desktop_title_wrapper.dart';

import 'package:flutter/services.dart';
import 'package:modipay/providers/auth_provider.dart';
import 'package:modipay/utils/colornotifire.dart';
import 'package:modipay/utils/media.dart';
import 'package:provider/provider.dart';

class ChangePinScreen extends StatefulWidget {
  const ChangePinScreen({Key? key}) : super(key: key);

  @override
  State<ChangePinScreen> createState() => _ChangePinScreenState();
}

class _ChangePinScreenState extends State<ChangePinScreen> {
  int _step = 0; // 0=old, 1=new, 2=confirm
  String _oldPin = '';
  String _newPin = '';
  bool _isLoading = false;
  String? _error;

  final List<FocusNode> _focusNodes = List.generate(4, (_) => FocusNode());
  final List<TextEditingController> _boxControllers = List.generate(4, (_) => TextEditingController());

  String get _currentPin => _boxControllers.map((c) => c.text).join();

  String get _stepTitle {
    switch (_step) {
      case 0: return 'Masukkan PIN Lama';
      case 1: return 'Buat PIN Baru';
      case 2: return 'Konfirmasi PIN Baru';
      default: return '';
    }
  }

  String get _stepSubtitle {
    switch (_step) {
      case 0: return 'Masukkan 4 digit PIN lama kamu';
      case 1: return 'Masukkan 4 digit PIN baru kamu';
      case 2: return 'Masukkan ulang PIN baru untuk konfirmasi';
      default: return '';
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNodes[0].requestFocus());
  }

  @override
  void dispose() {
    for (final n in _focusNodes) n.dispose();
    for (final c in _boxControllers) c.dispose();
    super.dispose();
  }

  void _clearBoxes() {
    for (final c in _boxControllers) c.clear();
    setState(() => _error = null);
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNodes[0].requestFocus());
  }

  void _onDigitEntered(int index, String value) {
    if (value.isNotEmpty && index < 3) {
      _focusNodes[index + 1].requestFocus();
    }
    if (_currentPin.length == 4) _onPinComplete();
  }

  void _onPinComplete() {
    final pin = _currentPin;
    setState(() => _error = null);

    if (_step == 0) {
      _oldPin = pin;
      setState(() => _step = 1);
      _clearBoxes();
    } else if (_step == 1) {
      _newPin = pin;
      setState(() => _step = 2);
      _clearBoxes();
    } else {
      _submitChange(pin);
    }
  }

  Future<void> _submitChange(String confirmPin) async {
    if (_newPin != confirmPin) {
      setState(() { _error = 'PIN tidak cocok, coba lagi'; _step = 1; });
      _newPin = '';
      _clearBoxes();
      return;
    }
    if (_oldPin == _newPin) {
      setState(() { _error = 'PIN baru tidak boleh sama dengan PIN lama'; _step = 1; });
      _newPin = '';
      _clearBoxes();
      return;
    }

    setState(() => _isLoading = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final result = await auth.changePin(_oldPin, _newPin);
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['message'] == 'PIN berhasil diubah') {
      _showSuccess();
    } else {
      setState(() { _error = result['message'] ?? 'Gagal mengubah PIN'; _step = 0; });
      _oldPin = '';
      _newPin = '';
      _clearBoxes();
    }
  }

  void _showSuccess() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_rounded, color: Color(0xFF22C55E), size: 64),
            const SizedBox(height: 16),
            const Text('PIN Berhasil Diubah', style: TextStyle(fontFamily: 'Gilroy Bold', fontSize: 18)),
            const SizedBox(height: 8),
            const Text('PIN transaksi kamu sudah diperbarui.', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Gilroy Medium', color: Colors.grey)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () { Navigator.pop(ctx); Navigator.pop(context); },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E88E5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 14)),
                child: const Text('OK', style: TextStyle(fontFamily: 'Gilroy Bold', color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notifire = Provider.of<ColorNotifire>(context, listen: true);
    return Scaffold(
      backgroundColor: notifire.getprimerycolor,
      appBar: AppBar(
        backgroundColor: notifire.getprimerycolor,
        elevation: 0,
        leading: GestureDetector(
          onTap: () {
            if (_step > 0) { setState(() { _step--; _error = null; }); _clearBoxes(); }
            else Navigator.pop(context);
          },
          child: Icon(Icons.arrow_back_ios_new_rounded, color: notifire.getdarkscolor, size: 20),
        ),
        title: DesktopTitleWrapper(child: Text('Ganti PIN', style: TextStyle(color: notifire.getdarkscolor, fontFamily: 'Gilroy Bold', fontSize: height / 45))),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF1E88E5)))
          : Padding(
              padding: EdgeInsets.symmetric(horizontal: width / 10, vertical: 32),
              child: Column(
                children: [
                  // Step indicators
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(3, (i) {
                      final active = i <= _step;
                      return Row(children: [
                        Container(
                          width: 28, height: 28,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: active ? const Color(0xFF1E88E5) : Colors.grey.shade300),
                          child: Center(
                            child: i < _step
                                ? const Icon(Icons.check, color: Colors.white, size: 16)
                                : Text('${i + 1}', style: TextStyle(color: active ? Colors.white : Colors.grey.shade500, fontFamily: 'Gilroy Bold', fontSize: 12)),
                          ),
                        ),
                        if (i < 2) Container(width: 40, height: 2, color: i < _step ? const Color(0xFF1E88E5) : Colors.grey.shade300),
                      ]);
                    }),
                  ),
                  const SizedBox(height: 40),
                  Text(_stepTitle, style: TextStyle(fontFamily: 'Gilroy Bold', color: notifire.getdarkscolor, fontSize: 20)),
                  const SizedBox(height: 8),
                  Text(_stepSubtitle, textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Gilroy Medium', color: notifire.getdarkgreycolor, fontSize: 14)),
                  const SizedBox(height: 40),
                  // 4 PIN boxes
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, (i) {
                      final filled = _boxControllers[i].text.isNotEmpty;
                      return Container(
                        width: 56, height: 60,
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        child: TextField(
                          controller: _boxControllers[i],
                          focusNode: _focusNodes[i],
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          maxLength: 1,
                          obscureText: true,
                          obscuringCharacter: '●',
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          style: TextStyle(fontFamily: 'Gilroy Bold', fontSize: 24, color: notifire.getdarkscolor),
                          decoration: InputDecoration(
                            counterText: '',
                            filled: true,
                            fillColor: filled ? const Color(0xFF1E88E5).withOpacity(0.08) : notifire.getdarkwhitecolor,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: filled ? const Color(0xFF1E88E5) : Colors.grey.withOpacity(0.2), width: filled ? 1.5 : 1)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: filled ? const Color(0xFF1E88E5) : Colors.grey.withOpacity(0.2), width: filled ? 1.5 : 1)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF1E88E5), width: 2)),
                            contentPadding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onChanged: (val) {
                            setState(() {});
                            if (val.isEmpty && i > 0) _focusNodes[i - 1].requestFocus();
                            else _onDigitEntered(i, val);
                          },
                        ),
                      );
                    }),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(color: Colors.red.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red, size: 16),
                          const SizedBox(width: 8),
                          Flexible(child: Text(_error!, style: const TextStyle(fontFamily: 'Gilroy Medium', color: Colors.red, fontSize: 13))),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
