import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:modipay/utils/toast.dart';
import 'package:modipay/bottombar/bottombar.dart';
import 'package:modipay/providers/auth_provider.dart';
import 'package:modipay/design/design.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/colornotifire.dart';
import '../utils/media.dart';

class SetupPinScreen extends StatefulWidget {
  const SetupPinScreen({Key? key}) : super(key: key);

  @override
  State<SetupPinScreen> createState() => _SetupPinScreenState();
}

class _SetupPinScreenState extends State<SetupPinScreen>
    with SingleTickerProviderStateMixin {
  late ColorNotifire notifire;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  // Step 1: enter PIN, Step 2: confirm PIN
  int _step = 1;
  String _pin = '';
  String _confirmPin = '';
  bool _isLoading = false;

  final List<FocusNode> _focusNodes = List.generate(4, (_) => FocusNode());
  final List<TextEditingController> _controllers =
      List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _confirmFocusNodes =
      List.generate(4, (_) => FocusNode());
  final List<TextEditingController> _confirmControllers =
      List.generate(4, (_) => TextEditingController());

  @override
  void initState() {
    super.initState();
    _loadDarkMode();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes[0].requestFocus();
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    for (final n in _focusNodes) {
      n.dispose();
    }
    for (final c in _controllers) {
      c.dispose();
    }
    for (final n in _confirmFocusNodes) {
      n.dispose();
    }
    for (final c in _confirmControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadDarkMode() async {
    final prefs = await SharedPreferences.getInstance();
    bool? previusstate = prefs.getBool("setIsDark");
    if (previusstate == null) {
      notifire.setIsDark = false;
    } else {
      notifire.setIsDark = previusstate;
    }
  }

  String _getCurrentPin() {
    if (_step == 1) {
      return _controllers.map((c) => c.text).join();
    } else {
      return _confirmControllers.map((c) => c.text).join();
    }
  }

  void _onDigitChanged(int index, String value) {
    final controllers = _step == 1 ? _controllers : _confirmControllers;
    final focusNodes = _step == 1 ? _focusNodes : _confirmFocusNodes;

    if (value.length == 1 && index < 3) {
      focusNodes[index + 1].requestFocus();
    }

    if (_step == 1) {
      _pin = controllers.map((c) => c.text).join();
    } else {
      _confirmPin = controllers.map((c) => c.text).join();
    }
    setState(() {});
  }

  void _onKeyDown(int index, RawKeyEvent event) {
    if (event is RawKeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace) {
      final controllers = _step == 1 ? _controllers : _confirmControllers;
      final focusNodes = _step == 1 ? _focusNodes : _confirmFocusNodes;

      if (controllers[index].text.isEmpty && index > 0) {
        controllers[index - 1].clear();
        focusNodes[index - 1].requestFocus();
        setState(() {});
      }
    }
  }

  Widget _pinBox({required int index, required bool confirmMode}) {
    final controllers = confirmMode ? _confirmControllers : _controllers;
    final focusNodes = confirmMode ? _confirmFocusNodes : _focusNodes;
    final text = controllers[index].text;
    final hasValue = text.isNotEmpty;
    final isActive = focusNodes[index].hasFocus && !_isLoading;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      width: 58,
      height: 64,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isActive ? notifire.getbluecolor : (hasValue ? Colors.grey.shade300 : Colors.grey.shade200),
          width: isActive ? 1.8 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isActive
                ? notifire.getbluecolor.withOpacity(0.12)
                : Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 120),
        opacity: hasValue ? 1 : 0,
        child: Container(
          width: 12,
          height: 12,
          decoration: const BoxDecoration(
            color: Colors.black87,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }

  void _goToConfirm() {
    if (_pin.length != 4) {
      showToast(msg: 'Masukkan 4 digit PIN');
      return;
    }
    setState(() => _step = 2);
    _animController.reset();
    _animController.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _confirmFocusNodes[0].requestFocus();
    });
  }

  void _goBack() {
    for (final c in _confirmControllers) {
      c.clear();
    }
    _confirmPin = '';
    setState(() => _step = 1);
    _animController.reset();
    _animController.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes[3].requestFocus();
    });
  }

  Future<void> _submitPin() async {
    if (_confirmPin.length != 4) {
      showToast(msg: 'Masukkan 4 digit PIN');
      return;
    }
    if (_pin != _confirmPin) {
      showToast(msg: 'PIN tidak cocok, silakan ulangi');
      for (final c in _confirmControllers) {
        c.clear();
      }
      _confirmPin = '';
      setState(() {});
      _confirmFocusNodes[0].requestFocus();
      return;
    }

    setState(() => _isLoading = true);

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final success = await auth.setPin(_pin);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      _showSuccessDialog();
    } else {
      showToast(msg: 'Gagal menyimpan PIN. Coba lagi.');
    }
  }

  Future<void> _showSuccessDialog() async {
    await AppDialog.success(
      context: context,
      title: 'PIN Berhasil Dibuat!',
      description: 'PIN transaksi kamu sudah aktif.\nGunakan PIN ini untuk setiap transaksi.',
      actionText: 'Mulai Gunakan Modipay',
    );
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const Bottombar()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    notifire = Provider.of<ColorNotifire>(context, listen: true);
    height = MediaQuery.of(context).size.height;
    width = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: notifire.getprimerycolor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: width / 14),
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(height: height / 10),
                  // Icon
                  Container(
                    width: height / 8,
                    height: height / 8,
                    decoration: BoxDecoration(
                      color: notifire.getbluecolor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _step == 1 ? Icons.lock_outline_rounded : Icons.verified_user_outlined,
                      color: notifire.getbluecolor,
                      size: height / 14,
                    ),
                  ),
                  SizedBox(height: height / 25),
                  Text(
                    _step == 1 ? 'Buat PIN Transaksi' : 'Konfirmasi PIN',
                    style: TextStyle(
                      color: notifire.getdarkscolor,
                      fontFamily: 'Gilroy Bold',
                      fontSize: height / 30,
                    ),
                  ),
                  SizedBox(height: height / 80),
                  Text(
                    _step == 1
                        ? 'Buat 4 digit PIN untuk keamanan\nsetiap transaksi kamu'
                        : 'Masukkan ulang PIN untuk\nmemastikan kamu tidak salah ketik',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: notifire.getdarkgreycolor,
                      fontFamily: 'Gilroy Medium',
                      fontSize: height / 55,
                      height: 1.4,
                    ),
                  ),
                  SizedBox(height: height / 14),

                  // PIN input boxes
                  GestureDetector(
                    onTap: () {
                      final focusNodes =
                          _step == 1 ? _focusNodes : _confirmFocusNodes;
                      final controllers =
                          _step == 1 ? _controllers : _confirmControllers;
                      final currentIndex = controllers.indexWhere(
                        (controller) => controller.text.isEmpty,
                      );
                      if (currentIndex >= 0) {
                        focusNodes[currentIndex].requestFocus();
                      } else {
                        focusNodes[3].requestFocus();
                      }
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(4, (index) {
                        return SizedBox(
                          width: 58,
                          height: 64,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              _pinBox(
                                index: index,
                                confirmMode: _step == 2,
                              ),
                              Opacity(
                                opacity: 0,
                                child: SizedBox(
                                  width: 58,
                                  height: 64,
                                  child: RawKeyboardListener(
                                    focusNode: FocusNode(),
                                    onKey: (event) => _onKeyDown(index, event),
                                    child: TextField(
                                      controller: _step == 1
                                          ? _controllers[index]
                                          : _confirmControllers[index],
                                      focusNode: _step == 1
                                          ? _focusNodes[index]
                                          : _confirmFocusNodes[index],
                                      textAlign: TextAlign.center,
                                      keyboardType: TextInputType.number,
                                      maxLength: 1,
                                      style: TextStyle(
                                        color: notifire.getdarkscolor,
                                        fontFamily: 'Gilroy Bold',
                                        fontSize: 20,
                                      ),
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                      ],
                                      decoration: const InputDecoration(
                                        counterText: '',
                                        border: InputBorder.none,
                                      ),
                                      onChanged: (v) => _onDigitChanged(index, v),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
                  ),

                  SizedBox(height: height / 12),

                  // Buttons
                  if (_step == 2)
                    GestureDetector(
                      onTap: _goBack,
                      child: Padding(
                        padding: EdgeInsets.only(bottom: height / 50),
                        child: Text(
                          'Ubah PIN',
                          style: TextStyle(
                            color: notifire.getbluecolor,
                            fontFamily: 'Gilroy Bold',
                            fontSize: height / 50,
                          ),
                        ),
                      ),
                    ),

                  GestureDetector(
                    onTap: _isLoading
                        ? null
                        : (_step == 1 ? _goToConfirm : _submitPin),
                    child: Container(
                      height: height / 15,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: notifire.getbluecolor,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: _isLoading
                            ? SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                _step == 1 ? 'Lanjutkan' : 'Simpan PIN',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontFamily: 'Gilroy Bold',
                                  fontSize: height / 45,
                                ),
                              ),
                      ),
                    ),
                  ),

                  SizedBox(height: height / 24),

                  // Step indicator
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _stepDot(1),
                      SizedBox(width: width / 30),
                      _stepDot(2),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _stepDot(int step) {
    final isActive = _step == step;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: isActive ? width / 10 : width / 30,
      height: 6,
      decoration: BoxDecoration(
        color: isActive
            ? notifire.getbluecolor
            : notifire.getdarkgreycolor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}
