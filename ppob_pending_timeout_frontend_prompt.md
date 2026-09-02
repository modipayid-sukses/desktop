# Prompt: PPOB pending/loading state — desktop app

Tempel prompt di bawah ini ke tool/agent yang mengerjakan frontend desktop (Electron/dsb) untuk
mengimplementasikan perilaku "tunggu biller" pada transaksi PPOB.

---

## Konteks

Backend ModiPay sudah diubah supaya transaksi PPOB (pulsa, token PLN, PDAM, BPJS, game top-up,
e-money, e-toll — lewat `POST /api/ppob/purchase` dan `POST /api/ppob/purchase-postpaid`) TIDAK
langsung sukses/gagal dalam satu response. Alurnya:

1. User submit pembelian → backend langsung balas `202`-style sukses ("Pembelian sedang diproses")
   dengan `order_id`, transaksi berstatus `pending`. Backend baru menghubungi biller (Digiflazz /
   Loketbayar) secara async setelah response ini dikirim.
2. Biller biasanya merespon dalam hitungan detik, tapi BISA butuh waktu lebih lama (retry
   otomatis di backend bisa berlangsung sampai puluhan menit untuk kasus tertentu).
3. Backend punya batas waktu wajar (default **10 menit**, lihat `pending_timeout_minutes` di
   response) — setelah itu status TETAP `pending` (saldo TIDAK di-refund otomatis, karena bisa saja
   biller sebenarnya berhasil memprosesnya), tapi UI harus berhenti menampilkan "loading" dan
   mengarahkan user untuk menghubungi CS.
4. Selama transaksi untuk `customer_no` yang sama masih `pending`, backend MENOLAK percobaan
   pembelian baru untuk `customer_no` itu (HTTP 429, `code: "transaction_in_progress"`) — supaya
   tidak ada ref_id/transaksi baru yang tercipta menumpuk di atas transaksi lama yang masih
   diproses biller. Transaksi lain (customer_no berbeda, produk berbeda) TIDAK terpengaruh dan
   boleh tetap diproses seperti biasa secara paralel.

Tugas Anda: implementasikan state machine UI + polling di desktop app sesuai kontrak API di bawah.

## Kontrak API

### 1. Submit pembelian

`POST /api/ppob/purchase` atau `POST /api/ppob/purchase-postpaid`

Response sukses (transaksi mulai diproses):
```json
{
  "status": "success",
  "message": "Pembelian sedang diproses",
  "data": { "transaction": { "id": 123, "order_id": "PPOB-XXXX", "status": "pending", ... } }
}
```

Response ditolak karena transaksi sebelumnya untuk `customer_no` yang sama masih berjalan:
```json
{
  "message": "Transaksi untuk nomor pelanggan ini masih diproses. Mohon tunggu hingga selesai, atau cek status transaksi sebelumnya sebelum mencoba lagi.",
  "code": "transaction_in_progress"
}
```
HTTP status: `429`.

### 2. Cek status (dipakai untuk polling)

`POST /api/ppob/check-status`
```json
{ "order_id": "PPOB-XXXX" }
```

Response:
```json
{
  "status": "success",
  "data": {
    "transaction": { "id": 123, "order_id": "PPOB-XXXX", "status": "pending|completed|failed", ... },
    "pending_minutes": 3,
    "pending_timeout_minutes": 10,
    "show_contact_cs": false
  }
}
```
- `transaction.status`: `pending` (masih diproses) / `completed` (sukses, cek field token/sn dsb di
  `transaction.note` atau `transaction.provider_ref` sesuai produk) / `failed` (gagal, saldo sudah
  dikembalikan otomatis oleh backend).
- `pending_minutes`: sudah berapa menit transaksi ini pending.
- `pending_timeout_minutes`: ambang waktu dari backend (saat ini 10 menit, bisa berubah — SELALU
  pakai nilai dari response ini, jangan hardcode di frontend).
- `show_contact_cs`: `true` kalau `pending_minutes >= pending_timeout_minutes` DAN status masih
  `pending`. Ini sinyal untuk ganti tampilan ke "hubungi CS", TANPA berhenti polling — transaksi
  bisa saja tetap selesai sendiri (sukses/gagal) setelah ambang ini lewat, backend akan terus
  mencoba/menerima webhook di belakang layar.

## State machine yang harus diimplementasikan

```
[Idle] --submit--> [Loading/Pending] --poll tiap 5-10 detik--> ...
                        |
                        |-- transaction.status == 'completed' --> [Sukses] (tampilkan hasil, stop polling)
                        |-- transaction.status == 'failed'    --> [Gagal] (tampilkan alasan, stop polling)
                        |-- show_contact_cs == true            --> [Pending - Hubungi CS] (TETAP polling,
                        |                                          ganti UI, JANGAN stop)
                        '-- masih pending, show_contact_cs=false --> tetap [Loading/Pending]
```

### 1. Loading/Pending (0 – pending_timeout_minutes)
- Tampilkan spinner/loading di layar transaksi tsb, teks: "Transaksi sedang diproses..." (boleh
  tampilkan estimasi: "biasanya selesai dalam beberapa detik").
- Poll `POST /api/ppob/check-status` tiap **5–10 detik** (gunakan backoff ringan, mis. mulai 3
  detik lalu naik ke 10 detik, supaya tidak membebani server pada transaksi yang genuinely lambat).
- **Tidak memblokir bagian lain aplikasi** — kasir/operator tetap bisa buka layar lain, mulai
  transaksi PPOB baru untuk `customer_no`/produk berbeda, dsb. State pending ini hanya melekat ke
  transaksi/`order_id` tsb, bukan mengunci seluruh aplikasi.
- Kalau user mencoba submit ulang untuk `customer_no` YANG SAMA sebelum transaksi ini selesai:
  jangan buat request baru dari sisi klien juga (idealnya tombol submit untuk `customer_no` itu
  di-disable selama status pending) — tapi kalaupun request terkirim, backend akan menolak dengan
  429 `transaction_in_progress`; tampilkan pesan dari response tsb, JANGAN retry otomatis.

### 2. Pending - Hubungi CS (setelah pending_timeout_minutes terlampaui)
- Ganti tampilan (bukan error merah — ini bukan kegagalan, transaksi masih mungkin berhasil):
  - Icon/warna netral (kuning/abu, bukan merah)
  - Teks: "Transaksi masih diproses lebih lama dari biasanya. Saldo Anda TIDAK hilang. Jika belum
    selesai dalam beberapa saat, silakan hubungi CS dengan menyebutkan ID transaksi: `{order_id}`."
  - Tampilkan `order_id` dengan jelas (mudah di-copy) — ini yang dibutuhkan CS untuk menelusuri via
    admin panel/`TransactionAdviceService`.
  - Sediakan tombol/aksi kontak CS kalau desktop app punya integrasi (WhatsApp/telepon/tiket),
    kirim `order_id` otomatis ke channel tsb kalau memungkinkan.
- **Lanjutkan polling** (interval boleh diperlambat, mis. tiap 20–30 detik) — begitu status berubah
  jadi `completed`/`failed`, transisi ke state final seperti biasa.
- Layar/transaksi lain tetap tidak terpengaruh (sama seperti state Loading).

### 3. Sukses / Gagal (final)
- Stop polling untuk `order_id` ini.
- Sukses: tampilkan detail hasil (token/serial number/dll dari `transaction`), boleh cetak struk.
- Gagal: tampilkan alasan (dari `transaction.note.fail_reason` kalau tersedia), info bahwa saldo
  sudah otomatis dikembalikan.

## Hal yang HARUS dihindari

- **Jangan** membuat transaksi/ref_id baru untuk `customer_no` yang sama selama transaksi
  sebelumnya masih pending — ini persis akar masalah yang sedang diperbaiki (data tercatat di kita
  tapi tidak match dengan biller). Disable tombol submit / tampilkan status pending yang jelas
  alih-alih membiarkan user submit ulang.
- **Jangan** treat `show_contact_cs: true` sebagai kegagalan dan otomatis retry/submit ulang —
  itu akan membuat ref_id kedua menumpuk di atas yang pertama.
- **Jangan** stop polling saat masuk state "Hubungi CS" — transaksi bisa selesai sendiri kapan saja
  setelahnya.
- **Jangan** blokir UI/thread lain di aplikasi selama menunggu — user harus tetap bisa memproses
  transaksi lain yang tidak terkait.
- **Jangan** hardcode timeout 5/10 menit di kode — selalu pakai `pending_timeout_minutes` dari
  response backend supaya tetap sinkron kalau nilainya diubah di server.

## Ringkasan siklus polling yang disarankan

| Fase | Interval poll | Kondisi berhenti |
|---|---|---|
| 0 – pending_timeout_minutes | 5–10 detik | status jadi completed/failed |
| > pending_timeout_minutes ("Hubungi CS") | 20–30 detik | status jadi completed/failed, atau user menutup layar transaksi |

Kalau desktop app ditutup/reload saat transaksi masih pending: saat dibuka lagi, cek riwayat
transaksi user (list transaksi dengan status `pending`) dan lanjutkan polling untuk `order_id`
tsb — jangan biarkan transaksi pending "hilang" dari pandangan user hanya karena app di-restart.
