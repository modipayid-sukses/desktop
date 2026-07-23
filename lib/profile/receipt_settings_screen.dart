import 'package:flutter/material.dart';
import 'package:modipay/widgets/desktop_title_wrapper.dart';

import 'package:modipay/utils/toast.dart';
import 'package:modipay/services/receipt_settings_service.dart';
import 'package:modipay/services/wilayah_service.dart';
import 'package:modipay/utils/colornotifire.dart';
import 'package:modipay/utils/responsive.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReceiptSettingsScreen extends StatefulWidget {
  const ReceiptSettingsScreen({Key? key}) : super(key: key);

  @override
  State<ReceiptSettingsScreen> createState() => _ReceiptSettingsScreenState();
}

class _ReceiptSettingsScreenState extends State<ReceiptSettingsScreen> {
  late ColorNotifire notifire;

  final _storeNameC = TextEditingController();
  final _phoneC = TextEditingController();
  final _streetC = TextEditingController();
  final _thanksC = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isLoadingRegencies = false;
  bool _isLoadingDistricts = false;
  bool _isLoadingVillages = false;
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
    _loadDarkMode();
    _initialize();
  }

  Future<void> _loadDarkMode() async {
    final prefs = await SharedPreferences.getInstance();
    final previous = prefs.getBool('setIsDark');
    notifire.setIsDark = previous ?? false;
  }

  Future<void> _initialize() async {
    try {
      final results = await Future.wait([
        ReceiptSettingsService.load(),
        WilayahService.getProvinces(),
      ]);

      final settings = results[0] as Map<String, String>;
      final provinces = results[1] as List<Map<String, String>>;

      _storeNameC.text = settings['storeName'] ?? '';
      _phoneC.text = settings['phone'] ?? '';
      _streetC.text = settings['street'] ?? '';
      _thanksC.text = settings['thanksMessage'] ?? 'Terimakasih telah berbelanja';

      _provinceCode = settings['provinceCode'] ?? '';
      _provinceName = settings['provinceName'] ?? '';
      _regencyCode = settings['regencyCode'] ?? '';
      _regencyName = settings['city'] ?? '';
      _districtCode = settings['districtCode'] ?? '';
      _districtName = settings['district'] ?? '';
      _villageCode = settings['villageCode'] ?? '';
      _villageName = settings['village'] ?? '';

      if (_provinceCode.isEmpty && provinces.isNotEmpty) {
        _provinceCode = provinces.first['code']!;
        _provinceName = provinces.first['name']!;
      }

      // Snapshot nilai tersimpan SEBELUM _loadRegencies/_loadDistricts
      // me-reset _districtCode/_villageCode/dll di setState mereka.
      final savedRegencyCode = _regencyCode;
      final savedRegencyName = _regencyName;
      final savedDistrictCode = _districtCode;
      final savedDistrictName = _districtName;
      final savedVillageCode = _villageCode;
      final savedVillageName = _villageName;

      if (_provinceCode.isNotEmpty) {
        await _loadRegencies(
            initialCode: savedRegencyCode, initialName: savedRegencyName);
      }

      if (_regencyCode.isNotEmpty) {
        await _loadDistricts(
            initialCode: savedDistrictCode, initialName: savedDistrictName);
      }

      if (_districtCode.isNotEmpty) {
        await _loadVillages(
            initialCode: savedVillageCode, initialName: savedVillageName);
      }

      if (mounted) {
        setState(() {
          _provinces = provinces;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      showToast(msg: 'Gagal memuat data provinsi');
    }
  }

  Future<void> _loadRegencies({String? initialCode, String? initialName}) async {
    if (_provinceCode.isEmpty) return;
    setState(() => _isLoadingRegencies = true);
    try {
      final regencies = await WilayahService.getRegencies(_provinceCode);
      String nextCode = initialCode ?? '';
      String nextName = initialName ?? '';

      if (nextCode.isNotEmpty && !regencies.any((item) => item['code'] == nextCode)) {
        nextCode = '';
        nextName = '';
      }

      setState(() {
        _regencies = regencies;
        _regencyCode = nextCode;
        _regencyName = nextName;
        _districts = [];
        _districtCode = '';
        _districtName = '';
        _villages = [];
        _villageCode = '';
        _villageName = '';
      });
    } catch (_) {
      showToast(msg: 'Gagal memuat kota/kabupaten');
    } finally {
      if (mounted) setState(() => _isLoadingRegencies = false);
    }
  }

  Future<void> _loadDistricts({String? initialCode, String? initialName}) async {
    if (_regencyCode.isEmpty) return;
    setState(() => _isLoadingDistricts = true);
    try {
      final districts = await WilayahService.getDistricts(_regencyCode);
      String nextCode = initialCode ?? '';
      String nextName = initialName ?? '';

      if (nextCode.isNotEmpty && !districts.any((item) => item['code'] == nextCode)) {
        nextCode = '';
        nextName = '';
      }

      setState(() {
        _districts = districts;
        _districtCode = nextCode;
        _districtName = nextName;
        _villages = [];
        _villageCode = '';
        _villageName = '';
      });
    } catch (_) {
      showToast(msg: 'Gagal memuat kecamatan');
    } finally {
      if (mounted) setState(() => _isLoadingDistricts = false);
    }
  }

  Future<void> _loadVillages({String? initialCode, String? initialName}) async {
    if (_districtCode.isEmpty) return;
    setState(() => _isLoadingVillages = true);
    try {
      final villages = await WilayahService.getVillages(_districtCode);
      String nextCode = initialCode ?? '';
      String nextName = initialName ?? '';

      if (nextCode.isNotEmpty && !villages.any((item) => item['code'] == nextCode)) {
        nextCode = '';
        nextName = '';
      }

      setState(() {
        _villages = villages;
        _villageCode = nextCode;
        _villageName = nextName;
      });
    } catch (_) {
      showToast(msg: 'Gagal memuat kelurahan/desa');
    } finally {
      if (mounted) setState(() => _isLoadingVillages = false);
    }
  }

  Future<void> _save() async {
    if (_isSaving) return;
    if (_storeNameC.text.trim().isEmpty) {
      showToast(msg: 'Nama toko/kedai wajib diisi');
      return;
    }

    setState(() => _isSaving = true);
    try {
      await ReceiptSettingsService.save(
        storeName: _storeNameC.text,
        phone: _phoneC.text,
        provinceCode: _provinceCode,
        provinceName: _provinceName,
        regencyCode: _regencyCode,
        city: _regencyName,
        districtCode: _districtCode,
        district: _districtName,
        villageCode: _villageCode,
        village: _villageName,
        street: _streetC.text,
        thanksMessage: _thanksC.text.trim().isEmpty
            ? 'Terimakasih telah berbelanja'
            : _thanksC.text,
      );
      if (!mounted) return;
      showToast(msg: 'Pengaturan struk disimpan');
      Navigator.pop(context);
    } catch (_) {
      showToast(msg: 'Gagal menyimpan pengaturan');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _storeNameC.dispose();
    _phoneC.dispose();
    _streetC.dispose();
    _thanksC.dispose();
    super.dispose();
  }

  Widget _buildDropdown({
    required String hint,
    required String value,
    required List<Map<String, String>> items,
    required ValueChanged<String?> onChanged,
    bool isLoading = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.3)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value.isEmpty ? null : value,
          isExpanded: true,
          hint: Text(hint, style: TextStyle(color: Colors.grey.shade400, fontFamily: 'Gilroy Medium', fontSize: 13)),
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

  InputDecoration _decoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade400, fontFamily: 'Gilroy Medium', fontSize: 13),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF1565C0), width: 1.3),
      ),
    );
  }

  Widget _sectionCard({required String title, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF18202A),
            fontFamily: 'Gilroy Bold',
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _fieldGroup(String label, Widget field) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF4B5565),
            fontFamily: 'Gilroy Medium',
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 6),
        field,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    notifire = Provider.of<ColorNotifire>(context, listen: true);
    const pageBg = Color(0xFFF3F6FB);

    return Scaffold(
      backgroundColor: pageBg,
      appBar: isDesktopPopup(context) ? null : AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1565C0)),
        title: DesktopTitleWrapper(child: const Text(
          'Pengaturan Struk',
          style: TextStyle(
            color: Color(0xFF1565C0),
            fontFamily: 'Gilroy Bold',
            fontSize: 17,
          ),
        ))
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionCard(
                    title: 'Identitas Toko',
                    children: [
                      _fieldGroup(
                        'Nama Toko/Kedai',
                        TextField(
                          controller: _storeNameC,
                          decoration: _decoration(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _fieldGroup(
                        'Nomor HP (opsional)',
                        TextField(
                          controller: _phoneC,
                          keyboardType: TextInputType.phone,
                          decoration: _decoration(hint: '08xx xxxx xxxx'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _sectionCard(
                    title: 'Alamat',
                    children: [
                      _fieldGroup(
                        'Provinsi',
                        _buildDropdown(
                          hint: 'Pilih Provinsi',
                          value: _provinceCode,
                          items: _provinces,
                          onChanged: (val) async {
                            if (val == null) return;
                            final selected = _provinces.firstWhere((p) => p['code'] == val);
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
                      ),
                      const SizedBox(height: 16),
                      _fieldGroup(
                        'Kota/Kabupaten',
                        _buildDropdown(
                          hint: _provinceCode.isEmpty ? 'Pilih provinsi dulu' : 'Pilih Kota/Kabupaten',
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
                      ),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _fieldGroup(
                              'Kecamatan',
                              _buildDropdown(
                                hint: _regencyCode.isEmpty ? 'Pilih kota dulu' : 'Pilih Kecamatan',
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
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _fieldGroup(
                              'Kelurahan/Desa',
                              _buildDropdown(
                                hint: _districtCode.isEmpty ? 'Pilih kecamatan dulu' : 'Pilih Kelurahan',
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
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _fieldGroup(
                        'Jalan',
                        TextField(
                          controller: _streetC,
                          decoration: _decoration(hint: 'Nama jalan, nomor rumah, RT/RW'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _sectionCard(
                    title: 'Footer Struk',
                    children: [
                      _fieldGroup(
                        'Ucapan terimakasih',
                        TextField(
                          controller: _thanksC,
                          maxLines: 3,
                          decoration: _decoration(hint: 'Contoh: Terimakasih sudah berbelanja di toko kami'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: const Color(0xFF1565C0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(26),
                        ),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Simpan Perubahan',
                              style: TextStyle(
                                color: Colors.white,
                                fontFamily: 'Gilroy Bold',
                                fontSize: 15,
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
