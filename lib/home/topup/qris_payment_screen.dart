import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../utils/colornotifire.dart';
import '../../utils/media.dart';

/// QRIS payment screen powered by OnixPayz.
///
/// Flow:
/// 1. On open, call `POST /api/topups` with the requested amount.
/// 2. Render the returned `qris_string` as a QR code and start a countdown
///    based on `expires_at`.
/// 3. Poll `GET /api/topups/{id}/status` every 5 seconds. The webhook is
///    the primary settlement path; polling is just to refresh the UI.
class QrisPaymentScreen extends StatefulWidget {
  final int amount;

  const QrisPaymentScreen({Key? key, required this.amount}) : super(key: key);

  @override
  State<QrisPaymentScreen> createState() => _QrisPaymentScreenState();
}

class _QrisPaymentScreenState extends State<QrisPaymentScreen> {
  late ColorNotifire notifire;
  final _currencyFormat = NumberFormat('#,###', 'id_ID');

  bool _isLoading = true;
  String? _error;
  String? _qrContent;
  int? _topupId;
  int _remainingSeconds = 0;
  Timer? _countdownTimer;
  Timer? _pollTimer;
  bool _isPaid = false;

  @override
  void initState() {
    super.initState();
    _generateQris();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _generateQris() async {
    try {
      final response = await ApiService.createTopup(widget.amount);
      if (!mounted) return;

      if (response['status'] == 'success') {
        final data = Map<String, dynamic>.from(response['data'] ?? {});
        final qrContent = data['qris_string']?.toString();
        final topupId = data['topup_id'] is int
            ? data['topup_id'] as int
            : int.tryParse(data['topup_id']?.toString() ?? '');
        final remaining = _resolveRemainingSeconds(data);

        if (qrContent == null || qrContent.isEmpty || topupId == null) {
          setState(() {
            _error = 'Pembayaran gagal dibuat. Coba lagi.';
            _isLoading = false;
          });
          return;
        }

        setState(() {
          _qrContent = qrContent;
          _topupId = topupId;
          _remainingSeconds = remaining;
          _isLoading = false;
        });
        _startCountdown();
        _startPolling();
      } else {
        setState(() {
          _error = response['message']?.toString() ?? 'Gagal generate QRIS';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = ApiService.userFriendlyMessage(e, fallback: 'Gagal generate QRIS');
        _isLoading = false;
      });
    }
  }

  int _resolveRemainingSeconds(Map<String, dynamic> data) {
    final raw = data['expires_in_seconds'];
    if (raw is int && raw > 0) return raw;
    if (raw is num && raw > 0) return raw.toInt();
    final expiresAtStr = data['expires_at']?.toString();
    if (expiresAtStr != null && expiresAtStr.isNotEmpty) {
      final expiresAt = DateTime.tryParse(expiresAtStr);
      if (expiresAt != null) {
        final delta = expiresAt.difference(DateTime.now()).inSeconds;
        if (delta > 0) return delta;
      }
    }
    return 30 * 60;
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _remainingSeconds--);
      if (_remainingSeconds <= 0) {
        _countdownTimer?.cancel();
        _pollTimer?.cancel();
        if (!_isPaid) {
          setState(() => _error = 'QRIS sudah expired');
        }
      }
    });
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!mounted || _topupId == null || _isPaid) return;

      try {
        final response = await ApiService.checkTopupStatus(_topupId!);
        final status = (response['trx_status'] ?? '').toString().toUpperCase();

        if (status == 'PAID' && mounted) {
          _pollTimer?.cancel();
          _countdownTimer?.cancel();
          setState(() => _isPaid = true);
          Provider.of<AuthProvider>(context, listen: false).fetchProfile();
          _showSuccessDialog();
        } else if (status == 'EXPIRED' && mounted) {
          _pollTimer?.cancel();
          _countdownTimer?.cancel();
          setState(() => _error = 'QRIS sudah expired');
        }
      } catch (_) {}
    });
  }

  void _showSuccessDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 60),
            const SizedBox(height: 16),
            const Text(
              'Pembayaran Berhasil',
              style: TextStyle(fontFamily: 'Gilroy Bold', fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              'Saldo Anda telah ditambahkan Rp ${_currencyFormat.format(widget.amount)}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Gilroy Medium',
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              child: const Text(
                'OK',
                style: TextStyle(fontFamily: 'Gilroy Bold', fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String get _formattedTime {
    final safe = _remainingSeconds < 0 ? 0 : _remainingSeconds;
    final minutes = safe ~/ 60;
    final seconds = safe % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    height = MediaQuery.of(context).size.height;
    width = MediaQuery.of(context).size.width;
    notifire = Provider.of<ColorNotifire>(context, listen: true);
    final blueColor = notifire.getbluecolor as Color;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Padding(
            padding: EdgeInsets.all(12),
            child: Icon(Icons.arrow_back, color: Color(0xFF1A1A1A)),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Pembayaran QRIS',
          style: TextStyle(color: Color(0xFF1A1A1A), fontFamily: 'Gilroy Bold', fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: blueColor))
          : _error != null
              ? _buildErrorView(blueColor)
              : _buildQrisView(blueColor),
    );
  }

  Widget _buildQrisView(Color blueColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      child: Column(
        children: [
          Text(
            'Rp ${_currencyFormat.format(widget.amount)}',
            style: const TextStyle(
              color: Color(0xFF1A1A1A),
              fontFamily: 'Gilroy Bold',
              fontSize: 28,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Scan QR code di bawah untuk membayar',
            style: TextStyle(color: Colors.grey[500], fontFamily: 'Gilroy Medium', fontSize: 13),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.black.withOpacity(0.08)),
            ),
            child: Column(
              children: [
                if (_qrContent != null) ...[
                  QrImageView(
                    data: _qrContent!,
                    version: QrVersions.auto,
                    size: 280,
                    gapless: true,
                  ),
                  const SizedBox(height: 8),
                  Image.asset(
                    'images/nobu_logo.png',
                    height: 80,
                    fit: BoxFit.contain,
                  ),
                ],
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _remainingSeconds > 60
                        ? const Color(0xFFF0F4FF)
                        : const Color(0xFFFFF8E1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        size: 16,
                        color: _remainingSeconds > 60 ? blueColor : const Color(0xFFF59E0B),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Berlaku $_formattedTime',
                        style: TextStyle(
                          color: _remainingSeconds > 60 ? blueColor : const Color(0xFFF59E0B),
                          fontFamily: 'Gilroy Bold',
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F4FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: blueColor.withOpacity(0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cara Pembayaran:',
                  style: TextStyle(color: blueColor, fontFamily: 'Gilroy Bold', fontSize: 13),
                ),
                const SizedBox(height: 8),
                _stepItem('1. Buka aplikasi e-wallet atau mobile banking'),
                _stepItem('2. Pilih menu Scan QR / QRIS'),
                _stepItem('3. Scan QR code di atas'),
                _stepItem('4. Konfirmasi pembayaran'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.grey[700],
          fontFamily: 'Gilroy Medium',
          fontSize: 12,
          height: 1.4,
        ),
      ),
    );
  }

  Widget _buildErrorView(Color blueColor) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: width / 10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded, color: Colors.red[300], size: 60),
            const SizedBox(height: 16),
            Text(
              _error ?? 'Terjadi kesalahan',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Gilroy Medium',
                fontSize: 15,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: blueColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Text(
                  'Kembali',
                  style: TextStyle(color: Colors.white, fontFamily: 'Gilroy Bold', fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
