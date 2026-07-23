import 'package:flutter/material.dart';
import 'package:modipay/widgets/desktop_title_wrapper.dart';

import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../services/biometric_service.dart';
import '../../utils/colornotifire.dart';
import '../../utils/qris_parser.dart';
import '../../utils/transaction_helpers.dart';
import '../../widgets/transaction_receipt.dart';

class QrisCustomerPaymentScreen extends StatefulWidget {
  final String qrisCode;

  const QrisCustomerPaymentScreen({
    required this.qrisCode,
    Key? key,
  }) : super(key: key);

  @override
  State<QrisCustomerPaymentScreen> createState() =>
      _QrisCustomerPaymentScreenState();
}

class _QrisCustomerPaymentScreenState extends State<QrisCustomerPaymentScreen> {
  late ColorNotifire notifire;
  final _currencyFormat = NumberFormat('#,###', 'id_ID');
  final _notesController = TextEditingController();
  final _pinController = TextEditingController();

  String _amountRaw = '';

  Map<String, dynamic>? _merchantInfo;
  QrisData? _qrisData;
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _biometricAvailable = false;
  bool _showNotesField = false;

  @override
  void initState() {
    super.initState();
    _parseQrisCode();
    _loadMerchantInfo();
    _checkBiometric();
  }

  @override
  void dispose() {
    _notesController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  void _parseQrisCode() {
    final parsed = QrisParser.parse(widget.qrisCode);
    if (parsed != null && mounted) {
      setState(() => _qrisData = parsed);
    }
  }

  Future<void> _checkBiometric() async {
    final available = await BiometricService.isAvailable();
    final enabled = await BiometricService.isEnabled();
    if (mounted) {
      setState(() => _biometricAvailable = available && enabled);
    }
  }

  Future<void> _loadMerchantInfo() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiService.getQrisPaymentDetails(widget.qrisCode);
      if (!mounted) return;

      if (response['status'] == 'success') {
        final data = response['data'];
        setState(() {
          _merchantInfo = data;
          _isLoading = false;
        });

        // Pre-fill amount
        final isDynamic = _qrisData?.isDynamicQris ?? false;
        final apiAmount = data?['amount'];
        final qrisAmount = _qrisData?.amount;

        if (isDynamic && apiAmount != null) {
          final amt = (apiAmount is num)
              ? apiAmount.toInt()
              : (int.tryParse(apiAmount.toString()) ?? 0);
          if (amt > 0) setState(() => _amountRaw = amt.toString());
        } else if (qrisAmount != null && qrisAmount.isNotEmpty) {
          final amt = int.tryParse(qrisAmount) ?? 0;
          if (amt > 0) setState(() => _amountRaw = amt.toString());
        }
      } else {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response['message'] ?? 'Gagal membaca kode QRIS')),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memproses QRIS: $e')),
        );
        Navigator.pop(context);
      }
    }
  }

  double get _amount {
    return double.tryParse(_amountRaw) ?? 0;
  }

  String get _amountFormatted {
    if (_amountRaw.isEmpty) return '0';
    final number = int.tryParse(_amountRaw) ?? 0;
    return _currencyFormat.format(number);
  }

  bool get _hasFixedAmount {
    final isDynamic = _qrisData?.isDynamicQris ?? false;
    return isDynamic &&
        (_merchantInfo?['amount'] != null ||
            (_qrisData?.amount != null && _qrisData!.amount!.isNotEmpty));
  }

  void _onNumpadTap(String digit) {
    if (_hasFixedAmount) return;
    if (_amountRaw.length >= 12) return;
    setState(() {
      if (_amountRaw == '0') {
        _amountRaw = digit;
      } else {
        _amountRaw += digit;
      }
    });
  }

  void _onNumpadDelete() {
    if (_hasFixedAmount) return;
    if (_amountRaw.isNotEmpty) {
      setState(() {
        _amountRaw = _amountRaw.substring(0, _amountRaw.length - 1);
      });
    }
  }

  Future<void> _showPinDialog() async {
    if (_amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan jumlah pembayaran')),
      );
      return;
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final balance = double.tryParse(auth.userBalance) ?? 0;
    if (balance < _amount) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saldo tidak mencukupi')),
      );
      return;
    }

    _pinController.clear();

    if (!auth.pinRequired) {
      _submitPayment(bypassPin: true);
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: !_isSubmitting,
      enableDrag: !_isSubmitting,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) => _buildPinSheet(sheetCtx, setSheetState),
        );
      },
    );
  }

  String? _pinError;
  bool _pinSubmitting = false;

  Widget _buildPinSheet(BuildContext ctx, StateSetter setSheetState) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          const Icon(Icons.lock_outline, size: 32, color: Color(0xFF0D47A1)),
          const SizedBox(height: 12),
          const Text(
            'Konfirmasi Pembayaran',
            style: TextStyle(fontSize: 18, fontFamily: 'Gilroy Bold', color: Color(0xFF111827)),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F7FA),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    _merchantInfo?['merchant_name'] ?? '-',
                    style: const TextStyle(fontSize: 14, fontFamily: 'Gilroy Bold', color: Color(0xFF111827)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Rp $_amountFormatted',
                  style: const TextStyle(fontSize: 16, fontFamily: 'Gilroy Bold', color: Color(0xFF0D47A1)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _pinController,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 4,
            textAlign: TextAlign.center,
            enabled: !_pinSubmitting,
            style: const TextStyle(fontSize: 22, letterSpacing: 10, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              counterText: '',
              hintText: '● ● ● ●',
              hintStyle: TextStyle(color: Colors.grey.shade300, letterSpacing: 10),
              filled: true,
              fillColor: const Color(0xFFF5F7FA),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF0D47A1), width: 1.5),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Colors.red, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
          if (_pinError != null) ...[  
            const SizedBox(height: 8),
            Text(
              _pinError!,
              style: const TextStyle(color: Colors.red, fontSize: 13, fontFamily: 'Gilroy Medium'),
            ),
          ],
          const SizedBox(height: 12),
          if (_biometricAvailable && !_pinSubmitting) ...[  
            TextButton.icon(
              onPressed: () async {
                final success = await BiometricService.authenticate(
                  reason: 'Konfirmasi pembayaran QRIS',
                );
                if (success && mounted) {
                  Navigator.pop(ctx);
                  _submitPayment(bypassPin: true);
                }
              },
              icon: const Icon(Icons.fingerprint, color: Color(0xFF0D47A1)),
              label: const Text(
                'Gunakan Biometrik',
                style: TextStyle(color: Color(0xFF0D47A1), fontFamily: 'Gilroy Bold'),
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (_pinSubmitting)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: SizedBox(
                width: 24, height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF0D47A1)),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text(
                      'Batal',
                      style: TextStyle(color: Color(0xFF111827), fontFamily: 'Gilroy Bold', fontSize: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _confirmPin(ctx, setSheetState),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D47A1),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text(
                      'Konfirmasi',
                      style: TextStyle(fontFamily: 'Gilroy Bold', fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _confirmPin(BuildContext sheetCtx, StateSetter setSheetState) async {
    if (_pinController.text.length != 4) {
      setSheetState(() => _pinError = 'PIN harus 4 digit');
      return;
    }

    setSheetState(() {
      _pinError = null;
      _pinSubmitting = true;
    });

    try {
      final response = await ApiService.submitQrisPayment(
        qrisCode: widget.qrisCode,
        amount: _amount,
        pin: _pinController.text,
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
      );

      if (!mounted) return;

      if (response['status'] == 'success') {
        Navigator.pop(sheetCtx);
        final txData = response['data'] ?? {};
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => TransactionReceipt(
              title: 'Pembayaran QRIS',
              status: txData['status'] ?? 'success',
              amount: _amount,
              receiverName: _merchantInfo?['merchant_name'] ?? 'Merchant',
              orderId: txData['id']?.toString(),
              providerRef: txData['reference_id'],
              notes: _notesController.text.isEmpty ? null : _notesController.text,
              transactionTime: txData['created_at'] != null
                  ? parseDateTime(txData['created_at'])
                  : DateTime.now(),
            ),
          ),
        );
        Provider.of<AuthProvider>(context, listen: false).fetchProfile();
      } else {
        // PIN salah atau error lain — tampilkan di modal, jangan tutup
        _pinController.clear();
        setSheetState(() {
          _pinSubmitting = false;
          _pinError = response['message'] ?? 'Pembayaran gagal';
        });
      }
    } catch (e) {
      _pinController.clear();
      setSheetState(() {
        _pinSubmitting = false;
        _pinError = e.toString();
      });
    }
  }

  /// Only used for biometric bypass (no PIN needed)
  Future<void> _submitPayment({bool bypassPin = false}) async {
    if (!bypassPin) return; // PIN flow is handled in _confirmPin

    setState(() => _isSubmitting = true);

    try {
      final response = await ApiService.submitQrisPayment(
        qrisCode: widget.qrisCode,
        amount: _amount,
        pin: '',
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
      );

      if (!mounted) return;

      if (response['status'] == 'success') {
        final txData = response['data'] ?? {};
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => TransactionReceipt(
              title: 'Pembayaran QRIS',
              status: txData['status'] ?? 'success',
              amount: _amount,
              receiverName: _merchantInfo?['merchant_name'] ?? 'Merchant',
              orderId: txData['id']?.toString(),
              providerRef: txData['reference_id'],
              notes: _notesController.text.isEmpty ? null : _notesController.text,
              transactionTime: txData['created_at'] != null
                  ? parseDateTime(txData['created_at'])
                  : DateTime.now(),
            ),
          ),
        );
        Provider.of<AuthProvider>(context, listen: false).fetchProfile();
      } else {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response['message'] ?? 'Pembayaran gagal')),
        );
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    notifire = Provider.of<ColorNotifire>(context, listen: true);

    final merchantName = _qrisData?.merchantName ?? _merchantInfo?['merchant_name'] ?? '-';
    final acquirerName = _qrisData?.acquirerName ?? '';
    final locationStr = _qrisData?.locationString ?? '';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1D1D1D),
        elevation: 0,
        scrolledUnderElevation: 0,
        title: DesktopTitleWrapper(child: const Text(
          'Pembayaran QRIS',
          style: TextStyle(fontFamily: 'Gilroy Bold', fontSize: 18, color: Color(0xFF1D1D1D)),
        )),
        leading: DesktopLeadingWrapper(child: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Color(0xFF1D1D1D)),
          onPressed: () => Navigator.pop(context),
        )),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0D47A1)))
          : _merchantInfo == null
              ? _buildErrorState()
              : _buildBody(merchantName, acquirerName, locationStr),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.qr_code_2, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              'QRIS Tidak Valid',
              style: TextStyle(fontSize: 18, fontFamily: 'Gilroy Bold', color: Color(0xFF111827)),
            ),
            const SizedBox(height: 8),
            Text(
              'Silakan scan ulang kode QRIS yang benar',
              style: TextStyle(fontSize: 14, fontFamily: 'Gilroy Medium', color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(String merchantName, String acquirerName, String locationStr) {
    return Column(
      children: [
        // Merchant info banner
        Container(
          width: double.infinity,
          color: const Color(0xFF0D47A1),
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                merchantName,
                style: const TextStyle(color: Colors.white, fontFamily: 'Gilroy Bold', fontSize: 16),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (locationStr.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  locationStr,
                  style: const TextStyle(color: Color(0xB3FFFFFF), fontSize: 13, fontFamily: 'Gilroy Medium'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (acquirerName.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  'Acquirer: $acquirerName',
                  style: const TextStyle(color: Color(0xB3FFFFFF), fontSize: 12, fontFamily: 'Gilroy Medium'),
                ),
              ],
            ],
          ),
        ),

        // Amount display
        Expanded(
          child: Column(
            children: [
              const SizedBox(height: 32),
              Text(
                'Jumlah Pembayaran',
                style: TextStyle(fontSize: 14, fontFamily: 'Gilroy Medium', color: Colors.grey.shade500),
              ),
              const SizedBox(height: 8),
              Text(
                'Rp $_amountFormatted',
                style: const TextStyle(
                  fontSize: 36,
                  fontFamily: 'Gilroy Bold',
                  color: Color(0xFF111827),
                ),
              ),
              if (_hasFixedAmount) ...[
                const SizedBox(height: 6),
                Text(
                  'Nominal ditentukan merchant',
                  style: TextStyle(fontSize: 12, fontFamily: 'Gilroy Medium', color: Colors.grey.shade400),
                ),
              ],
              const SizedBox(height: 12),
              if (!_showNotesField)
                GestureDetector(
                  onTap: () => setState(() => _showNotesField = true),
                  child: Text(
                    '+ Tambah Catatan',
                    style: TextStyle(fontSize: 13, fontFamily: 'Gilroy Bold', color: Colors.grey.shade400),
                  ),
                ),
              if (_showNotesField)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: TextField(
                    controller: _notesController,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13, fontFamily: 'Gilroy Medium', color: Color(0xFF111827)),
                    decoration: InputDecoration(
                      hintText: 'Catatan (opsional)',
                      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      border: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade300)),
                      focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF0D47A1))),
                    ),
                  ),
                ),
              const Spacer(),
            ],
          ),
        ),

        // Custom numpad + pay button
        if (!_hasFixedAmount) _buildNumpad(),

        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _showPinDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D47A1),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 22, height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                    )
                  : const Text('Bayar', style: TextStyle(fontFamily: 'Gilroy Bold', fontSize: 16)),
            ),
          ),
        ),
        SizedBox(height: MediaQuery.of(context).padding.bottom),
      ],
    );
  }

  Widget _buildNumpad() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          for (final row in [
            ['1', '2', '3'],
            ['4', '5', '6'],
            ['7', '8', '9'],
            ['', '0', 'del'],
          ])
            Row(
              children: row.map((key) {
                if (key.isEmpty) {
                  return const Expanded(child: SizedBox(height: 56));
                }
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      if (key == 'del') {
                        _onNumpadDelete();
                      } else {
                        _onNumpadTap(key);
                      }
                    },
                    child: Container(
                      height: 56,
                      color: Colors.transparent,
                      alignment: Alignment.center,
                      child: key == 'del'
                          ? Icon(Icons.backspace_outlined, size: 22, color: Colors.grey.shade700)
                          : Text(
                              key,
                              style: TextStyle(
                                fontSize: 24,
                                fontFamily: 'Gilroy Bold',
                                color: Colors.grey.shade800,
                              ),
                            ),
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}
