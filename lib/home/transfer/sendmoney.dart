import 'package:flutter/material.dart';
import 'package:modipay/home/transfer/sendall.dart';
import 'package:modipay/services/api_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/colornotifire.dart';
import '../../utils/media.dart';
import '../../utils/string.dart';

class SendMoney extends StatefulWidget {
  const SendMoney({Key? key}) : super(key: key);

  @override
  State<SendMoney> createState() => _SendMoneyState();
}

class _SendMoneyState extends State<SendMoney>
    with SingleTickerProviderStateMixin {
  late ColorNotifire notifire;

  getdarkmodepreviousstate() async {
    final prefs = await SharedPreferences.getInstance();
    bool? previusstate = prefs.getBool("setIsDark");
    if (previusstate == null) {
      notifire.setIsDark = false;
    } else {
      notifire.setIsDark = previusstate;
    }
  }

  TabController? controller;
  List<Widget> get _tabs => [
    SendAll(key: UniqueKey()),
    SendAll(key: UniqueKey()),
    SendAll(key: UniqueKey()),
    SendAll(key: UniqueKey()),
  ];

  @override
  void initState() {
    super.initState();
    controller = TabController(length: 4, vsync: this);
  }

  void _showAddContactDialog() {
    final phoneController = TextEditingController();
    bool searching = false;
    bool found = false;
    bool saving = false;
    Map<String, dynamic>? foundUser;
    String? errorMessage;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              decoration: BoxDecoration(
                color: notifire.getprimerycolor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.fromLTRB(
                20, 
                18, 
                20, 
                MediaQuery.of(context).viewInsets.bottom + 20
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Tambah Kontak Modipay',
                    style: TextStyle(
                      fontFamily: 'Gilroy Bold',
                      fontSize: 18,
                      color: Color(0xFF1F1F1F),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (!found) ...[
                    const Text(
                      'Masukkan Nomor HP Pengguna',
                      style: TextStyle(
                        fontFamily: 'Gilroy Medium',
                        fontSize: 13,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      autofocus: true,
                      style: TextStyle(
                        fontFamily: 'Gilroy Medium',
                        fontSize: 15,
                        color: notifire.getdarkscolor,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Contoh: 0812xxxxxxxx',
                        hintStyle: TextStyle(color: Colors.grey.shade400),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: notifire.getbluecolor, width: 1.5),
                        ),
                      ),
                    ),
                    if (errorMessage != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        errorMessage!,
                        style: const TextStyle(
                          fontFamily: 'Gilroy Medium',
                          fontSize: 12,
                          color: Colors.red,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: searching
                            ? null
                            : () async {
                                final phone = phoneController.text.trim();
                                if (phone.isEmpty) {
                                  setSheetState(() => errorMessage = 'Nomor HP tidak boleh kosong');
                                  return;
                                }
                                setSheetState(() {
                                  searching = true;
                                  errorMessage = null;
                                });
                                try {
                                  final res = await ApiService.searchUser(phone);
                                  setSheetState(() {
                                    searching = false;
                                    found = true;
                                    foundUser = res;
                                  });
                                } catch (e) {
                                  setSheetState(() {
                                    searching = false;
                                    errorMessage = ApiService.userFriendlyMessage(e, fallback: 'Pengguna tidak ditemukan');
                                  });
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: notifire.getbluecolor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: searching
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text(
                                'Cari Pengguna',
                                style: TextStyle(
                                  fontFamily: 'Gilroy Bold',
                                  fontSize: 15,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ] else ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.green.shade200, width: 1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.check_circle_rounded, color: Colors.green, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Pengguna Ditemukan!',
                                style: TextStyle(
                                  fontFamily: 'Gilroy Bold',
                                  fontSize: 14,
                                  color: Colors.green.shade700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            foundUser?['name'] ?? '',
                            style: const TextStyle(
                              fontFamily: 'Gilroy Bold',
                              fontSize: 16,
                              color: Color(0xFF2C3E50),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            foundUser?['phone'] ?? '',
                            style: TextStyle(
                              fontFamily: 'Gilroy Medium',
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: OutlinedButton(
                              onPressed: () {
                                setSheetState(() {
                                  found = false;
                                  foundUser = null;
                                  phoneController.clear();
                                });
                              },
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: Colors.grey.shade300),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text(
                                'Cari Lagi',
                                style: TextStyle(
                                  fontFamily: 'Gilroy Bold',
                                  fontSize: 15,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              onPressed: saving
                                  ? null
                                  : () async {
                                      setSheetState(() => saving = true);
                                      try {
                                        final res = await ApiService.createContact(
                                          name: foundUser?['name'] ?? '',
                                          phone: foundUser?['phone'] ?? '',
                                          category: 'favorite',
                                        );
                                        if (res.containsKey('contact')) {
                                          Navigator.pop(ctx);
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('Kontak berhasil ditambahkan ke daftar transfer'),
                                              behavior: SnackBarBehavior.floating,
                                            ),
                                          );
                                          setState(() {}); // Trigger rebuild to reload list
                                        } else {
                                          setSheetState(() {
                                            saving = false;
                                            errorMessage = res['message'] ?? 'Gagal menyimpan kontak';
                                          });
                                        }
                                      } catch (e) {
                                        setSheetState(() {
                                          saving = false;
                                          errorMessage = ApiService.userFriendlyMessage(e, fallback: 'Gagal menyimpan kontak');
                                        });
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: notifire.getbluecolor,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: saving
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Text(
                                      'Simpan Kontak',
                                      style: TextStyle(
                                        fontFamily: 'Gilroy Bold',
                                        fontSize: 15,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    notifire = Provider.of<ColorNotifire>(context, listen: true);
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Kirim uang',
          style: TextStyle(
            fontSize: 20,
            fontFamily: 'Gilroy Bold',
            color: notifire.getdarkscolor,
          ),
        ),
        actions: [
          GestureDetector(
            onTap: _showAddContactDialog,
            child: Container(
              height: 40,
              width: 40,
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.withOpacity(0.4)),
              ),
              child: Icon(Icons.add, color: notifire.getdarkscolor),
            ),
          ),
        ],
        backgroundColor: notifire.getprimerycolor,
        leading: GestureDetector(
          onTap: () {
            Navigator.pop(context);
          },
          child: Container(
            height: 40,
            width: 40,
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey.withOpacity(0.4)),
            ),
            child: Icon(Icons.arrow_back, color: notifire.getdarkscolor),
          ),
        ),
      ),
      backgroundColor: notifire.getprimerycolor,
      body: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          children: [
            Stack(
              children: [
                Container(
                  height: height,
                  width: width,
                  color: Colors.transparent,
                  child: Image.asset(
                    "images/background.png",
                    fit: BoxFit.cover,
                  ),
                ),
                Column(
                  children: [
                    SizedBox(
                      height: height / 40,
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: width / 20),
                      child: Container(
                        color: Colors.transparent,
                        width: width,
                        height: height / 15,
                        child: TextField(
                          autofocus: false,
                          style: TextStyle(
                            fontSize: height / 50,
                            color: notifire.getdarkscolor,
                          ),
                          decoration: InputDecoration(
                            hintText: "Cari kontak..",
                            filled: true,
                            fillColor: notifire.getprimerydarkcolor,
                            hintStyle: TextStyle(
                                color: Colors.grey, fontSize: height / 60),
                            prefixIcon: Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal: width / 50,
                                  vertical: height / 60),
                              child: Image.asset(
                                "images/search.png",
                                color: notifire.getdarkgreycolor,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide:
                                  BorderSide(color: notifire.getbluecolor),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: const BorderSide(
                                color: Color(0xffd3d3d3),
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      height: height / 50,
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: width / 20),
                      child: Container(
                        height: height / 1.2,
                        color: Colors.transparent,
                        child: Column(
                          children: <Widget>[
                            Container(
                              height: 45,
                              decoration: BoxDecoration(
                                  color: notifire.gettabcolor,
                                  borderRadius: BorderRadius.circular(10)),
                              child: Padding(
                                padding: EdgeInsets.all(height / 200),
                                child: TabBar(
                                  labelStyle: const TextStyle(
                                      fontFamily: 'Gilroy Bold'),
                                  indicator: BoxDecoration(
                                      color: notifire.gettabwhitecolor,
                                      borderRadius: BorderRadius.circular(10)),
                                  indicatorColor: notifire.getbluecolor,
                                  controller: controller,
                                  labelColor: notifire.getdarkscolor,
                                  unselectedLabelColor: Colors.grey,
                                  indicatorSize: TabBarIndicatorSize.tab,
                                  dividerColor: Colors.transparent,
                                  tabs: const [
                                    Tab(text: CustomStrings.all),
                                    Tab(text: CustomStrings.favorite),
                                    Tab(text: CustomStrings.bank),
                                    Tab(text: CustomStrings.ewallet),
                                  ],
                                ),
                              ),
                            ),
                            Expanded(
                              child: TabBarView(
                                controller: controller,
                                children: _tabs,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
