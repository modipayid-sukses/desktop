import 'package:pdf/pdf.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ukuran kertas yang tersedia saat mencetak struk.
enum ReceiptPaperSize { mm58, mm80, a4, letter }

extension ReceiptPaperSizeX on ReceiptPaperSize {
  String get label {
    switch (this) {
      case ReceiptPaperSize.mm58:
        return '58mm (Thermal)';
      case ReceiptPaperSize.mm80:
        return '80mm (Thermal)';
      case ReceiptPaperSize.a4:
        return 'A4';
      case ReceiptPaperSize.letter:
        return 'Letter';
    }
  }

  PdfPageFormat get pdfPageFormat {
    switch (this) {
      case ReceiptPaperSize.mm58:
        return PdfPageFormat.roll57;
      case ReceiptPaperSize.mm80:
        return PdfPageFormat.roll80;
      case ReceiptPaperSize.a4:
        return PdfPageFormat.a4;
      case ReceiptPaperSize.letter:
        return PdfPageFormat.letter;
    }
  }
}

/// Menyimpan/memuat pilihan ukuran kertas terakhir yang dipakai user,
/// supaya tidak perlu memilih ulang setiap kali mencetak struk.
class ReceiptPaperSizeService {
  static const _key = 'receipt_paper_size';

  static Future<ReceiptPaperSize> loadPreferred() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    return ReceiptPaperSize.values.firstWhere(
      (e) => e.name == saved,
      orElse: () => ReceiptPaperSize.mm80,
    );
  }

  static Future<void> savePreferred(ReceiptPaperSize size) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, size.name);
  }
}
