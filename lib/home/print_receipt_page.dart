import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gobank/services/receipt_settings_service.dart';
import 'package:gobank/widgets/universal_receipt.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';

/// Halaman cetak struk: menampilkan layout struk thermal (UniversalReceipt)
/// dan menyediakan aksi share & simpan ke galeri.
class PrintReceiptPage extends StatefulWidget {
  final Map<String, dynamic> data;
  final bool autoDownload;

  const PrintReceiptPage({
    super.key,
    required this.data,
    this.autoDownload = false,
  });

  @override
  State<PrintReceiptPage> createState() => _PrintReceiptPageState();
}

class _PrintReceiptPageState extends State<PrintReceiptPage> {
  final GlobalKey _receiptKey = GlobalKey();
  Map<String, String> _receiptSettings = const {};
  bool _busy = false;
  bool _settingsLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await ReceiptSettingsService.load();
    if (!mounted) return;
    setState(() {
      _receiptSettings = settings;
      _settingsLoaded = true;
    });
    if (widget.autoDownload) {
      // Tunggu satu frame agar widget ter-render sebelum capture.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _saveToGallery();
      });
    }
  }

  Future<bool> _requestGalleryPermission() async {
    if (Platform.isIOS) {
      final status = await Permission.photos.request();
      return status.isGranted || status.isLimited;
    }
    if (Platform.isAndroid) {
      final photoStatus = await Permission.photos.request();
      if (photoStatus.isGranted || photoStatus.isLimited) return true;
      final storageStatus = await Permission.storage.request();
      return storageStatus.isGranted;
    }
    return true;
  }

  Future<Uint8List?> _captureBytes() async {
    try {
      final boundary = _receiptKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveToGallery() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final granted = await _requestGalleryPermission();
      if (!granted) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Izin penyimpanan ditolak')),
        );
        return;
      }
      final bytes = await _captureBytes();
      if (bytes == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal menyimpan struk')),
        );
        return;
      }
      final orderId = (widget.data['order_id'] ?? widget.data['id'] ??
              DateTime.now().millisecondsSinceEpoch)
          .toString();
      final result = await ImageGallerySaverPlus.saveImage(
        Uint8List.fromList(bytes),
        name: 'STRUK_$orderId',
      );
      if (!mounted) return;
      final ok = result is Map ? result['isSuccess'] == true : false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok
              ? 'Struk berhasil disimpan ke galeri'
              : 'Gagal menyimpan struk'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal menyimpan struk')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _shareReceipt() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final bytes = await _captureBytes();
      if (bytes == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal membagikan struk')),
        );
        return;
      }
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/receipt_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path)], text: 'Struk transaksi');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal membagikan struk')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE9ECEF),
      appBar: AppBar(
        backgroundColor: const Color(0xFF3F75B7),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Cetak Struk',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Gilroy Bold',
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Bagikan',
            onPressed: _busy ? null : _shareReceipt,
            icon: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.share_rounded, color: Colors.white),
          ),
        ],
      ),
      body: !_settingsLoaded
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 380),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: RepaintBoundary(
                        key: _receiptKey,
                        child: UniversalReceipt(
                          data: widget.data,
                          receiptSettings: _receiptSettings,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _shareReceipt,
                    icon: const Icon(Icons.share_rounded,
                        color: Color(0xFF3F75B7)),
                    label: const Text(
                      'Bagikan',
                      style: TextStyle(
                        fontFamily: 'Gilroy Bold',
                        fontSize: 15,
                        color: Color(0xFF3F75B7),
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(
                          color: Color(0xFF3F75B7), width: 1.5),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _busy ? null : _saveToGallery,
                    icon: const Icon(Icons.download_rounded,
                        color: Colors.white),
                    label: const Text(
                      'Simpan',
                      style: TextStyle(
                        fontFamily: 'Gilroy Bold',
                        fontSize: 15,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3F75B7),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
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
}
