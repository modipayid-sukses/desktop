import 'package:flutter/material.dart';
import 'package:modipay/home/transfer/transfermoney.dart';
import 'package:modipay/services/api_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/colornotifire.dart';
import '../../utils/media.dart';
import '../../utils/string.dart';

class SendAll extends StatefulWidget {
  const SendAll({Key? key}) : super(key: key);

  @override
  State<SendAll> createState() => _SendAllState();
}

class _SendAllState extends State<SendAll> {
  late ColorNotifire notifire;

  List<Map<String, dynamic>> _contacts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    try {
      final data = await ApiService.getContacts();
      if (mounted) {
        setState(() {
          _contacts = List<Map<String, dynamic>>.from(data);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List avatarImages = [
    "images/man4.png",
    "images/man5.png",
    "images/man6.png",
    "images/man7.png",
  ];

  @override
  Widget build(BuildContext context) {
    notifire = Provider.of<ColorNotifire>(context, listen: true);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _loading
          ? Center(child: CircularProgressIndicator(color: notifire.getbluecolor))
          : _contacts.isEmpty
              ? Center(child: Text('Belum ada kontak', style: TextStyle(color: notifire.getdarkgreycolor)))
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      SizedBox(height: height / 50),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _contacts.length,
                        padding: EdgeInsets.zero,
                        itemBuilder: (context, index) {
                          final contact = _contacts[index];
                          return Column(
                            children: [
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => TransferMoney(
                                        contactId: contact['receiver_user_id'] ?? contact['id'],
                                        contactName: contact['name'] ?? '',
                                        contactPhone: contact['phone'] ?? '',
                                        contactCategory: contact['category'] ?? 'bank',
                                      ),
                                    ),
                                  );
                                },
                                child: Container(
                                  color: Colors.transparent,
                                  child: Row(
                                    children: [
                                      Container(
                                        height: height / 15,
                                        width: width / 7,
                                        decoration: const BoxDecoration(
                                            color: Colors.transparent,
                                            shape: BoxShape.circle),
                                        child: Image.asset(
                                          avatarImages[index % avatarImages.length],
                                        ),
                                      ),
                                      SizedBox(width: width / 30),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            contact['name'] ?? '',
                                            style: TextStyle(
                                                fontSize: height / 45,
                                                color: notifire.getdarkscolor,
                                                fontFamily: 'Gilroy Bold'),
                                          ),
                                          SizedBox(height: height / 200),
                                          Text(
                                            '${contact['category']?.toString().toUpperCase() ?? 'BANK'} | ${contact['phone'] ?? ''}',
                                            style: TextStyle(
                                                fontSize: height / 55,
                                                color: Colors.grey,
                                                fontFamily: 'Gilroy Medium'),
                                          ),
                                        ],
                                      ),
                                      const Spacer(),
                                      GestureDetector(
                                        onTap: () async {
                                          await ApiService.toggleFavorite(contact['id']);
                                          _loadContacts();
                                        },
                                        child: Image.asset(
                                          contact['is_favorite'] == true
                                              ? "images/fillstar.png"
                                              : "images/favorite.png",
                                          height: height / 35,
                                          color: contact['is_favorite'] == true
                                              ? null
                                              : notifire.getdarkscolor,
                                        ),
                                      ),
                                      SizedBox(width: width / 20),
                                    ],
                                  ),
                                ),
                              ),
                              Divider(
                                thickness: 1,
                                color: Colors.grey.withOpacity(0.4),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
    );
  }
}

