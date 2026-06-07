import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../utils/colornotifire.dart';
import '../utils/media.dart';

class ComplaintFormScreen extends StatefulWidget {
  final int? transactionId;
  final String? transactionCode;
  const ComplaintFormScreen({Key? key, this.transactionId, this.transactionCode}) : super(key: key);

  @override
  State<ComplaintFormScreen> createState() => _ComplaintFormScreenState();
}

class _ComplaintFormScreenState extends State<ComplaintFormScreen> {
  late ColorNotifire notifire;
  final _formKey = GlobalKey<FormState>();
  
  String _selectedCategory = 'ppob';
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  late final TextEditingController _transactionIdController;
  
  bool _isLoading = false;

  final Map<String, String> _categories = {
    'ppob': 'Transaksi PPOB',
    'transfer': 'Transfer Saldo',
    'account': 'Akun & Keamanan',
    'other': 'Lainnya',
  };

  @override
  void initState() {
    super.initState();
    _transactionIdController = TextEditingController(
      text: widget.transactionCode ?? (widget.transactionId != null ? widget.transactionId.toString() : ''),
    );
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    _transactionIdController.dispose();
    super.dispose();
  }

  Future<void> _submitComplaint() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    
    int? txId = widget.transactionId;
    String? txCode = widget.transactionCode;
    
    // If not preset from route, try parsing whatever the user manually wrote
    if (txId == null && txCode == null && _transactionIdController.text.trim().isNotEmpty) {
      final input = _transactionIdController.text.trim();
      final parsed = int.tryParse(input);
      if (parsed != null) {
        txId = parsed;
      } else {
        txCode = input;
      }
    }

    try {
      final response = await ApiService.createComplaint(
        category: _selectedCategory,
        subject: _subjectController.text.trim(),
        message: _messageController.text.trim(),
        transactionId: txId,
        transactionCode: txCode,
      );

      if (response['status'] == 'success') {
        Fluttertoast.showToast(msg: 'Pengaduan berhasil dikirim');
        if (mounted) Navigator.pop(context, true);
      } else {
        Fluttertoast.showToast(msg: response['message'] ?? 'Gagal mengirim pengaduan');
      }
    } catch (e) {
      Fluttertoast.showToast(msg: ApiService.userFriendlyMessage(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    notifire = Provider.of<ColorNotifire>(context, listen: true);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: notifire.getprimerycolor,
        elevation: 0,
        iconTheme: IconThemeData(color: notifire.getdarkscolor),
        centerTitle: true,
        title: Text(
          'Buat Pengaduan',
          style: TextStyle(
            color: notifire.getdarkscolor,
            fontFamily: 'Gilroy Bold',
            fontSize: height / 40,
          ),
        ),
      ),
      backgroundColor: notifire.getprimerycolor,
      body: SingleChildScrollView(
        child: Stack(
          children: [
            Container(
              height: height * 0.9,
              width: width,
              color: Colors.transparent,
              child: Image.asset(
                "images/background.png",
                fit: BoxFit.cover,
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: width / 20, vertical: height / 40),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Kategori Masalah",
                      style: TextStyle(
                        color: notifire.getdarkscolor,
                        fontFamily: 'Gilroy Bold',
                        fontSize: height / 50,
                      ),
                    ),
                    SizedBox(height: height / 80),
                    DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: notifire.getdarkwhitecolor,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: notifire.getbluecolor),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      dropdownColor: notifire.getprimerycolor,
                      items: _categories.entries.map((entry) {
                        return DropdownMenuItem<String>(
                          value: entry.key,
                          child: Text(
                            entry.value,
                            style: TextStyle(color: notifire.getdarkscolor, fontFamily: 'Gilroy Medium'),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedCategory = val;
                          });
                        }
                      },
                    ),
                    SizedBox(height: height / 40),
                    Text(
                      "ID Transaksi (Opsional)",
                      style: TextStyle(
                        color: notifire.getdarkscolor,
                        fontFamily: 'Gilroy Bold',
                        fontSize: height / 50,
                      ),
                    ),
                    SizedBox(height: height / 80),
                    TextFormField(
                      controller: _transactionIdController,
                      keyboardType: TextInputType.text, // Allow alphanumeric for transaction codes (e.g. TOPUP-...)
                      readOnly: widget.transactionId != null || widget.transactionCode != null,
                      style: TextStyle(
                        color: (widget.transactionId != null || widget.transactionCode != null)
                            ? notifire.getdarkscolor.withOpacity(0.5) 
                            : notifire.getdarkscolor, 
                        fontFamily: 'Gilroy Medium'
                      ),
                      decoration: InputDecoration(
                        hintText: "Contoh: 12345 atau TOPUP-XXX",
                        hintStyle: const TextStyle(color: Colors.grey),
                        filled: true,
                        fillColor: (widget.transactionId != null || widget.transactionCode != null)
                            ? notifire.getdarkwhitecolor.withOpacity(0.6) 
                            : notifire.getdarkwhitecolor,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: (widget.transactionId != null || widget.transactionCode != null)
                                ? Colors.grey.withOpacity(0.3) 
                                : notifire.getbluecolor
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    SizedBox(height: height / 40),
                    Text(
                      "Subjek / Judul Masalah",
                      style: TextStyle(
                        color: notifire.getdarkscolor,
                        fontFamily: 'Gilroy Bold',
                        fontSize: height / 50,
                      ),
                    ),
                    SizedBox(height: height / 80),
                    TextFormField(
                      controller: _subjectController,
                      style: TextStyle(color: notifire.getdarkscolor, fontFamily: 'Gilroy Medium'),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Subjek tidak boleh kosong';
                        }
                        return null;
                      },
                      decoration: InputDecoration(
                        hintText: "Contoh: Saldo Belum Masuk",
                        hintStyle: const TextStyle(color: Colors.grey),
                        filled: true,
                        fillColor: notifire.getdarkwhitecolor,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: notifire.getbluecolor),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    SizedBox(height: height / 40),
                    Text(
                      "Detail Masalah",
                      style: TextStyle(
                        color: notifire.getdarkscolor,
                        fontFamily: 'Gilroy Bold',
                        fontSize: height / 50,
                      ),
                    ),
                    SizedBox(height: height / 80),
                    TextFormField(
                      controller: _messageController,
                      maxLines: 6,
                      style: TextStyle(color: notifire.getdarkscolor, fontFamily: 'Gilroy Medium'),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Detail masalah tidak boleh kosong';
                        }
                        return null;
                      },
                      decoration: InputDecoration(
                        hintText: "Jelaskan secara detail masalah Anda agar kami dapat membantu lebih cepat...",
                        hintStyle: const TextStyle(color: Colors.grey),
                        filled: true,
                        fillColor: notifire.getdarkwhitecolor,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: notifire.getbluecolor),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    SizedBox(height: height / 20),
                    GestureDetector(
                      onTap: _isLoading ? null : _submitComplaint,
                      child: Container(
                        height: height / 17,
                        width: width,
                        decoration: BoxDecoration(
                          color: notifire.getbluecolor,
                          borderRadius: const BorderRadius.all(
                            Radius.circular(30),
                          ),
                        ),
                        child: Center(
                          child: _isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text(
                                  "Kirim Laporan",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontFamily: 'Gilroy Bold',
                                    fontSize: 16,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
