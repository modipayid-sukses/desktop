# Single-Device Login — Workflow

Fitur ini memastikan satu akun ModiPay hanya bisa aktif di satu perangkat dalam satu waktu. Saat user login di perangkat baru, perangkat lama otomatis dipaksa logout.

## Arsitektur Singkat

```
┌──────────────┐                       ┌──────────────────────┐
│ Flutter App  │                       │  Laravel Panel API   │
│  (mobile)    │  ───── login ───────▶ │  panel.modipay.biz.id│
│              │  ◀──── token ───────  │                      │
│              │                       │                      │
│              │  ── X-Device-Id: ID ▶ │  device.bound        │
│              │     Bearer <token>    │  middleware          │
│              │  ◀── 200 / 401 ─────  │                      │
└──────────────┘                       └──────────────────────┘
```

## Aturan Inti

1. Setiap install Flutter punya `device_id` stabil (Android `id`, iOS `identifierForVendor`, fallback random) yang disimpan di `SharedPreferences`.
2. Saat login (`/login`, `/login-pin`, `/verify-otp` tipe login, `/register`):
   - App mengirim `device_id`, `device_name`, `device_platform`, `app_version` di body request.
   - Sama dengan empat header: `X-Device-Id`, `X-Device-Name`, `X-Device-Platform`, `X-App-Version` (di-set otomatis oleh `_headers()`).
   - Backend menyimpan info ini di kolom users dan, **bila device_id berbeda dari sebelumnya**, menghapus semua token Sanctum sebelumnya milik user.
3. Setiap request berikutnya wajib mengirim `X-Device-Id`. Middleware `device.bound` membandingkan dengan `users.device_id`. Mismatch → revoke token saat ini, return `401` dengan `error_code: device_mismatch`.
4. App menangkap `error_code: device_mismatch` lewat `unauthorizedHandler`, set flag `kickedByOtherDevice`, lalu menampilkan dialog informatif sebelum redirect ke layar login.

## Skenario

### A. Login pertama kali di Device A
1. User isi nomor + PIN, app POST `/api/login-pin` membawa device A.
2. Backend simpan `device_id=A`, kembalikan `token=A1`.
3. Semua request berikutnya mengirim `Authorization: Bearer A1` + `X-Device-Id: A`. Lolos middleware.

### B. User login di Device B (Device A masih hidup)
1. POST `/api/login-pin` membawa device B.
2. `recordDeviceInfo()` mendeteksi `users.device_id (=A) != B`, panggil `tokens()->delete()` → token A1 hilang dari DB.
3. Backend simpan `device_id=B`, kembalikan `token=B1`.
4. Device A: request berikutnya pakai token A1 yang sudah tidak ada di DB → Sanctum balas `401 Unauthenticated` (token tidak valid).
5. App di Device A menerima 401, `unauthorizedHandler` dipanggil, sesi lokal dibersihkan, user diredirect ke login.

### C. Token valid tapi dipakai di device beda (skenario spoof)
1. Penyerang mencuri token B1 tapi memakai device id berbeda.
2. Middleware `device.bound` mendeteksi `device_id` tidak match, revoke token B1, return `401 device_mismatch`.
3. Pengguna sah harus login ulang.

### D. User uninstall + reinstall di HP yang sama
1. Reinstall menghasilkan `device_id` baru (karena Android `id` mungkin berubah, atau fallback random regen).
2. Saat login lagi, ini diperlakukan sebagai device baru — token sebelumnya direvoke. Aman.

## File yang Disentuh

### Backend (`/www/wwwroot/panel.modipay.biz.id/`)

| File | Perubahan |
| --- | --- |
| `database/migrations/2026_05_24_000001_add_device_info_to_users_table.php` | Tambah kolom `device_name`, `device_platform`, `device_app_version`, `last_login_ip`, `last_login_at`. Sudah dijalankan. |
| `app/Models/User.php` | Tambahkan field di `Fillable` & cast `last_login_at`. |
| `app/Http/Controllers/Api/AuthController.php` | Helper `deviceId()` + `recordDeviceInfo()` yang menyimpan info device dan menghapus token lama saat device berganti. Dipanggil di `login`, `loginPin`, `verifyOtp` (tipe login), `register`. |
| `app/Http/Middleware/DeviceBoundMiddleware.php` | Sudah ada sebelumnya, sekarang juga return `error_code: device_mismatch` di body untuk dideteksi client. |
| `routes/api.php` | Group `auth:sanctum` ditambahi middleware `device.bound`. |
| `resources/views/admin/users/show.blade.php` | Tab Informasi user di admin panel: section baru **Perangkat & Sesi** (nama perangkat, platform, versi app, device id, login terakhir, IP). |

### Flutter (`/Users/user/Desktop/modipay copy 2/`)

| File | Perubahan |
| --- | --- |
| `lib/services/device_identity_service.dart` | Diperluas: simpan device name + platform OS, ekspos `metadata()` untuk auth API. |
| `lib/services/api_service.dart` | `_headers()` selalu sisipkan `X-Device-Id` / `X-Device-Name` / `X-Device-Platform` / `X-App-Version`. Helper `_withDevicePayload()` menyisipkan field device di body `login` / `loginWithPin` / `verifyOtp` / `register`. `unauthorizedHandler` sekarang menerima `errorCode`. |
| `lib/providers/auth_provider.dart` | Flag `kickedByOtherDevice` di-set saat handler menerima `error_code: device_mismatch`. Method `consumeKickedByOtherDevice()` untuk reset. |
| `lib/bottombar/bottombar.dart` | Saat `auth.isLoggedIn` jadi false dengan flag aktif, tampilkan dialog "Login dari Perangkat Lain" sebelum redirect ke `Login()`. |
| `lib/splashscreen.dart` | Setelah `loadToken()` kalau token ditolak karena device-mismatch, tampilkan dialog informatif sebelum lanjut ke alur normal. |

## Endpoint Reference

Semua endpoint auth menerima device info via body atau header. Header diutamakan saat keduanya ada.

```
POST /api/login
POST /api/login-pin
POST /api/verify-otp           (type=login akan trigger recordDeviceInfo)
POST /api/register

Header:
  X-Device-Id:        <opaque-string>
  X-Device-Name:      <human readable>
  X-Device-Platform:  android <ver> | ios <ver>
  X-App-Version:      <semver>

Body (alternative):
  device_id, device_name, device_platform, app_version
```

Semua endpoint protected (di group `auth:sanctum`):

```
Header:
  Authorization: Bearer <token>
  X-Device-Id:   <same id as during login>
```

Response saat device mismatch:

```json
HTTP/1.1 401 Unauthorized
{
  "message": "Akun ini sedang login di perangkat lain.",
  "error_code": "device_mismatch"
}
```

## Manual Test (curl)

Berhasil dijalankan:

```bash
# 1) Login Device A
curl -k -X POST https://panel.modipay.biz.id/api/login-pin \
  -H 'Content-Type: application/json' \
  -d '{"login":"81999000001","pin":"1234","device_id":"A","device_name":"Pixel 7","device_platform":"android 14","app_version":"1.0.1"}'
# → token=A1, user.device_id=A

# 2) Profile dari Device A (OK)
curl -k https://panel.modipay.biz.id/api/profile \
  -H 'Authorization: Bearer A1' -H 'X-Device-Id: A'

# 3) Login Device B → token A1 ter-revoke
curl -k -X POST https://panel.modipay.biz.id/api/login-pin \
  -H 'Content-Type: application/json' \
  -d '{"login":"81999000001","pin":"1234","device_id":"B",...}'
# → token=B1, user.device_id=B

# 4) Token A1 sudah tidak valid → 401 Unauthenticated
curl -k https://panel.modipay.biz.id/api/profile \
  -H 'Authorization: Bearer A1' -H 'X-Device-Id: A'

# 5) Token B1 + device A header → 401 device_mismatch
curl -k https://panel.modipay.biz.id/api/profile \
  -H 'Authorization: Bearer B1' -H 'X-Device-Id: A'
```

## Halaman Admin

Buka admin panel → Pengguna → klik salah satu user → tab **Informasi**, scroll ke section **Perangkat & Sesi**:

- Perangkat (nama merk + model)
- Platform (Android / iOS dengan ikon)
- Versi Aplikasi
- Device ID (truncated, tooltip menampilkan penuh)
- Login Terakhir (tanggal + diff "x menit yang lalu")
- IP Login Terakhir

User yang belum pernah login dari aplikasi (atau yang masih pakai versi app lama) akan menampilkan badge **"Belum login dari aplikasi"**.

## Catatan Operasional

- **Backward compatibility**: app versi lama tidak mengirim device_id. Backend menyimpan apa adanya (kolom tetap null) dan middleware `device.bound` melewati request bila `users.device_id` masih null. Setelah user upgrade app dan login sekali, device-nya terikat.
- **Force logout dari admin**: cukup set `users.device_id = null` (atau update ke nilai berbeda) → semua token user di-revoke pada login berikutnya, dan request berjalan tetap valid sampai dia logout/login lagi. Jika ingin instant kick: `\App\Models\User::find($id)->tokens()->delete()`.
- **Race condition**: bila user di-issue token baru hampir bersamaan di dua device, yang menang adalah request yang masuk paling akhir (yang men-set `device_id`). Token yang dibuat sebelum delete akan otomatis ter-revoke pada delete.
- **Privasi**: device id yang disimpan adalah identifier perangkat (bukan IMEI/UUID hardware bila pakai fallback). Aman untuk dilihat admin sebagai string opaque.

## Rollback

Bila ingin menonaktifkan single-login sementara:

1. Hapus `'device.bound'` dari grup middleware di `routes/api.php` baris yang sudah diubah, atau
2. Set `users.device_id = null` untuk semua user → middleware otomatis melewati semua request.

File backup tersedia di server dengan suffix `.bak.singlelogin`/`.bak.singlelogin2`.
