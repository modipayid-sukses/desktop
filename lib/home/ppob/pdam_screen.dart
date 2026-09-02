import 'package:flutter/material.dart';
import 'package:modipay/widgets/desktop_title_wrapper.dart';

import 'package:flutter/services.dart';
import 'package:modipay/utils/toast.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../utils/responsive.dart';
import '../../services/api_service.dart';
import '../../services/app_exception.dart';
import '../../utils/colornotifire.dart';
import '../../utils/color.dart';
import '../../providers/auth_provider.dart';
import '../../design/design.dart';
import '../../services/pending_ppob_service.dart';
import 'pdam_inquiry_screen.dart';
import 'components/saved_customers_bottom_sheet.dart';

// ── Tokens warna mengikuti style PPOB (BPJS / Indihome) ─────────────────────
const Color _kHeaderBlue = Color(0xFF3F6FB4);
const Color _kPageBg = Color(0xFFF8F9FD);
const Color _kCardBorder = Color(0xFFE5E9EE);
const Color _kInputFill = Color(0xFFF5F6F8);
const Color _kInputBorder = Color(0xFFD4D8DF);
const Color _kTextPrimary = Color(0xFF1D1D1D);
const Color _kTextSecondary = Color(0xFF6B7280);
const Color _kErrorBg = Color(0xFFFFF4F4);
const Color _kErrorBorder = Color(0xFFF5C2C2);
const Color _kErrorText = Color(0xFFB00020);

class PdamScreen extends StatefulWidget {
  const PdamScreen({super.key});

  @override
  State<PdamScreen> createState() => _PdamScreenState();
}

class _PdamScreenState extends State<PdamScreen> {
  late ColorNotifire notifire;
  final TextEditingController _customerIdController = TextEditingController();
  final FocusNode _customerIdFocus = FocusNode();

  // City list dari admin panel
  bool _isLoadingCities = false;
  List<Map<String, dynamic>> _cities = [];
  Map<String, dynamic>? _selectedCity;

  // Inquiry state
  bool _isInquiring = false;
  String? _inquiryError;

  // Desktop: hasil inquiry ditampilkan inline di halaman yang sama (bukan
  // navigasi ke PdamInquiryResultScreen seperti alur mobile), meniru
  // referensi desain dua-kolom.
  Map<String, dynamic>? _inquiryData;
  bool _isPaying = false;

  // Search di bottom-sheet
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _filteredCities = [];

  @override
  void initState() {
    super.initState();
    notifire = Provider.of<ColorNotifire>(context, listen: false);
    _loadDarkMode();
    _loadCities();
  }

  @override
  void dispose() {
    _customerIdController.dispose();
    _customerIdFocus.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDarkMode() async {
    final prefs = await SharedPreferences.getInstance();
    bool? previusstate = prefs.getBool('setIsDark');
    if (previusstate == null) {
      notifire.setIsDark = false;
    } else {
      notifire.setIsDark = previusstate;
    }
  }

  Future<void> _loadCities() async {
    setState(() => _isLoadingCities = true);
    try {
      final products = await ApiService.getPpobProducts(
        cmd: 'pasca',
        brand: 'PDAM',
      );

      final unique = <String, Map<String, dynamic>>{};
      for (final p in products) {
        if (p is! Map) continue;
        final item = Map<String, dynamic>.from(p);
        final sku = (item['buyer_sku_code'] ?? item['product_code'] ?? '')
            .toString()
            .trim();
        if (sku.isEmpty) continue;
        unique.putIfAbsent(sku, () => item);
      }

      final list = unique.values.toList()
        ..sort((a, b) {
          final an = (a['product_name'] ?? '').toString().toLowerCase();
          final bn = (b['product_name'] ?? '').toString().toLowerCase();
          return an.compareTo(bn);
        });

      if (!mounted) return;
      setState(() {
        _cities = list;
        _filteredCities = List.from(list);
        _isLoadingCities = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingCities = false);
      showToast(
        msg: ApiService.userFriendlyMessage(e,
            fallback: 'Gagal memuat daftar kota PDAM'),
      );
    }
  }

  String _cityNameOf(Map<String, dynamic> city) {
    final name =
        (city['product_name'] ?? city['product_code'] ?? '').toString().trim();
    return name.isEmpty ? '-' : name;
  }

  String _citySkuOf(Map<String, dynamic> city) {
    return (city['buyer_sku_code'] ?? city['product_code'] ?? '')
        .toString()
        .trim();
  }

  void _showCityPicker() {
    if (_isLoadingCities) {
      showToast(msg: 'Sedang memuat daftar kota...');
      return;
    }
    if (_cities.isEmpty) {
      showToast(msg: 'Daftar kota PDAM belum tersedia');
      _loadCities();
      return;
    }

    _searchController.clear();
    _filteredCities = List.from(_cities);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Container(
              height: MediaQuery.of(ctx).size.height * 0.75,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  // Handle bar
                  Container(
                    margin: const EdgeInsets.only(top: 10),
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD4D8DF),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 12),
                    child: Row(
                      children: [
                        Icon(Icons.location_city_outlined,
                            color: _kHeaderBlue, size: 22),
                        SizedBox(width: 10),
                        Text(
                          'Pilih Kota PDAM',
                          style: TextStyle(
                            color: _kTextPrimary,
                            fontFamily: 'Gilroy Bold',
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Search
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      height: 46,
                      decoration: BoxDecoration(
                        color: _kInputFill,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _kInputBorder),
                      ),
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(
                          color: _kTextPrimary,
                          fontFamily: 'Gilroy Medium',
                          fontSize: 14,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Cari kota...',
                          hintStyle: TextStyle(
                            color: _kTextSecondary,
                            fontFamily: 'Gilroy Medium',
                            fontSize: 14,
                          ),
                          prefixIcon: Icon(Icons.search,
                              color: _kTextSecondary, size: 20),
                          border: InputBorder.none,
                          contentPadding:
                              EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                        ),
                        onChanged: (value) {
                          final q = value.toLowerCase();
                          setModalState(() {
                            _filteredCities = _cities
                                .where((city) =>
                                    _cityNameOf(city)
                                        .toLowerCase()
                                        .contains(q) ||
                                    _citySkuOf(city)
                                        .toLowerCase()
                                        .contains(q))
                                .toList();
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: _filteredCities.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.search_off,
                                    size: 56, color: Color(0xFFD4D8DF)),
                                SizedBox(height: 8),
                                Text(
                                  'Tidak ada kota ditemukan',
                                  style: TextStyle(
                                    color: _kTextSecondary,
                                    fontFamily: 'Gilroy Medium',
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                            itemCount: _filteredCities.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (ctx, index) {
                              final city = _filteredCities[index];
                              final cityName = _cityNameOf(city);
                              final citySku = _citySkuOf(city);
                              final isSelected = _selectedCity != null &&
                                  _citySkuOf(_selectedCity!) == citySku;
                              return InkWell(
                                onTap: () {
                                  setState(() {
                                    _selectedCity = city;
                                    _inquiryError = null;
                                    _inquiryData = null;
                                  });
                                  Navigator.pop(ctx);
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(0xFFEAF1FB)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected
                                          ? _kHeaderBlue
                                          : _kCardBorder,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? _kHeaderBlue
                                                  .withValues(alpha: 0.16)
                                              : const Color(0xFFF3F4F6),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: const Icon(
                                          Icons.water_drop_outlined,
                                          color: _kHeaderBlue,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              cityName,
                                              style: const TextStyle(
                                                color: _kTextPrimary,
                                                fontFamily: 'Gilroy Bold',
                                                fontSize: 14,
                                              ),
                                            ),
                                            if (citySku.isNotEmpty)
                                              Padding(
                                                padding: const EdgeInsets
                                                    .only(top: 2),
                                                child: Text(
                                                  citySku,
                                                  style: const TextStyle(
                                                    color: _kTextSecondary,
                                                    fontFamily: 'Gilroy Medium',
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      if (isSelected)
                                        const Icon(Icons.check_circle,
                                            color: _kHeaderBlue, size: 22),
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

  Future<void> _doInquiry() async {
    final customerId = _customerIdController.text.trim();
    if (customerId.isEmpty) {
      showToast(msg: 'Masukkan ID Pelanggan PDAM');
      _customerIdFocus.requestFocus();
      return;
    }
    if (_selectedCity == null) {
      showToast(msg: 'Pilih kota terlebih dahulu');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isInquiring = true;
      _inquiryError = null;
    });

    try {
      final sku = _citySkuOf(_selectedCity!);
      final result = await ApiService.pdamInquiry(
        kodeProduk: sku,
        customerNo: customerId,
      );

      final status = (result['status'] ?? '').toString().toLowerCase();
      final isSuccess = status == 'success' || status == 'sukses';

      if (!mounted) return;
      setState(() => _isInquiring = false);

      if (isSuccess && result['data'] is Map) {
        final data = Map<String, dynamic>.from(result['data'] as Map);
        if (isDesktop(context)) {
          setState(() => _inquiryData = data);
          return;
        }
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PdamInquiryResultScreen(
              inquiryData: data,
              customerId: customerId,
              cityName: _cityNameOf(_selectedCity!),
            ),
          ),
        );
      } else {
        setState(() {
          _inquiryError =
              (result['message'] ?? 'Cek tagihan gagal').toString();
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _inquiryError =
            ApiService.userFriendlyMessage(e, fallback: 'Cek tagihan gagal');
        _isInquiring = false;
      });
    }
  }

  void _clearError() {
    if (_inquiryError != null || _inquiryData != null) {
      setState(() {
        _inquiryError = null;
        _inquiryData = null;
      });
    }
  }

  Future<void> _openSavedCustomers() async {
    final selectedNo = await SavedCustomersBottomSheet.show(
      context,
      category: 'pdam',
      accentColor: _kHeaderBlue,
    );
    if (selectedNo != null && selectedNo.isNotEmpty) {
      setState(() {
        _customerIdController.text = selectedNo;
        _inquiryError = null;
        _inquiryData = null;
      });
    }
  }

  // ─── Desktop: helpers & pembayaran inline ───────────────────────────────

  double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    final clean = value.toString().replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(clean) ?? 0;
  }

  String _money(dynamic v) {
    final n = _toDouble(v);
    return 'Rp ${NumberFormat('#,###', 'id_ID').format(n.toInt())}';
  }

  List<Map<String, dynamic>> get _tagihanList {
    final data = _inquiryData;
    if (data == null || data['tagihan'] is! List) return [];
    return List<Map<String, dynamic>>.from(
      (data['tagihan'] as List).whereType<Map>().map(Map<String, dynamic>.from),
    );
  }

  /// Alur bayar desktop: dialog PIN kasir (sama seperti flow PPOB desktop
  /// lain) lalu `ApiService.purchaseLoketbayar` — API yang sama persis
  /// dengan yang dipakai `_PdamPayPinScreenState._pay` di alur mobile,
  /// hanya menambahkan kasirCode/kasirPin sesuai pola `TransactionPinAuthDialog`.
  Future<void> _payDesktop() async {
    final data = _inquiryData;
    if (data == null) return;
    final total = _toDouble(data['total'] ?? data['selling_price']);
    if (total <= 0) {
      showToast(msg: 'Total tagihan tidak valid');
      return;
    }
    final refId = (data['ref_id'] ?? '').toString().trim();
    if (refId.isEmpty) {
      showToast(msg: 'Ref ID tidak ditemukan, silakan cek tagihan ulang');
      return;
    }
    final kodeProduk = (data['kode_produk'] ??
            (_selectedCity != null ? _citySkuOf(_selectedCity!) : ''))
        .toString();
    final customerNo =
        (data['idpel'] ?? data['customer_no'] ?? _customerIdController.text.trim()).toString();
    final customerName = (data['nama'] ?? data['customer_name'] ?? '-').toString();
    final cityName = _selectedCity != null ? _cityNameOf(_selectedCity!) : 'PDAM';

    await TransactionPinAuthDialog.show(
      context: context,
      onConfirm: (kasirCode, kasirPin) async {
        setState(() => _isPaying = true);
        final stopwatch = Stopwatch()..start();
        try {
          final response = await ApiService.purchaseLoketbayar(
            kodeProduk: kodeProduk,
            customerNo: customerNo,
            nominal: total.toInt(),
            refId: refId,
            pin: kasirPin,
            kasirCode: kasirCode,
            kasirPin: kasirPin,
            productName: 'PDAM $cityName',
          );
          stopwatch.stop();
          if (!mounted) return;
          setState(() => _isPaying = false);

          if (response.containsKey('transaction')) {
            Provider.of<AuthProvider>(context, listen: false).updateBalance();
            final tx = response['transaction'] as Map<String, dynamic>? ?? {};
            Navigator.of(context, rootNavigator: true).pop();

            final orderId = (tx['order_id'] ?? '-').toString();
            void showSuccess(Map<String, dynamic> finalTx) {
              TransactionSuccessDialog.show(
                context: context,
                subtitle: 'Tagihan PDAM $cityName berhasil dibayar',
                orderId: (finalTx['order_id'] ?? orderId).toString(),
                rows: [
                  MapEntry('ID Pelanggan', customerNo),
                  MapEntry('Nama', customerName),
                  MapEntry('Wilayah', cityName),
                ],
                totalLabel: _money(total),
              );
            }

            // Backend PPOB/Loketbayar memproses transaksi secara async — respons
            // ini cuma tanda transaksi diterima (status 'pending'), belum tentu
            // sukses. Lihat ppob_pending_timeout_frontend_prompt.md di repo
            // modiback: harus polling /ppob/check-status sampai final, TANPA
            // membuat transaksi baru untuk customer_no yang sama selama masih
            // pending.
            if ((tx['status'] ?? '').toString() == 'pending') {
              PendingPpobService.instance.track(orderId, initialTransaction: tx);
              TransactionPendingDialog.show(
                context: context,
                orderId: orderId,
                description: 'Tagihan PDAM $cityName untuk $customerNo',
                onCompleted: (finalTx) {
                  PendingPpobService.instance.dismiss(orderId);
                  showSuccess(finalTx);
                },
                onFailed: (finalTx) {
                  PendingPpobService.instance.dismiss(orderId);
                  TransactionFailedDialog.show(
                    context: context,
                    orderId: orderId,
                    reason: TransactionFailedDialog.reasonFromTransaction(finalTx),
                  );
                },
              );
            } else {
              showSuccess(tx);
            }
          } else {
            throw AppException(response['message']?.toString() ?? 'Pembayaran gagal');
          }
        } catch (e) {
          if (mounted) setState(() => _isPaying = false);
          if (e is AppException) rethrow;
          throw AppException(ApiService.userFriendlyMessage(e, fallback: 'Pembayaran gagal'));
        }
      },
    );
  }

  Widget _desktopHeader() {
    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(color: desktopPrimaryBtn.withValues(alpha: 0.08), shape: BoxShape.circle),
          alignment: Alignment.center,
          child: const Icon(Icons.water_drop_rounded, color: desktopPrimaryBtn, size: 24),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pembayaran PDAM', style: GoogleFonts.hankenGrotesk(fontSize: 20, fontWeight: FontWeight.w800, color: desktopTextPrimary)),
            Text('Bayar tagihan air PDAM dengan mudah dan cepat', style: GoogleFonts.hankenGrotesk(fontSize: 13, color: desktopTextSecondary)),
          ],
        ),
      ],
    );
  }

  Widget _desktopDropdownField() {
    return InkWell(
      onTap: _showCityPicker,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: desktopSurfaceCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: desktopBorder),
        ),
        child: Row(
          children: [
            const Icon(Icons.location_on_outlined, size: 20, color: desktopTextSecondary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _selectedCity != null
                    ? _cityNameOf(_selectedCity!)
                    : (_isLoadingCities ? 'Memuat daftar kota...' : 'Pilih wilayah PDAM'),
                style: GoogleFonts.hankenGrotesk(
                  fontSize: 14,
                  fontWeight: _selectedCity != null ? FontWeight.w700 : FontWeight.w500,
                  color: _selectedCity != null ? desktopTextPrimary : desktopTextSecondary.withValues(alpha: 0.7),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (_isLoadingCities)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(desktopAccentBlue)),
              )
            else
              const Icon(Icons.keyboard_arrow_down_rounded, color: desktopTextSecondary),
          ],
        ),
      ),
    );
  }

  Widget _desktopTrustBadge(IconData icon, String title, String subtitle) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 18, color: desktopAccentBlue),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: GoogleFonts.hankenGrotesk(fontSize: 12, fontWeight: FontWeight.w700, color: desktopTextPrimary)),
                Text(subtitle, style: GoogleFonts.hankenGrotesk(fontSize: 10.5, color: desktopTextSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _billInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: GoogleFonts.hankenGrotesk(fontSize: 12.5, color: desktopTextSecondary))),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: GoogleFonts.hankenGrotesk(fontSize: 12.5, fontWeight: FontWeight.w700, color: desktopTextPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopBillInfo() {
    final data = _inquiryData;
    if (data == null) {
      // ── Empty state: "Informasi tagihan akan muncul di sini" ──────────
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 40),
        decoration: BoxDecoration(
          color: desktopSurfacePage,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: desktopBorder.withValues(alpha: 0.6)),
        ),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(color: desktopSurfaceCard, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: const Icon(Icons.receipt_long_outlined, size: 26, color: desktopTextSecondary),
            ),
            const SizedBox(height: 14),
            Text('Informasi tagihan akan muncul di sini', style: GoogleFonts.hankenGrotesk(fontSize: 13.5, fontWeight: FontWeight.w700, color: desktopTextPrimary)),
            const SizedBox(height: 4),
            Text(
              'Lengkapi langkah 1 dan 2, lalu klik "Cek Tagihan" untuk melihat detail tagihan.',
              textAlign: TextAlign.center,
              style: GoogleFonts.hankenGrotesk(fontSize: 12, color: desktopTextSecondary),
            ),
          ],
        ),
      );
    }

    final customerId = _customerIdController.text.trim();
    final tagihan = _tagihanList;
    final cityName = _selectedCity != null ? _cityNameOf(_selectedCity!) : '-';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: desktopSurfacePage,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Data Pelanggan', style: GoogleFonts.hankenGrotesk(fontSize: 13, fontWeight: FontWeight.w700, color: desktopTextPrimary)),
          const SizedBox(height: 8),
          _billInfoRow('No. Pelanggan', (data['idpel'] ?? data['customer_no'] ?? customerId).toString()),
          _billInfoRow('Nama', (data['nama'] ?? data['customer_name'] ?? '-').toString()),
          _billInfoRow('Kota', cityName),
          if ((data['alamat'] ?? '').toString().isNotEmpty) _billInfoRow('Alamat', data['alamat'].toString()),
          if (tagihan.isNotEmpty) ...[
            const SizedBox(height: 14),
            Divider(color: desktopBorder.withValues(alpha: 0.6), height: 1),
            const SizedBox(height: 10),
            Text('Rincian Pemakaian', style: GoogleFonts.hankenGrotesk(fontSize: 13, fontWeight: FontWeight.w700, color: desktopTextPrimary)),
            const SizedBox(height: 8),
            for (int i = 0; i < tagihan.length; i++) ...[
              if (i > 0) const SizedBox(height: 6),
              _billInfoRow('Periode', (tagihan[i]['periode'] ?? '-').toString()),
              if (tagihan[i]['pemakaian'] != null) _billInfoRow('Pemakaian', '${tagihan[i]['pemakaian']} m³'),
              _billInfoRow('Tagihan', _money(tagihan[i]['nominal'] ?? tagihan[i]['tagihan'])),
            ],
          ],
          const SizedBox(height: 14),
          Divider(color: desktopBorder.withValues(alpha: 0.6), height: 1),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(color: desktopSurfaceCard, borderRadius: BorderRadius.circular(10)),
            child: Row(
              children: [
                Text('Total Bayar', style: GoogleFonts.hankenGrotesk(fontSize: 13, fontWeight: FontWeight.w700, color: desktopTextSecondary)),
                const Spacer(),
                Text(
                  _money(data['total'] ?? data['selling_price']),
                  style: GoogleFonts.hankenGrotesk(fontSize: 17, fontWeight: FontWeight.w800, color: desktopAccentBlue),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Layout desktop dua-kolom khusus PDAM: kiri = pilih wilayah + ID
  // Pelanggan + tombol "Cek Tagihan" + informasi tagihan inline, kanan =
  // ringkasan transaksi sticky. Tombol "Bayar Sekarang" memanggil
  // _payDesktop (dialog PIN kasir lalu ApiService.purchaseLoketbayar).
  Widget _buildDesktopLayout() {
    final data = _inquiryData;
    final customerId = _customerIdController.text.trim();
    final cityName = _selectedCity != null ? _cityNameOf(_selectedCity!) : null;
    final total = data != null ? _toDouble(data['total'] ?? data['selling_price']) : 0.0;
    final tagihanAmount = data != null ? _toDouble(data['nominal'] ?? data['tagihan']) : 0.0;
    final admin = data != null ? _toDouble(data['admin']) : 0.0;
    final periode = _tagihanList.isNotEmpty ? (_tagihanList.first['periode'] ?? '-').toString() : '-';
    final canConfirm = data != null && !_isPaying;

    return Scaffold(
      backgroundColor: desktopSurfacePage,
      body: PpobDesktopTwoColumnLayout(
        left: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _desktopHeader(),
            const SizedBox(height: 28),
            const PpobStepHeader(step: 1, title: 'Masukkan Wilayah PDAM'),
            const SizedBox(height: 12),
            _desktopDropdownField(),
            const SizedBox(height: 12),
            const PpobDesktopBanner(
              icon: Icons.info_outline_rounded,
              title: 'Pastikan wilayah PDAM yang Anda pilih sesuai dengan tempat pelanggan.',
              tone: PpobBannerTone.info,
            ),
            const SizedBox(height: 28),
            const PpobStepHeader(step: 2, title: 'Masukkan ID Pelanggan'),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: desktopBorderedField(
                    icon: Icons.person_outline_rounded,
                    controller: _customerIdController,
                    focusNode: _customerIdFocus,
                    keyboardType: TextInputType.number,
                    hint: 'Contoh: 12345678901',
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (_) => _clearError(),
                    onSubmitted: (_) => _isInquiring ? null : _doInquiry(),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isInquiring ? null : _doInquiry,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: desktopPrimaryBtn,
                      disabledBackgroundColor: desktopPrimaryBtn.withValues(alpha: 0.5),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _isInquiring
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2.4, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                          )
                        : Text('Cek Tagihan', style: GoogleFonts.hankenGrotesk(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                ),
              ],
            ),
            if (_inquiryError != null && !_isInquiring) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: _kErrorBg,
                  border: Border.all(color: _kErrorBorder),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(_inquiryError!, style: GoogleFonts.hankenGrotesk(fontSize: 12.5, color: _kErrorText)),
              ),
            ] else ...[
              const SizedBox(height: 12),
              const PpobDesktopBanner(
                icon: Icons.info_outline_rounded,
                title: 'Masukkan ID Pelanggan dengan benar untuk mendapatkan informasi tagihan.',
                tone: PpobBannerTone.info,
              ),
            ],
            const SizedBox(height: 28),
            const PpobStepHeader(step: 3, title: 'Informasi Tagihan'),
            const SizedBox(height: 12),
            _buildDesktopBillInfo(),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: desktopBorder.withValues(alpha: 0.5)))),
              child: Row(
                children: [
                  _desktopTrustBadge(Icons.verified_rounded, 'Tagihan Resmi', 'Langsung dari PDAM'),
                  _desktopTrustBadge(Icons.bolt_rounded, 'Proses Cepat', '1-3 detik'),
                  _desktopTrustBadge(Icons.shield_outlined, 'Aman & Terpercaya', 'Transaksi terenkripsi'),
                  _desktopTrustBadge(Icons.access_time_rounded, '24/7', 'Layanan tersedia'),
                ],
              ),
            ),
          ],
        ),
        right: PpobDesktopSummaryPanel(
          rows: [
            const PpobDetailRow(icon: Icons.water_drop_outlined, label: 'Penyedia', value: 'PDAM'),
            PpobDetailRow(icon: Icons.location_on_outlined, label: 'Wilayah PDAM', value: cityName ?? '-'),
            PpobDetailRow(icon: Icons.badge_outlined, label: 'ID Pelanggan', value: data != null ? (data['idpel'] ?? data['customer_no'] ?? customerId).toString() : '-'),
            PpobDetailRow(icon: Icons.person_outline, label: 'Nama Pelanggan', value: data != null ? (data['nama'] ?? data['customer_name'] ?? '-').toString() : '-'),
            const PpobDetailRow(icon: Icons.inventory_2_outlined, label: 'Produk', value: 'Pembayaran PDAM'),
            PpobDetailRow(icon: Icons.calendar_month_outlined, label: 'Bulan Tagihan', value: data != null ? periode : '-'),
            PpobDetailRow(icon: Icons.description_outlined, label: 'Jumlah Tagihan', value: data != null ? _money(tagihanAmount) : '-'),
            PpobDetailRow(icon: Icons.receipt_long_outlined, label: 'Admin', value: data != null ? _money(admin) : '-'),
          ],
          totalLabel: data != null ? _money(total) : 'Rp 0',
          confirmLabel: 'Bayar Sekarang',
          loading: _isPaying,
          onConfirm: canConfirm ? _payDesktop : null,
        ),
      ),
    );
  }

  // ─── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    notifire = Provider.of<ColorNotifire>(context, listen: true);

    if (isDesktop(context)) {
      return _buildDesktopLayout();
    }

    return Scaffold(
      resizeToAvoidBottomInset: false,
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
          'PDAM',
          style: TextStyle(
            color: _kTextPrimary,
            fontFamily: 'Gilroy Bold',
            fontSize: 18,
          ),
        ))
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF16215C).withValues(alpha: 0.06),
                            blurRadius: 20,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'PDAM',
                              style: TextStyle(
                                color: _kTextPrimary,
                                fontFamily: 'Gilroy Bold',
                                fontSize: 22,
                              ),
                            ),
                          ),
                          const Divider(height: 0, color: Color(0xFFECEEF2)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Kota PDAM',
                                  style: TextStyle(
                                    color: _kTextPrimary,
                                    fontFamily: 'Gilroy Bold',
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                InkWell(
                                  onTap: _showCityPicker,
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    height: 48,
                                    padding: const EdgeInsets.symmetric(horizontal: 14),
                                    decoration: BoxDecoration(
                                      color: _kInputFill,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            _selectedCity != null
                                                ? _cityNameOf(_selectedCity!)
                                                : (_isLoadingCities
                                                    ? 'Memuat daftar kota...'
                                                    : 'Pilih kota PDAM'),
                                            style: TextStyle(
                                              color: _selectedCity != null
                                                  ? _kTextPrimary
                                                  : _kTextSecondary,
                                              fontFamily: _selectedCity != null
                                                  ? 'Gilroy Bold'
                                                  : 'Gilroy Medium',
                                              fontSize: 14,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        if (_isLoadingCities)
                                          const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.4,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                      _kHeaderBlue),
                                            ),
                                          )
                                        else
                                          const Icon(Icons.keyboard_arrow_down_rounded,
                                              color: _kTextSecondary),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                const Text(
                                  'Nomor Pelanggan',
                                  style: TextStyle(
                                    color: _kTextPrimary,
                                    fontFamily: 'Gilroy Bold',
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: _kInputFill,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: _customerIdController,
                                          focusNode: _customerIdFocus,
                                          keyboardType: TextInputType.number,
                                          inputFormatters: [
                                            FilteringTextInputFormatter.digitsOnly,
                                          ],
                                          style: const TextStyle(
                                            color: _kTextPrimary,
                                            fontFamily: 'Gilroy Medium',
                                            fontSize: 14,
                                          ),
                                          onChanged: (_) => _clearError(),
                                          decoration: const InputDecoration(
                                            hintText: 'Masukkan Nomor Pelanggan',
                                            hintStyle: TextStyle(
                                              color: _kTextSecondary,
                                              fontFamily: 'Gilroy Medium',
                                              fontSize: 14,
                                            ),
                                            border: InputBorder.none,
                                            contentPadding: EdgeInsets.symmetric(
                                                horizontal: 14, vertical: 12),
                                          ),
                                        ),
                                      ),
                                      InkWell(
                                        onTap: _openSavedCustomers,
                                        borderRadius: BorderRadius.circular(8),
                                        child: const Padding(
                                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          child: Icon(
                                            Icons.contact_page_outlined,
                                            color: _kHeaderBlue,
                                            size: 24,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (_inquiryError != null && !_isInquiring) ...[
                                  const SizedBox(height: 16),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: _kErrorBg,
                                      border: Border.all(color: _kErrorBorder),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      _inquiryError!,
                                      style: const TextStyle(
                                        color: _kErrorText,
                                        fontFamily: 'Gilroy Medium',
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
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
                                onPressed: _isInquiring ? null : _doInquiry,
                                style: ElevatedButton.styleFrom(
                                  elevation: 0,
                                  backgroundColor: _kHeaderBlue,
                                  disabledBackgroundColor: const Color(0xFF8AA8D6),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: _isInquiring
                                    ? const Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.4,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                      Colors.white),
                                            ),
                                          ),
                                          SizedBox(width: 10),
                                          Text(
                                            'Memeriksa tagihan…',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontFamily: 'Gilroy Bold',
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      )
                                    : const Text(
                                        'Cek Tagihan',
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
                  ],
                ),
              ),
            ),
          ),
        ),
      )
    );
  }
}
