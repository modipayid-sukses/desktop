import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../services/api_service.dart';
import '../utils/colornotifire.dart';
import 'package:provider/provider.dart';

class AddAgentScreen extends StatefulWidget {
  const AddAgentScreen({Key? key}) : super(key: key);

  @override
  State<AddAgentScreen> createState() => _AddAgentScreenState();
}

class _AddAgentScreenState extends State<AddAgentScreen> {
  final _searchController = TextEditingController();
  bool _isSearching = false;
  bool _isAdding = false;
  Map<String, dynamic>? _foundUser;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchUser() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      Fluttertoast.showToast(msg: 'Masukkan nomor HP atau nama pengguna');
      return;
    }
    setState(() {
      _isSearching = true;
      _foundUser = null;
    });
    try {
      final result = await ApiService.searchUserForAgen(query);
      // contacts/search-user returns {id, name, phone} directly
      if (result.containsKey('id')) {
        setState(() => _foundUser = result);
      } else {
        Fluttertoast.showToast(msg: result['message'] ?? 'Pengguna tidak ditemukan');
      }
    } catch (e) {
      Fluttertoast.showToast(msg: ApiService.userFriendlyMessage(e));
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _addAsAgent() async {
    if (_foundUser == null) return;
    setState(() => _isAdding = true);
    try {
      final res = await ApiService.addAgen(userId: _foundUser!['id']);
      Fluttertoast.showToast(msg: res['message'] ?? 'Agen berhasil ditambahkan');
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      Fluttertoast.showToast(msg: ApiService.userFriendlyMessage(e));
    } finally {
      if (mounted) setState(() => _isAdding = false);
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

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        iconTheme: IconThemeData(color: textColor),
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Tambah Agen',
          style: TextStyle(
            color: textColor,
            fontSize: 20,
            fontFamily: 'Gilroy Bold',
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cari Pengguna',
              style: TextStyle(
                color: textColor,
                fontFamily: 'Gilroy Bold',
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Masukkan nomor HP atau nama pengguna yang ingin dijadikan agen.',
              style: TextStyle(
                color: subtitleColor,
                fontFamily: 'Gilroy Medium',
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: TextStyle(color: textColor, fontFamily: 'Gilroy Medium', fontSize: 14),
                    keyboardType: TextInputType.text,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _searchUser(),
                    decoration: InputDecoration(
                      hintText: 'Nomor HP / Nama',
                      hintStyle: TextStyle(color: subtitleColor, fontSize: 13, fontFamily: 'Gilroy Medium'),
                      prefixIcon: Icon(Icons.person_search_outlined, color: subtitleColor, size: 22),
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
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isSearching ? null : _searchUser,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    child: _isSearching
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.search_rounded, color: Colors.white, size: 22),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Hasil pencarian
            if (_foundUser != null) ...[
              Text(
                'Hasil Pencarian',
                style: TextStyle(
                  color: subtitleColor,
                  fontFamily: 'Gilroy Bold',
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE9E9EE)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.person_rounded, color: accent, size: 26),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _foundUser!['name'] ?? 'Nama Pengguna',
                            style: TextStyle(
                              color: textColor,
                              fontFamily: 'Gilroy Bold',
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _foundUser!['phone'] ?? _foundUser!['email'] ?? '-',
                            style: TextStyle(
                              color: subtitleColor,
                              fontFamily: 'Gilroy Medium',
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: _isAdding ? null : _addAsAgent,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: _isAdding
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text(
                              'Tambah',
                              style: TextStyle(
                                color: Colors.white,
                                fontFamily: 'Gilroy Bold',
                                fontSize: 13,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
