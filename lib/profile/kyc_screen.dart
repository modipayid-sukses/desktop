import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../utils/colornotifire.dart';
import '../utils/media.dart';

class KycScreen extends StatefulWidget {
  const KycScreen({Key? key}) : super(key: key);

  @override
  State<KycScreen> createState() => _KycScreenState();
}

class _KycScreenState extends State<KycScreen> {
  late ColorNotifire notifire;
  final _picker = ImagePicker();
  File? _ktpFile;
  File? _selfieFile;
  bool _isSubmitting = false;
  String _kycStatus = 'none';

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    try {
      final response = await ApiService.getKycStatus();
      if (mounted && response['status'] == 'success') {
        setState(() {
          _kycStatus = response['data']?['kyc_status'] ?? 'none';
        });
      }
    } catch (_) {}
  }

  Future<void> _pickImage(bool isKtp) async {
    final picked = await _picker.pickImage(source: ImageSource.camera, maxWidth: 1200, imageQuality: 80);
    if (picked != null) {
      setState(() {
        if (isKtp) {
          _ktpFile = File(picked.path);
        } else {
          _selfieFile = File(picked.path);
        }
      });
    }
  }

  Future<void> _pickFromGallery(bool isKtp) async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1200, imageQuality: 80);
    if (picked != null) {
      setState(() {
        if (isKtp) {
          _ktpFile = File(picked.path);
        } else {
          _selfieFile = File(picked.path);
        }
      });
    }
  }

  void _showPickerOptions(bool isKtp) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: notifire.getprimerycolor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isKtp ? 'Foto KTP' : 'Selfie dengan KTP',
              style: TextStyle(
                color: notifire.getdarkscolor,
                fontFamily: 'Gilroy Bold',
                fontSize: height / 45,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Icon(Icons.camera_alt, color: notifire.getbluecolor),
              title: Text('Kamera', style: TextStyle(color: notifire.getdarkscolor, fontFamily: 'Gilroy Medium')),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(isKtp);
              },
            ),
            ListTile(
              leading: Icon(Icons.photo_library, color: notifire.getbluecolor),
              title: Text('Galeri', style: TextStyle(color: notifire.getdarkscolor, fontFamily: 'Gilroy Medium')),
              onTap: () {
                Navigator.pop(ctx);
                _pickFromGallery(isKtp);
              },
            ),
            SizedBox(height: MediaQuery.of(ctx).padding.bottom),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_ktpFile == null || _selfieFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Upload foto KTP dan selfie dengan KTP'), behavior: SnackBarBehavior.floating),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final response = await ApiService.uploadKyc(
        ktpFile: _ktpFile!,
        selfieFile: _selfieFile!,
      );

      if (mounted) {
        if (response.containsKey('kyc_status')) {
          Provider.of<AuthProvider>(context, listen: false).fetchProfile();
          setState(() => _kycStatus = response['kyc_status']);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['message'] ?? 'KYC berhasil diupload'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: const Color(0xFF4CAF50),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['message'] ?? 'Upload gagal'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Koneksi error'), behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String _statusText(String status) {
    switch (status) {
      case 'pending':
        return 'Menunggu Verifikasi';
      case 'approved':
        return 'Terverifikasi';
      case 'rejected':
        return 'Ditolak';
      default:
        return 'Belum Verifikasi';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return const Color(0xFFFF9800);
      case 'approved':
        return const Color(0xFF4CAF50);
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.schedule;
      case 'approved':
        return Icons.verified;
      case 'rejected':
        return Icons.cancel;
      default:
        return Icons.info_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    notifire = Provider.of<ColorNotifire>(context, listen: true);

    return Scaffold(
      backgroundColor: notifire.getprimerycolor,
      appBar: AppBar(
        backgroundColor: notifire.getprimerycolor,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Icon(Icons.arrow_back, color: notifire.getdarkscolor),
        ),
        title: Text(
          'Verifikasi KYC',
          style: TextStyle(
            color: notifire.getdarkscolor,
            fontFamily: 'Gilroy Bold',
            fontSize: height / 42,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(width / 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _statusColor(_kycStatus).withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _statusColor(_kycStatus).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(_statusIcon(_kycStatus), color: _statusColor(_kycStatus), size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Status KYC',
                          style: TextStyle(
                            color: notifire.getdarkgreycolor,
                            fontFamily: 'Gilroy Medium',
                            fontSize: height / 60,
                          ),
                        ),
                        Text(
                          _statusText(_kycStatus),
                          style: TextStyle(
                            color: _statusColor(_kycStatus),
                            fontFamily: 'Gilroy Bold',
                            fontSize: height / 48,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            if (_kycStatus == 'approved') ...[
              SizedBox(height: height / 20),
              Center(
                child: Column(
                  children: [
                    Icon(Icons.verified_rounded, color: const Color(0xFF4CAF50), size: 80),
                    const SizedBox(height: 16),
                    Text(
                      'KYC Anda sudah terverifikasi',
                      style: TextStyle(
                        color: notifire.getdarkscolor,
                        fontFamily: 'Gilroy Bold',
                        fontSize: height / 45,
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (_kycStatus == 'pending') ...[
              SizedBox(height: height / 20),
              Center(
                child: Column(
                  children: [
                    Icon(Icons.hourglass_top, color: const Color(0xFFFF9800), size: 64),
                    const SizedBox(height: 16),
                    Text(
                      'Dokumen sedang diverifikasi',
                      style: TextStyle(
                        color: notifire.getdarkscolor,
                        fontFamily: 'Gilroy Bold',
                        fontSize: height / 45,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Proses verifikasi membutuhkan waktu 1x24 jam',
                      style: TextStyle(
                        color: notifire.getdarkgreycolor,
                        fontFamily: 'Gilroy Medium',
                        fontSize: height / 55,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ] else ...[
              SizedBox(height: height / 30),
              Text(
                'Foto KTP',
                style: TextStyle(
                  color: notifire.getdarkscolor,
                  fontFamily: 'Gilroy Bold',
                  fontSize: height / 48,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Pastikan foto KTP jelas dan tidak terpotong',
                style: TextStyle(
                  color: notifire.getdarkgreycolor,
                  fontFamily: 'Gilroy Medium',
                  fontSize: height / 60,
                ),
              ),
              const SizedBox(height: 12),
              _buildUploadArea(
                file: _ktpFile,
                icon: Icons.credit_card,
                label: 'Upload Foto KTP',
                onTap: () => _showPickerOptions(true),
              ),

              SizedBox(height: height / 30),
              Text(
                'Selfie dengan KTP',
                style: TextStyle(
                  color: notifire.getdarkscolor,
                  fontFamily: 'Gilroy Bold',
                  fontSize: height / 48,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Foto diri Anda sambil memegang KTP di samping wajah',
                style: TextStyle(
                  color: notifire.getdarkgreycolor,
                  fontFamily: 'Gilroy Medium',
                  fontSize: height / 60,
                ),
              ),
              const SizedBox(height: 12),
              _buildUploadArea(
                file: _selfieFile,
                icon: Icons.person,
                label: 'Upload Selfie dengan KTP',
                onTap: () => _showPickerOptions(false),
              ),

              SizedBox(height: height / 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: (_ktpFile != null && _selfieFile != null && !_isSubmitting) ? _submit : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: notifire.getbluecolor,
                    disabledBackgroundColor: Colors.grey.withOpacity(0.3),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(
                          'Kirim Verifikasi',
                          style: TextStyle(
                            color: Colors.white,
                            fontFamily: 'Gilroy Bold',
                            fontSize: height / 48,
                          ),
                        ),
                ),
              ),
            ],
            SizedBox(height: height / 20),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadArea({
    required File? file,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: file != null ? null : height / 5,
        decoration: BoxDecoration(
          color: notifire.gettabwhitecolor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: file != null ? notifire.getbluecolor.withOpacity(0.5) : Colors.grey.withOpacity(0.3),
            width: file != null ? 2 : 1,
            style: file != null ? BorderStyle.solid : BorderStyle.solid,
          ),
        ),
        child: file != null
            ? Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      file,
                      width: double.infinity,
                      height: height / 4,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.check_circle, color: notifire.getbluecolor, size: 24),
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Ganti foto',
                        style: TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'Gilroy Medium'),
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: notifire.getdarkgreycolor.withOpacity(0.4), size: 40),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    style: TextStyle(
                      color: notifire.getdarkgreycolor,
                      fontFamily: 'Gilroy Medium',
                      fontSize: height / 55,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap untuk memilih foto',
                    style: TextStyle(
                      color: notifire.getdarkgreycolor.withOpacity(0.5),
                      fontFamily: 'Gilroy Medium',
                      fontSize: height / 65,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
