import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:modipay/home/transfer/transfermoney.dart';
import 'package:modipay/services/api_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/colornotifire.dart';
import '../../utils/media.dart';
import '../../utils/string.dart';

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

class SendAll extends StatefulWidget {
  final String? category;
  final String searchQuery;

  const SendAll({Key? key, this.category, this.searchQuery = ''}) : super(key: key);

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

  @override
  void didUpdateWidget(SendAll oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchQuery != widget.searchQuery || oldWidget.category != widget.category) {
      _loadContacts();
    }
  }

  Future<void> _loadContacts() async {
    if (mounted) setState(() => _loading = true);
    try {
      final data = await ApiService.getContacts(
        category: widget.category ?? 'favorite',
        search: widget.searchQuery.isEmpty ? null : widget.searchQuery,
      );
      debugPrint('[SendAll] Received contacts data: $data');
      if (mounted) {
        setState(() {
          _contacts = (data as List).map((e) {
            final map = Map<String, dynamic>.from(e as Map);
            debugPrint('[SendAll] Contact item: $map');
            return map;
          }).toList();
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('[SendAll] Error loading contacts: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildInitialAvatar(String name, int index) {
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';
    return Container(
      color: _avatarColors[index % _avatarColors.length],
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white,
          fontFamily: 'Gilroy Bold',
          fontSize: height / 40,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    notifire = Provider.of<ColorNotifire>(context, listen: true);
    return Container(
      color: Colors.transparent,
      child: _loading
          ? Center(child: CircularProgressIndicator(color: notifire.getbluecolor))
          : _contacts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.contact_support_outlined, size: 48, color: const Color(0xFF3567A9).withOpacity(0.3)),
                      const SizedBox(height: 12),
                      const Text(
                        'Belum ada kontak',
                        style: TextStyle(
                          color: Color(0xFF3567A9),
                          fontFamily: 'Gilroy Medium',
                        ),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      SizedBox(height: height / 50),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF43A047).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.star_rounded, color: Color(0xFF43A047), size: 18),
                          ),
                          SizedBox(width: width / 40),
                          const Text(
                            'Kontak Favorit',
                            style: TextStyle(
                              fontSize: 16,
                              fontFamily: 'Gilroy Bold',
                              color: Color(0xFF182974),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: height / 60),
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
                                  final receiverId = contact['receiver_user_id'];
                                  if (receiverId == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Kontak ini bukan pengguna Modipay aktif'),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                    return;
                                  }
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => TransferMoney(
                                        contactId: receiverId,
                                        contactName: contact['name'] ?? '',
                                        contactPhone: contact['phone'] ?? '',
                                        contactCategory: contact['category'] ?? 'favorite',
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
                                        child: ClipOval(
                                          child: () {
                                            final avatarPath = contact['avatar']?.toString();
                                            final avatarUrl = ApiService.avatarUrl(avatarPath);
                                            final name = contact['name']?.toString() ?? '';
                                            if (avatarUrl.isNotEmpty) {
                                              return CachedNetworkImage(
                                                imageUrl: avatarUrl,
                                                cacheKey: avatarPath,
                                                fit: BoxFit.cover,
                                                fadeInDuration: Duration.zero,
                                                errorWidget: (_, __, ___) => _buildInitialAvatar(name, index),
                                              );
                                            }
                                            return _buildInitialAvatar(name, index);
                                          }(),
                                        ),
                                      ),
                                      SizedBox(width: width / 30),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            contact['name'] ?? '',
                                            style: const TextStyle(
                                                fontSize: 16,
                                                color: Color(0xFF182974),
                                                fontFamily: 'Gilroy Bold'),
                                          ),
                                          SizedBox(height: height / 200),
                                          Row(
                                            children: [
                                              Text(
                                                contact['phone'] ?? '',
                                                style: const TextStyle(
                                                    fontSize: 14,
                                                    color: Color(0xFF3567A9),
                                                    fontFamily: 'Gilroy Medium'),
                                              ),
                                              if (contact['is_modipay_user'] == true) ...[
                                                const SizedBox(width: 6),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFF43A047),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: const Text(
                                                    'Modipay',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      color: Colors.white,
                                                      fontFamily: 'Gilroy Bold',
                                                    ),
                                                  ),
                                                ),
                                              ],
                                              if (contact['is_modipay_user'] != true) ...[
                                                const SizedBox(width: 6),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFFF9800),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: const Text(
                                                    'Non-Modipay',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      color: Colors.white,
                                                      fontFamily: 'Gilroy Bold',
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
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
                                              : const Color(0xFF182974),
                                        ),
                                      ),
                                      SizedBox(width: width / 20),
                                    ],
                                  ),
                                ),
                              ),
                              Divider(
                                thickness: 1,
                                color: const Color(0xFF3567A9).withOpacity(0.15),
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

