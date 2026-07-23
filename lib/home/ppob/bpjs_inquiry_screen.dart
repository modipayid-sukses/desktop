import 'package:flutter/material.dart';
import 'package:modipay/widgets/desktop_title_wrapper.dart';
import '../../utils/responsive.dart';

import 'package:flutter/services.dart';
import 'package:modipay/utils/toast.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../services/biometric_service.dart';
import '../../widgets/transaction_receipt.dart';

// ── Token warna senada dengan PpobProductScreen ────────────────────────────
const Color _kHeaderBlue = Color(0xFF3F6FB4);
const Color _kPageBg = Color(0xFFFAFAFA);
const Color _kCardBorder = Color(0xFFE5E9EE);
const Color _kTextPrimary = Color(0xFF1D1D1D);
const Color _kTextSecondary = Color(0xFF6B7280);

class BpjsInquiryResultScreen extends StatelessWidget {
  /// Data hasil inquiry dari endpoint `/api/loketbayar/bpjs/inquiry`.
  final Map<String, dynamic> inquiryData;

  /// Nomor BPJS yang dimasukkan user (fallback bila response tidak punya).
  final String customerId;

  /// Nama produk BPJS yang dipilih user di layar sebelumnya.
  final String productName;

  const BpjsInquiryResultScreen({
    super.key,
    required this.inquiryData,
    required this.customerId,
    required this.productName,
  });

  // ─── Helpers ───────────────────────────────────────────────────────────

  static double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    if (value is String) {
      // Remove common non-numeric characters like commas or spaces if any
      final clean = value.replaceAll(RegExp(r'[^0-9.]'), '');
      return double.tryParse(clean) ?? 0;
    }
    return double.tryParse(value.toString()) ?? 0;
  }

  /// Pilih kandidat skalar pertama yang bernilai > 0. Backend kadang
  /// meneruskan response mentah Loket Bayar (mis. `tagihan`/`total` flat) atau
  /// gagal men-summarize sehingga `nominal` bernilai 0/null — sehingga `??`
  /// saja tidak cukup (nilai 0 bukan null). Nilai bertipe List diabaikan.
  static double _firstAmount(List<dynamic> candidates) {
    for (final c in candidates) {
      if (c is List) continue;
      final n = _toDouble(c);
      if (n > 0) return n;
    }
    return 0;
  }

  static String _firstText(List<dynamic> candidates) {
    for (final c in candidates) {
      final s = (c ?? '').toString().trim();
      if (s.isNotEmpty) return s;
    }
    return '';
  }

  String _money(dynamic v) {
    if (v == null) return 'Rp 0';
    final n = _toDouble(v);
    if (n == 0) return 'Gratis!';
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
      appBar: isDesktopPopup(context) ? null : AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        backgroundColor: _kPageBg,
        leading: DesktopLeadingWrapper(
          child: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: _kTextPrimary),
          ),
        ),
        iconTheme: const IconThemeData(color: _kTextPrimary),
        title: DesktopTitleWrapper(child: const Text(
          'Detail Tagihan',
          style: TextStyle(
            color: _kTextPrimary,
            fontFamily: 'Gilroy Bold',
            fontSize: 18,
          ),
        ))
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
                    // Card 1: Data Peserta
                    _Card(
                      title: 'Data Peserta',
                      children: [
                        _row(
                          'No. BPJS',
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
                        _row('Jenis', productName),
                        if ((data['kode_produk'] ?? '').toString().isNotEmpty)
                          _row('Kode Produk', data['kode_produk'].toString()),
                        if ((data['segmen'] ?? '').toString().isNotEmpty)
                          _row('Segmen', data['segmen'].toString()),
                        if ((data['kelas'] ?? '').toString().isNotEmpty)
                          _row('Kelas', data['kelas'].toString()),
                        if ((data['alamat'] ?? '').toString().isNotEmpty)
                          _row('Alamat', data['alamat'].toString()),
                        if ((data['lembar_tagihan'] ?? '')
                            .toString()
                            .isNotEmpty)
                          _row(
                            'Jumlah Bulan',
                            data['lembar_tagihan'].toString(),
                          ),
                        if ((data['periode'] ?? '').toString().isNotEmpty)
                          _row('Periode', data['periode'].toString()),
                      ],
                    ),

                    if (tagihan.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _Card(
                        title: 'Rincian Tagihan',
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
                            if ((tagihan[i]['periode'] ?? '').toString().isNotEmpty)
                              _row(
                                'Periode',
                                (tagihan[i]['periode'] ?? '-').toString(),
                              ),
                            if (tagihan[i]['premi'] != null)
                              _row(
                                'Premi',
                                _money(tagihan[i]['premi']),
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
                        _row(
                          'Total Tagihan',
                          _money(_firstAmount([
                            data['nominal'],
                            data['tagihan'],
                          ])),
                        ),
                        if (_toDouble(data['denda']) > 0)
                          _row('Total Denda', _money(data['denda'])),
                        _row('Biaya Admin', _money(data['admin'])),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Divider(height: 1, color: _kCardBorder),
                        ),
                        _row(
                          'Total Bayar',
                          _money(_firstAmount([
                            data['total'],
                            data['selling_price'],
                          ])),
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
                          double total = _firstAmount([
                            data['total'],
                            data['selling_price'],
                          ]);
                          if (total <= 0) {
                            total = _toDouble(data['tagihan']) +
                                _toDouble(data['admin']) +
                                _toDouble(data['denda']);
                          }
                          if (total <= 0) {
                            showToast(
                              msg: 'Total tagihan tidak valid',
                            );
                            return;
                          }
                          final refId = _firstText([
                            data['ref_id'],
                            data['refID'],
                          ]);
                          if (refId.isEmpty) {
                            showToast(
                              msg:
                                  'Ref ID tidak ditemukan, silakan cek tagihan ulang',
                            );
                            return;
                          }
                          final kodeProduk = _firstText([
                            data['kode_produk'],
                            data['kodeProduk'],
                          ]);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => _BpjsPayPinScreen(
                                kodeProduk: kodeProduk,
                                customerNo: (data['idpel'] ??
                                        data['customer_no'] ??
                                        data['noVA'] ??
                                        customerId)
                                    .toString(),
                                customerName: (data['nama'] ??
                                        data['customer_name'] ??
                                        '-')
                                    .toString(),
                                productName: productName,
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
                          'Bayar ${_money(_firstAmount([data['total'], data['selling_price']]))}',
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
        borderRadius: BorderRadius.circular(20),
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
// PIN screen untuk pembayaran BPJS via Loket Bayar.
// ═══════════════════════════════════════════════════════════════════════════

class _BpjsPayPinScreen extends StatefulWidget {
  final String kodeProduk;
  final String customerNo;
  final String customerName;
  final String productName;
  final String refId;
  final double total;

  const _BpjsPayPinScreen({
    required this.kodeProduk,
    required this.customerNo,
    required this.customerName,
    required this.productName,
    required this.refId,
    required this.total,
  });

  @override
  State<_BpjsPayPinScreen> createState() => _BpjsPayPinScreenState();
}

class _BpjsPayPinScreenState extends State<_BpjsPayPinScreen> {
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
      reason: 'Konfirmasi pembayaran BPJS ${widget.productName}',
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
      showToast(msg: 'Masukkan PIN 4 digit');
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
        productName: 'BPJS ${widget.productName}',
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
              title: 'Pembayaran BPJS ${widget.productName}',
              status: (tx['status'] ?? 'completed').toString(),
              amount: widget.total,
              productName: 'BPJS ${widget.productName}',
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
        showToast(
          msg: response['message']?.toString() ?? 'Pembayaran gagal',
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isPaying = false);
      showToast(
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
      appBar: isDesktopPopup(context) ? null : AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        backgroundColor: _kPageBg,
        leading: DesktopLeadingWrapper(
          child: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: _kTextPrimary),
          ),
        ),
        iconTheme: const IconThemeData(color: _kTextPrimary),
        title: DesktopTitleWrapper(child: const Text(
          'Konfirmasi Pembayaran',
          style: TextStyle(
            color: _kTextPrimary,
            fontFamily: 'Gilroy Bold',
            fontSize: 18,
          ),
        ))
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
                    _summaryRow('Layanan', 'BPJS ${widget.productName}'),
                    _summaryRow('No. BPJS', widget.customerNo),
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
