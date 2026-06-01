import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../services/api_service.dart';
import '../../services/wilayah_service.dart';
import '../../utils/colornotifire.dart';
import '../../utils/media.dart';

class MerchantKycScreen extends StatefulWidget {
  const MerchantKycScreen({Key? key}) : super(key: key);

  @override
  State<MerchantKycScreen> createState() => _MerchantKycScreenState();
}

class _MerchantKycScreenState extends State<MerchantKycScreen> {
  late ColorNotifire notifire;
  final _formKey = GlobalKey<FormState>();
  final _storeNameController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _streetController = TextEditingController();

  File? _ktpPhoto;
  File? _selfiePhoto;
  String? _selectedBusinessType;
  String? _selectedBank;
  bool _isSubmitting = false;

  // Address state
  List<Map<String, String>> _provinces = [];
  List<Map<String, String>> _regencies = [];
  List<Map<String, String>> _districts = [];
  List<Map<String, String>> _villages = [];
  String _provinceCode = '';
  String _provinceName = '';
  String _regencyCode = '';
  String _regencyName = '';
  String _districtCode = '';
  String _districtName = '';
  String _villageCode = '';
  String _villageName = '';
  bool _isLoadingProvinces = true;
  bool _isLoadingRegencies = false;
  bool _isLoadingDistricts = false;
  bool _isLoadingVillages = false;

  final List<String> _banks = [
    'Bank BCA',
    'Bank BNI',
    'Bank BRI',
    'Bank Mandiri',
    'Bank Syariah Indonesia',
    'Bank CIMB Niaga',
    'Bank Danamon',
    'Bank Permata',
    'Bank BTN',
    'Bank OCBC NISP',
    'Bank Mega',
    'Bank Jago',
    'SeaBank',
    'Bank Neo Commerce',
  ];

  final List<String> _businessTypes = [
    'Warung/Toko Kelontong',
    'Konter Pulsa',
    'Toko Online',
    'Jasa/Service',
    'Makanan & Minuman',
    'Fashion',
    'Elektronik',
    'Lainnya',
  ];

  @override
  void initState() {
    super.initState();
    _loadProvinces();
  }

  @override
  void dispose() {
    _storeNameController.dispose();
    _ownerNameController.dispose();
    _phoneController.dispose();
    _accountNumberController.dispose();
    _streetController.dispose();
    super.dispose();
  }

  Future<void> _loadProvinces() async {
    try {
      final provinces = await WilayahService.getProvinces();
      if (mounted) setState(() { _provinces = provinces; _isLoadingProvinces = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoadingProvinces = false);
    }
  }

  Future<void> _loadRegencies() async {
    if (_provinceCode.isEmpty) return;
    setState(() { _isLoadingRegencies = true; _regencies = []; _districts = []; _villages = []; });
    try {
      final regencies = await WilayahService.getRegencies(_provinceCode);
      if (mounted) setState(() { _regencies = regencies; _isLoadingRegencies = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoadingRegencies = false);
    }
  }

  Future<void> _loadDistricts() async {
    if (_regencyCode.isEmpty) return;
    setState(() { _isLoadingDistricts = true; _districts = []; _villages = []; });
    try {
      final districts = await WilayahService.getDistricts(_regencyCode);
      if (mounted) setState(() { _districts = districts; _isLoadingDistricts = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoadingDistricts = false);
    }
  }

  Future<void> _loadVillages() async {
    if (_districtCode.isEmpty) return;
    setState(() { _isLoadingVillages = true; _villages = []; });
    try {
      final villages = await WilayahService.getVillages(_districtCode);
      if (mounted) setState(() { _villages = villages; _isLoadingVillages = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoadingVillages = false);
    }
  }

  Future<void> _pickImage(bool isKtp) async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('Kamera'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Galeri'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;
    final picked = await picker.pickImage(source: source, imageQuality: 80);
    if (picked == null) return;

    setState(() {
      if (isKtp) {
        _ktpPhoto = File(picked.path);
      } else {
        _selfiePhoto = File(picked.path);
      }
    });
  }

  String get _fullAddress {
    final parts = <String>[];
    if (_streetController.text.trim().isNotEmpty) parts.add(_streetController.text.trim());
    if (_villageName.isNotEmpty) parts.add(_villageName);
    if (_districtName.isNotEmpty) parts.add(_districtName);
    if (_regencyName.isNotEmpty) parts.add(_regencyName);
    if (_provinceName.isNotEmpty) parts.add(_provinceName);
    return parts.join(', ');
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedBank == null) { _showSnackBar('Pilih bank'); return; }
    if (_provinceCode.isEmpty) { _showSnackBar('Pilih provinsi'); return; }
    if (_regencyCode.isEmpty) { _showSnackBar('Pilih kota/kabupaten'); return; }
    if (_districtCode.isEmpty) { _showSnackBar('Pilih kecamatan'); return; }
    if (_villageCode.isEmpty) { _showSnackBar('Pilih kelurahan/desa'); return; }
    if (_streetController.text.trim().isEmpty) { _showSnackBar('Masukkan nama jalan'); return; }
    if (_selectedBusinessType == null) { _showSnackBar('Pilih jenis usaha'); return; }
    if (_ktpPhoto == null) { _showSnackBar('Upload foto KTP'); return; }
    if (_selfiePhoto == null) { _showSnackBar('Upload foto selfie dengan KTP'); return; }

    setState(() => _isSubmitting = true);

    try {
      final response = await ApiService.submitMerchantKyc(
        storeName: _storeNameController.text.trim(),
        ownerName: _ownerNameController.text.trim(),
        phone: _phoneController.text.trim(),
        accountNumber: _accountNumberController.text.trim(),
        bankName: _selectedBank!,
        address: _fullAddress,
        ktpPhoto: _ktpPhoto!,
        selfiePhoto: _selfiePhoto!,
        businessType: _selectedBusinessType!,
      );

      if (!mounted) return;

      if (response['status'] == 'success') {
        _showSuccessDialog();
      } else {
        _showSnackBar(response['message'] ?? 'Gagal mengirim KYC');
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar(ApiService.userFriendlyMessage(e, fallback: 'Gagal mengirim KYC'));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 60),
            const SizedBox(height: 16),
            const Text('Pengajuan Berhasil', style: TextStyle(fontFamily: 'Gilroy Bold', fontSize: 18)),
            const SizedBox(height: 8),
            Text(
              'Data KYC Anda sedang dalam proses review. Kami akan memberitahu hasilnya.',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Gilroy Medium', fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () { Navigator.pop(ctx); Navigator.pop(context); },
              child: const Text('OK', style: TextStyle(fontFamily: 'Gilroy Bold', fontSize: 15)),
            ),
          ),
        ],
      ),
    );
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
    final blueColor = notifire.getbluecolor as Color;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Padding(
            padding: EdgeInsets.all(12),
            child: Icon(Icons.arrow_back, color: Color(0xFF1A1A1A)),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Verifikasi Merchant',
          style: TextStyle(color: Color(0xFF1A1A1A), fontFamily: 'Gilroy Bold', fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Info banner ──
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: blueColor.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: blueColor.withOpacity(0.15)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline_rounded, color: blueColor, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Lengkapi data berikut untuk mengaktifkan fitur limit transaksi.',
                              style: TextStyle(color: Colors.grey[700], fontFamily: 'Gilroy Medium', fontSize: 13, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Form fields ──
                    _buildLabel('Nama Toko/Kedai'),
                    const SizedBox(height: 8),
                    _buildTextField(controller: _storeNameController, hint: 'Masukkan nama toko', validator: (v) => v!.isEmpty ? 'Wajib diisi' : null),
                    const SizedBox(height: 18),

                    _buildLabel('Pemilik'),
                    const SizedBox(height: 8),
                    _buildTextField(controller: _ownerNameController, hint: 'Nama lengkap pemilik', validator: (v) => v!.isEmpty ? 'Wajib diisi' : null),
                    const SizedBox(height: 18),

                    _buildLabel('Nomor HP'),
                    const SizedBox(height: 8),
                    _buildTextField(controller: _phoneController, hint: '08xxxxxxxxxx', keyboardType: TextInputType.phone, validator: (v) => v!.isEmpty ? 'Wajib diisi' : null),
                    const SizedBox(height: 18),

                    _buildLabel('Nomor Rekening'),
                    const SizedBox(height: 8),
                    _buildTextField(controller: _accountNumberController, hint: 'Nomor rekening bank', keyboardType: TextInputType.number, validator: (v) => v!.isEmpty ? 'Wajib diisi' : null),
                    const SizedBox(height: 18),

                    _buildLabel('Bank'),
                    const SizedBox(height: 8),
                    _buildSimpleDropdown(
                      value: _selectedBank,
                      hint: 'Pilih bank',
                      items: _banks,
                      onChanged: (val) => setState(() => _selectedBank = val),
                    ),
                    const SizedBox(height: 24),

                    // ── Alamat section ──
                    const Text('Alamat', style: TextStyle(color: Color(0xFF1A1A1A), fontFamily: 'Gilroy Bold', fontSize: 16)),
                    const SizedBox(height: 12),

                    _buildLabel('Provinsi'),
                    const SizedBox(height: 8),
                    _buildWilayahDropdown(
                      hint: 'Pilih Provinsi',
                      value: _provinceCode,
                      items: _provinces,
                      isLoading: _isLoadingProvinces,
                      onChanged: (val) async {
                        if (val == null) return;
                        final selected = _provinces.firstWhere((p) => p['code'] == val);
                        setState(() {
                          _provinceCode = selected['code'] ?? '';
                          _provinceName = selected['name'] ?? '';
                          _regencyCode = ''; _regencyName = '';
                          _districtCode = ''; _districtName = '';
                          _villageCode = ''; _villageName = '';
                          _regencies = []; _districts = []; _villages = [];
                        });
                        await _loadRegencies();
                      },
                    ),
                    const SizedBox(height: 12),

                    _buildLabel('Kota/Kabupaten'),
                    const SizedBox(height: 8),
                    _buildWilayahDropdown(
                      hint: _provinceCode.isEmpty ? 'Pilih provinsi dulu' : 'Pilih Kota/Kabupaten',
                      value: _regencyCode,
                      items: _regencies,
                      isLoading: _isLoadingRegencies,
                      onChanged: (val) async {
                        if (val == null) return;
                        final selected = _regencies.firstWhere((p) => p['code'] == val);
                        setState(() {
                          _regencyCode = selected['code'] ?? '';
                          _regencyName = selected['name'] ?? '';
                          _districtCode = ''; _districtName = '';
                          _villageCode = ''; _villageName = '';
                          _districts = []; _villages = [];
                        });
                        await _loadDistricts();
                      },
                    ),
                    const SizedBox(height: 12),

                    _buildLabel('Kecamatan'),
                    const SizedBox(height: 8),
                    _buildWilayahDropdown(
                      hint: _regencyCode.isEmpty ? 'Pilih kota dulu' : 'Pilih Kecamatan',
                      value: _districtCode,
                      items: _districts,
                      isLoading: _isLoadingDistricts,
                      onChanged: (val) async {
                        if (val == null) return;
                        final selected = _districts.firstWhere((p) => p['code'] == val);
                        setState(() {
                          _districtCode = selected['code'] ?? '';
                          _districtName = selected['name'] ?? '';
                          _villageCode = ''; _villageName = '';
                          _villages = [];
                        });
                        await _loadVillages();
                      },
                    ),
                    const SizedBox(height: 12),

                    _buildLabel('Desa/Kelurahan'),
                    const SizedBox(height: 8),
                    _buildWilayahDropdown(
                      hint: _districtCode.isEmpty ? 'Pilih kecamatan dulu' : 'Pilih Desa/Kelurahan',
                      value: _villageCode,
                      items: _villages,
                      isLoading: _isLoadingVillages,
                      onChanged: (val) {
                        if (val == null) return;
                        final selected = _villages.firstWhere((p) => p['code'] == val);
                        setState(() {
                          _villageCode = selected['code'] ?? '';
                          _villageName = selected['name'] ?? '';
                        });
                      },
                    ),
                    const SizedBox(height: 12),

                    _buildLabel('Jalan'),
                    const SizedBox(height: 8),
                    _buildTextField(controller: _streetController, hint: 'Nama jalan, RT/RW, No.', validator: (v) => v!.isEmpty ? 'Wajib diisi' : null),
                    const SizedBox(height: 24),

                    // ── Jenis Usaha ──
                    _buildLabel('Jenis Usaha'),
                    const SizedBox(height: 8),
                    _buildSimpleDropdown(
                      value: _selectedBusinessType,
                      hint: 'Pilih jenis usaha',
                      items: _businessTypes,
                      onChanged: (val) => setState(() => _selectedBusinessType = val),
                    ),
                    const SizedBox(height: 24),

                    // ── Photo uploads ──
                    _buildLabel('Foto KTP'),
                    const SizedBox(height: 8),
                    _buildPhotoUpload(file: _ktpPhoto, onTap: () => _pickImage(true), placeholder: 'Upload foto KTP', blueColor: blueColor),
                    const SizedBox(height: 18),

                    _buildLabel('Selfie dengan KTP'),
                    const SizedBox(height: 8),
                    _buildPhotoUpload(file: _selfiePhoto, onTap: () => _pickImage(false), placeholder: 'Upload selfie memegang KTP', blueColor: blueColor),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),

          // ── Submit button ──
          Container(
            padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).padding.bottom + 20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, -2))],
            ),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: blueColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: _isSubmitting
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Kirim Pengajuan', style: TextStyle(color: Colors.white, fontFamily: 'Gilroy Bold', fontSize: 16)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Widgets ──

  Widget _buildLabel(String text) {
    return Text(text, style: const TextStyle(color: Color(0xFF1A1A1A), fontFamily: 'Gilroy Bold', fontSize: 14));
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      style: const TextStyle(color: Color(0xFF1A1A1A), fontFamily: 'Gilroy Medium', fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[400], fontFamily: 'Gilroy Medium', fontSize: 14),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.black.withOpacity(0.1))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.black.withOpacity(0.1))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: notifire.getbluecolor, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.red, width: 1)),
      ),
    );
  }

  Widget _buildSimpleDropdown({
    required String? value,
    required String hint,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withOpacity(0.1)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          hint: Text(hint, style: TextStyle(color: Colors.grey[400], fontFamily: 'Gilroy Medium', fontSize: 14)),
          style: const TextStyle(color: Color(0xFF1A1A1A), fontFamily: 'Gilroy Medium', fontSize: 15),
          items: items.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildWilayahDropdown({
    required String hint,
    required String value,
    required List<Map<String, String>> items,
    required ValueChanged<String?> onChanged,
    bool isLoading = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withOpacity(0.1)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value.isEmpty ? null : value,
          isExpanded: true,
          hint: Text(hint, style: TextStyle(color: Colors.grey[400], fontFamily: 'Gilroy Medium', fontSize: 14)),
          style: const TextStyle(color: Color(0xFF1A1A1A), fontFamily: 'Gilroy Medium', fontSize: 15),
          items: items.map((item) => DropdownMenuItem<String>(value: item['code'], child: Text(item['name'] ?? '-'))).toList(),
          onChanged: isLoading ? null : onChanged,
          icon: isLoading
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.keyboard_arrow_down_rounded),
        ),
      ),
    );
  }

  Widget _buildPhotoUpload({
    required File? file,
    required VoidCallback onTap,
    required String placeholder,
    required Color blueColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: file != null ? 180 : 100,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: file != null ? blueColor.withOpacity(0.3) : Colors.black.withOpacity(0.1)),
        ),
        child: file != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.file(file, fit: BoxFit.cover),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)],
                        ),
                        child: Icon(Icons.edit_rounded, color: blueColor, size: 16),
                      ),
                    ),
                  ],
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cloud_upload_outlined, color: Colors.grey[400], size: 32),
                  const SizedBox(height: 8),
                  Text(placeholder, style: TextStyle(color: Colors.grey[500], fontFamily: 'Gilroy Medium', fontSize: 13)),
                ],
              ),
      ),
    );
  }
}
