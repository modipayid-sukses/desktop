# Prompt Implementasi — Fitur "Limit Saldo" di Admin Panel

## Konteks
**ModiPay** punya admin panel berbasis **Laravel** di `https://panel.modipay.biz.id`.
Aplikasi mobile (Flutter) hanya konsumen API. Fitur **Limit Saldo** ini dibangun **di admin panel**
sebagai halaman monitoring + pengelolaan limit saldo seluruh agen.

Hierarki user ada di `users.hierarchy_level` enum: `supermaster | master | agen | null`.
Seorang **master** membawahi banyak **agen** (relasi parent, mis. `users.parent_id`).
Admin panel melihat lintas master (atau difilter per-master).

> Sesuaikan implementasi dengan stack panel yang dipakai (Blade + Controller, Livewire, atau Filament Resource/Page).
> Bagian di bawah menjelaskan **kebutuhan fungsional + data**, bukan mengikat ke satu framework UI.

### Tabel/kolom relevan yang sudah ada
- `users`: `id, name, phone, hierarchy_level, parent_id, kredit_verified (0/1), kredit_limit, balance`.
- `merchant_kyc`: pengajuan/verifikasi merchant per-user, `status` enum `none|pending|approved|rejected`.
- Data limit per-user (dipakai endpoint mobile `merchant-kyc/limit-detail`): `kredit_limit`, `used_amount`,
  `available_amount`, `due_date`, `days_left`, `service_fee`.
- Riwayat/tagihan limit punya flag `limit_paid` (lihat `merchant-kyc/limit-history` & `pay-bill`).

---

## Halaman: "Limit Saldo Agen" (admin panel)
Tambahkan menu **Limit Saldo** di sidebar panel. Halaman berisi 3 bagian.

### A. Kartu Ringkasan (stat cards, agregat seluruh agen)
| Kartu | Definisi |
|---|---|
| **Pengajuan Limit Saldo** | Jumlah agen dengan pengajuan limit **pending** (`merchant_kyc.status = 'pending'`). |
| **Toko Terverifikasi** | Jumlah agen dengan merchant terverifikasi (`merchant_kyc.status = 'approved'` / `kredit_verified = 1`). |
| **Total Limit Disetujui** | `SUM(kredit_limit)` agen yang limitnya aktif/disetujui (Rp). |
| **Saldo Limit Terpakai** | `SUM(used_amount)` seluruh agen (Rp). |
| **Limit Tersedia** | `SUM(kredit_limit) - SUM(used_amount)` (Rp, clamp ≥ 0) — belum dipakai seluruh agen. |

### B. Kartu "Tagihan Limit Saldo Hari Ini" (3 bucket, masing-masing bisa di-klik → daftar detail)
Hitung dari tagihan **belum lunas** (`limit_paid = 0`), timezone `Asia/Jakarta`:
| Bucket | Definisi | Detail saat di-klik |
|---|---|---|
| **Jatuh Tempo Hari Ini** | `due_date = hari ini` | Modal/halaman daftar: Nama, No HP, Nominal, Jatuh tempo. |
| **Jatuh Tempo < 3 Hari** | `due_date` dalam 1–3 hari ke depan (`> today AND <= today+3`) | idem. |
| **Lewat Jatuh Tempo** | `due_date < hari ini` (user belum bayar) | idem + tandai "Telat N hari". |

Tiap kartu menampilkan **jumlah agen + total nominal**, dan tombol/aksi untuk melihat list detailnya.

### C. Tabel "Daftar Limit Agen"
Kolom: **Nama**, **Nomor HP**, **Plafon** (`kredit_limit`), **Terpakai** (`used_amount`),
**Sisa Limit** (`plafon - used`), **Status** (Disetujui/Pending/Ditolak dari `merchant_kyc.status`),
dan **Aksi** → tautan ke halaman **manajemen user** agen tsb (detail user di panel).

Fitur tabel: pencarian (nama/HP), filter status, sort, pagination. (Opsional) ekspor.

---

## Aksi admin (panel)
Di halaman manajemen user / dari tabel, admin dapat:
1. **Setujui / Tolak** pengajuan limit (`merchant_kyc.status` → `approved`/`rejected`).
2. **Set / ubah Plafon** (`users.kredit_limit`).
3. **Aktif/nonaktifkan** fitur limit user (`kredit_verified`).
4. **Lihat & tandai** pembayaran tagihan (selaras `limit_paid`).
Semua aksi tercatat di audit log/activity bila panel sudah punya mekanismenya.

---

## Penegakan: agen lewat jatuh tempo → aplikasi tidak bisa dipakai
Ini efeknya ke **aplikasi mobile**, tapi sumber kebenarannya di server/panel.
1. Sediakan computed flag **`limit_overdue`** untuk user agen = `true` bila ada tagihan limit
   **belum lunas** dengan `due_date < hari ini`.
2. Sertakan `limit_overdue` pada response profil user (endpoint `/login`, `/profile`) agar app membacanya.
3. Tegakkan **di server**: middleware/guard pada endpoint transaksi (PPOB, transfer, top-up, QRIS) menolak
   request user dengan `limit_overdue = true`:
   ```json
   { "message": "Tagihan limit Anda lewat jatuh tempo. Lunasi untuk melanjutkan transaksi.", "error_code": "limit_overdue" }
   ```
   **Kecualikan** endpoint pembayaran tagihan limit agar user tetap bisa melunasi.
4. Setelah tagihan dilunasi, `limit_overdue` kembali `false` dan transaksi terbuka lagi.
5. (Disarankan) scheduled job harian menandai akun yang baru lewat jatuh tempo + kirim notifikasi.

---

## Saran struktur Laravel (sesuaikan bila panel pakai Filament/Livewire)
- **Route** (admin, ter-proteksi middleware role admin):
  - `GET /admin/limit-saldo` → halaman dashboard (ringkasan + bucket + tabel).
  - `GET /admin/limit-saldo/bills/{bucket}` → daftar detail tagihan (`bucket` ∈ `due_today|due_soon|overdue`).
  - `POST /admin/limit-saldo/{user}/approve` | `/reject` | `/plafon` → aksi admin.
- **Controller**: `Admin\LimitSaldoController` dengan method `index`, `bills`, `approve`, `reject`, `updatePlafon`.
- **Query agregat** (contoh, batasi ke agen): hitung counter & sum via query builder; bucket pakai
  `whereDate('due_date', ...)` + `where('limit_paid', 0)`.
- **View**: `resources/views/admin/limit-saldo/index.blade.php` (+ partial untuk kartu, tabel, modal detail).
- Filter opsional **per master**: dropdown master → `where('parent_id', $masterId)`.

## Acceptance criteria
- Semua angka agregat akurat & hanya dari agen (bukan user biasa); konsisten timezone `Asia/Jakarta`.
- Tiga bucket tagihan menampilkan count+total yang sama dengan jumlah baris pada list detailnya.
- Aksi approve/reject/ubah plafon langsung tercermin di tabel & ringkasan.
- `limit_overdue` benar mem-flag agen telat bayar, dan transaksi mobile-nya tertolak server-side
  sampai lunas.
- Hanya admin yang berwenang dapat mengakses halaman & aksinya.
