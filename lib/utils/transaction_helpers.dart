import 'dart:convert';

/// Hitung total efektif dari sebuah transaksi.
///
/// Untuk transaksi e-wallet bebas nominal & beberapa produk PPOB lain,
/// `tx['amount']` dari list endpoint kadang sudah jadi total provider
/// (mis. 10.850 untuk GoPay 10rb), bukan saldo dipotong sesungguhnya
/// (= nominal user + admin panel). Kalau `note` JSON menyimpan field
/// `nominal` + `admin` valid, pakai itu sebagai total yang benar.
///
/// Untuk transaksi yang `note` tidak punya field tsb (mis. pulsa fixed,
/// transfer bank yang `note.total` sudah benar), fall-back ke
/// `tx['amount']` apa adanya.
double effectiveTransactionTotal(Map<String, dynamic> tx) {
  final amount = double.tryParse(tx['amount']?.toString() ?? '0') ?? 0;

  Map<String, dynamic>? note;
  final rawNote = tx['note'];
  if (rawNote is Map) {
    note = Map<String, dynamic>.from(rawNote);
  } else if (rawNote is String && rawNote.isNotEmpty) {
    try {
      final decoded = jsonDecode(rawNote);
      if (decoded is Map) {
        note = Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}
  }
  if (note == null) return amount;

  double parseNum(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) {
      return double.tryParse(v.replaceAll(',', '').trim()) ?? 0.0;
    }
    return 0.0;
  }

  final notedNominal = parseNum(note['nominal']);
  final notedAdmin = parseNum(note['admin']);
  if (notedNominal > 0 && notedAdmin > 0) {
    return notedNominal + notedAdmin;
  }

  // Untuk transfer bank: note.total = saldo dipotong (nominal + admin
  // panel), itu yang valid. Kalau note.total ada tapi note.admin tidak,
  // jangan pakai note.total karena bisa jadi total provider.
  // Cek: ada `account_number` (transfer bank) → note.total valid.
  final isBankTransfer = note['account_number'] != null;
  final notedTotal = parseNum(note['total']);
  if (isBankTransfer && notedTotal > 0) {
    return notedTotal;
  }

  return amount;
}
