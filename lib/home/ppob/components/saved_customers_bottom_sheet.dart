import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';

import '../../../services/api_service.dart';
import '../../../utils/colornotifire.dart';
import '../../../design/design.dart';

class SavedCustomersBottomSheet extends StatefulWidget {
  final String category;
  final Color accentColor;

  const SavedCustomersBottomSheet({
    super.key,
    required this.category,
    required this.accentColor,
  });

  static Future<String?> show(
    BuildContext context, {
    required String category,
    Color accentColor = const Color(0xFF3F6FB4),
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SavedCustomersBottomSheet(
        category: category,
        accentColor: accentColor,
      ),
    );
  }

  @override
  State<SavedCustomersBottomSheet> createState() => _SavedCustomersBottomSheetState();
}

class _SavedCustomersBottomSheetState extends State<SavedCustomersBottomSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  bool _isLoading = false;
  List<dynamic> _customers = [];
  List<dynamic> _filteredCustomers = [];

  // Form state untuk Tambah Pelanggan Baru
  bool _isAddingNew = false;
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _numberCtrl = TextEditingController();
  final TextEditingController _notesCtrl = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _nameCtrl.dispose();
    _numberCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCustomers() async {
    setState(() => _isLoading = true);
    try {
      final list = await ApiService.getSavedCustomers(
        category: widget.category,
      );
      if (mounted) {
        setState(() {
          _customers = list;
          _filterList(_searchCtrl.text);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        Fluttertoast.showToast(
          msg: ApiService.userFriendlyMessage(e, fallback: 'Gagal memuat daftar pelanggan'),
        );
      }
    }
  }

  void _filterList(String query) {
    final q = query.toLowerCase();
    setState(() {
      _filteredCustomers = _customers.where((c) {
        final name = (c['name'] ?? '').toString().toLowerCase();
        final num = (c['customer_number'] ?? '').toString().toLowerCase();
        final notes = (c['notes'] ?? '').toString().toLowerCase();
        return name.contains(q) || num.contains(q) || notes.contains(q);
      }).toList();
    });
  }

  Future<void> _deleteCustomer(int id, String name) async {
    final confirm = await AppDialog.confirm(
      context: context,
      title: 'Hapus Pelanggan',
      description: 'Apakah Anda yakin ingin menghapus "$name" dari daftar pelanggan?',
      confirmText: 'Hapus',
      cancelText: 'Batal',
      isDestructive: true,
    );

    if (!confirm) return;

    try {
      await ApiService.deleteSavedCustomer(id);
      Fluttertoast.showToast(msg: 'Pelanggan berhasil dihapus');
      _loadCustomers();
    } catch (e) {
      Fluttertoast.showToast(
        msg: ApiService.userFriendlyMessage(e, fallback: 'Gagal menghapus pelanggan'),
      );
    }
  }

  Future<void> _saveNewCustomer() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      await ApiService.saveCustomer(
        name: _nameCtrl.text.trim(),
        customerNumber: _numberCtrl.text.trim(),
        category: widget.category,
        notes: _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
      );

      Fluttertoast.showToast(msg: 'Pelanggan berhasil disimpan');
      if (mounted) {
        setState(() {
          _isAddingNew = false;
          _nameCtrl.clear();
          _numberCtrl.clear();
          _notesCtrl.clear();
        });
        _loadCustomers();
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: ApiService.userFriendlyMessage(e, fallback: 'Gagal menyimpan pelanggan'),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifire = Provider.of<ColorNotifire>(context, listen: true);
    final textPrimary = notifire.getdarkscolor;
    final textSecondary = notifire.getdarkgreycolor;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(bottom: bottomInset),
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag indicator
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.contact_phone_outlined,
                      color: widget.accentColor,
                      size: 24,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _isAddingNew ? 'Tambah Pelanggan' : 'Daftar Pelanggan',
                      style: TextStyle(
                        color: textPrimary,
                        fontFamily: 'Gilroy Bold',
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
                if (!_isAddingNew)
                  TextButton.icon(
                    onPressed: () {
                      setState(() => _isAddingNew = true);
                    },
                    icon: Icon(Icons.add, color: widget.accentColor, size: 18),
                    label: Text(
                      'Tambah Baru',
                      style: TextStyle(
                        color: widget.accentColor,
                        fontFamily: 'Gilroy Bold',
                        fontSize: 14,
                      ),
                    ),
                  )
                else
                  TextButton(
                    onPressed: () {
                      setState(() => _isAddingNew = false);
                    },
                    child: Text(
                      'Kembali',
                      style: TextStyle(
                        color: textSecondary,
                        fontFamily: 'Gilroy Medium',
                        fontSize: 14,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          
          const Divider(height: 1, color: Color(0xFFE5E9EE)),
          
          Expanded(
            child: _isAddingNew ? _buildAddForm(textPrimary, textSecondary) : _buildList(textPrimary, textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildAddForm(Color textPrimary, Color textSecondary) {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Nama Pelanggan
            Text(
              'Nama Pelanggan',
              style: TextStyle(
                color: textPrimary,
                fontFamily: 'Gilroy Bold',
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nameCtrl,
              validator: (v) => v == null || v.trim().isEmpty ? 'Nama harus diisi' : null,
              decoration: InputDecoration(
                hintText: 'Contoh: Listrik Rumah Ibu',
                hintStyle: TextStyle(color: textSecondary.withOpacity(0.6), fontFamily: 'Gilroy Medium'),
                filled: true,
                fillColor: const Color(0xFFF3F4F6),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Nomor Pelanggan / IDPEL
            Text(
              'Nomor Pelanggan / ID',
              style: TextStyle(
                color: textPrimary,
                fontFamily: 'Gilroy Bold',
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _numberCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (v) => v == null || v.trim().isEmpty ? 'Nomor pelanggan harus diisi' : null,
              decoration: InputDecoration(
                hintText: 'Masukkan nomor tagihan / ID',
                hintStyle: TextStyle(color: textSecondary.withOpacity(0.6), fontFamily: 'Gilroy Medium'),
                filled: true,
                fillColor: const Color(0xFFF3F4F6),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Catatan (Opsional)
            Text(
              'Catatan (Opsional)',
              style: TextStyle(
                color: textPrimary,
                fontFamily: 'Gilroy Bold',
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _notesCtrl,
              decoration: InputDecoration(
                hintText: 'Contoh: Meteran samping pintu',
                hintStyle: TextStyle(color: textSecondary.withOpacity(0.6), fontFamily: 'Gilroy Medium'),
                filled: true,
                fillColor: const Color(0xFFF3F4F6),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
            
            const SizedBox(height: 32),
            
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveNewCustomer,
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.accentColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)),
                      )
                    : const Text(
                        'Simpan Pelanggan',
                        style: TextStyle(color: Colors.white, fontFamily: 'Gilroy Bold', fontSize: 14),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(Color textPrimary, Color textSecondary) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        // Search Bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFD4D8DF)),
            ),
            child: TextField(
              controller: _searchCtrl,
              style: TextStyle(color: textPrimary, fontFamily: 'Gilroy Medium', fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Cari nama atau nomor...',
                hintStyle: TextStyle(color: textSecondary.withOpacity(0.6), fontFamily: 'Gilroy Medium', fontSize: 14),
                prefixIcon: const Icon(Icons.search, color: Colors.grey, size: 20),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              ),
              onChanged: _filterList,
            ),
          ),
        ),
        
        Expanded(
          child: _filteredCustomers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off_outlined, size: 64, color: textSecondary.withOpacity(0.3)),
                      const SizedBox(height: 12),
                      Text(
                        _searchCtrl.text.isNotEmpty
                            ? 'Pelanggan tidak ditemukan'
                            : 'Belum ada pelanggan disimpan',
                        style: TextStyle(
                          color: textSecondary,
                          fontFamily: 'Gilroy Medium',
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: _filteredCustomers.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (ctx, index) {
                    final customer = _filteredCustomers[index];
                    final name = (customer['name'] ?? '-').toString();
                    final num = (customer['customer_number'] ?? '').toString();
                    final notes = (customer['notes'] ?? '').toString();
                    final id = customer['id'] as int;

                    return Card(
                      color: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Color(0xFFE5E9EE)),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        title: Text(
                          name,
                          style: TextStyle(
                            color: textPrimary,
                            fontFamily: 'Gilroy Bold',
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              num,
                              style: TextStyle(
                                color: textSecondary,
                                fontFamily: 'Gilroy Medium',
                                fontSize: 13,
                              ),
                            ),
                            if (notes.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                notes,
                                style: TextStyle(
                                  color: textSecondary.withOpacity(0.7),
                                  fontFamily: 'Gilroy Medium',
                                  fontSize: 11,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ]
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline_outlined, color: Colors.red, size: 20),
                          onPressed: () => _deleteCustomer(id, name),
                        ),
                        onTap: () {
                          Navigator.pop(context, num);
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
