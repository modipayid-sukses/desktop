import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../services/biometric_service.dart';
import '../../widgets/transaction_receipt.dart';

// ── Token warna senada dengan PpobProductScreen (BPJS / Indihome) ──────────
const Color _kHeaderBlue = Color(0xFF3F6FB4);
const Color _kPageBg = Color(0xFFFAFAFA);
const Color _kCardBorder = Color(0xFFE5E9EE);
const Color _kTextPrimary = Color(0xFF1D1D1D);
const Color _kTextSecondary = Color(0xFF6B7280);

class PdamInquiryResultScreen extends StatelessWidget {
  /// Data hasil inquiry dari endpoint `/api/loketbayar/pdam/inquiry`.
  final Map<String, dynamic> inquiryData;

  /// ID pelanggan yang dimasukkan user (fallback bila response tidak punya).
  final String customerId;

  /// Nama kota PDAM yang dipilih user di layar sebelumnya.
  final String cityName;

  const PdamInquiryResultScreen({
    super.key,
    required this.inquiryData,
    required this.customerId,
    required this.cityName,
  });

  // ─── Helpers ───────────────────────────────────────────────────────────

  static double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return double.tryParse(value.toString()) ?? 0;
  }

  String _money(dynamic v) {
    final n = _toDouble(v);
    if (n <= 0) return 'Gratis!';
    return 'Rp ${NumberFormat('#,###', 'id_ID').format(n.toInt())}';
  }

  // ─── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final data = inquiryData;
    final tagihan = (data['tagihan'] is List)
        ? List<Map<String, dynamic>>.from(
            (data['tagihan'] as List)
                .whereType<Map>()
                .map(Map<String, dynamic>.from),
          )
        : <Map<String, dynamic>>[];

    return Scaffold(
      backgroundColor: _kPageBg,
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: _kHeaderBlue,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarBrightness: Brightness.dark,
          statusBarIconBrightness: Brightness.light,
          statusBarColor: Colors.transparent,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Detail Tagihan',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Gilroy Bold',
            fontSize: 18,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Card 1: Data pelanggan
                    _Card(
                      title: 'Data Pelanggan',
                      children: [
                        _row(
                          'No. Pelanggan',
                          (data['idpel'] ??
                                  data['customer_no'] ??
                                  customerId)
                              .toString(),
                        ),
                        _row(
                          'Nama',
                          (data['nama'] ?? data['customer_name'] ?? '-')
                              .toString(),
                        ),
                        _row('Kota', cityName),
                        if ((data['kode_produk'] ?? '').toString().isNotEmpty)
                          _row('Kode Produk', data['kode_produk'].toString()),
                        if ((data['tarif'] ?? '').toString().isNotEmpty)
                          _row('Tarif', data['tarif'].toString()),
                        if ((data['alamat'] ?? '').toString().isNotEmpty)
                          _row('Alamat', data['alamat'].toString()),
                        if ((data['lembar_tagihan'] ?? '')
                            .toString()
                            .isNotEmpty)
                          _row(
                            'Jumlah Bulan',
                            data['lembar_tagihan'].toString(),
                          ),
                      ],
                    ),

                    if (tagihan.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _Card(
                        title: 'Rincian Pemakaian',
                        children: [
                          for (int i = 0; i < tagihan.length; i++) ...[
                            if (i > 0)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Divider(
                                  height: 1,
                                  color: _kCardBorder,
                                ),
                              ),
                            _row(
                              'Periode',
                              (tagihan[i]['periode'] ?? '-').toString(),
                            ),
                            if (tagihan[i]['meter_awal'] != null)
                              _row(
                                'Meter Awal',
                                tagihan[i]['meter_awal'].toString(),
                              ),
                            if (tagihan[i]['meter_akhir'] != null)
                              _row(
                                'Meter Akhir',
                                tagihan[i]['meter_akhir'].toString(),
                              ),
                            if (tagihan[i]['pemakaian'] != null)
                              _row(
                                'Pemakaian',
                                '${tagihan[i]['pemakaian']} m³',
                              ),
                            _row(
                              'Tagihan',
                              _money(tagihan[i]['nominal']),
                            ),
                            if (_toDouble(tagihan[i]['denda']) > 0)
                              _row(
                                'Denda',
                                _money(tagihan[i]['denda']),
                              ),
                          ],
                        ],
                      ),
                    ],

                    const SizedBox(height: 12),
                    _Card(
                      title: 'Ringkasan Pembayaran',
                      children: [
                        _row('Total Tagihan', _money(data['nominal'])),
                        if (_toDouble(data['denda']) > 0)
                          _row('Total Denda', _money(data['denda'])),
                        _row('Biaya Admin', _money(data['admin'])),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Divider(height: 1, color: _kCardBorder),
                        ),
                        _row(
                          'Total Bayar',
                          _money(data['total'] ?? data['selling_price']),
                          highlight: true,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Bottom action bar
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: _kCardBorder),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: _kHeaderBlue),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Batal',
                          style: TextStyle(
                            color: _kHeaderBlue,
                            fontFamily: 'Gilroy Bold',
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {
                          final total = _toDouble(
                              data['total'] ?? data['selling_price']);
                          if (total <= 0) {
                            Fluttertoast.showToast(
                              msg: 'Total tagihan tidak valid',
                            );
                            return;
                          }
                          final refId =
                              (data['ref_id'] ?? '').toString().trim();
                          if (refId.isEmpty) {
                            Fluttertoast.showToast(
                              msg:
                                  'Ref ID tidak ditemukan, silakan cek tagihan ulang',
                            );
                            return;
                          }
                          final kodeProduk =
                              (data['kode_produk'] ?? '').toString().trim();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => _PdamPayPinScreen(
                                kodeProduk: kodeProduk,
                                customerNo: (data['idpel'] ??
                                        data['customer_no'] ??
                                        customerId)
                                    .toString(),
                                customerName: (data['nama'] ??
                                        data['customer_name'] ??
                                        '-')
                                    .toString(),
                                cityName: cityName,
                                refId: refId,
                                total: total,
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          backgroundColor: Colors.green,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Bayar ${_money(data['total'] ?? data['selling_price'])}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontFamily: 'Gilroy Bold',
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Small widgets ──────────────────────────────────────────────────────

  Widget _row(String label, String value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: _kTextSecondary,
              fontFamily: 'Gilroy Medium',
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: highlight ? _kHeaderBlue : _kTextPrimary,
                fontFamily: highlight ? 'Gilroy Bold' : 'Gilroy Medium',
                fontSize: highlight ? 16 : 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _Card({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: _kTextPrimary,
              fontFamily: 'Gilroy Bold',
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PIN screen untuk pembayaran PDAM via Loket Bayar.
// ═══════════════════════════════════════════════════════════════════════════

class _PdamPayPinScreen extends StatefulWidget {
  final String kodeProduk;
  final String customerNo;
  final String customerName;
  final String cityName;
  final String refId;
  final double total;

  const _PdamPayPinScreen({
    required this.kodeProduk,
    required this.customerNo,
    required this.customerName,
    required this.cityName,
    required this.refId,
    required this.total,
  });

  @override
  State<_PdamPayPinScreen> createState() => _PdamPayPinScreenState();
}

class _PdamPayPinScreenState extends State<_PdamPayPinScreen> {
  final TextEditingController _pinCtrl = TextEditingController();
  final FocusNode _pinFocus = FocusNode();
  bool _isPaying = false;
  bool _showPin = false;
  bool _biometricAvailable = false;
  bool _usedBiometric = false;

  @override
  void initState() {
    super.initState();
    _checkBiometric();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.pinRequired) {
      // Auto-pay kalau user sudah disable PIN.
      WidgetsBinding.instance.addPostFrameCallback((_) => _pay());
    } else {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _pinFocus.requestFocus(),
      );
    }
  }

  @override
  void dispose() {
    _pinCtrl.dispose();
    _pinFocus.dispose();
    super.dispose();
  }

  Future<void> _checkBiometric() async {
    final available = await BiometricService.isAvailable();
    final enabled = await BiometricService.isEnabled();
    if (mounted) {
      setState(() => _biometricAvailable = available && enabled);
    }
  }

  Future<void> _handleBiometric() async {
    final ok = await BiometricService.authenticate(
      reason: 'Konfirmasi pembayaran PDAM ${widget.cityName}',
    );
    if (ok && mounted) {
      _usedBiometric = true;
      _pay(bypassPin: true);
    }
  }

  String get _formattedTotal =>
      'Rp ${NumberFormat('#,###', 'id_ID').format(widget.total.toInt())}';

  Future<void> _pay({bool bypassPin = false}) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final pin = _pinCtrl.text.trim();
    if (!bypassPin && auth.pinRequired && pin.length != 4) {
      Fluttertoast.showToast(msg: 'Masukkan PIN 4 digit');
      return;
    }

    setState(() => _isPaying = true);
    final stopwatch = Stopwatch()..start();

    try {
      final response = await ApiService.purchaseLoketbayar(
        kodeProduk: widget.kodeProduk,
        customerNo: widget.customerNo,
        nominal: widget.total.toInt(),
        refId: widget.refId,
        pin: pin,
        biometricAuth: _usedBiometric,
        productName: 'PDAM ${widget.cityName}',
      );
      stopwatch.stop();

      if (!mounted) return;
      setState(() => _isPaying = false);

      if (response.containsKey('transaction')) {
        // Refresh saldo
        Provider.of<AuthProvider>(context, listen: false).updateBalance();

        final tx = response['transaction'] as Map<String, dynamic>? ?? {};
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => TransactionReceipt(
              title: 'Pembayaran PDAM ${widget.cityName}',
              status: (tx['status'] ?? 'completed').toString(),
              amount: widget.total,
              productName: 'PDAM ${widget.cityName}',
              customerNo: widget.customerNo,
              receiverName: widget.customerName,
              orderId: tx['order_id']?.toString(),
              providerRef: tx['provider_ref']?.toString(),
              category: 'Pascabayar',
              transactionTime: DateTime.now(),
              processingMs: stopwatch.elapsedMilliseconds,
            ),
          ),
        );
      } else {
        Fluttertoast.showToast(
          msg: response['message']?.toString() ?? 'Pembayaran gagal',
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isPaying = false);
      Fluttertoast.showToast(
        msg: ApiService.userFriendlyMessage(e, fallback: 'Pembayaran gagal'),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final needPin = auth.pinRequired;

    return Scaffold(
      backgroundColor: _kPageBg,
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: _kHeaderBlue,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarBrightness: Brightness.dark,
          statusBarIconBrightness: Brightness.light,
          statusBarColor: Colors.transparent,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Konfirmasi Pembayaran',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Gilroy Bold',
            fontSize: 18,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Summary card ───────────────────────────────────────────
            Container(
              color: _kHeaderBlue,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Anda akan membayar',
                      style: TextStyle(
                        color: _kTextSecondary,
                        fontFamily: 'Gilroy Medium',
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formattedTotal,
                      style: const TextStyle(
                        color: _kHeaderBlue,
                        fontFamily: 'Gilroy Bold',
                        fontSize: 24,
                      ),
                    ),
                    const Divider(height: 20, color: _kCardBorder),
                    _summaryRow('Layanan', 'PDAM ${widget.cityName}'),
                    _summaryRow('No. Pelanggan', widget.customerNo),
                    _summaryRow('Nama', widget.customerName),
                  ],
                ),
              ),
            ),

            // ── PIN input area ─────────────────────────────────────────
            Expanded(
              child: needPin
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Masukkan PIN',
                            style: TextStyle(
                              color: _kTextPrimary,
                              fontFamily: 'Gilroy Bold',
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'PIN 4 digit untuk konfirmasi pembayaran',
                            style: TextStyle(
                              color: _kTextSecondary,
                              fontFamily: 'Gilroy Medium',
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _pinCtrl,
                            focusNode: _pinFocus,
                            keyboardType: TextInputType.number,
                            obscureText: !_showPin,
                            maxLength: 4,
                            textAlign: TextAlign.center,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            style: const TextStyle(
                              color: _kTextPrimary,
                              fontFamily: 'Gilroy Bold',
                              fontSize: 22,
                              letterSpacing: 8,
                            ),
                            decoration: InputDecoration(
                              counterText: '',
                              hintText: '••••',
                              hintStyle: const TextStyle(
                                color: _kTextSecondary,
                                fontFamily: 'Gilroy Bold',
                                fontSize: 22,
                                letterSpacing: 8,
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 14,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    const BorderSide(color: _kCardBorder),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    const BorderSide(color: _kCardBorder),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    const BorderSide(color: _kHeaderBlue),
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _showPin
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: _kTextSecondary,
                                ),
                                onPressed: () {
                                  setState(() => _showPin = !_showPin);
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (_biometricAvailable)
                            OutlinedButton.icon(
                              onPressed: _isPaying ? null : _handleBiometric,
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(46),
                                side: const BorderSide(color: _kHeaderBlue),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: const Icon(
                                Icons.fingerprint,
                                color: _kHeaderBlue,
                              ),
                              label: const Text(
                                'Gunakan Biometrik',
                                style: TextStyle(
                                  color: _kHeaderBlue,
                                  fontFamily: 'Gilroy Bold',
                                  fontSize: 14,
                                ),
                              ),
                            ),
                        ],
                      ),
                    )
                  : const Center(
                      child: CircularProgressIndicator(
                        color: _kHeaderBlue,
                      ),
                    ),
            ),

            // ── Bottom pay button ──────────────────────────────────────
            if (needPin)
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: _kCardBorder)),
                ),
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isPaying ? null : () => _pay(),
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: Colors.green,
                      disabledBackgroundColor: Colors.green.shade200,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isPaying
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              ),
                              SizedBox(width: 10),
                              Text(
                                'Memproses pembayaran…',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontFamily: 'Gilroy Bold',
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          )
                        : Text(
                            'Bayar $_formattedTotal',
                            style: const TextStyle(
                              color: Colors.white,
                              fontFamily: 'Gilroy Bold',
                              fontSize: 14,
                            ),
                          ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: _kTextSecondary,
              fontFamily: 'Gilroy Medium',
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: _kTextPrimary,
                fontFamily: 'Gilroy Medium',
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
