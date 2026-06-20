import 'package:flutter/material.dart';
import 'package:modipay/widgets/desktop_title_wrapper.dart';

import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../utils/colornotifire.dart';
import '../../utils/media.dart';
import 'qris_customer_payment_screen.dart';

class QrisScanScreen extends StatefulWidget {
  const QrisScanScreen({Key? key}) : super(key: key);

  @override
  State<QrisScanScreen> createState() => _QrisScanScreenState();
}

class _QrisScanScreenState extends State<QrisScanScreen> {
  late ColorNotifire notifire;
  final MobileScannerController scannerController = MobileScannerController();
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _loadDarkMode();
  }

  Future<void> _loadDarkMode() async {
    final prefs = await SharedPreferences.getInstance();
    bool? prev = prefs.getBool("setIsDark");
    if (prev != null && mounted) {
      notifire.setIsDark = prev;
    }
  }

  void _handleQRCode(String qrCode) {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);

    // Validate if it looks like a QRIS code
    if (!_isValidQrisCode(qrCode)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kode QRIS tidak valid. Silakan coba lagi.'),
        ),
      );
      setState(() => _isProcessing = false);
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => QrisCustomerPaymentScreen(
          qrisCode: qrCode,
        ),
      ),
    ).then((_) {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    });
  }

  bool _isValidQrisCode(String code) {
    // QRIS codes should start with '00' and be between 40-250 characters
    if (code.isEmpty) return false;
    return code.startsWith('00') && code.length >= 40;
  }

  void _onManualQRInput() {
    final inputController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Masukkan Kode QRIS'),
        content: TextField(
          controller: inputController,
          decoration: const InputDecoration(
            hintText: 'Paste kode QRIS di sini...',
            border: OutlineInputBorder(),
          ),
          maxLines: null,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () {
              if (inputController.text.isNotEmpty) {
                Navigator.pop(ctx);
                _handleQRCode(inputController.text.trim());
              }
            },
            child: const Text('Lanjutkan'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    notifire = Provider.of<ColorNotifire>(context, listen: true);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: DesktopTitleWrapper(child: const Text(
          'Scan QRIS',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Gilroy Bold',
          ),
        )),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on_outlined),
            onPressed: () => scannerController.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: scannerController,
            onDetect: (capture) {
              if (_isProcessing) return;

              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                final code = barcode.rawValue;
                if (code != null && code.isNotEmpty) {
                  _handleQRCode(code);
                  break;
                }
              }
            },
            errorBuilder: (context, error) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Error kamera: $error',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _onManualQRInput,
                      icon: const Icon(Icons.text_fields),
                      label: const Text('Input Manual'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          // Scan frame overlay
          CustomPaint(
            painter: ScanFramePainter(),
            size: Size.infinite,
          ),
          // Bottom controls
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.symmetric(
                vertical: 32,
                horizontal: 20,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.8),
                  ],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Arahkan kamera ke kode QRIS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: height / 50,
                      fontFamily: 'Gilroy Medium',
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  GestureDetector(
                    onTap: _onManualQRInput,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.5),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.text_fields,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Input Manual',
                            style: TextStyle(
                              color: Colors.white,
                              fontFamily: 'Gilroy Medium',
                              fontSize: height / 60,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ScanFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final Offset center = Offset(size.width / 2, size.height / 2);
    final double squareSize = 250;

    // Draw square frame
    final Rect rect = Rect.fromCenter(
      center: center,
      width: squareSize,
      height: squareSize,
    );
    canvas.drawRect(rect, paint);

    // Draw corners highlight
    final Paint cornerPaint = Paint()
      ..color = Colors.greenAccent
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;

    const double cornerLength = 30;

    // Top-left corner
    canvas.drawLine(
      Offset(rect.left, rect.top),
      Offset(rect.left + cornerLength, rect.top),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(rect.left, rect.top),
      Offset(rect.left, rect.top + cornerLength),
      cornerPaint,
    );

    // Top-right corner
    canvas.drawLine(
      Offset(rect.right, rect.top),
      Offset(rect.right - cornerLength, rect.top),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(rect.right, rect.top),
      Offset(rect.right, rect.top + cornerLength),
      cornerPaint,
    );

    // Bottom-left corner
    canvas.drawLine(
      Offset(rect.left, rect.bottom),
      Offset(rect.left + cornerLength, rect.bottom),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(rect.left, rect.bottom),
      Offset(rect.left, rect.bottom - cornerLength),
      cornerPaint,
    );

    // Bottom-right corner
    canvas.drawLine(
      Offset(rect.right, rect.bottom),
      Offset(rect.right - cornerLength, rect.bottom),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(rect.right, rect.bottom),
      Offset(rect.right, rect.bottom - cornerLength),
      cornerPaint,
    );

    // Draw semi-transparent overlay outside frame
    final Paint overlayPaint = Paint()..color = Colors.black.withOpacity(0.5);

    // Top
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, rect.top),
      overlayPaint,
    );

    // Bottom
    canvas.drawRect(
      Rect.fromLTWH(0, rect.bottom, size.width, size.height - rect.bottom),
      overlayPaint,
    );

    // Left
    canvas.drawRect(
      Rect.fromLTWH(0, rect.top, rect.left, squareSize),
      overlayPaint,
    );

    // Right
    canvas.drawRect(
      Rect.fromLTWH(rect.right, rect.top, size.width - rect.right, squareSize),
      overlayPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
