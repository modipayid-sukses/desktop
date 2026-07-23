import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:modipay/widgets/desktop_title_wrapper.dart';
import '../utils/responsive.dart';

import 'package:modipay/services/api_service.dart';
import 'package:modipay/utils/media.dart';
import 'package:modipay/utils/string.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/color.dart';
import '../utils/colornotifire.dart';
import '../utils/transaction_helpers.dart';

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
      final date = parseDateTime(dateStr);
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
      backgroundColor: desktopSurfacePage,
      appBar: isDesktopPopup(context) ? null : AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.white,
        leading: DesktopLeadingWrapper(
          child: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: desktopTextPrimary),
          ),
        ),
        iconTheme: const IconThemeData(color: desktopTextPrimary),
        title: DesktopTitleWrapper(child: Text(
          CustomStrings.notification,
          style: GoogleFonts.hankenGrotesk(
            color: desktopTextPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ))
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? Center(
                  child: Text(
                    'Belum ada notifikasi',
                    style: GoogleFonts.hankenGrotesk(
                      color: desktopTextSecondary,
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 5,
                                child: Text(
                                  'Notifikasi',
                                  style: GoogleFonts.hankenGrotesk(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                    color: desktopTextSecondary,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  'Tanggal',
                                  textAlign: TextAlign.right,
                                  style: GoogleFonts.hankenGrotesk(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                    color: desktopTextSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Divider(height: 1, color: desktopBorder.withOpacity(0.5)),
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _notifications.length,
                          separatorBuilder: (_, __) => Divider(height: 1, color: desktopBorder.withOpacity(0.2)),
                          itemBuilder: (context, index) {
                            final n = _notifications[index];
                            final type = n['icon'] ?? n['type'] ?? 'info';
                            final isRead = n['is_read'] == true;
                            final color = _getNotificationColor(type);
                            final img = _getNotificationImage(type);
                            return InkWell(
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
                              child: notificationRow(
                                color,
                                img,
                                n['title'] ?? '',
                                _formatDate(n['created_at']),
                                isRead,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }

  void _showNotificationDetail(Map<String, dynamic> notification, Color color, String imagePath) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.45,
          minChildSize: 0.3,
          maxChildSize: 0.85,
          expand: false,
          builder: (context, scrollController) {
            final media = MediaQuery.of(context);
            final w = media.size.width;
            final h = media.size.height;
            return Container(
              decoration: BoxDecoration(
                color: notifire.getprimerycolor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.all(w / 20),
              child: ListView(
                controller: scrollController,
                shrinkWrap: true,
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
                  SizedBox(height: h / 40),
                  Row(
                    children: [
                      Container(
                        height: h / 15,
                        width: w / 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color.withOpacity(0.15),
                        ),
                        child: Center(
                          child: Padding(
                            padding: EdgeInsets.all(h / 70),
                            child: Image.asset(imagePath, color: color),
                          ),
                        ),
                      ),
                      SizedBox(width: w / 30),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              notification['title'] ?? 'Notifikasi',
                              style: TextStyle(
                                color: notifire.getdarkscolor,
                                fontFamily: 'Gilroy Bold',
                                fontSize: h / 45,
                              ),
                            ),
                            SizedBox(height: h / 150),
                            Text(
                              _formatDate(notification['created_at']),
                              style: TextStyle(
                                color: Colors.grey,
                                fontFamily: 'Gilroy Medium',
                                fontSize: h / 60,
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
                      fontSize: h / 50,
                      height: 1.4,
                    ),
                  ),
                  SizedBox(height: h / 30),
                  SizedBox(
                    width: double.infinity,
                    height: h / 16,
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
                          fontSize: h / 50,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: h / 50),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget notificationRow(clr, img, txt, txt2, bool isRead) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: clr.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Image.asset(img, color: clr, width: 16, height: 16),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          txt,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.hankenGrotesk(
                            color: desktopTextPrimary,
                            fontWeight: isRead ? FontWeight.w500 : FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      if (!isRead) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: desktopErrorRed.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Baru',
                            style: GoogleFonts.hankenGrotesk(
                              fontWeight: FontWeight.w700,
                              fontSize: 10.5,
                              color: desktopErrorRed,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              txt2,
              textAlign: TextAlign.right,
              style: GoogleFonts.hankenGrotesk(
                color: desktopTextSecondary,
                fontWeight: FontWeight.w500,
                fontSize: 12.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
