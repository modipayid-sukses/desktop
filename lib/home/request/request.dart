import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:gobank/providers/auth_provider.dart';
import 'package:gobank/services/api_service.dart';
import 'package:gobank/services/biometric_service.dart';
import 'package:gobank/utils/button.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../utils/colornotifire.dart';
import '../../utils/media.dart';

class Request extends StatefulWidget {
  const Request({Key? key}) : super(key: key);

  @override
  State<Request> createState() => _RequestState();
}

class _RequestState extends State<Request> {
  late ColorNotifire notifire;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _bankNameController = TextEditingController();
  final TextEditingController _accountNumberController = TextEditingController();
  final TextEditingController _accountNameController = TextEditingController();
  final NumberFormat _currencyFormat = NumberFormat('#,###', 'id_ID');

  List<Map<String, dynamic>> _accounts = [];
  List<Map<String, String>> _bankOptions = [];
  bool _loading = true;
  bool _saving = false;
  String _query = '';
  bool _loadingSearch = false;
  String _selectedDestinationType = 'bank';
  String _selectedDestinationCode = '';
  bool _biometricAvailable = false;

  Future<void> getdarkmodepreviousstate() async {
    final prefs = await SharedPreferences.getInstance();
    final previusstate = prefs.getBool('setIsDark');
    if (!mounted) return;
    final color = Provider.of<ColorNotifire>(context, listen: false);
    color.setIsDark = previusstate ?? false;
  }

  @override
  void initState() {
    super.initState();
    getdarkmodepreviousstate();
    _checkBiometric();
    _loadBankOptionsFromJson();
    _searchController.addListener(_onSearchChanged);
    _loadAccounts();
  }

  Future<void> _checkBiometric() async {
    final available = await BiometricService.isAvailable();
    final enabled = await BiometricService.isEnabled();
    if (!mounted) return;
    setState(() => _biometricAvailable = available && enabled);
  }

  Future<void> _loadBankOptionsFromJson() async {
    try {
      final jsonStr = await rootBundle.loadString('assets/data/bank_list.json');
      final decoded = jsonDecode(jsonStr);
      if (decoded is List || decoded is Map) {
        final banks = <Map<String, String>>[];
        final List source;
        if (decoded is Map) {
          final banks = decoded['banks'] is List ? List.from(decoded['banks'] as List) : <dynamic>[];
          final ewallets = decoded['ewallets'] is List ? List.from(decoded['ewallets'] as List) : <dynamic>[];
          source = [...banks, ...ewallets];
        } else if (decoded is List) {
          source = List.from(decoded);
        } else {
          source = [];
        }

        for (final item in source) {
          if (item is String && item.trim().isNotEmpty) {
            banks.add({'name': item.trim(), 'code': ''});
          } else if (item is Map) {
            final dynamic name =
                item['name'] ?? item['bank_name'] ?? item['bankName'] ?? item['label'];
            final dynamic code = item['code'] ?? item['bank_code'] ?? item['bankCode'];
            final dynamic type = item['type'];
            if (name != null && name.toString().trim().isNotEmpty) {
              banks.add({
                'name': name.toString().trim(),
                'code': code?.toString().trim().toLowerCase() ?? '',
                'type': type?.toString().trim().toLowerCase() ?? 'bank',
              });
            }
          }
        }
        final uniq = <String, Map<String, String>>{};
        for (final bank in banks) {
          uniq[bank['name']!.toLowerCase()] = bank;
        }
        _bankOptions = uniq.values.toList()
          ..sort((a, b) => a['name']!.compareTo(b['name']!));
        if (mounted) setState(() {});
      }
    } catch (_) {
      _bankOptions = [];
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _bankNameController.dispose();
    _accountNumberController.dispose();
    _accountNameController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final next = _searchController.text.trim();
    if (next == _query) return;
    setState(() {
      _query = next;
      _loadingSearch = true;
    });
    _loadAccounts().then((_) {
      if (!mounted) return;
      setState(() => _loadingSearch = false);
    });
  }

  Future<void> _loadAccounts() async {
    if (mounted) {
      setState(() => _loading = true);
    }
    try {
      final contacts = await ApiService.getContacts(
        category: 'bank',
        search: _query.isEmpty ? null : _query,
      );
      if (!mounted) return;
      setState(() {
        _accounts = List<Map<String, dynamic>>.from(contacts);
      });
    } catch (_) {
      if (mounted) {
        Fluttertoast.showToast(msg: 'Gagal memuat data rekening');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showAddAccountDialog() async {
    if (_accounts.isNotEmpty) {
      Fluttertoast.showToast(msg: 'Hanya 1 rekening bank yang dapat ditambahkan');
      return;
    }

    _bankNameController.clear();
    _accountNumberController.clear();
    _accountNameController.clear();
    _selectedDestinationType = 'bank';
    _selectedDestinationCode = '';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Container(
              padding: EdgeInsets.fromLTRB(
                width / 20,
                18,
                width / 20,
                MediaQuery.of(context).viewInsets.bottom + 18,
              ),
              decoration: BoxDecoration(
                color: notifire.getprimerycolor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Tambah Rekening Baru',
                    style: TextStyle(
                      fontFamily: 'Gilroy Bold',
                      fontSize: height / 44,
                      color: notifire.getdarkscolor,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _bankPickerField(
                    controller: _bankNameController,
                    hint: _bankOptions.isEmpty
                    ? 'Tujuan (bank/e-wallet) belum tersedia'
                    : 'Pilih Bank / E-Wallet',
                    onTap: () async {
                      final selected = await _showBankPicker();
                      if (selected == null || !mounted) return;
                      setDialogState(() {
                        _bankNameController.text = selected['name'] ?? '';
                        _selectedDestinationType =
                            (selected['type'] ?? 'bank').toLowerCase() == 'ewallet'
                                ? 'ewallet'
                                : 'bank';
                        _selectedDestinationCode = (selected['code'] ?? '').toLowerCase();
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  _sheetField(
                    controller: _accountNumberController,
                    hint: _selectedDestinationType == 'ewallet' ? 'Nomor E-Wallet' : 'Nomor Rekening',
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 10),
                  _sheetField(
                    controller: _accountNameController,
                    hint: 'Nama Pemilik Rekening',
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: _saving ? null : () => Navigator.pop(ctx),
                          child: Container(
                            height: 48,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              color: notifire.getprimerydarkcolor,
                            ),
                            child: Center(
                              child: Text(
                                'Batal',
                                style: TextStyle(
                                  fontFamily: 'Gilroy Bold',
                                  color: notifire.getdarkscolor,
                                  fontSize: height / 55,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GestureDetector(
                          onTap: _saving
                              ? null
                              : () async {
                                  final bankName = _bankNameController.text.trim();
                                  final accountNumber = _accountNumberController.text.trim();
                                  final accountName = _accountNameController.text.trim();

                                  if (bankName.isEmpty || accountNumber.isEmpty || accountName.isEmpty) {
                                    Fluttertoast.showToast(msg: 'Semua field wajib diisi');
                                    return;
                                  }

                                  setDialogState(() => _saving = true);
                                  try {
                                    final res = await ApiService.createContact(
                                      name: accountName,
                                      phone: accountNumber,
                                      email: bankName,
                                      category: _selectedDestinationType,
                                    );
                                    if (res.containsKey('contact')) {
                                      if (mounted) Navigator.pop(ctx);
                                      Fluttertoast.showToast(msg: 'Rekening berhasil ditambahkan');
                                      await _loadAccounts();
                                    } else {
                                      Fluttertoast.showToast(msg: res['message'] ?? 'Gagal menambah rekening');
                                    }
                                  } catch (_) {
                                    Fluttertoast.showToast(msg: 'Gagal menambah rekening');
                                  } finally {
                                    if (mounted) {
                                      setDialogState(() => _saving = false);
                                    }
                                  }
                                },
                          child: Container(
                            height: 48,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              color: const Color(0xFF1565C0),
                            ),
                            child: Center(
                              child: _saving
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : Text(
                                      'Simpan',
                                      style: TextStyle(
                                        fontFamily: 'Gilroy Bold',
                                        color: Colors.white,
                                        fontSize: height / 55,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<Map<String, String>?> _showBankPicker() async {
    if (_bankOptions.isEmpty) {
      Fluttertoast.showToast(msg: 'List bank dari JSON belum terisi');
      return null;
    }

    final searchController = TextEditingController();
    var filtered = List<Map<String, String>>.from(_bankOptions);

    final selected = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Dialog(
              insetPadding: EdgeInsets.symmetric(horizontal: width / 20, vertical: 24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.72,
                padding: EdgeInsets.fromLTRB(width / 24, 14, width / 24, 12),
                decoration: BoxDecoration(
                  color: notifire.getprimerycolor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    Text(
                      'Pilih Bank / E-Wallet',
                      style: TextStyle(
                        fontFamily: 'Gilroy Bold',
                        color: notifire.getdarkscolor,
                        fontSize: height / 45,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: notifire.getprimerydarkcolor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xffd3d3d3)),
                      ),
                      child: TextField(
                        controller: searchController,
                        onChanged: (value) {
                          final q = value.trim().toLowerCase();
                          setModalState(() {
                            filtered = _bankOptions
                                .where((bank) {
                                  final name = (bank['name'] ?? '').toLowerCase();
                                  final code = (bank['code'] ?? '').toLowerCase();
                                  return name.contains(q) || code.contains(q);
                                })
                                .toList();
                          });
                        },
                        style: TextStyle(
                          color: notifire.getdarkscolor,
                          fontFamily: 'Gilroy Medium',
                          fontSize: height / 55,
                        ),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Cari nama / code...',
                          hintStyle: TextStyle(
                            color: notifire.getdarkgreycolor,
                            fontFamily: 'Gilroy Medium',
                            fontSize: height / 62,
                          ),
                          prefixIcon: Icon(Icons.search_rounded, color: notifire.getdarkgreycolor),
                          contentPadding: const EdgeInsets.only(top: 14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Text(
                                'Data tidak ditemukan',
                                style: TextStyle(
                                  color: notifire.getdarkgreycolor,
                                  fontFamily: 'Gilroy Medium',
                                ),
                              ),
                            )
                          : ListView.separated(
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) => Divider(color: Colors.grey.withOpacity(0.2), height: 1),
                              itemBuilder: (context, index) {
                                final bank = filtered[index];
                                final bankName = bank['name'] ?? '-';
                                final bankCode = bank['code'] ?? '';
                                final bankType = bank['type'] ?? 'bank';
                                final selected = _bankNameController.text.trim().toLowerCase() == bankName.toLowerCase();
                                return GestureDetector(
                                  onTap: () {
                                    Navigator.pop(ctx, bank);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                    decoration: BoxDecoration(
                                      color: selected ? const Color(0xFF1565C0).withOpacity(0.09) : Colors.transparent,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                bankName,
                                                style: TextStyle(
                                                  color: notifire.getdarkscolor,
                                                  fontFamily: 'Gilroy Medium',
                                                  fontSize: height / 56,
                                                ),
                                              ),
                                              if (bankCode.isNotEmpty)
                                                Padding(
                                                  padding: const EdgeInsets.only(top: 2),
                                                  child: Row(
                                                    children: [
                                                      Text(
                                                        bankCode.toUpperCase(),
                                                        style: TextStyle(
                                                          color: notifire.getdarkgreycolor,
                                                          fontFamily: 'Gilroy Medium',
                                                          fontSize: height / 70,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 6),
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                                        decoration: BoxDecoration(
                                                          color: bankType == 'ewallet'
                                                              ? const Color(0xFFFFF3E0)
                                                              : const Color(0xFFE3F2FD),
                                                          borderRadius: BorderRadius.circular(99),
                                                        ),
                                                        child: Text(
                                                          bankType == 'ewallet' ? 'E-Wallet' : 'Bank',
                                                          style: TextStyle(
                                                            color: bankType == 'ewallet'
                                                                ? const Color(0xFFEF6C00)
                                                                : const Color(0xFF1565C0),
                                                            fontFamily: 'Gilroy Bold',
                                                            fontSize: height / 78,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        if (selected)
                                          const Icon(Icons.check_circle_rounded, color: Color(0xFF1565C0), size: 18),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    searchController.dispose();
    return selected;
  }

  @override
  Widget build(BuildContext context) {
    notifire = Provider.of<ColorNotifire>(context, listen: true);

    return Scaffold(
      backgroundColor: notifire.getprimerycolor,
      appBar: AppBar(
        elevation: 0,
        iconTheme: IconThemeData(color: notifire.getdarkscolor),
        backgroundColor: notifire.getprimerycolor,
        title: Text(
          'Penarikan',
          style: TextStyle(
            color: notifire.getdarkscolor,
            fontSize: height / 40,
            fontFamily: 'Gilroy Bold',
          ),
        ),
      ),
      body: Container(
        width: width,
        height: height,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('images/background.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(width / 20, 14, width / 20, 10),
              child: Container(
                width: width,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F4FA8), Color(0xFF1E88E5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Rekening Penarikan',
                            style: TextStyle(
                              color: Colors.white,
                              fontFamily: 'Gilroy Bold',
                              fontSize: height / 52,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${_accounts.length} rekening tersimpan (maksimal 1)',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontFamily: 'Gilroy Medium',
                              fontSize: height / 64,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: _accounts.isNotEmpty ? null : _showAddAccountDialog,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _accounts.isNotEmpty ? Colors.white.withOpacity(0.35) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.add_rounded,
                          color: _accounts.isNotEmpty ? Colors.white70 : const Color(0xFF1565C0),
                          size: 22,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: width / 20),
              child: Stack(
                alignment: Alignment.centerRight,
                children: [
                  Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: notifire.getprimerydarkcolor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xffd3d3d3)),
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: TextStyle(
                        color: notifire.getdarkscolor,
                        fontFamily: 'Gilroy Medium',
                        fontSize: height / 55,
                      ),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Cari bank / no rekening / pemilik...',
                        hintStyle: TextStyle(
                          color: notifire.getdarkgreycolor,
                          fontSize: height / 62,
                          fontFamily: 'Gilroy Medium',
                        ),
                        prefixIcon: Icon(Icons.search_rounded, color: notifire.getdarkgreycolor),
                        contentPadding: const EdgeInsets.only(top: 14),
                      ),
                    ),
                  ),
                  if (_loadingSearch)
                    const Padding(
                      padding: EdgeInsets.only(right: 14),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else if (_query.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: IconButton(
                        onPressed: () {
                          _searchController.clear();
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(height: height / 80),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _accounts.isEmpty
                      ? Center(
                          child: Text(
                            'Belum ada rekening tersimpan',
                            style: TextStyle(
                              fontFamily: 'Gilroy Medium',
                              color: notifire.getdarkgreycolor,
                              fontSize: height / 55,
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: EdgeInsets.symmetric(horizontal: width / 20, vertical: 8),
                          itemCount: _accounts.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final item = _accounts[index];
                            final accountName = (item['name'] ?? '-').toString();
                            final accountNumber = (item['phone'] ?? '-').toString();
                            final bankName = (item['email'] ?? 'Bank').toString();

                            return GestureDetector(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => WithdrawalAmountScreen(
                                    account: item,
                                    biometricAvailable: _biometricAvailable,
                                  ),
                                ),
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: notifire.getprimerydarkcolor,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: Colors.grey.withOpacity(0.18)),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 46,
                                      height: 46,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF1565C0).withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(Icons.account_balance_rounded, color: Color(0xFF1565C0)),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            accountName,
                                            style: TextStyle(
                                              fontFamily: 'Gilroy Bold',
                                              color: notifire.getdarkscolor,
                                              fontSize: height / 52,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF1565C0).withOpacity(0.08),
                                              borderRadius: BorderRadius.circular(999),
                                            ),
                                            child: Text(
                                              bankName,
                                              style: TextStyle(
                                                fontFamily: 'Gilroy Bold',
                                                color: const Color(0xFF1565C0),
                                                fontSize: height / 72,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            accountNumber,
                                            style: TextStyle(
                                              fontFamily: 'Gilroy Medium',
                                              color: notifire.getdarkgreycolor,
                                              fontSize: height / 60,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: Colors.green.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(999),
                                          ),
                                          child: Text(
                                            'Aktif',
                                            style: TextStyle(
                                              color: Colors.green.shade700,
                                              fontFamily: 'Gilroy Bold',
                                              fontSize: height / 70,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Klik untuk tarik',
                                          style: TextStyle(
                                            color: notifire.getdarkgreycolor,
                                            fontFamily: 'Gilroy Medium',
                                            fontSize: height / 74,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(width / 20, 8, width / 20, 18),
              child: GestureDetector(
                onTap: _accounts.isNotEmpty ? null : _showAddAccountDialog,
                child: Opacity(
                  opacity: _accounts.isNotEmpty ? 0.55 : 1,
                  child: Custombutton.button(const Color(0xFF1565C0), 'Tambah Rekening', width),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sheetField({
    required TextEditingController controller,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    int? maxLength,
    List<TextInputFormatter>? inputFormatters,
    ValueChanged<String>? onChanged,
  }) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: notifire.getprimerydarkcolor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xffd3d3d3)),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        maxLength: maxLength,
        inputFormatters: inputFormatters,
        onChanged: onChanged,
        style: TextStyle(
          color: notifire.getdarkscolor,
          fontFamily: 'Gilroy Medium',
          fontSize: height / 55,
        ),
        decoration: InputDecoration(
          counterText: '',
          border: InputBorder.none,
          hintText: hint,
          hintStyle: TextStyle(
            color: notifire.getdarkgreycolor,
            fontFamily: 'Gilroy Medium',
            fontSize: height / 62,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      ),
    );
  }

  Widget _bankPickerField({
    required TextEditingController controller,
    required String hint,
    required Future<void> Function() onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: notifire.getprimerydarkcolor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xffd3d3d3)),
        ),
        child: Row(
          children: [
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                controller.text.trim().isEmpty ? hint : controller.text.trim(),
                style: TextStyle(
                  color: controller.text.trim().isEmpty ? notifire.getdarkgreycolor : notifire.getdarkscolor,
                  fontFamily: 'Gilroy Medium',
                  fontSize: height / 55,
                ),
              ),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF1565C0)),
            const SizedBox(width: 10),
          ],
        ),
      ),
    );
  }
}

class WithdrawalVerificationScreen extends StatefulWidget {
  const WithdrawalVerificationScreen({
    Key? key,
    required this.account,
    required this.amount,
    required this.biometricAvailable,
  }) : super(key: key);

  final Map<String, dynamic> account;
  final double amount;
  final bool biometricAvailable;

  @override
  State<WithdrawalVerificationScreen> createState() => _WithdrawalVerificationScreenState();
}

class WithdrawalAmountScreen extends StatefulWidget {
  const WithdrawalAmountScreen({
    Key? key,
    required this.account,
    required this.biometricAvailable,
  }) : super(key: key);

  final Map<String, dynamic> account;
  final bool biometricAvailable;

  @override
  State<WithdrawalAmountScreen> createState() => _WithdrawalAmountScreenState();
}

class _WithdrawalAmountScreenState extends State<WithdrawalAmountScreen> {
  final TextEditingController _amountController = TextEditingController();
  final NumberFormat _currencyFormat = NumberFormat('#,###', 'id_ID');

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  double _parseAmount() {
    final raw = _amountController.text.replaceAll('.', '').replaceAll(',', '');
    return double.tryParse(raw) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final notifire = Provider.of<ColorNotifire>(context, listen: true);
    final auth = Provider.of<AuthProvider>(context, listen: true);

    final bankName = (widget.account['email'] ?? 'Bank').toString();
    final accountName = (widget.account['name'] ?? '-').toString();
    final accountNumber = (widget.account['phone'] ?? '-').toString();
    final balance = double.tryParse(auth.userBalance.toString()) ?? 0;

    return Scaffold(
      backgroundColor: notifire.getprimerycolor,
      appBar: AppBar(
        backgroundColor: notifire.getprimerycolor,
        elevation: 0,
        iconTheme: IconThemeData(color: notifire.getdarkscolor),
        title: Text(
          'Nominal Penarikan',
          style: TextStyle(
            color: notifire.getdarkscolor,
            fontFamily: 'Gilroy Bold',
            fontSize: height / 44,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(width / 20, 10, width / 20, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: notifire.getprimerydarkcolor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.withOpacity(0.18)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bankName,
                      style: TextStyle(
                        fontFamily: 'Gilroy Bold',
                        color: const Color(0xFF1565C0),
                        fontSize: height / 58,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$accountName • $accountNumber',
                      style: TextStyle(
                        fontFamily: 'Gilroy Medium',
                        color: notifire.getdarkgreycolor,
                        fontSize: height / 62,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Saldo tersedia: Rp ${_currencyFormat.format(balance.toInt())}',
                      style: TextStyle(
                        fontFamily: 'Gilroy Bold',
                        color: notifire.getdarkscolor,
                        fontSize: height / 62,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: height / 20),
              Text(
                'Masukkan Nominal',
                style: TextStyle(
                  color: notifire.getdarkscolor,
                  fontFamily: 'Gilroy Bold',
                  fontSize: height / 48,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                height: 62,
                decoration: BoxDecoration(
                  color: notifire.getprimerydarkcolor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xffd3d3d3)),
                ),
                child: TextField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: TextStyle(
                    color: notifire.getdarkscolor,
                    fontFamily: 'Gilroy Bold',
                    fontSize: height / 34,
                    letterSpacing: 1.2,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Rp 0',
                    hintStyle: TextStyle(
                      color: Colors.grey.withOpacity(0.4),
                      fontFamily: 'Gilroy Bold',
                      fontSize: height / 34,
                    ),
                  ),
                  onChanged: (value) {
                    final numeric = value.replaceAll('.', '').replaceAll(',', '');
                    final parsed = int.tryParse(numeric) ?? 0;
                    final formatted = parsed == 0 ? '' : _currencyFormat.format(parsed);
                    _amountController.value = TextEditingValue(
                      text: formatted,
                      selection: TextSelection.collapsed(offset: formatted.length),
                    );
                    setState(() {});
                  },
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Minimal penarikan Rp 10.000',
                style: TextStyle(
                  color: notifire.getdarkgreycolor,
                  fontFamily: 'Gilroy Medium',
                  fontSize: height / 66,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () async {
                    final amount = _parseAmount();
                    if (amount < 10000) {
                      Fluttertoast.showToast(msg: 'Minimal penarikan Rp 10.000');
                      return;
                    }
                    if (balance < amount) {
                      Fluttertoast.showToast(msg: 'Saldo kurang');
                      return;
                    }

                    await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => WithdrawalVerificationScreen(
                          account: widget.account,
                          amount: amount,
                          biometricAvailable: widget.biometricAvailable,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    'Konfirmasi',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Gilroy Bold',
                      fontSize: height / 52,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WithdrawalVerificationScreenState extends State<WithdrawalVerificationScreen> {
  final TextEditingController _pinController = TextEditingController();
  final NumberFormat _currencyFormat = NumberFormat('#,###', 'id_ID');
  bool _showPinInput = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _showPinInput = !widget.biometricAvailable;
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _submit({required bool useBiometric}) async {
    if (_submitting) return;

    if (!useBiometric && _pinController.text.trim().length != 4) {
      Fluttertoast.showToast(msg: 'Masukkan 4 digit PIN');
      return;
    }

    if (useBiometric) {
      final ok = await BiometricService.authenticate(
        reason: 'Verifikasi penarikan saldo',
      );
      if (!ok) {
        Fluttertoast.showToast(msg: 'Verifikasi biometrik gagal');
        return;
      }
    }

    setState(() => _submitting = true);
    try {
      final res = await ApiService.createWithdrawalRequest(
        contactId: int.tryParse(widget.account['id'].toString()) ?? 0,
        amount: widget.amount,
        pin: useBiometric ? null : _pinController.text.trim(),
        biometricAuth: useBiometric,
      );

      if (res['status'] == 'success' || res['transaction'] != null) {
        if (!mounted) return;
        Fluttertoast.showToast(
          msg: res['message'] ?? 'Permintaan penarikan dibuat. Menunggu konfirmasi admin.',
        );
        Navigator.pop(context, true);
      } else {
        Fluttertoast.showToast(msg: res['message'] ?? 'Gagal mengajukan penarikan');
      }
    } catch (_) {
      Fluttertoast.showToast(msg: 'Gagal mengajukan penarikan');
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifire = Provider.of<ColorNotifire>(context, listen: true);
    final bankName = (widget.account['email'] ?? 'Bank').toString();
    final accountName = (widget.account['name'] ?? '-').toString();
    final accountNumber = (widget.account['phone'] ?? '-').toString();

    return Scaffold(
      backgroundColor: notifire.getprimerycolor,
      appBar: AppBar(
        backgroundColor: notifire.getprimerycolor,
        elevation: 0,
        iconTheme: IconThemeData(color: notifire.getdarkscolor),
        title: Text(
          'Verifikasi Penarikan',
          style: TextStyle(
            color: notifire.getdarkscolor,
            fontFamily: 'Gilroy Bold',
            fontSize: height / 44,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(width / 20, 10, width / 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F4FA8), Color(0xFF1E88E5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Penarikan',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.88),
                        fontFamily: 'Gilroy Medium',
                        fontSize: height / 60,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Rp ${_currencyFormat.format(widget.amount.toInt())}',
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'Gilroy Bold',
                        fontSize: height / 32,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '$bankName • $accountNumber',
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'Gilroy Medium',
                        fontSize: height / 62,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      accountName,
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'Gilroy Bold',
                        fontSize: height / 60,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: height / 20),
              if (widget.biometricAvailable && !_showPinInput) ...[
                Center(
                  child: GestureDetector(
                    onTap: _submitting ? null : () => _submit(useBiometric: true),
                    child: Container(
                      width: 92,
                      height: 92,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF1565C0).withOpacity(0.1),
                        border: Border.all(
                          color: const Color(0xFF1565C0).withOpacity(0.35),
                          width: 2,
                        ),
                      ),
                      child: const Icon(Icons.fingerprint_rounded, size: 56, color: Color(0xFF1565C0)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    'Gunakan sidik jari / face recognition',
                    style: TextStyle(
                      color: notifire.getdarkgreycolor,
                      fontFamily: 'Gilroy Medium',
                      fontSize: height / 62,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Center(
                  child: GestureDetector(
                    onTap: _submitting ? null : () => setState(() => _showPinInput = true),
                    child: Text(
                      'Gunakan PIN',
                      style: TextStyle(
                        color: notifire.getdarkgreycolor,
                        fontFamily: 'Gilroy Medium',
                        fontSize: height / 66,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
                if (_submitting) ...[
                  const SizedBox(height: 18),
                  const Center(child: CircularProgressIndicator()),
                ],
              ] else ...[
                Text(
                  'Masukkan PIN Transaksi',
                  style: TextStyle(
                    color: notifire.getdarkscolor,
                    fontFamily: 'Gilroy Bold',
                    fontSize: height / 48,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: notifire.getprimerydarkcolor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xffd3d3d3)),
                  ),
                  child: TextField(
                    controller: _pinController,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    obscureText: true,
                    textAlign: TextAlign.center,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: TextStyle(
                      color: notifire.getdarkscolor,
                      fontFamily: 'Gilroy Bold',
                      fontSize: height / 34,
                      letterSpacing: 10,
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      counterText: '',
                      hintText: '____',
                      hintStyle: TextStyle(
                        color: Colors.grey.withOpacity(0.4),
                        fontFamily: 'Gilroy Bold',
                        fontSize: height / 34,
                        letterSpacing: 10,
                      ),
                    ),
                  ),
                ),
                if (widget.biometricAvailable) ...[
                  const SizedBox(height: 10),
                  Center(
                    child: GestureDetector(
                      onTap: _submitting ? null : () => setState(() => _showPinInput = false),
                      child: Text(
                        'Gunakan Sidik Jari',
                        style: TextStyle(
                          color: notifire.getdarkgreycolor,
                          fontFamily: 'Gilroy Medium',
                          fontSize: height / 66,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _submitting ? null : () => _submit(useBiometric: false),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1565C0),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(
                            'Konfirmasi Penarikan',
                            style: TextStyle(
                              color: Colors.white,
                              fontFamily: 'Gilroy Bold',
                              fontSize: height / 52,
                            ),
                          ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
