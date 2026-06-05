import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:modipay/bottombar/bottombar.dart';
import 'package:modipay/providers/auth_provider.dart';
import 'package:modipay/services/api_service.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../utils/media.dart';

class QrisScreen extends StatefulWidget {
  final String qrisString;
  final String? expiresAt;
  final int topupId;
  final int amount;

  const QrisScreen({
    Key? key,
    required this.qrisString,
    this.expiresAt,
    required this.topupId,
    required this.amount,
  }) : super(key: key);

  @override
  State<QrisScreen> createState() => _QrisScreenState();
}

class _QrisScreenState extends State<QrisScreen> {
  final GlobalKey _qrKey = GlobalKey();
  Timer? _pollTimer;
  bool _isCompleted = false;

  static const _blue = Color(0xff1565C0);
  static const _blueLight = Color(0xff42A5F5);
  static const _successGreen = Color(0xFF4CAF50);

  @override
  void initState() {
    super.initState();
    debugPrint('QrisScreen: qrisString="${widget.qrisString}", length=${widget.qrisString.length}');
    debugPrint('QrisScreen: topupId=${widget.topupId}, amount=${widget.amount}');
    debugPrint('QrisScreen: width=$width');
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (_isCompleted) return;
      try {
        final response = await ApiService.getTopupStatus(widget.topupId);
        final status = response['topup']?['status'];
        if (status == 'completed') {
          _pollTimer?.cancel();
          if (mounted) {
            setState(() => _isCompleted = true);
            Provider.of<AuthProvider>(context, listen: false).updateBalance();
          }
        } else if (status == 'failed' || status == 'expired') {
          _pollTimer?.cancel();
          if (mounted) {
            Fluttertoast.showToast(
              msg: status == 'expired' ? 'Pembayaran expired' : 'Pembayaran gagal',
            );
            Navigator.pop(context);
          }
        }
      } catch (_) {}
    });
  }

  Future<void> _downloadQr() async {
    bool granted = false;
    if (await Permission.photos.status.isGranted || await Permission.storage.status.isGranted) {
      granted = true;
    } else {
      final photos = await Permission.photos.request();
      if (photos.isGranted) {
        granted = true;
      } else {
        final storage = await Permission.storage.request();
        granted = storage.isGranted;
      }
    }
    if (!granted) {
      Fluttertoast.showToast(msg: 'Izin penyimpanan diperlukan');
      return;
    }
    try {
      final boundary = _qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final Uint8List pngBytes = byteData!.buffer.asUint8List();
      final result = await ImageGallerySaverPlus.saveImage(pngBytes, name: 'QRIS_${widget.topupId}');
      if (result['isSuccess'] == true) {
        Fluttertoast.showToast(msg: 'QR Code berhasil disimpan');
      } else {
        Fluttertoast.showToast(msg: 'Gagal menyimpan QR Code');
      }
    } catch (e) {
      Fluttertoast.showToast(msg: 'Gagal menyimpan QR Code');
    }
  }

  String _formatAmount(int amount) {
    final str = amount.toString();
    final result = StringBuffer();
    int count = 0;
    for (int i = str.length - 1; i >= 0; i--) {
      result.write(str[i]);
      count++;
      if (count % 3 == 0 && i > 0) result.write('.');
    }
    return result.toString().split('').reversed.join();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      color: _isCompleted ? _successGreen : _blue,
      child: Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            // App bar
            Padding(
              padding: EdgeInsets.symmetric(horizontal: width / 20, vertical: 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  const Expanded(
                    child: Text(
                      'Top Up',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'Gilroy Bold',
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                ],
              ),
            ),

            // Card content
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: width / 15),
                  child: Column(
                    children: [
                      const SizedBox(height: 10),
                      // White receipt card
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Column(
                          children: [
                            const SizedBox(height: 30),
                            // Status icon
                            _isCompleted ? _buildAnimatedSuccessIcon() : _buildPendingIcon(),
                            const SizedBox(height: 20),
                            // Title
                            _isCompleted
                                ? Column(
                                    children: [
                                        const Text(
                                          'Top Up Berhasil!',
                                          style: TextStyle(
                                            fontFamily: 'Gilroy Bold',
                                            fontSize: 22,
                                            color: Color(0xFF1A1A2E),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Saldo kamu telah bertambah',
                                          style: TextStyle(
                                            fontFamily: 'Gilroy Medium',
                                            fontSize: 14,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    )
                                : Column(
                                    children: [
                                      const Text(
                                        'Scan QR Code',
                                        style: TextStyle(
                                          fontFamily: 'Gilroy Bold',
                                          fontSize: 22,
                                          color: Color(0xFF1A1A2E),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Scan QRIS di bawah untuk top up',
                                        style: TextStyle(
                                          fontFamily: 'Gilroy Medium',
                                          fontSize: 14,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                            const SizedBox(height: 20),
                            // Amount
                            _isCompleted
                                ? Column(
                                    children: [
                                      Text(
                                        'Total Top Up',
                                        style: TextStyle(
                                          fontFamily: 'Gilroy Medium',
                                          fontSize: 13,
                                          color: Colors.grey[500],
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Rp ${_formatAmount(widget.amount)}',
                                        style: const TextStyle(
                                          fontFamily: 'Gilroy Bold',
                                          fontSize: 32,
                                          color: _successGreen,
                                        ),
                                      ),
                                    ],
                                  )
                                : Column(
                                    children: [
                                      Text(
                                        'Total Top Up',
                                        style: TextStyle(
                                          fontFamily: 'Gilroy Medium',
                                          fontSize: 13,
                                          color: Colors.grey[500],
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Rp ${_formatAmount(widget.amount)}',
                                        style: const TextStyle(
                                          fontFamily: 'Gilroy Bold',
                                          fontSize: 32,
                                          color: Color(0xFF1A1A2E),
                                        ),
                                      ),
                                    ],
                                  ),
                            const SizedBox(height: 20),
                            // Dashed divider
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              child: Row(
                                children: List.generate(
                                  30,
                                  (i) => Expanded(
                                    child: Container(
                                      height: 1.5,
                                      color: i.isEven ? Colors.grey[300] : Colors.transparent,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // QR Code (only when not completed)
                            if (!_isCompleted) ...[
                              RepaintBoundary(
                                key: _qrKey,
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.grey[200]!),
                                  ),
                                  child: SizedBox(
                                    width: MediaQuery.of(context).size.width * 0.5,
                                    height: MediaQuery.of(context).size.width * 0.5,
                                    child: QrImageView(
                                      data: widget.qrisString,
                                      version: QrVersions.auto,
                                      size: MediaQuery.of(context).size.width * 0.5,
                                      backgroundColor: Colors.white,
                                      eyeStyle: const QrEyeStyle(
                                        eyeShape: QrEyeShape.square,
                                        color: Color(0xff1565C0),
                                      ),
                                      dataModuleStyle: const QrDataModuleStyle(
                                        dataModuleShape: QrDataModuleShape.square,
                                        color: Color(0xFF1A1A2E),
                                      ),
                                      errorStateBuilder: (cxt, err) {
                                        debugPrint('QR Error: $err');
                                        return const Center(
                                          child: Text('QR Error', style: TextStyle(color: Colors.red)),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              // Waiting spinner
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    height: 16,
                                    width: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: _blueLight,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Menunggu pembayaran...',
                                    style: TextStyle(
                                      fontFamily: 'Gilroy Medium',
                                      fontSize: 13,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                              if (widget.expiresAt != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Berlaku sampai: ${widget.expiresAt}',
                                  style: TextStyle(
                                    fontFamily: 'Gilroy Medium',
                                    fontSize: 12,
                                    color: Colors.grey[400],
                                  ),
                                ),
                              ],
                            ],
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Buttons
                      if (!_isCompleted)
                        // Download QR button
                        GestureDetector(
                          onTap: _downloadQr,
                          child: Container(
                            height: 52,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: _blueLight,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.download_rounded, color: Colors.white, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Download QR Code',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontFamily: 'Gilroy Bold',
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      if (_isCompleted) ...[
                        Column(
                            children: [
                              // Done button
                              GestureDetector(
                                onTap: () {
                                  Navigator.pushAndRemoveUntil(
                                    context,
                                    MaterialPageRoute(builder: (_) => const Bottombar()),
                                    (route) => false,
                                  );
                                },
                                child: Container(
                                  height: 52,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: _successGreen,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Center(
                                    child: Text(
                                      'Kembali ke Beranda',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontFamily: 'Gilroy Bold',
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              // Top up more
                              GestureDetector(
                                onTap: () => Navigator.pop(context),
                                child: const Text(
                                  'Top up lagi',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontFamily: 'Gilroy Bold',
                                    fontSize: 14,
                                    decoration: TextDecoration.underline,
                                    decorationColor: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ),

            // Bottom scallop decoration
            SizedBox(
              height: 20,
              child: Row(
                children: List.generate(
                  (width / 16).ceil(),
                  (i) => Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: _isCompleted ? _successGreen : _blue,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildAnimatedSuccessIcon() {
    return Container(
      height: 80,
      width: 80,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: _successGreen,
      ),
      child: const Icon(Icons.check_rounded, color: Colors.white, size: 44),
    );
  }

  Widget _buildPendingIcon() {
    return Container(
      height: 80,
      width: 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.grey[100],
        border: Border.all(color: _blueLight, width: 4),
      ),
      child: Icon(Icons.qr_code_2, color: _blueLight, size: 40),
    );
  }
}
