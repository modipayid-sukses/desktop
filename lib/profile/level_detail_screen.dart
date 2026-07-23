import 'package:flutter/material.dart';
import 'package:modipay/widgets/desktop_title_wrapper.dart';

import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../utils/colornotifire.dart';
import '../utils/media.dart';
import 'kyc_screen.dart';

class LevelDetailScreen extends StatefulWidget {
  const LevelDetailScreen({Key? key}) : super(key: key);

  @override
  State<LevelDetailScreen> createState() => _LevelDetailScreenState();
}

class _LevelDetailScreenState extends State<LevelDetailScreen> {
  late ColorNotifire notifire;
  bool _isLoading = true;
  Map<String, dynamic>? _data;
  final _currencyFormat = NumberFormat('#,###', 'id_ID');

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final response = await ApiService.getLevelDetail();
      if (mounted && response['status'] == 'success') {
        setState(() {
          _data = response['data'];
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _levelColor(String level) {
    switch (level.toLowerCase()) {
      case 'gold':
        return const Color(0xFFD4A017);
      case 'platinum':
        return const Color(0xFF8C9EAF);
      default:
        return const Color(0xFFCD7F32);
    }
  }

  IconData _levelIcon(String level) {
    switch (level.toLowerCase()) {
      case 'gold':
        return Icons.workspace_premium;
      case 'platinum':
        return Icons.diamond_outlined;
      default:
        return Icons.shield_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    notifire = Provider.of<ColorNotifire>(context, listen: true);
    final auth = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: notifire.getprimerycolor,
      appBar: AppBar(
        backgroundColor: notifire.getprimerycolor,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Icon(Icons.arrow_back, color: notifire.getdarkscolor),
        ),
        title: DesktopTitleWrapper(child: Text(
          'Level Keanggotaan',
          style: TextStyle(
            color: notifire.getdarkscolor,
            fontSize: height / 42,
            fontFamily: 'Gilroy Bold',
          ),
        )),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _data == null
              ? Center(
                  child: Text(
                    'Gagal memuat data',
                    style: TextStyle(
                      color: notifire.getdarkgreycolor,
                      fontFamily: 'Gilroy Medium',
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: width / 20, vertical: width / 30),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Current level - icon + text standalone (no card bg)
                      _buildCurrentLevel(auth),
                      SizedBox(height: height / 25),
                      // Coins
                      _buildCoinsRow(auth),
                      SizedBox(height: height / 25),
                      // Progress
                      _buildProgress(),
                      SizedBox(height: height / 25),
                      // All levels
                      Text(
                        'Semua Level',
                        style: TextStyle(
                          color: notifire.getdarkscolor,
                          fontSize: height / 45,
                          fontFamily: 'Gilroy Bold',
                        ),
                      ),
                      SizedBox(height: height / 50),
                      ..._buildLevelList(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildCurrentLevel(AuthProvider auth) {
    final currentLevel = _data!['current_level'] ?? 'bronze';
    final color = _levelColor(currentLevel);

    return Center(
      child: Column(
        children: [
          Icon(_levelIcon(currentLevel), color: color, size: 48),
          const SizedBox(height: 8),
          Text(
            currentLevel.toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: height / 28,
              fontFamily: 'Gilroy Bold',
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            auth.userName,
            style: TextStyle(
              color: notifire.getdarkgreycolor,
              fontSize: height / 50,
              fontFamily: 'Gilroy Medium',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoinsRow(AuthProvider auth) {
    return Row(
      children: [
        const Icon(Icons.monetization_on, color: Color(0xFFFFB300), size: 22),
        const SizedBox(width: 8),
        Text(
          '${auth.userCoins}',
          style: TextStyle(
            color: notifire.getdarkscolor,
            fontSize: height / 42,
            fontFamily: 'Gilroy Bold',
          ),
        ),
        const SizedBox(width: 6),
        Text(
          'Koin',
          style: TextStyle(
            color: notifire.getdarkgreycolor,
            fontSize: height / 52,
            fontFamily: 'Gilroy Medium',
          ),
        ),
      ],
    );
  }

  Widget _buildProgress() {
    final currentLevel = _data!['current_level'] ?? 'bronze';
    final totalTopup = (_data!['total_topup'] as num?)?.toDouble() ?? 0;
    final kycVerified = _data!['kyc_verified'] == true;

    String? nextLevel;
    double? nextTarget;
    if (currentLevel == 'bronze') {
      nextLevel = 'Gold';
      nextTarget = 500000;
    } else if (currentLevel == 'gold') {
      nextLevel = 'Platinum';
      nextTarget = 2500000;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Progress',
          style: TextStyle(
            color: notifire.getdarkscolor,
            fontSize: height / 45,
            fontFamily: 'Gilroy Bold',
          ),
        ),
        SizedBox(height: height / 60),
        // Total topup row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Total Top Up',
              style: TextStyle(
                color: notifire.getdarkgreycolor,
                fontSize: height / 55,
                fontFamily: 'Gilroy Medium',
              ),
            ),
            Text(
              'Rp ${_currencyFormat.format(totalTopup.toInt())}',
              style: TextStyle(
                color: notifire.getdarkscolor,
                fontSize: height / 55,
                fontFamily: 'Gilroy Bold',
              ),
            ),
          ],
        ),
        SizedBox(height: height / 70),
        // KYC row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Verifikasi KYC',
              style: TextStyle(
                color: notifire.getdarkgreycolor,
                fontSize: height / 55,
                fontFamily: 'Gilroy Medium',
              ),
            ),
            GestureDetector(
              onTap: !kycVerified
                  ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => const KycScreen()))
                  : null,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    kycVerified ? 'Terverifikasi' : 'Belum',
                    style: TextStyle(
                      color: kycVerified ? const Color(0xFF4CAF50) : const Color(0xFFFF9800),
                      fontSize: height / 55,
                      fontFamily: 'Gilroy Bold',
                    ),
                  ),
                  if (!kycVerified) ...[
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right, color: const Color(0xFFFF9800), size: 16),
                  ],
                ],
              ),
            ),
          ],
        ),
        if (nextLevel != null && nextTarget != null) ...[
          SizedBox(height: height / 40),
          Divider(color: notifire.getdarkgreycolor.withOpacity(0.1), height: 1),
          SizedBox(height: height / 40),
          Text(
            'Menuju $nextLevel',
            style: TextStyle(
              color: notifire.getdarkscolor,
              fontSize: height / 50,
              fontFamily: 'Gilroy Bold',
            ),
          ),
          SizedBox(height: height / 60),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (totalTopup / nextTarget).clamp(0.0, 1.0),
              backgroundColor: notifire.getdarkgreycolor.withOpacity(0.08),
              valueColor: AlwaysStoppedAnimation<Color>(_levelColor(nextLevel.toLowerCase())),
              minHeight: 6,
            ),
          ),
          SizedBox(height: height / 80),
          Text(
            'Rp ${_currencyFormat.format(totalTopup.toInt())} / Rp ${_currencyFormat.format(nextTarget.toInt())}',
            style: TextStyle(
              color: notifire.getdarkgreycolor,
              fontSize: height / 60,
              fontFamily: 'Gilroy Medium',
            ),
          ),
          if (!kycVerified) ...[
            SizedBox(height: height / 60),
            Row(
              children: [
                Icon(Icons.info_outline, color: const Color(0xFFFF9800), size: 14),
                const SizedBox(width: 6),
                Text(
                  'Verifikasi KYC diperlukan untuk naik level',
                  style: TextStyle(
                    color: const Color(0xFFFF9800),
                    fontSize: height / 62,
                    fontFamily: 'Gilroy Medium',
                  ),
                ),
              ],
            ),
          ],
        ],
        if (currentLevel == 'platinum') ...[
          SizedBox(height: height / 40),
          Divider(color: notifire.getdarkgreycolor.withOpacity(0.1), height: 1),
          SizedBox(height: height / 50),
          Row(
            children: [
              Icon(Icons.check_circle, color: const Color(0xFF4CAF50), size: 16),
              const SizedBox(width: 6),
              Text(
                'Level tertinggi tercapai',
                style: TextStyle(
                  color: const Color(0xFF4CAF50),
                  fontSize: height / 55,
                  fontFamily: 'Gilroy Bold',
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  List<Widget> _buildLevelList() {
    final levels = _data!['levels'] as Map<String, dynamic>;
    final currentLevel = _data!['current_level'] ?? 'bronze';
    final order = ['bronze', 'gold', 'platinum'];

    return order.map((key) {
      final level = levels[key] as Map<String, dynamic>;
      final isCurrent = key == currentLevel;
      final color = _levelColor(key);
      final benefits = List<String>.from(level['benefits'] ?? []);
      final minTopup = (level['min_topup'] as num?)?.toInt() ?? 0;
      final kycRequired = level['kyc_required'] == true;

      return Padding(
        padding: EdgeInsets.only(bottom: height / 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Level name row — standalone text, no card
            Row(
              children: [
                Icon(_levelIcon(key), color: color, size: 20),
                const SizedBox(width: 8),
                Text(
                  level['name'] ?? key.toUpperCase(),
                  style: TextStyle(
                    color: notifire.getdarkscolor,
                    fontSize: height / 45,
                    fontFamily: 'Gilroy Bold',
                  ),
                ),
                if (isCurrent) ...[
                  const SizedBox(width: 8),
                  Text(
                    '• Saat ini',
                    style: TextStyle(
                      color: color,
                      fontSize: height / 58,
                      fontFamily: 'Gilroy Bold',
                    ),
                  ),
                ],
              ],
            ),
            SizedBox(height: height / 80),
            // Requirements
            if (minTopup > 0 || kycRequired) ...[
              if (minTopup > 0)
                _infoRow(Icons.arrow_upward, 'Top up minimal Rp ${_currencyFormat.format(minTopup)}'),
              if (kycRequired)
                _infoRow(Icons.verified_user_outlined, 'Verifikasi KYC'),
              SizedBox(height: height / 100),
            ],
            // Benefits
            ...benefits.map((b) => _infoRow(Icons.check, b, color: color)),
            // Divider between levels
            SizedBox(height: height / 60),
            Divider(color: notifire.getdarkgreycolor.withOpacity(0.08), height: 1),
          ],
        ),
      );
    }).toList();
  }

  Widget _infoRow(IconData icon, String text, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4, left: 28),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color ?? notifire.getdarkgreycolor, size: 14),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: notifire.getdarkscolor.withOpacity(0.8),
                fontSize: height / 58,
                fontFamily: 'Gilroy Medium',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
