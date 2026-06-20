import 'package:flutter/material.dart';
import 'package:modipay/widgets/desktop_title_wrapper.dart';

import 'package:fluttertoast/fluttertoast.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../utils/colornotifire.dart';
import 'package:provider/provider.dart';

class AddAgentScreen extends StatefulWidget {
  const AddAgentScreen({Key? key}) : super(key: key);

  @override
  State<AddAgentScreen> createState() => _AddAgentScreenState();
}

class _AddAgentScreenState extends State<AddAgentScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isSaving = false;
  bool _isExistingMode = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final phone = _phoneController.text.trim();

    if (_isExistingMode) {
      if (phone.isEmpty) {
        Fluttertoast.showToast(msg: 'No. HP wajib diisi');
        return;
      }

      setState(() => _isSaving = true);
      try {
        final res = await ApiService.addExistingAgen(phone: phone);
        Fluttertoast.showToast(msg: res['message'] ?? 'Agen berhasil ditambahkan');
        if (mounted) Navigator.pop(context, true);
      } catch (e) {
        Fluttertoast.showToast(msg: ApiService.userFriendlyMessage(e));
      } finally {
        if (mounted) setState(() => _isSaving = false);
      }
      return;
    }

    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (name.isEmpty || phone.isEmpty || password.isEmpty) {
      Fluttertoast.showToast(msg: 'Nama, No. HP, dan Password wajib diisi');
      return;
    }
    if (password.length < 6) {
      Fluttertoast.showToast(msg: 'Password minimal 6 karakter');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final res = await ApiService.addAgen(
        name: name,
        phone: phone,
        password: password,
        email: email.isEmpty ? null : email,
        referralCode: auth.referralCode,
      );
      Fluttertoast.showToast(msg: res['message'] ?? 'Agen berhasil ditambahkan');
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      Fluttertoast.showToast(msg: ApiService.userFriendlyMessage(e));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifire = Provider.of<ColorNotifire>(context, listen: true);
    final bgColor = notifire.getprimerycolor;
    final cardColor = notifire.getdarkwhitecolor;
    final textColor = notifire.getdarkscolor;
    final subtitleColor = notifire.getdarkgreycolor;
    final accent = notifire.getbluecolor;

    InputDecoration fieldDecoration(String hint, IconData icon) {
      return InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: subtitleColor, fontSize: 13, fontFamily: 'Gilroy Medium'),
        prefixIcon: Icon(icon, color: subtitleColor, size: 22),
        filled: true,
        fillColor: cardColor,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
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
          borderSide: BorderSide(color: accent, width: 1.5),
        ),
      );
    }

    Widget fieldLabel(String text) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            text,
            style: TextStyle(color: textColor, fontFamily: 'Gilroy Bold', fontSize: 13),
          ),
        );

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        iconTheme: IconThemeData(color: textColor),
        elevation: 0,
        centerTitle: true,
        title: DesktopTitleWrapper(child: Text(
          'Tambah Agen',
          style: TextStyle(
            color: textColor,
            fontSize: 20,
            fontFamily: 'Gilroy Bold',
          ),
        ))
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFD3DBE8)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _isExistingMode = false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: !_isExistingMode ? accent : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Akun Baru',
                          style: TextStyle(
                            color: !_isExistingMode ? Colors.white : textColor,
                            fontFamily: 'Gilroy Bold',
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _isExistingMode = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _isExistingMode ? accent : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Akun Existing',
                          style: TextStyle(
                            color: _isExistingMode ? Colors.white : textColor,
                            fontFamily: 'Gilroy Bold',
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _isExistingMode ? 'Tambahkan Akun Existing' : 'Buat Akun Agen Baru',
              style: TextStyle(
                color: textColor,
                fontFamily: 'Gilroy Bold',
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _isExistingMode
                  ? 'Tambahkan pengguna yang sudah terdaftar ke dalam hierarki Agen Anda. Gunakan nomor HP mereka untuk mencari akun.'
                  : 'Akun agen baru akan dibuat di bawah hierarki Anda. Bagikan No. HP dan Password ini ke agen untuk login.',
              style: TextStyle(
                color: subtitleColor,
                fontFamily: 'Gilroy Medium',
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 20),
            if (!_isExistingMode) ...[
              fieldLabel('Nama Agen'),
              TextField(
                controller: _nameController,
                style: TextStyle(color: textColor, fontFamily: 'Gilroy Medium', fontSize: 14),
                decoration: fieldDecoration('Masukkan nama agen', Icons.person_outline_rounded),
              ),
              const SizedBox(height: 16),
            ],
            fieldLabel('No. HP'),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              style: TextStyle(color: textColor, fontFamily: 'Gilroy Medium', fontSize: 14),
              decoration: fieldDecoration('Contoh: 0812xxxxxxxx', Icons.phone_outlined),
            ),
            if (!_isExistingMode) ...[
              const SizedBox(height: 16),
              fieldLabel('Email (opsional)'),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: TextStyle(color: textColor, fontFamily: 'Gilroy Medium', fontSize: 14),
                decoration: fieldDecoration('Masukkan email agen', Icons.email_outlined),
              ),
              const SizedBox(height: 16),
              fieldLabel('Password'),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                style: TextStyle(color: textColor, fontFamily: 'Gilroy Medium', fontSize: 14),
                decoration: fieldDecoration('Minimal 6 karakter', Icons.lock_outline_rounded).copyWith(
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: subtitleColor,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        _isExistingMode ? 'Tambahkan Agen' : 'Buat Akun Agen',
                        style: const TextStyle(
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
