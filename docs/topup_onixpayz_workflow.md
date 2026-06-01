# Top Up via OnixPayz QRIS — Workflow

Top up saldo ModiPay sekarang **QRIS-only** dan diproses oleh [OnixPayz](https://onixpayz.com/docs). Integrasi SiPay dan Duitku sudah sepenuhnya dihapus dari backend & aplikasi.

## Arsitektur

```
┌──────────────┐                       ┌──────────────────────┐                    ┌──────────────┐
│ Flutter App  │  POST /api/topups     │  Laravel Panel API   │  POST /pay/qris    │  OnixPayz    │
│              │ ─────────────────────▶│  (TopupController)   │ ──────────────────▶│  /api/v1     │
│              │ ◀──── data{qris} ─────│                      │ ◀──── qris_string ─│              │
│              │                       │                      │                    │              │
│  Render QR   │                       │                      │                    │              │
│  scan & bayar│                       │                      │                    │              │
│              │                       │                      │ ◀── webhook ───────│              │
│              │                       │  OnixPayz            │   payment.success  │              │
│              │  GET /topups/{id}/    │  WebhookController   │                    │              │
│              │  status (polling)     │  (saldo +=, tx log)  │                    │              │
└──────────────┘                       └──────────────────────┘                    └──────────────┘
```

## Flow Lengkap

1. **User** membuka layar Top Up (`TopupChannelScreen`) dari beranda/bottombar.
2. User memilih nominal cepat atau mengetik nominal manual (min Rp 10.000) lalu menekan **Lanjut Bayar**.
3. App mengarah ke `QrisPaymentScreen(amount: ...)`.
4. `QrisPaymentScreen.initState()` memanggil `ApiService.createTopup(amount)` → `POST /api/topups`.
5. **Laravel** (`TopupController::store`):
   - Validasi `amount >= 10000`.
   - Generate `external_id = TOPUP-XXXXXXXXXXXX`.
   - Panggil `OnixPayzService::createQrisPayment([...])` → `POST https://onixpayz.com/api/v1/pay` dengan API key di header `X-API-Key`. Endpoint `/pay` (umum) digunakan karena ia otomatis generate QRIS dinamis tanpa butuh QRIS statis di-upload merchant.
   - Simpan record di tabel `topups` dengan `status=pending`, `payment_method=QRIS_ONIXPAYZ`, `qris_string`, `expires_at`.
   - Return `{status, message, data: {topup_id, reference_id, amount, qris_string, payment_url, expires_at, expires_in_seconds}}`.
6. **App** menerima response, render `qris_string` sebagai QR code, mulai countdown `expires_in_seconds`, dan polling tiap 5 detik ke `GET /api/topups/{id}/status`.
7. **User** scan QR pakai e-wallet/m-banking dan menyelesaikan pembayaran.
8. **OnixPayz** mengirim webhook `payment.success` (signed dengan HMAC-SHA256 di header `X-NexPay-Signature`) ke `POST /api/callbacks/onixpayz`.
9. **Laravel** (`OnixPayzWebhookController::handle`):
   - Verifikasi signature via `OnixPayzService::verifySignature($rawBody, $signature)`.
   - Cari `Topup` berdasarkan `reference_id`.
   - `status='pending' → 'completed'`, `users.balance += amount`, `users.total_topup += amount`, recalculate level, buat record di tabel `transactions` (category=`topup`), kirim push notification.
10. **App** polling berikutnya menerima `trx_status: PAID`, menampilkan dialog "Pembayaran Berhasil" lalu pop kembali ke beranda.

Polling adalah **fallback**. Jalur utama settlement adalah webhook. Polling ada untuk UX (supaya layar QRIS otomatis menutup tanpa user perlu refresh).

## Endpoint API

### POST `/api/topups`
**Auth**: Bearer token, X-Device-Id (single login enforced).
**Body**: `{ "amount": 50000 }`

**Response**:
```json
{
  "status": "success",
  "message": "QRIS berhasil dibuat",
  "data": {
    "topup_id": 12,
    "reference_id": "TOPUP-ABCDEF123456",
    "amount": 50000,
    "qris_string": "00020101021226...",
    "payment_url": "https://onixpayz.com/p/NX-...",
    "expires_at": "2026-05-24T07:30:00+07:00",
    "expires_in_seconds": 1800
  }
}
```

### GET `/api/topups/{id}/status`
Polling endpoint. Mengembalikan status terakhir; bila masih pending, ikut memanggil OnixPayz `/pay/{id}` sekali untuk memastikan tidak ada webhook yang tertinggal.

**Response**:
```json
{
  "status": "success",
  "trx_status": "PAID",     // PENDING | PAID | EXPIRED | FAILED
  "amount": 50000,
  "paid_at": "2026-05-24T07:15:42+07:00"
}
```

### POST `/api/topups/check-pending`
Reconcile semua topup pending milik user. Cocok dipanggil saat app resume (user balik dari background, mungkin sempat bayar tapi webhook belum sempat ter-deliver).

### GET `/api/topups`
Daftar topup user (paginated, terbaru duluan).

### GET `/api/topups/{id}`
Detail topup tunggal.

### POST `/api/callbacks/onixpayz` (juga `/api/webhooks/onixpayz`)
Webhook handler. Headers yang diharapkan:
- `X-NexPay-Signature` — HMAC-SHA256 dari raw body.
- `X-NexPay-Event` — `payment.success` / `payment.failed` / `payment.expired`.

## Konfigurasi

### `.env` (server)
```
ONIXPAYZ_API_KEY=npk_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
ONIXPAYZ_WEBHOOK_SECRET=nps_xxxxxxxxxxxxxxxxxxxxxxxx
ONIXPAYZ_BASE_URL=https://onixpayz.com/api/v1
```

API key & webhook secret didapat dari [Dashboard OnixPayz → API Keys](https://onixpayz.com/api-keys).

### Webhook URL
Daftarkan URL berikut di Dashboard OnixPayz → Settings → Webhook URL:
```
https://panel.modipay.biz.id/api/callbacks/onixpayz
```

### QRIS Statis (opsional)
Endpoint `/pay/qris` mengkonversi QRIS statis merchant menjadi dinamis (nominal terembed) dan butuh setup tambahan: akun aktif + minimal 1 QRIS statis di-upload di Dashboard → QRIS Statis → QRIS Saya. **Saat ini kita tidak memakai endpoint ini** — kita pakai `/pay` umum yang langsung generate QRIS dinamis (Shopee Pay channel) tanpa setup tambahan.

Bila kamu ingin migrasi ke `/pay/qris` (misal supaya pakai QRIS milik sendiri), tinggal ganti `"{$this->baseUrl}/pay"` jadi `"{$this->baseUrl}/pay/qris"` di `OnixPayzService::createQrisPayment()`.

## File yang Berubah / Dihapus

### Backend (`/www/wwwroot/panel.modipay.biz.id/`)

**Diubah**:
- `app/Services/OnixPayzService.php` — disederhanakan, hanya menyediakan `createQrisPayment()`, `getPayment()`, `verifySignature()`. Auto-inject `callback_url` ke request.
- `app/Http/Controllers/Api/TopupController.php` — full rewrite. QRIS-only via OnixPayz. Method: `store`, `status`, `index`, `show`, `checkPending`.
- `app/Http/Controllers/Api/TransactionController.php` — disederhanakan, jadi read-only (`index`, `show`, `updateNote`). Method `channels`, `store`, `storeQris` dihapus.
- `app/Http/Controllers/Api/QrisMerchantController.php::createPayment` — DuitkuService → OnixPayzService.
- `app/Http/Controllers/Api/MerchantKycController.php::payBill` (cabang QRIS) — SipayService → OnixPayzService, payment_method jadi `QRIS_ONIXPAYZ_LIMIT`.
- `routes/api.php` — hapus route: `/transactions/channels`, `/transactions`, `/transactions/qris`, `/callbacks/duitku`, `/callbacks/duitku/return`, `/callbacks/sipay`, `/topups/payment-methods`, `/topups/sipay-qris`, `/topups/{id}/sipay-status`. Tambah `/topups/{id}/status`.
- `config/services.php` — hapus blok `sipay`, `duitku`.
- `.env` — hapus `SIPAY_*`, `DUITKU_*`.
- `resources/views/admin/settings/index.blade.php` — kartu Duitku diganti kartu OnixPayz.
- `resources/views/livewire/admin/topups/index.blade.php` — option filter `QRIS_SIPAY*` → `QRIS_ONIXPAYZ*`.

**Dihapus** (di-rename `.bak.removed` di server, bisa di-rm penuh kapan saja):
- `app/Services/SipayService.php`
- `app/Services/DuitkuService.php`
- `app/Http/Controllers/Api/SipayCallbackController.php`
- `app/Http/Controllers/Api/DuitkuCallbackController.php`

Backup file yang di-replace ada dengan suffix `.bak.onixpayz`.

### Flutter (`/Users/user/Desktop/modipay copy 2/`)

**Diubah**:
- `lib/services/api_service.dart` — hapus `topup`, `topupSipayQris`, `checkSipayStatus`, `getTopupPaymentMethods`. Tambah `createTopup(amount)` dan `checkTopupStatus(topupId)`.
- `lib/home/topup/topup_channel_screen.dart` — full rewrite. Hilangkan listing channel; sekarang langsung input nominal → tombol **Lanjut Bayar** → `QrisPaymentScreen`. Class name dipertahankan supaya call-site lain tidak perlu diubah.
- `lib/home/limit/bayar_tagihan_screen.dart` — `ApiService.checkSipayStatus` → `ApiService.checkTopupStatus`.

**Baru**:
- `lib/home/topup/qris_payment_screen.dart` — pengganti `sipay_qris_screen.dart` dengan endpoint baru.

**Dihapus**:
- `lib/home/topup/sipay_qris_screen.dart`
- `lib/home/topup/topupcard/topup.dart` (intermediary screen utk channel-specific input)
- `lib/home/topup/topup_payment_screen.dart` (untuk VA/redirect URL — tidak relevan lagi)

## Manual Verifikasi

```bash
# 1) Buat user dengan token (server side)
sudo -u www php artisan tinker --execute='$u=App\Models\User::firstOrCreate(["phone"=>"81000111222"],["name"=>"QA","pin"=>"1234"]);echo $u->createToken("qa")->plainTextToken;'

# 2) Create topup
curl -X POST https://panel.modipay.biz.id/api/topups \
  -H "Authorization: Bearer <TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{"amount":15000}'
# Expect: {"status":"success","data":{"qris_string":"...","topup_id":N,...}}
# Bila merchant OnixPayz belum aktif: {"status":"error","message":"Gagal membuat pembayaran. Coba lagi."}
# Cek log: tail storage/logs/laravel.log → "Merchant not registered or inactive"

# 3) Polling status
curl https://panel.modipay.biz.id/api/topups/<ID>/status \
  -H "Authorization: Bearer <TOKEN>"
# Expect: {"trx_status":"PENDING"} sampai user bayar atau expired

# 4) Simulasi webhook (testing only — pakai sandbox key)
# Lihat dokumentasi OnixPayz section "Simulasi Pembayaran" untuk endpoint
# POST /api/v1/pay/{id}/simulate dengan body {"status":"completed"}
```

## Status Akun OnixPayz Saat Ini

API key di `.env` sudah aktif dan endpoint `POST /pay` berfungsi: setiap topup baru menghasilkan QRIS dinamis (Shopee Pay channel) yang bisa langsung di-scan oleh user.
