import 'package:flutter/material.dart';

import 'package:flutter/services.dart';
import '../../utils/responsive.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../utils/colornotifire.dart';
import '../../utils/media.dart';
import '../../design/design.dart';
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

  Future<void> _showDisabledDialog() async {
    await AppDialog.show(
      context: context,
      barrierDismissible: false,
      tone: AppDialogTone.warning,
      title: 'Fitur Tidak Aktif',
      description: 'Fitur ini belum aktif di akun anda, silahkan hubungi admin',
      primaryActionText: 'OK',
    );
    if (mounted) Navigator.pop(context);
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
      backgroundColor: const Color(0xFFF8F9FD),
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 16, 8),
              child: Row(
                children: [
                  if (!isDesktop(context))
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.arrow_back, color: notifire.getdarkscolor),
                    )
                  else
                    const SizedBox(width: 16),
                  Text(
                    'Transfer Bank',
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
            child: _loadingBanks
                ? Center(
                    child: CircularProgressIndicator(
                        color: notifire.getbluecolor))
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                    child: Column(
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
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
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _fieldLabel('Pilih Bank Tujuan'),
                              const SizedBox(height: 8),
                              _buildBankSelector(),
                              const SizedBox(height: 20),
                              _fieldLabel('Nomor Rekening'),
                              const SizedBox(height: 8),
                              _buildAccountField(),
                              const SizedBox(height: 20),
                              _fieldLabel('Jumlah Transfer'),
                              const SizedBox(height: 8),
                              _buildAmountField(),
                              const SizedBox(height: 12),
                              _buildQuickAmounts(),
                              const SizedBox(height: 20),
                              _fieldLabel('Catatan (Opsional)'),
                              const SizedBox(height: 8),
                              _buildNotesField(),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.lock_outline_rounded,
                                size: 16, color: Colors.grey[500]),
                            const SizedBox(width: 8),
                            Text(
                              'Transaksi aman dan terenkripsi',
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontFamily: 'Gilroy Medium',
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
          ),
          _buildBottomPanel(),
        ],
      ),
    );
  }

  Widget _fieldLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        color: Colors.grey[750],
        fontFamily: 'Gilroy Medium',
        fontSize: 14,
      ),
    );
  }

  Widget _buildBankSelector() {
    return GestureDetector(
      onTap: _showBankPicker,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F6F8),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            if (_selectedBank != null) ...[
              CircleAvatar(
                radius: 14,
                backgroundColor: notifire.getbluecolor.withOpacity(0.1),
                child: Text(
                  _selectedBank!['name'].toString().isNotEmpty
                      ? _selectedBank!['name'].toString()[0].toUpperCase()
                      : 'B',
                  style: TextStyle(
                    color: notifire.getbluecolor,
                    fontFamily: 'Gilroy Bold',
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                _selectedBank?['name'] ?? 'Pilih bank tujuan',
                style: TextStyle(
                  color: _selectedBank != null
                      ? notifire.getdarkscolor
                      : Colors.grey[600],
                  fontFamily: 'Gilroy Medium',
                  fontSize: 15,
                ),
              ),
            ),
            Icon(Icons.keyboard_arrow_down_rounded,
                color: Colors.grey[600], size: 22),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountField() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6F8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _accountController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: TextStyle(
                color: notifire.getdarkscolor,
                fontFamily: 'Gilroy Medium',
                fontSize: 15,
              ),
              decoration: InputDecoration(
                hintText: 'Masukkan nomor rekening',
                hintStyle: TextStyle(
                  color: Colors.grey[400],
                  fontFamily: 'Gilroy Medium',
                  fontSize: 15,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
          ),
          GestureDetector(
            onTap: _goToInquiry,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Cek',
                style: TextStyle(
                  color: notifire.getbluecolor,
                  fontFamily: 'Gilroy Bold',
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountField() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6F8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: _amountController,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: _onAmountChanged,
        style: TextStyle(
          color: notifire.getdarkscolor,
          fontFamily: 'Gilroy Bold',
          fontSize: 18,
        ),
        decoration: InputDecoration(
          prefixText: 'Rp ',
          prefixStyle: TextStyle(
            color: notifire.getdarkscolor,
            fontFamily: 'Gilroy Bold',
            fontSize: 18,
          ),
          hintText: '0',
          hintStyle: TextStyle(
            color: Colors.grey[400],
            fontFamily: 'Gilroy Bold',
            fontSize: 18,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildQuickAmounts() {
    final List<int> quickAmounts = [50000, 100000, 500000];
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: quickAmounts.map((amount) {
        return GestureDetector(
          onTap: () {
            _amountController.text = _currencyFormat.format(amount);
            setState(() {});
          },
          child: Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.withOpacity(0.35)),
            ),
            child: Text(
              'Rp ${_currencyFormat.format(amount)}',
              style: TextStyle(
                color: Colors.grey[700],
                fontFamily: 'Gilroy Medium',
                fontSize: 13,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildNotesField() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6F8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: _notesController,
        keyboardType: TextInputType.text,
        maxLines: 3,
        style: TextStyle(
          color: notifire.getdarkscolor,
          fontFamily: 'Gilroy Medium',
          fontSize: 15,
        ),
        decoration: InputDecoration(
          hintText: 'Tambah catatan untuk transfer ini...',
          hintStyle: TextStyle(
            color: Colors.grey[400],
            fontFamily: 'Gilroy Medium',
            fontSize: 14,
          ),
          contentPadding: const EdgeInsets.all(16),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildBottomPanel() {
    final adminFee = _selectedBank != null
        ? (double.tryParse((_selectedBank!['total_fee'] ??
                    _selectedBank!['admin'] ??
                    0)
                .toString()) ??
            2500.0)
        : 2500.0;

    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
            top: BorderSide(color: Colors.grey.withOpacity(0.15))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Biaya Admin',
                style: TextStyle(
                  color: Colors.grey[700],
                  fontFamily: 'Gilroy Medium',
                  fontSize: 14,
                ),
              ),
              Text(
                'Rp ${_currencyFormat.format(adminFee.toInt())}',
                style: TextStyle(
                  color: notifire.getdarkscolor,
                  fontFamily: 'Gilroy Bold',
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _goToInquiry,
              style: ElevatedButton.styleFrom(
                backgroundColor: notifire.getbluecolor,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Transfer Sekarang',
                          style: TextStyle(
                            color: Colors.white,
                            fontFamily: 'Gilroy Bold',
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.send_rounded,
                            color: Colors.white, size: 18),
                      ],
                    ),
            ),
          ),
        ],
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
