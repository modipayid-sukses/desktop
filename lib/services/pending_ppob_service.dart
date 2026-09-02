import 'dart:async';

import 'package:flutter/foundation.dart';

import 'api_service.dart';

enum PendingPpobStatus { pending, contactCs, completed, failed }

class PendingPpobEntry {
  final String orderId;
  Map<String, dynamic> transaction;
  int pendingMinutes;
  int pendingTimeoutMinutes;
  PendingPpobStatus status;

  PendingPpobEntry({
    required this.orderId,
    required this.transaction,
    this.pendingMinutes = 0,
    this.pendingTimeoutMinutes = 10,
    this.status = PendingPpobStatus.pending,
  });
}

/// Melacak transaksi PPOB yang backend masih memprosesnya secara async
/// (status `pending` dari `POST /ppob/purchase` atau `/loketbayar/purchase`)
/// dan mem-polling `POST /ppob/check-status` sampai selesai, LEPAS dari
/// layar/dialog mana yang sedang dibuka — supaya kasir tetap bisa berpindah
/// layar atau memulai transaksi lain sementara ini jalan di background.
/// Lihat ppob_pending_timeout_frontend_prompt.md (repo modiback) untuk
/// kontrak API lengkapnya.
///
/// Didaftarkan sebagai singleton lewat `ChangeNotifierProvider` di
/// `main.dart` (bukan dibuat per-screen) supaya polling-nya tidak ikut mati
/// saat user pindah halaman/menutup dialog.
class PendingPpobService extends ChangeNotifier {
  PendingPpobService._();

  /// Singleton, dipakai lewat `ChangeNotifierProvider.value` di main.dart
  /// (untuk didengarkan widget) dan diakses langsung secara statis dari
  /// tempat yang tidak punya BuildContext, misalnya AuthProvider setelah
  /// login/auto-login berhasil — meniru pola `ApiService.unauthorizedHandler`
  /// yang sudah dipakai di codebase ini.
  static final PendingPpobService instance = PendingPpobService._();

  final Map<String, PendingPpobEntry> _entries = {};
  final Map<String, Timer> _timers = {};

  PendingPpobEntry? entryFor(String orderId) => _entries[orderId];

  bool isTracking(String orderId) => _timers.containsKey(orderId);

  List<PendingPpobEntry> get activeEntries => _entries.values
      .where((e) => e.status == PendingPpobStatus.pending || e.status == PendingPpobStatus.contactCs)
      .toList(growable: false);

  /// Mulai (atau lanjutkan) polling untuk [orderId]. Aman dipanggil
  /// berkali-kali — panggilan berikutnya untuk order_id yang sama diabaikan
  /// selama polling-nya masih berjalan.
  void track(String orderId, {Map<String, dynamic>? initialTransaction}) {
    if (orderId.isEmpty || _timers.containsKey(orderId)) return;

    _entries[orderId] = PendingPpobEntry(
      orderId: orderId,
      transaction: initialTransaction ?? _entries[orderId]?.transaction ?? {'order_id': orderId, 'status': 'pending'},
    );
    notifyListeners();
    _scheduleNext(orderId, const Duration(seconds: 3));
  }

  void _scheduleNext(String orderId, Duration delay) {
    _timers[orderId]?.cancel();
    _timers[orderId] = Timer(delay, () => _poll(orderId));
  }

  Future<void> _poll(String orderId) async {
    final entry = _entries[orderId];
    if (entry == null) return;

    try {
      final response = await ApiService.checkPpobStatus(orderId: orderId);
      final data = response['data'] is Map ? Map<String, dynamic>.from(response['data'] as Map) : <String, dynamic>{};
      final tx = data['transaction'] is Map ? Map<String, dynamic>.from(data['transaction'] as Map) : entry.transaction;
      final status = (tx['status'] ?? 'pending').toString();
      final showContactCs = data['show_contact_cs'] == true;

      entry
        ..transaction = tx
        ..pendingMinutes = (data['pending_minutes'] as num?)?.toInt() ?? entry.pendingMinutes
        ..pendingTimeoutMinutes = (data['pending_timeout_minutes'] as num?)?.toInt() ?? entry.pendingTimeoutMinutes;

      if (status == 'completed') {
        entry.status = PendingPpobStatus.completed;
        _stopPolling(orderId);
      } else if (status == 'failed') {
        entry.status = PendingPpobStatus.failed;
        _stopPolling(orderId);
      } else {
        // Tetap pending di backend — JANGAN treat show_contact_cs sebagai
        // gagal, dan JANGAN berhenti polling (lihat dokumentasi prompt).
        entry.status = showContactCs ? PendingPpobStatus.contactCs : PendingPpobStatus.pending;
        _scheduleNext(orderId, _nextDelay(entry));
      }
      notifyListeners();
    } catch (_) {
      // Network hiccup — jangan pindah ke state gagal hanya karena satu
      // polling gagal terkirim, coba lagi di interval berikutnya.
      _scheduleNext(orderId, _nextDelay(entry));
    }
  }

  Duration _nextDelay(PendingPpobEntry entry) {
    if (entry.status == PendingPpobStatus.contactCs) {
      return const Duration(seconds: 25);
    }
    // Backoff ringan: 5 detik dulu, naik ke 10 detik setelah menit pertama.
    return entry.pendingMinutes < 1 ? const Duration(seconds: 5) : const Duration(seconds: 10);
  }

  void _stopPolling(String orderId) {
    _timers[orderId]?.cancel();
    _timers.remove(orderId);
  }

  /// Dipanggil UI setelah selesai menampilkan hasil akhir (sukses/gagal)
  /// untuk [orderId], supaya entry-nya tidak menumpuk selamanya di memori.
  void dismiss(String orderId) {
    _stopPolling(orderId);
    _entries.remove(orderId);
    notifyListeners();
  }

  /// Dipanggil sekali saat app start (lihat main.dart) — ambil transaksi
  /// yang statusnya masih `pending` dari riwayat lalu lanjutkan polling-nya,
  /// supaya transaksi pending tidak "hilang" dari pandangan user hanya
  /// karena app di-restart/reload.
  Future<void> resumePendingFromHistory() async {
    try {
      final response = await ApiService.getTransactions(page: 1);
      final list = response['data'] is List ? response['data'] as List : const [];
      for (final item in list) {
        if (item is! Map) continue;
        final tx = Map<String, dynamic>.from(item);
        if ((tx['status'] ?? '').toString() != 'pending') continue;
        final orderId = (tx['order_id'] ?? '').toString();
        if (orderId.isEmpty) continue;
        track(orderId, initialTransaction: tx);
      }
    } catch (_) {
      // Best-effort — jangan blokir startup app kalau ini gagal.
    }
  }

  @override
  void dispose() {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
    super.dispose();
  }
}
