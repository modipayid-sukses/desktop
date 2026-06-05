import 'package:flutter/material.dart';
import 'package:modipay/services/api_service.dart';
import 'package:modipay/utils/media.dart';
import 'package:modipay/utils/string.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/colornotifire.dart';

class Notificationindex extends StatefulWidget {
  final String title;
  const Notificationindex(this.title, {Key? key}) : super(key: key);

  @override
  State<Notificationindex> createState() => _NotificationindexState();
}

class _NotificationindexState extends State<Notificationindex> {
  late ColorNotifire notifire;
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;

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
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    try {
      final result = await ApiService.getNotifications();
      debugPrint('[Notifications] API Result: $result');
      if (result['success'] == true || result['data'] != null) {
        setState(() {
          final rawList = result['data'] as List? ?? [];
          _notifications = rawList.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e, stack) {
      debugPrint('[Notifications] Error loading notifications: $e\n$stack');
      setState(() => _isLoading = false);
    }
  }

  String _getNotificationImage(String type) {
    switch (type) {
      case 'transfer':
        return 'images/banktransfer.png';
      case 'topup':
        return 'images/successfull.png';
      case 'payment':
        return 'images/order.png';
      case 'promo':
        return 'images/bankinsurance.png';
      default:
        return 'images/lockdown.png';
    }
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'transfer':
        return const Color(0xff1565C0);
      case 'topup':
        return const Color(0xff4BD37B);
      case 'payment':
        return const Color(0xffFFA03C);
      case 'promo':
        return const Color(0xff10AFFF);
      default:
        return const Color(0xff10AFFF);
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr).toLocal();
      final now = DateTime.now();
      final diff = now.difference(date);
      if (diff.inDays == 0) return 'Hari ini';
      if (diff.inDays == 1) return 'Kemarin';
      if (diff.inDays < 7) return '${diff.inDays} hari lalu';
      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    notifire = Provider.of<ColorNotifire>(context, listen: true);
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: notifire.getprimerycolor,
        iconTheme: IconThemeData(color: notifire.getdarkscolor),
        title: Text(
          CustomStrings.notification,
          style: TextStyle(
            color: notifire.getdarkscolor,
            fontFamily: 'Gilroy Bold',
            fontSize: height / 40,
          ),
        ),
      ),
      backgroundColor: notifire.getprimerycolor,
      body: Stack(
        children: [
          Image.asset(
            "images/background.png",
            fit: BoxFit.cover,
          ),
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _notifications.isEmpty
                  ? Center(
                      child: Text(
                        'Belum ada notifikasi',
                        style: TextStyle(
                          color: notifire.getdarkgreycolor,
                          fontFamily: 'Gilroy Medium',
                          fontSize: height / 50,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _notifications.length,
                      padding: EdgeInsets.symmetric(
                        horizontal: width / 20,
                        vertical: height / 30,
                      ),
                      itemBuilder: (context, index) {
                        final n = _notifications[index];
                        final type = n['icon'] ?? n['type'] ?? 'info';
                        final isRead = n['is_read'] == true;
                        final color = _getNotificationColor(type);
                        final img = _getNotificationImage(type);
                        return Column(
                          children: [
                            InkWell(
                              borderRadius: const BorderRadius.all(
                                Radius.circular(20),
                              ),
                              onTap: () async {
                                _showNotificationDetail(n, color, img);
                                if (!isRead) {
                                  try {
                                    await ApiService.markNotificationRead(n['id']);
                                    setState(() {
                                      _notifications[index]['is_read'] = true;
                                    });
                                  } catch (e) {
                                    // Silent error
                                  }
                                }
                              },
                              child: not(
                                color,
                                img,
                                n['title'] ?? '',
                                _formatDate(n['created_at']),
                                isRead,
                              ),
                            ),
                            SizedBox(
                              height: height / 60,
                            ),
                          ],
                        );
                      },
                    ),
        ],
      ),
    );
  }

  void _showNotificationDetail(Map<String, dynamic> notification, Color color, String imagePath) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: BoxDecoration(
            color: notifire.getprimerycolor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.all(width / 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 50,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              SizedBox(height: height / 40),
              Row(
                children: [
                  Container(
                    height: height / 15,
                    width: width / 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color.withOpacity(0.15),
                    ),
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.all(height / 70),
                        child: Image.asset(imagePath, color: color),
                      ),
                    ),
                  ),
                  SizedBox(width: width / 30),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          notification['title'] ?? 'Notifikasi',
                          style: TextStyle(
                            color: notifire.getdarkscolor,
                            fontFamily: 'Gilroy Bold',
                            fontSize: height / 45,
                          ),
                        ),
                        SizedBox(height: height / 150),
                        Text(
                          _formatDate(notification['created_at']),
                          style: TextStyle(
                            color: Colors.grey,
                            fontFamily: 'Gilroy Medium',
                            fontSize: height / 60,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 30),
              Text(
                notification['message'] ?? '',
                style: TextStyle(
                  color: notifire.getdarkscolor,
                  fontFamily: 'Gilroy Medium',
                  fontSize: height / 50,
                  height: 1.4,
                ),
              ),
              SizedBox(height: height / 30),
              SizedBox(
                width: double.infinity,
                height: height / 16,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff6C5CE7),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Tutup',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Gilroy Bold',
                      fontSize: height / 50,
                    ),
                  ),
                ),
              ),
              SizedBox(height: height / 50),
            ],
          ),
        );
      },
    );
  }

  Widget not(clr, img, txt, txt2, bool isRead) {
    return Container(
      height: height / 11,
      width: width,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.all(
          Radius.circular(20),
        ),
        color: notifire.gettabwhitecolor,
      ),
      child: Row(
        children: [
          SizedBox(
            width: width / 35,
          ),
          Container(
            height: height / 15,
            width: width / 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isRead ? clr.withOpacity(0.1) : clr,
            ),
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(height / 70),
                child: Image.asset(img, color: isRead ? clr : Colors.white),
              ),
            ),
          ),
          SizedBox(
            width: width / 50,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  txt,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: TextStyle(
                      color: notifire.getdarkscolor,
                      fontFamily: isRead ? 'Gilroy Medium' : 'Gilroy Bold',
                      fontSize: height / 54),
                ),
                SizedBox(
                  height: height / 150,
                ),
                Text(
                  txt2,
                  style: TextStyle(
                      color: Colors.grey,
                      fontFamily: 'Gilroy Medium',
                      fontSize: height / 60),
                ),
              ],
            ),
          ),
          if (!isRead)
            Container(
              margin: EdgeInsets.only(right: width / 20),
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xffFF3B30),
              ),
            ),
        ],
      ),
    );
  }
}
