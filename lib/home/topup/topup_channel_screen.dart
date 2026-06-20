import 'package:flutter/material.dart';
import 'package:modipay/widgets/desktop_title_wrapper.dart';

import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';

import '../../utils/colornotifire.dart';
import '../../utils/media.dart';
import 'qris_payment_screen.dart';

/// Top up entry point.
///
/// Top up is QRIS-only via OnixPayz. The user picks (or types) the nominal,
/// then we navigate to [QrisPaymentScreen] which actually creates the
/// transaction and shows the QR code.
///
/// The class is still named `TopupChannelScreen` so existing call-sites
/// (`bottombar`, `home`, `topcard`, `confirmpayment`, `topphoneamount`) keep
/// compiling without further edits.
class TopupChannelScreen extends StatefulWidget {
  const TopupChannelScreen({Key? key}) : super(key: key);

  @override
  State<TopupChannelScreen> createState() => _TopupChannelScreenState();
}

class _TopupChannelScreenState extends State<TopupChannelScreen> {
  late ColorNotifire notifire;
  final _amountController = TextEditingController();
  int? _selectedNominal;
  bool _isSubmitting = false;

  static const int _minAmount = 10000;
  static const List<int> _nominals = [
    10000,
    20000,
    50000,
    100000,
    500000,
    1000000,
  ];

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  int get _currentAmount =>
      int.tryParse(_amountController.text.replaceAll('.', '')) ?? 0;

  String _formatRupiah(int amount) {
    final str = amount.toString();
    final result = StringBuffer();
    int count = 0;
    for (int i = str.length - 1; i >= 0; i--) {
      result.write(str[i]);
      count++;
      if (count % 3 == 0 && i > 0) result.write('.');
    }
    return 'Rp ${result.toString().split('').reversed.join()}';
  }

  String _formatNominalShort(int amount) {
    if (amount >= 1000000) {
      final whole = amount ~/ 1000000;
      final remain = amount % 1000000;
      return remain == 0 ? 'Rp $whole Jt' : 'Rp ${(amount / 1000000).toStringAsFixed(1)} Jt';
    } else if (amount >= 1000) {
      return 'Rp ${(amount / 1000).toStringAsFixed(0)} Rb';
    }
    return 'Rp $amount';
  }

  void _setNominal(int nominal) {
    setState(() => _selectedNominal = nominal);
    _amountController.text = _formatRupiah(nominal).replaceFirst('Rp ', '');
  }

  Future<void> _continue() async {
    if (_isSubmitting) return;
    final amount = _currentAmount;
    if (amount < _minAmount) {
      Fluttertoast.showToast(msg: 'Minimum top up Rp ${_formatRupiah(_minAmount).replaceFirst('Rp ', '')}');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => QrisPaymentScreen(amount: amount),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    height = MediaQuery.of(context).size.height;
    width = MediaQuery.of(context).size.width;
    notifire = Provider.of<ColorNotifire>(context, listen: true);

    return Scaffold(
      backgroundColor: const Color(0xFF182974),
      appBar: AppBar(
        leading: DesktopLeadingWrapper(child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            height: 40,
            width: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withOpacity(0.35)),
            ),
            child: const Icon(Icons.arrow_back, color: Colors.white),
          ),
        )),
        backgroundColor: const Color(0xFF182974),
        elevation: 0,
        title: DesktopTitleWrapper(child: const Text(
          'Top Up Saldo',
          style: TextStyle(color: Colors.white, fontFamily: 'Gilroy Bold'),
        )),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          Positioned.fill(child: Container(color: const Color(0xFF182974))),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 70,
              decoration: const BoxDecoration(
                color: Color(0xFF2A5B9C),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.elliptical(220, 90),
                  bottomRight: Radius.elliptical(220, 90),
                ),
              ),
            ),
          ),
          Positioned.fill(
            top: 16,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
              ),
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(width / 15, 28, width / 15, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildPaymentInfoCard(),
                          const SizedBox(height: 24),
                          _buildAmountInput(),
                          const SizedBox(height: 24),
                          Text(
                            'Pilih Nominal',
                            style: TextStyle(
                              color: notifire.getdarkscolor,
                              fontFamily: 'Gilroy Bold',
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildNominalGrid(),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(Icons.info_outline, size: 14, color: Colors.grey[400]),
                              const SizedBox(width: 6),
                              Text(
                                'Minimum top up Rp 10.000',
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontFamily: 'Gilroy Medium',
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  _buildBottomButton(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: notifire.getbluecolor.withOpacity(0.18)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: notifire.getbluecolor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.qr_code_2, color: notifire.getbluecolor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bayar dengan QRIS',
                  style: TextStyle(
                    color: notifire.getdarkscolor,
                    fontFamily: 'Gilroy Bold',
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Scan kode QR menggunakan aplikasi e-wallet atau mobile banking apa pun.',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontFamily: 'Gilroy Medium',
                    fontSize: 11.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountInput() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: notifire.gettabwhitecolor,
        border: Border(
          bottom: BorderSide(color: Colors.grey.withOpacity(0.28)),
        ),
      ),
      child: Column(
        children: [
          Text(
            'Masukkan Nominal',
            style: TextStyle(
              color: Colors.grey[500],
              fontFamily: 'Gilroy Medium',
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Rp',
                style: TextStyle(
                  color: notifire.getdarkscolor.withOpacity(0.5),
                  fontFamily: 'Gilroy Bold',
                  fontSize: 28,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: width * 0.45,
                child: TextFormField(
                  controller: _amountController,
                  style: TextStyle(
                    color: notifire.getdarkscolor,
                    fontSize: 32,
                    fontFamily: 'Gilroy Bold',
                  ),
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    _ThousandsSeparatorFormatter(),
                  ],
                  decoration: InputDecoration(
                    border: const UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.transparent),
                    ),
                    enabledBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.transparent),
                    ),
                    focusedBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.transparent),
                    ),
                    hintText: '0',
                    hintStyle: TextStyle(
                      color: notifire.getdarkscolor.withOpacity(0.15),
                      fontSize: 32,
                      fontFamily: 'Gilroy Bold',
                    ),
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (_) => setState(() => _selectedNominal = null),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNominalGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 2.4,
      ),
      itemCount: _nominals.length,
      itemBuilder: (context, index) {
        final nominal = _nominals[index];
        final isSelected = _selectedNominal == nominal;
        return GestureDetector(
          onTap: () => _setNominal(nominal),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: isSelected ? notifire.getbluecolor : notifire.gettabwhitecolor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? notifire.getbluecolor
                    : notifire.getbluecolor.withOpacity(0.25),
                width: isSelected ? 1.5 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: notifire.getbluecolor.withOpacity(0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: Text(
                _formatNominalShort(nominal),
                style: TextStyle(
                  color: isSelected ? Colors.white : notifire.getbluecolor,
                  fontFamily: 'Gilroy Bold',
                  fontSize: 13,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomButton() {
    final isActive = _currentAmount >= _minAmount;
    return Container(
      padding: EdgeInsets.fromLTRB(
        width / 15,
        12,
        width / 15,
        MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: notifire.getprimerycolor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: GestureDetector(
        onTap: !isActive || _isSubmitting ? null : _continue,
        child: Container(
          height: 54,
          decoration: BoxDecoration(
            color: isActive
                ? notifire.getbluecolor
                : notifire.getbluecolor.withOpacity(0.4),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: _isSubmitting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                  )
                : Text(
                    isActive ? 'Lanjut Bayar ${_formatRupiah(_currentAmount)}' : 'Lanjut Bayar',
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'Gilroy Bold',
                      fontSize: 16,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _ThousandsSeparatorFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return const TextEditingValue();
    final buf = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buf.write('.');
      buf.write(digits[i]);
    }
    final formatted = buf.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
