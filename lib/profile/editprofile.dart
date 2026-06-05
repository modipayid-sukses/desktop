import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:modipay/bottombar/bottombar.dart';
import 'package:modipay/providers/auth_provider.dart';
import 'package:modipay/services/api_service.dart';
import 'package:modipay/services/wilayah_service.dart';
import 'package:modipay/utils/colornotifire.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

class EditProfile extends StatefulWidget {
  const EditProfile({Key? key}) : super(key: key);

  @override
  State<EditProfile> createState() => _EditProfileState();
}

class _EditProfileState extends State<EditProfile> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _streetController = TextEditingController();

  final _picker = ImagePicker();

  bool _isSaving = false;
  bool _isUploadingAvatar = false;
  bool _isLoadingRegions = false;
  bool _isLoadingRegencies = false;
  bool _isLoadingDistricts = false;
  bool _isLoadingVillages = false;
  File? _selectedAvatar;

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

  @override
  void initState() {
    super.initState();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    _nameController.text = auth.userName;
    _emailController.text = auth.userEmail;
    _phoneController.text = auth.userPhone;
    _streetController.text = '';
    _loadRegions();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _streetController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    try {
      final email = _emailController.text.trim();
      final result = await ApiService.updateProfile({
        'name': _nameController.text.trim(),
        'email': email.isEmpty ? null : email,
        'address': _composeAddress(),
      });

      if (result.containsKey('user')) {
        final auth = Provider.of<AuthProvider>(context, listen: false);
        await auth.fetchProfile();
        Fluttertoast.showToast(msg: 'Profil berhasil diperbarui');
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const Bottombar()),
          );
        }
      } else {
        Fluttertoast.showToast(msg: result['message'] ?? 'Gagal memperbarui profil');
      }
    } catch (_) {
      Fluttertoast.showToast(msg: 'Kesalahan jaringan');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _loadRegions() async {
    setState(() => _isLoadingRegions = true);
    try {
      final provinces = await WilayahService.getProvinces();
      if (!mounted) return;

      setState(() {
        _provinces = provinces;
      });

      if (_provinces.isNotEmpty) {
        _provinceCode = _provinces.first['code'] ?? '';
        _provinceName = _provinces.first['name'] ?? '';
        await _loadRegencies();
      }
    } catch (_) {
      Fluttertoast.showToast(msg: 'Gagal memuat wilayah');
    } finally {
      if (mounted) setState(() => _isLoadingRegions = false);
    }
  }

  Future<void> _loadRegencies() async {
    if (_provinceCode.isEmpty) return;
    setState(() => _isLoadingRegencies = true);
    try {
      final regencies = await WilayahService.getRegencies(_provinceCode);
      if (!mounted) return;
      setState(() {
        _regencies = regencies;
        _regencyCode = '';
        _regencyName = '';
        _districtCode = '';
        _districtName = '';
        _villageCode = '';
        _villageName = '';
        _districts = [];
        _villages = [];
      });
    } catch (_) {
      Fluttertoast.showToast(msg: 'Gagal memuat kota/kabupaten');
    } finally {
      if (mounted) setState(() => _isLoadingRegencies = false);
    }
  }

  Future<void> _loadDistricts() async {
    if (_regencyCode.isEmpty) return;
    setState(() => _isLoadingDistricts = true);
    try {
      final districts = await WilayahService.getDistricts(_regencyCode);
      if (!mounted) return;
      setState(() {
        _districts = districts;
        _districtCode = '';
        _districtName = '';
        _villageCode = '';
        _villageName = '';
        _villages = [];
      });
    } catch (_) {
      Fluttertoast.showToast(msg: 'Gagal memuat kecamatan');
    } finally {
      if (mounted) setState(() => _isLoadingDistricts = false);
    }
  }

  Future<void> _loadVillages() async {
    if (_districtCode.isEmpty) return;
    setState(() => _isLoadingVillages = true);
    try {
      final villages = await WilayahService.getVillages(_districtCode);
      if (!mounted) return;
      setState(() {
        _villages = villages;
        _villageCode = '';
        _villageName = '';
      });
    } catch (_) {
      Fluttertoast.showToast(msg: 'Gagal memuat desa/kelurahan');
    } finally {
      if (mounted) setState(() => _isLoadingVillages = false);
    }
  }

  String _composeAddress() {
    final parts = <String>[];
    if (_provinceName.isNotEmpty) parts.add(_provinceName);
    if (_regencyName.isNotEmpty) parts.add(_regencyName);
    if (_districtName.isNotEmpty) parts.add(_districtName);
    if (_villageName.isNotEmpty) parts.add(_villageName);
    final street = _streetController.text.trim();
    if (street.isNotEmpty) parts.add(street);
    return parts.join(', ');
  }

  Widget _buildDropdown({
    required String hint,
    required String value,
    required List<Map<String, String>> items,
    required ValueChanged<String?> onChanged,
    bool isLoading = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD3DBE8)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value.isEmpty ? null : value,
          isExpanded: true,
          hint: Text(hint),
          items: items
              .map(
                (item) => DropdownMenuItem<String>(
                  value: item['code'],
                  child: Text(item['name'] ?? '-'),
                ),
              )
              .toList(),
          onChanged: isLoading ? null : onChanged,
          icon: isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.keyboard_arrow_down_rounded),
        ),
      ),
    );
  }

  Future<void> _pickAndUploadAvatar() async {
    if (_isUploadingAvatar) return;

    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      imageQuality: 85,
    );
    if (picked == null) return;

    setState(() {
      _selectedAvatar = File(picked.path);
      _isUploadingAvatar = true;
    });

    try {
      final result = await ApiService.uploadAvatar(_selectedAvatar!);
      if (result['avatar'] != null) {
        final auth = Provider.of<AuthProvider>(context, listen: false);
        await auth.fetchProfile();
        Fluttertoast.showToast(msg: 'Foto profil berhasil diperbarui');
      } else {
        Fluttertoast.showToast(msg: result['message'] ?? 'Gagal upload foto profil');
      }
    } catch (_) {
      Fluttertoast.showToast(msg: 'Gagal upload foto profil');
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  InputDecoration _fieldDecoration({
    required String hint,
    required Color accent,
    required Color hintColor,
    required Color fill,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: hintColor,
        fontSize: 13,
        fontFamily: 'Gilroy Medium',
      ),
      filled: true,
      fillColor: fill,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFD3DBE8)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFD3DBE8)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: accent, width: 1.4),
      ),
    );
  }

  Widget _formLabel(String text, Color color) {
    return Text(
      text,
      style: TextStyle(
        color: color,
        fontSize: 12,
        fontFamily: 'Gilroy Medium',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notifire = Provider.of<ColorNotifire>(context, listen: true);
    final auth = Provider.of<AuthProvider>(context);

    final bgColor = notifire.getprimerycolor;
    final cardColor = notifire.getdarkwhitecolor;
    final textColor = notifire.getdarkscolor;
    final subtitleColor = notifire.getdarkgreycolor;
    final accent = notifire.getbluecolor;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: bgColor,
        iconTheme: IconThemeData(color: textColor),
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Edit Profil',
          style: TextStyle(
            color: textColor,
            fontSize: 20,
            fontFamily: 'Gilroy Bold',
          ),
        ),
      ),
      backgroundColor: bgColor,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(18),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x26000000),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.person_outline_rounded, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Perbarui identitas profil kamu agar tetap akurat.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.95),
                        fontFamily: 'Gilroy Medium',
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      GestureDetector(
                        onTap: _pickAndUploadAvatar,
                        child: Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: accent.withOpacity(0.3), width: 2),
                          ),
                          child: ClipOval(
                            child: _selectedAvatar != null
                                ? Image.file(_selectedAvatar!, fit: BoxFit.cover)
                                : auth.userAvatar != null && auth.userAvatar!.isNotEmpty
                                    ? CachedNetworkImage(
                                        imageUrl: ApiService.avatarUrl(auth.userAvatar),
                                        fit: BoxFit.cover,
                                        fadeInDuration: Duration.zero,
                                        errorWidget: (_, __, ___) =>
                                            Image.asset('images/man4.png', fit: BoxFit.cover),
                                      )
                                    : Image.asset('images/man4.png', fit: BoxFit.cover),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: _pickAndUploadAvatar,
                        child: Container(
                          height: 30,
                          width: 30,
                          decoration: BoxDecoration(
                            color: accent,
                            shape: BoxShape.circle,
                            border: Border.all(color: cardColor, width: 2),
                          ),
                          child: _isUploadingAvatar
                              ? const Padding(
                                  padding: EdgeInsets.all(7),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 16),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    auth.userName.isEmpty ? 'Pengguna' : auth.userName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textColor,
                      fontFamily: 'Gilroy Bold',
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Ketuk foto untuk ubah avatar',
                    style: TextStyle(
                      color: subtitleColor,
                      fontFamily: 'Gilroy Medium',
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _formLabel('Nama Lengkap', subtitleColor),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _nameController,
                    style: TextStyle(color: textColor, fontFamily: 'Gilroy Medium', fontSize: 14),
                    decoration: _fieldDecoration(
                      hint: 'Masukkan nama lengkap',
                      accent: accent,
                      hintColor: subtitleColor,
                      fill: cardColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _formLabel('Email', subtitleColor),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: TextStyle(color: textColor, fontFamily: 'Gilroy Medium', fontSize: 14),
                    decoration: _fieldDecoration(
                      hint: 'Masukkan email',
                      accent: accent,
                      hintColor: subtitleColor,
                      fill: cardColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _formLabel('Nomor Telepon', subtitleColor),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _phoneController,
                    readOnly: true,
                    keyboardType: TextInputType.phone,
                    style: TextStyle(color: textColor.withOpacity(0.75), fontFamily: 'Gilroy Medium', fontSize: 14),
                    decoration: _fieldDecoration(
                      hint: 'Nomor telepon tidak dapat diubah',
                      accent: accent,
                      hintColor: subtitleColor,
                      fill: const Color(0xFFF5F7FB),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _formLabel('Alamat', subtitleColor),
                  const SizedBox(height: 6),
                  _buildDropdown(
                    hint: _isLoadingRegions ? 'Memuat provinsi...' : 'Pilih Provinsi',
                    value: _provinceCode,
                    items: _provinces,
                    isLoading: _isLoadingRegions,
                    onChanged: (val) async {
                      if (val == null) return;
                      final selected = _provinces.firstWhere((item) => item['code'] == val);
                      setState(() {
                        _provinceCode = selected['code'] ?? '';
                        _provinceName = selected['name'] ?? '';
                        _regencyCode = '';
                        _regencyName = '';
                        _districtCode = '';
                        _districtName = '';
                        _villageCode = '';
                        _villageName = '';
                        _regencies = [];
                        _districts = [];
                        _villages = [];
                      });
                      await _loadRegencies();
                    },
                  ),
                  const SizedBox(height: 8),
                  _buildDropdown(
                    hint: _provinceCode.isEmpty ? 'Pilih provinsi dulu' : 'Pilih Kabupaten/Kota',
                    value: _regencyCode,
                    items: _regencies,
                    isLoading: _isLoadingRegencies,
                    onChanged: (val) async {
                      if (val == null) return;
                      final selected = _regencies.firstWhere((item) => item['code'] == val);
                      setState(() {
                        _regencyCode = selected['code'] ?? '';
                        _regencyName = selected['name'] ?? '';
                        _districtCode = '';
                        _districtName = '';
                        _villageCode = '';
                        _villageName = '';
                        _districts = [];
                        _villages = [];
                      });
                      await _loadDistricts();
                    },
                  ),
                  const SizedBox(height: 8),
                  _buildDropdown(
                    hint: _regencyCode.isEmpty ? 'Pilih kabupaten/kota dulu' : 'Pilih Kecamatan',
                    value: _districtCode,
                    items: _districts,
                    isLoading: _isLoadingDistricts,
                    onChanged: (val) async {
                      if (val == null) return;
                      final selected = _districts.firstWhere((item) => item['code'] == val);
                      setState(() {
                        _districtCode = selected['code'] ?? '';
                        _districtName = selected['name'] ?? '';
                        _villageCode = '';
                        _villageName = '';
                        _villages = [];
                      });
                      await _loadVillages();
                    },
                  ),
                  const SizedBox(height: 8),
                  _buildDropdown(
                    hint: _districtCode.isEmpty ? 'Pilih kecamatan dulu' : 'Pilih Desa/Kelurahan',
                    value: _villageCode,
                    items: _villages,
                    isLoading: _isLoadingVillages,
                    onChanged: (val) {
                      if (val == null) return;
                      final selected = _villages.firstWhere((item) => item['code'] == val);
                      setState(() {
                        _villageCode = selected['code'] ?? '';
                        _villageName = selected['name'] ?? '';
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _streetController,
                    maxLines: 2,
                    style: TextStyle(color: textColor, fontFamily: 'Gilroy Medium', fontSize: 14),
                    decoration: _fieldDecoration(
                      hint: 'Jalan',
                      accent: accent,
                      hintColor: subtitleColor,
                      fill: cardColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: accent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Simpan Perubahan',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontFamily: 'Gilroy Bold',
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
