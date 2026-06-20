import 'package:flutter/material.dart';
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
class TopupChannelScreen extends StatefulWidget {
  const TopupChannelScreen({Key? key}) : super(key: key);

  @override
  State<TopupChannelScreen> createState() => _TopupChannelScreenState();
}

class _TopupChannelScreenState extends State<TopupChannelScreen> {
  late ColorNotifire notifire;
  final _amountController = TextEditingController();
  final _amountFocusNode = FocusNode();
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
  void initState() {
    super.initState();
    _amountFocusNode.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _amountFocusNode.dispose();
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
      backgroundColor: const Color(0xFFF8F9FD),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              children: [
                // Custom Top Navigation Bar (Kembali Button)
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    child: Column(
                      children: [
                        // Main Top Up Form Card
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF16215C).withOpacity(0.06),
                                blurRadius: 20,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Card Header
                              Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(
                                  'Isi Saldo',
                                  style: TextStyle(
                                    color: notifire.getdarkscolor,
                                    fontFamily: 'Gilroy Bold',
                                    fontSize: 22,
                                  ),
                                ),
                              ),
                              const Divider(height: 0, color: Color(0xFFECEEF2)),
                              // Card Body
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                                child: Column(
                                  children: [
                                    Text(
                                      'Masukkan Nominal',
                                      style: TextStyle(
                                        color: Colors.grey[650],
                                        fontFamily: 'Gilroy Medium',
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    // Rp amount input row
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.baseline,
                                      textBaseline: TextBaseline.alphabetic,
                                      children: [
                                        Text(
                                          'Rp',
                                          style: TextStyle(
                                            color: _amountFocusNode.hasFocus
                                                ? const Color(0xFF0E3CBC)
                                                : Colors.grey[400],
                                            fontFamily: 'Gilroy Bold',
                                            fontSize: 28,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        SizedBox(
                                          width: 256,
                                          child: TextField(
                                            controller: _amountController,
                                            focusNode: _amountFocusNode,
                                            style: TextStyle(
                                              color: notifire.getdarkscolor,
                                              fontSize: 48,
                                              fontFamily: 'Gilroy Bold',
                                            ),
                                            keyboardType: TextInputType.number,
                                            textAlign: TextAlign.center,
                                            inputFormatters: [
                                              FilteringTextInputFormatter.digitsOnly,
                                              _ThousandsSeparatorFormatter(),
                                            ],
                                            decoration: InputDecoration(
                                              border: InputBorder.none,
                                              enabledBorder: InputBorder.none,
                                              focusedBorder: InputBorder.none,
                                              hintText: '0',
                                              hintStyle: TextStyle(
                                                color: Colors.grey[200],
                                                fontSize: 48,
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
                                    const SizedBox(height: 24),
                                    const Divider(height: 0, color: Color(0xFFE0E3E6)),
                                    const SizedBox(height: 24),
                                    // Choose nominal title
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Pilih Nominal',
                                          style: TextStyle(
                                            color: notifire.getdarkscolor,
                                            fontFamily: 'Gilroy Bold',
                                            fontSize: 16,
                                          ),
                                        ),
                                        Icon(Icons.touch_app_outlined,
                                            color: Colors.grey[400], size: 20),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    // Nominal Grid
                                    _buildNominalGrid(),
                                    const SizedBox(height: 24),
                                    // Warning minimum top up
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF2F4F8),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.info_outline,
                                              size: 18, color: Colors.grey[600]),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Minimum top up Rp 10.000',
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontFamily: 'Gilroy Medium',
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Card Footer - Lanjut Bayar button section
                              Container(
                                padding: const EdgeInsets.all(24),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFF2F4F8),
                                  borderRadius: BorderRadius.only(
                                    bottomLeft: Radius.circular(16),
                                    bottomRight: Radius.circular(16),
                                  ),
                                ),
                                child: SizedBox(
                                  width: double.infinity,
                                  height: 52,
                                  child: ElevatedButton(
                                    onPressed: _currentAmount >= _minAmount && !_isSubmitting
                                        ? _continue
                                        : null,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF3457D5),
                                      disabledBackgroundColor: const Color(0xFF3457D5).withOpacity(0.5),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
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
                                            'Lanjut Bayar',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontFamily: 'Gilroy Bold',
                                              fontSize: 15,
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                        // Trust badges
                        _buildTrustBadges(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNominalGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 2.3,
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
              color: isSelected ? const Color(0xFF3457D5) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? const Color(0xFF3457D5) : const Color(0xFFE0E3E6),
                width: 2.0,
              ),
            ),
            child: Center(
              child: Text(
                _formatNominalShort(nominal),
                style: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF191C1F),
                  fontFamily: 'Gilroy Bold',
                  fontSize: 14,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTrustBadges() {
    return Center(
      child: Opacity(
        opacity: 0.4,
        child: Wrap(
          spacing: 24,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: [
            _buildTrustItem(Icons.verified_user_outlined, 'TERENSKRIPSI 256-BIT'),
            _buildTrustItem(Icons.speed_outlined, 'PROSES INSTAN'),
            _buildTrustItem(Icons.published_with_changes_outlined, 'REFUND TERJAMIN'),
          ],
        ),
      ),
    );
  }

  Widget _buildTrustItem(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: const Color(0xFF191C1F)),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF191C1F),
            fontFamily: 'Gilroy Bold',
            fontSize: 10,
            letterSpacing: 1.2,
          ),
        ),
      ],
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
