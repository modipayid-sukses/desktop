import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../utils/colornotifire.dart';
import '../../utils/media.dart';
import 'bank_transfer_inquiry_screen.dart';

class BankTransferScreen extends StatefulWidget {
  const BankTransferScreen({Key? key}) : super(key: key);

  @override
  State<BankTransferScreen> createState() => _BankTransferScreenState();
}

class _BankTransferScreenState extends State<BankTransferScreen> {
  late ColorNotifire notifire;
  final _amountController = TextEditingController();
  final _accountController = TextEditingController();
  final _notesController = TextEditingController();
  final _currencyFormat = NumberFormat('#,###', 'id_ID');

  List<Map<String, dynamic>> _banks = [];
  Map<String, dynamic>? _selectedBank;
  bool _loadingBanks = true;
  bool _isLoading = false;

  static const int minAmount = 10000;

  @override
  void initState() {
    super.initState();
    _loadBanks();
    _checkTransferStatus();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _accountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _checkTransferStatus() async {
    try {
      final response = await ApiService.bankTransferStatus();
      if (!mounted) return;

      if (response['status'] == 'disabled') {
        _showDisabledDialog();
      }
    } catch (_) {}
  }

  void _showDisabledDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Fitur Tidak Aktif',
          style: TextStyle(fontFamily: 'Gilroy Bold', fontSize: 18),
        ),
        content: const Text(
          'Fitur ini belum aktif di akun anda, silahkan hubungi admin',
          style: TextStyle(fontFamily: 'Gilroy Medium', fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text(
              'OK',
              style: TextStyle(fontFamily: 'Gilroy Bold'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadBanks() async {
    try {
      // Sumber daftar bank: backend `/bank-transfers/banks` yang membaca
      // dari produk Loketbayar (cmd=transfer, is_active=true). Admin atur
      // biaya & ketersediaan via panel admin.
      final response = await ApiService.getBanks();
      final list = response['data'];
      if (list is List) {
        final banks = List<Map<String, dynamic>>.from(
          list.map((e) => Map<String, dynamic>.from(e as Map)),
        );
        banks.sort(
            (a, b) => (a['name'] as String).compareTo(b['name'] as String));
        if (mounted) {
          setState(() {
            _banks = banks;
            _loadingBanks = false;
          });
        }
      } else {
        if (mounted) setState(() => _loadingBanks = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loadingBanks = false);
    }
  }

  double get _amount {
    final text = _amountController.text.replaceAll('.', '').replaceAll(',', '');
    return double.tryParse(text) ?? 0;
  }

  void _onAmountChanged(String value) {
    final text = value.replaceAll('.', '').replaceAll(',', '');
    final number = int.tryParse(text) ?? 0;
    if (number > 0) {
      _amountController.value = TextEditingValue(
        text: _currencyFormat.format(number),
        selection: TextSelection.collapsed(
            offset: _currencyFormat.format(number).length),
      );
    }
    setState(() {});
  }

  void _goToInquiry() async {
    if (_selectedBank == null) {
      _showSnackBar('Pilih bank tujuan');
      return;
    }
    if (_accountController.text.trim().isEmpty) {
      _showSnackBar('Masukkan nomor rekening');
      return;
    }
    if (_amount < minAmount) {
      _showSnackBar('Minimal transfer Rp ${_currencyFormat.format(minAmount)}');
      return;
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final balance = double.tryParse(auth.userBalance) ?? 0;
    if (balance < _amount) {
      _showSnackBar('Saldo tidak mencukupi');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await ApiService.bankTransferInquiry(
        bankCode: _selectedBank!['code'],
        accountNumber: _accountController.text.trim(),
        amount: _amount,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (response['status'] == 'error') {
        _showSnackBar(response['message'] ?? 'Inquiry gagal');
        return;
      }

      final data = response['data'] ?? response;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BankTransferInquiryScreen(
            bankCode: _selectedBank!['code'],
            bankName: data['bank'] ?? _selectedBank!['name'],
            accountNumber: _accountController.text.trim(),
            amount: (data['nominal'] ?? _amount).toDouble(),
            admin: (data['admin'] ?? 0).toDouble(),
            total: (data['total'] ?? _amount).toDouble(),
            providerTotal:
                (data['provider_total'] ?? data['total'] ?? _amount).toDouble(),
            namaPenerima: data['nama_penerima'] ?? '-',
            refId: data['ref_id'] ?? '',
            kodeProduk: data['kode_produk'] ?? '',
            notes: _notesController.text.trim().isNotEmpty
                ? _notesController.text.trim()
                : null,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnackBar(ApiService.userFriendlyMessage(e, fallback: 'Inquiry gagal'));
    }
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
      backgroundColor: const Color(0xFF182974),
      appBar: AppBar(
        leading: GestureDetector(
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
        ),
        backgroundColor: const Color(0xFF182974),
        elevation: 0,
        title: const Text(
          'Transfer Bank',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Gilroy Bold',
          ),
        ),
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
              child: _loadingBanks
                  ? Center(
                      child:
                          CircularProgressIndicator(color: notifire.getbluecolor))
                  : SingleChildScrollView(
                      padding:
                          EdgeInsets.fromLTRB(width / 20, 28, width / 20, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Bank Tujuan ──
                          _simpleLabel('Bank Tujuan'),
                          const SizedBox(height: 10),
                          GestureDetector(
                            onTap: _showBankPicker,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF7F8FA),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: _selectedBank != null
                                      ? notifire.getbluecolor.withOpacity(0.3)
                                      : Colors.grey.withOpacity(0.15),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _selectedBank?['name'] ??
                                          'Pilih bank tujuan',
                                      style: TextStyle(
                                        color: _selectedBank != null
                                            ? notifire.getdarkscolor
                                            : Colors.grey[400],
                                        fontFamily: 'Gilroy Medium',
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                  Icon(Icons.keyboard_arrow_down_rounded,
                                      color: Colors.grey[400], size: 22),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 22),

                          // ── Nomor Rekening ──
                          _simpleLabel('Nomor Rekening'),
                          const SizedBox(height: 4),
                          _underlineTextField(
                            controller: _accountController,
                            hint: 'Masukkan nomor rekening',
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly
                            ],
                          ),
                          const SizedBox(height: 22),

                          // ── Jumlah Transfer ──
                          _simpleLabel('Jumlah Transfer'),
                          const SizedBox(height: 4),
                          _underlineTextField(
                            controller: _amountController,
                            hint: '0',
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly
                            ],
                            onChanged: _onAmountChanged,
                            prefixText: 'Rp ',
                          ),
                          const SizedBox(height: 22),

                          // ── Catatan ──
                          _simpleLabel('Catatan'),
                          const SizedBox(height: 4),
                          _underlineTextField(
                            controller: _notesController,
                            hint: 'Opsional',
                            keyboardType: TextInputType.text,
                          ),
                          const SizedBox(height: 36),

                          // ── Submit button ──
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _goToInquiry,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: notifire.getbluecolor,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                                elevation: 0,
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                          color: Colors.white, strokeWidth: 2),
                                    )
                                  : Text(
                                      'Transfer Sekarang',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontFamily: 'Gilroy Bold',
                                        fontSize: height / 50,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _simpleLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        color: Colors.grey[600],
        fontFamily: 'Gilroy Medium',
        fontSize: 13,
      ),
    );
  }

  Widget _underlineTextField({
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    void Function(String)? onChanged,
    String? prefixText,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
      style: TextStyle(
        color: notifire.getdarkscolor,
        fontFamily: 'Gilroy Medium',
        fontSize: 16,
      ),
      decoration: InputDecoration(
        prefixText: prefixText,
        prefixStyle: TextStyle(
          color: notifire.getdarkscolor,
          fontFamily: 'Gilroy Medium',
          fontSize: 16,
        ),
        hintText: hint,
        hintStyle: TextStyle(
          color: Colors.grey[350],
          fontFamily: 'Gilroy Medium',
          fontSize: 15,
        ),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        border: UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.grey.withOpacity(0.25)),
        ),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.grey.withOpacity(0.25)),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: notifire.getbluecolor, width: 1.5),
        ),
      ),
    );
  }

  void _showBankPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final filtered = _banks.where((b) {
              return (b['name'] as String)
                  .toLowerCase()
                  .contains(searchQuery.toLowerCase());
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.6,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: TextField(
                      onChanged: (v) =>
                          setSheetState(() => searchQuery = v),
                      style: const TextStyle(
                        fontFamily: 'Gilroy Medium',
                        fontSize: 14,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Cari bank...',
                        hintStyle: TextStyle(
                          color: Colors.grey[400],
                          fontFamily: 'Gilroy Medium',
                          fontSize: 14,
                        ),
                        prefixIcon: Icon(Icons.search_rounded,
                            color: Colors.grey[400], size: 20),
                        filled: true,
                        fillColor: const Color(0xFFF5F6F8),
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        color: Colors.grey.withOpacity(0.08),
                        indent: 16,
                        endIndent: 16,
                      ),
                      itemBuilder: (ctx, i) {
                        final bank = filtered[i];
                        final isSelected =
                            _selectedBank?['code'] == bank['code'];
                        final totalFee =
                            (bank['total_fee'] ?? bank['admin'] ?? 0)
                                .toDouble();
                        final feeLabel = totalFee > 0
                            ? 'Admin Rp ${_currencyFormat.format(totalFee.toInt())}'
                            : 'Gratis admin';
                        return InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () {
                            setState(() => _selectedBank = bank);
                            Navigator.pop(ctx);
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        bank['name'],
                                        style: TextStyle(
                                          color: isSelected
                                              ? notifire.getbluecolor
                                              : Colors.grey[800],
                                          fontFamily: isSelected
                                              ? 'Gilroy Bold'
                                              : 'Gilroy Medium',
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        feeLabel,
                                        style: TextStyle(
                                          color: Colors.grey[500],
                                          fontFamily: 'Gilroy Medium',
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isSelected)
                                  Icon(Icons.check_rounded,
                                      color: notifire.getbluecolor, size: 20),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
