import 'dart:io';
import 'package:modipay/widgets/desktop_title_wrapper.dart';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/api_service.dart';
import '../../utils/colornotifire.dart';
import '../../design/design.dart';

class QrisMerchantRegisterScreen extends StatefulWidget {
  const QrisMerchantRegisterScreen({Key? key}) : super(key: key);

  @override
  State<QrisMerchantRegisterScreen> createState() => _QrisMerchantRegisterScreenState();
}

class _QrisMerchantRegisterScreenState extends State<QrisMerchantRegisterScreen> {
  late ColorNotifire notifire;
  final _businessNameController = TextEditingController();
  String _businessType = 'Makanan & Minuman';
  File? _photoProduct;
  File? _photoPlace;
  bool _isSubmitting = false;
  String? _currentStatus;

  final _businessTypes = [
    'Makanan & Minuman',
    'Fashion & Pakaian',
    'Elektronik',
    'Jasa & Layanan',
    'Toko Kelontong',
    'Kesehatan & Kecantikan',
    'Pendidikan',
    'Lainnya',
  ];

  bool get _hasBusinessName => _businessNameController.text.trim().isNotEmpty;
  bool get _hasProductPhoto => _photoProduct != null;
  bool get _hasPlacePhoto => _photoPlace != null;
  int get _completionCount =>
      (_hasBusinessName ? 1 : 0) + (_hasProductPhoto ? 1 : 0) + (_hasPlacePhoto ? 1 : 0);
  bool get _isFormReady => _completionCount == 3;

  @override
  void initState() {
    super.initState();
    _loadDarkMode();
    _loadStatus();
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    super.dispose();
  }

  Future<void> _loadDarkMode() async {
    final prefs = await SharedPreferences.getInstance();
    bool? prev = prefs.getBool("setIsDark");
    if (prev != null) notifire.setIsDark = prev;
  }

  Future<void> _loadStatus() async {
    try {
      final res = await ApiService.getQrisMerchantStatus();
      if (mounted && res['status'] == 'success') {
        final merchant = res['data']?['merchant'];
        if (merchant != null) {
          setState(() => _currentStatus = merchant['status']);
        }
      }
    } catch (_) {}
  }

  Future<void> _pickImage(bool isProduct) async {
    final picker = ImagePicker();
    final source = await AppBottomSheet.show<ImageSource>(
      context: context,
      title: 'Pilih Sumber Foto',
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.camera_alt, color: notifire.getdarkscolor),
            title: Text('Kamera', style: TextStyle(color: notifire.getdarkscolor, fontFamily: 'Gilroy Medium')),
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.photo_library, color: notifire.getdarkscolor),
            title: Text('Galeri', style: TextStyle(color: notifire.getdarkscolor, fontFamily: 'Gilroy Medium')),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
        ],
      ),
    );
    if (source == null) return;
    final picked = await picker.pickImage(source: source, maxWidth: 1200, imageQuality: 85);
    if (picked != null) {
      setState(() {
        if (isProduct) {
          _photoProduct = File(picked.path);
        } else {
          _photoPlace = File(picked.path);
        }
      });
    }
  }

  Future<void> _submit() async {
    final name = _businessNameController.text.trim();
    if (name.isEmpty) {
      Fluttertoast.showToast(msg: 'Masukkan nama usaha');
      return;
    }
    if (_photoProduct == null) {
      Fluttertoast.showToast(msg: 'Upload foto produk');
      return;
    }
    if (_photoPlace == null) {
      Fluttertoast.showToast(msg: 'Upload foto tempat usaha');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final res = await ApiService.registerQrisMerchant(
        businessName: name,
        businessType: _businessType,
        photoProduct: _photoProduct!,
        photoPlace: _photoPlace!,
      );

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      if (res.containsKey('merchant')) {
        setState(() => _currentStatus = 'pending');
        Fluttertoast.showToast(msg: 'Pengajuan berhasil dikirim');
      } else {
        Fluttertoast.showToast(msg: res['message'] ?? 'Gagal mengirim pengajuan');
      }
    } catch (e) {
      if (mounted) setState(() => _isSubmitting = false);
      Fluttertoast.showToast(msg: 'Kesalahan koneksi');
    }
  }

  @override
  Widget build(BuildContext context) {
    notifire = Provider.of<ColorNotifire>(context, listen: true);
    final cardColor = notifire.gettabwhitecolor;
    final cardBorder = notifire.getdarkgreycolor.withOpacity(0.15);

    return Scaffold(
      backgroundColor: notifire.getprimerycolor,
      appBar: AppBar(
        backgroundColor: notifire.getprimerycolor,
        elevation: 0,
        iconTheme: IconThemeData(color: notifire.getdarkscolor),
        centerTitle: true,
        title: DesktopTitleWrapper(child: Text(
          'Aktivasi QRIS Merchant',
          style: TextStyle(
            color: notifire.getdarkscolor,
            fontFamily: 'Gilroy Bold',
            fontSize: 18,
          ),
        ))
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: cardBorder),
                ),
                child: _currentStatus == 'pending'
                    ? _buildPendingState()
                    : _currentStatus == 'rejected'
                        ? _buildRejectedState()
                        : _buildForm(),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _currentStatus == null
          ? SafeArea(
              top: false,
              child: Container(
                color: notifire.getprimerycolor,
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: (_isSubmitting || !_isFormReady) ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: notifire.getbluecolor,
                      disabledBackgroundColor: notifire.getdarkgreycolor.withOpacity(0.25),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                          )
                        : Text(
                            _isFormReady ? 'Ajukan Aktivasi' : 'Lengkapi Data Dulu',
                            style: const TextStyle(color: Colors.white, fontFamily: 'Gilroy Bold', fontSize: 16),
                          ),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildPendingState() {
    return Column(
      children: [
        const SizedBox(height: 40),
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            color: const Color(0xFFFF9800).withOpacity(0.14),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.hourglass_top, color: Color(0xFFFF9800), size: 36),
        ),
        const SizedBox(height: 18),
        Text(
          'Menunggu Verifikasi',
          style: TextStyle(
            color: notifire.getdarkscolor,
            fontFamily: 'Gilroy Bold',
            fontSize: 20,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Pengajuan QRIS Merchant Anda sedang dalam proses verifikasi. Kami akan menghubungi Anda setelah proses selesai.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: notifire.getdarkgreycolor,
            fontFamily: 'Gilroy Medium',
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: notifire.gettabwhitecolor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: notifire.getdarkgreycolor.withOpacity(0.2)),
          ),
          child: Text(
            'Estimasi verifikasi 1x24 jam pada hari kerja.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: notifire.getdarkgreycolor,
              fontFamily: 'Gilroy Medium',
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRejectedState() {
    return Column(
      children: [
        const SizedBox(height: 40),
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.14),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.close, color: Colors.red, size: 36),
        ),
        const SizedBox(height: 18),
        Text(
          'Pengajuan Ditolak',
          style: TextStyle(
            color: notifire.getdarkscolor,
            fontFamily: 'Gilroy Bold',
            fontSize: 20,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Silakan periksa data dan foto Anda, lalu ajukan kembali.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: notifire.getdarkgreycolor,
            fontFamily: 'Gilroy Medium',
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: () => setState(() => _currentStatus = null),
            style: ElevatedButton.styleFrom(
              backgroundColor: notifire.getbluecolor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: const Text('Ajukan Kembali', style: TextStyle(color: Colors.white, fontFamily: 'Gilroy Bold', fontSize: 15)),
          ),
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepHeader('1', 'Data Usaha'),
        const SizedBox(height: 14),
        _buildQuickBusinessTypeChips(),
        const SizedBox(height: 18),
        Text('Nama Usaha', style: _labelStyle()),
        const SizedBox(height: 8),
        TextField(
          controller: _businessNameController,
          onChanged: (_) => setState(() {}),
          style: TextStyle(color: notifire.getdarkscolor, fontFamily: 'Gilroy Medium'),
          decoration: _inputDecoration('Contoh: Warung Makan Barokah'),
        ),
        const SizedBox(height: 18),
        Text('Jenis Usaha', style: _labelStyle()),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: notifire.gettabwhitecolor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: notifire.getdarkgreycolor.withOpacity(0.15)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _businessType,
              isExpanded: true,
              dropdownColor: notifire.getprimerycolor,
              style: TextStyle(color: notifire.getdarkscolor, fontFamily: 'Gilroy Medium', fontSize: 15),
              items: _businessTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
              onChanged: (v) => setState(() => _businessType = v!),
            ),
          ),
        ),
        const SizedBox(height: 24),
        _stepHeader('2', 'Dokumen Foto'),
        const SizedBox(height: 12),
        Text('Foto Produk', style: _labelStyle()),
        const SizedBox(height: 8),
        _photoUploadBox(_photoProduct, true),
        const SizedBox(height: 20),
        Text('Foto Tempat Usaha', style: _labelStyle()),
        const SizedBox(height: 8),
        _photoUploadBox(_photoPlace, false),
        const SizedBox(height: 14),
        Text(
          'Data aman, dipakai hanya untuk verifikasi merchant.',
          style: TextStyle(
            color: notifire.getdarkgreycolor,
            fontFamily: 'Gilroy Medium',
            fontSize: 11.5,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickBusinessTypeChips() {
    final quickTypes = _businessTypes.take(4).toList();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: quickTypes.map((type) {
        final selected = _businessType == type;
        return InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () => setState(() => _businessType = type),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? notifire.getbluecolor.withOpacity(0.12) : notifire.gettabwhitecolor,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: selected ? notifire.getbluecolor : notifire.getdarkgreycolor.withOpacity(0.22),
              ),
            ),
            child: Text(
              type,
              style: TextStyle(
                color: selected ? notifire.getbluecolor : notifire.getdarkgreycolor,
                fontFamily: 'Gilroy Bold',
                fontSize: 11.5,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _stepHeader(String step, String title) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: notifire.getbluecolor,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Center(
            child: Text(
              '0$step',
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'Gilroy Bold',
                fontSize: 12,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '$title • Wajib',
          style: TextStyle(
            color: notifire.getdarkscolor,
            fontFamily: 'Gilroy Bold',
            fontSize: 15,
          ),
        ),
      ],
    );
  }

  Widget _photoUploadBox(File? photo, bool isProduct) {
    return GestureDetector(
      onTap: () => _pickImage(isProduct),
      child: Container(
        width: double.infinity,
        height: 168,
        decoration: BoxDecoration(
          color: notifire.gettabwhitecolor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: photo == null
                ? notifire.getbluecolor.withOpacity(0.5)
                : notifire.getdarkgreycolor.withOpacity(0.15),
            style: photo == null ? BorderStyle.solid : BorderStyle.none,
          ),
        ),
        child: photo != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.file(photo, fit: BoxFit.cover),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.edit, color: Colors.white, size: 14),
                            SizedBox(width: 4),
                            Text(
                              'Ganti',
                              style: TextStyle(color: Colors.white, fontFamily: 'Gilroy Medium', fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo_rounded, color: notifire.getbluecolor, size: 34),
                  const SizedBox(height: 8),
                  Text(
                    isProduct ? 'Tambah foto produk' : 'Tambah foto tempat usaha',
                    style: TextStyle(color: notifire.getdarkscolor, fontFamily: 'Gilroy Bold', fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Pilih dari kamera atau galeri',
                    style: TextStyle(
                      color: notifire.getdarkgreycolor,
                      fontFamily: 'Gilroy Medium',
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  TextStyle _labelStyle() => TextStyle(
        color: notifire.getdarkscolor,
        fontFamily: 'Gilroy Bold',
        fontSize: 14,
      );

  InputDecoration _inputDecoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: notifire.getdarkgreycolor.withOpacity(0.4),
          fontFamily: 'Gilroy Medium',
        ),
        filled: true,
        fillColor: notifire.gettabwhitecolor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: notifire.getdarkgreycolor.withOpacity(0.15)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: notifire.getdarkgreycolor.withOpacity(0.15)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: notifire.getbluecolor),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      );
}
