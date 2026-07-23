import 'package:flutter/material.dart';
import 'package:flutter_native_contact_picker/flutter_native_contact_picker.dart';
import 'package:modipay/home/transfer/sendall.dart';
import '../../utils/responsive.dart';
import 'package:modipay/services/api_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/auth_provider.dart';
import '../../utils/colornotifire.dart';
import '../../utils/media.dart';
import '../../utils/string.dart';
import 'transfermoney.dart';

const List<Color> _avatarColors = [
  Color(0xFF1E88E5), // blue
  Color(0xFF43A047), // green
  Color(0xFFFF9800), // orange
  Color(0xFFE53935), // red
  Color(0xFF8E24AA), // purple
  Color(0xFF00ACC1), // cyan
  Color(0xFFFF7043), // deep orange
  Color(0xFF5C6BC0), // indigo
];

class SendMoney extends StatefulWidget {
  const SendMoney({Key? key}) : super(key: key);

  @override
  State<SendMoney> createState() => _SendMoneyState();
}

class _SendMoneyState extends State<SendMoney> {
  late ColorNotifire notifire;
  final _searchController = TextEditingController();
  final FlutterNativeContactPicker _contactPicker = FlutterNativeContactPicker();
  String _searchQuery = '';
  Key _refreshKey = UniqueKey();
  List<Map<String, dynamic>> _agents = [];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  getdarkmodepreviousstate() async {
    final prefs = await SharedPreferences.getInstance();
    bool? previusstate = prefs.getBool("setIsDark");
    if (previusstate == null) {
      notifire.setIsDark = false;
    } else {
      notifire.setIsDark = previusstate;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAgents());
  }

  Future<void> _loadAgents() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isMasterAgent) return;
    try {
      final response = await ApiService.getAgens();
      final data = response['data'];
      if (mounted && data is List) {
        setState(() {
          _agents = data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        });
      }
    } catch (_) {}
  }

  String _normalizeMsisdn(String raw) {
    var digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('62')) {
      digits = '0${digits.substring(2)}';
    } else if (digits.startsWith('8')) {
      digits = '0$digits';
    }
    return digits;
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
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                        color: const Color(0xFF3567A9).withOpacity(0.2),
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
                      color: Color(0xFF182974),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (!found) ...[
                    const Text(
                      'Masukkan Nomor HP Pengguna',
                      style: TextStyle(
                        fontFamily: 'Gilroy Medium',
                        fontSize: 13,
                        color: Color(0xFF3567A9),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      autofocus: true,
                      style: const TextStyle(
                        fontFamily: 'Gilroy Medium',
                        fontSize: 15,
                        color: Color(0xFF182974),
                      ),
                      decoration: InputDecoration(
                        hintText: 'Contoh: 0812xxxxxxxx',
                        hintStyle: TextStyle(color: const Color(0xFF3567A9).withOpacity(0.4)),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        suffixIcon: IconButton(
                          icon: Icon(Icons.contacts_rounded, color: notifire.getbluecolor),
                          tooltip: 'Pilih dari kontak HP',
                          onPressed: () async {
                            try {
                              final contact = await _contactPicker.selectPhoneNumber();
                              final selected = contact?.selectedPhoneNumber?.trim() ?? '';
                              final fromList = (contact?.phoneNumbers != null &&
                                      contact!.phoneNumbers!.isNotEmpty)
                                  ? contact.phoneNumbers!.first.trim()
                                  : '';
                              final raw = selected.isNotEmpty ? selected : fromList;
                              final normalized = _normalizeMsisdn(raw);
                              if (normalized.isEmpty) {
                                setSheetState(() => errorMessage = 'Nomor dari kontak tidak valid');
                                return;
                              }
                              phoneController.text = normalized;
                              setSheetState(() => errorMessage = null);
                            } catch (_) {
                              setSheetState(() => errorMessage = 'Gagal mengambil kontak');
                            }
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: const Color(0xFF3567A9).withOpacity(0.3)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: const Color(0xFF3567A9).withOpacity(0.3)),
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
                            style: const TextStyle(
                              fontFamily: 'Gilroy Medium',
                              fontSize: 13,
                              color: Color(0xFF3567A9),
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
                                side: const BorderSide(color: Color(0xFF3567A9)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text(
                                'Cari Lagi',
                                style: TextStyle(
                                  fontFamily: 'Gilroy Bold',
                                  fontSize: 15,
                                  color: Color(0xFF3567A9),
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
                                          avatar: foundUser?['avatar']?.toString(),
                                        );
                                        if (res.containsKey('contact')) {
                                          Navigator.pop(ctx);
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('Kontak berhasil ditambahkan ke daftar transfer'),
                                              behavior: SnackBarBehavior.floating,
                                            ),
                                          );
                                          setState(() {
                                            _refreshKey = UniqueKey();
                                          });
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
    final auth = Provider.of<AuthProvider>(context);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: isDesktopPopup(context) ? null : AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: Color(0xFF182974)),
        ),
        title: const Text(
          'Kirim uang',
          style: TextStyle(fontSize: 17, fontFamily: 'Gilroy Bold', color: Color(0xFF182974)),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _showAddContactDialog,
            icon: const Icon(Icons.add, color: Color(0xFF182974)),
          ),
        ],
      ),
      body: Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(width / 20, 8, width / 20, 0),
                child: TextField(
                  controller: _searchController,
                  autofocus: false,
                  style: TextStyle(
                    fontSize: height / 50,
                    color: const Color(0xFF182974),
                  ),
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val.trim();
                    });
                  },
                  decoration: InputDecoration(
                    hintText: "Cari kontak..",
                    filled: true,
                    fillColor: const Color(0xFFF5F6F8),
                    hintStyle: TextStyle(color: const Color(0xFF3567A9).withOpacity(0.5), fontSize: height / 60),
                    prefixIcon: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Image.asset(
                        "images/search.png",
                        color: const Color(0xFF3567A9),
                        height: 20,
                      ),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Color(0xFF182974), width: 1.5),
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (auth.isMasterAgent && _agents.isNotEmpty) ...[
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: width / 20),
                  child: Text(
                    'Agen Saya',
                    style: TextStyle(
                      fontSize: height / 55,
                      fontFamily: 'Gilroy Bold',
                      color: const Color(0xFF182974),
                    ),
                  ),
                ),
                SizedBox(height: height / 100),
                SizedBox(
                  height: 90,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.symmetric(horizontal: width / 20),
                    itemCount: _agents.length,
                    itemBuilder: (context, index) {
                      final agent = _agents[index];
                      final agentId = agent['id'] is int
                          ? agent['id'] as int
                          : int.tryParse(agent['id'].toString()) ?? 0;
                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => TransferMoney(
                                contactId: agentId,
                                contactName: agent['name']?.toString() ?? '',
                                contactPhone: agent['phone']?.toString() ?? '',
                                contactCategory: 'agent',
                              ),
                            ),
                          );
                        },
                        child: Container(
                          width: 72,
                          margin: const EdgeInsets.only(right: 12),
                          child: Column(
                            children: [
                              CircleAvatar(
                                radius: 26,
                                backgroundColor: _avatarColors[index % _avatarColors.length],
                                child: Text(
                                  agent['name']?.toString().isNotEmpty == true
                                      ? agent['name'].toString()[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontFamily: 'Gilroy Bold',
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                agent['name']?.toString() ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: height / 75,
                                  fontFamily: 'Gilroy Medium',
                                  color: const Color(0xFF182974),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                SizedBox(height: height / 60),
              ],
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: width / 20),
                  child: SendAll(
                    key: _refreshKey,
                    searchQuery: _searchQuery,
                  ),
                ),
              ),
            ],
          ),
    );
  }
}
