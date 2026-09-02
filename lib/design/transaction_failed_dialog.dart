// Desktop "Transaksi Gagal" popup: ditampilkan saat polling
// `PendingPpobService`/`TransactionPendingDialog` melihat transaction.status
// berubah jadi 'failed'. Backend sudah mengembalikan saldo otomatis untuk
// kasus ini (lihat ppob_pending_timeout_frontend_prompt.md di repo
// modiback) — dialog ini hanya menginformasikan, bukan menawarkan retry
// otomatis (retry harus lewat aksi eksplisit user memulai transaksi baru).
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../utils/color.dart';

class TransactionFailedDialog extends StatelessWidget {
  final String orderId;
  final String reason;

  const TransactionFailedDialog({
    super.key,
    required this.orderId,
    required this.reason,
  });

  static String reasonFromTransaction(Map<String, dynamic> transaction) {
    final rawNote = transaction['note'];
    Map<String, dynamic>? note;
    if (rawNote is Map) {
      note = Map<String, dynamic>.from(rawNote);
    } else if (rawNote is String && rawNote.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(rawNote);
        if (decoded is Map) note = Map<String, dynamic>.from(decoded);
      } catch (_) {
        // note bukan JSON valid — abaikan, pakai fallback di bawah.
      }
    }
    final reason = note?['fail_reason'] ?? note?['message'];
    return (reason ?? 'Transaksi tidak dapat diselesaikan oleh penyedia layanan.').toString();
  }

  static Future<void> show({
    required BuildContext context,
    required String orderId,
    required String reason,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => TransactionFailedDialog(orderId: orderId, reason: reason),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        width: 420,
        padding: const EdgeInsets.fromLTRB(28, 16, 28, 28),
        decoration: BoxDecoration(
          color: desktopSurfaceCard,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 32, offset: const Offset(0, 12)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                InkWell(
                  onTap: () => Navigator.of(context, rootNavigator: true).pop(),
                  borderRadius: BorderRadius.circular(20),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.close_rounded, size: 20, color: desktopTextSecondary),
                  ),
                ),
              ],
            ),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(color: desktopErrorRed.withValues(alpha: 0.1), shape: BoxShape.circle),
              alignment: Alignment.center,
              child: const Icon(Icons.close_rounded, color: desktopErrorRed, size: 34),
            ),
            const SizedBox(height: 14),
            Text(
              'Transaksi Gagal',
              style: GoogleFonts.hankenGrotesk(fontSize: 19, fontWeight: FontWeight.w800, color: desktopTextPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              reason,
              textAlign: TextAlign.center,
              style: GoogleFonts.hankenGrotesk(fontSize: 13, color: desktopTextSecondary, height: 1.4),
            ),
            const SizedBox(height: 4),
            Text(
              'Saldo Anda sudah dikembalikan secara otomatis.',
              textAlign: TextAlign.center,
              style: GoogleFonts.hankenGrotesk(fontSize: 12.5, fontWeight: FontWeight.w700, color: desktopSuccessFg),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: desktopErrorRed.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: desktopBorder.withValues(alpha: 0.6)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ID Transaksi', style: GoogleFonts.hankenGrotesk(fontSize: 11, color: desktopTextSecondary)),
                  const SizedBox(height: 2),
                  Text(
                    orderId,
                    style: GoogleFonts.hankenGrotesk(fontSize: 13, fontWeight: FontWeight.w700, color: desktopTextPrimary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: desktopPrimaryBtn,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  'Tutup',
                  style: GoogleFonts.hankenGrotesk(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
