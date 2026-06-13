# Prompt Implementasi — Fitur "Kode Referral Master" di Backend (Laravel)

## Konteks
**ModiPay** punya backend Laravel di `https://panel.modipay.biz.id`. Aplikasi mobile (Flutter)
sudah diubah untuk:
1. Menampilkan kode referral milik user yang sedang login di halaman **Profil** (dengan tombol
   copy) — **hanya untuk user dengan `hierarchy_level = 'master'`**.
2. Mengirim `referral_code` saat **master menambah agen baru** (endpoint `POST /hierarchy/agens`) —
   diisi otomatis dari kode referral milik master yang login.
3. Mewajibkan input **Kode Referral** saat **registrasi mandiri** (endpoint `POST /register`) —
   field wajib diisi oleh agen/user baru sebelum lanjut OTP, dan harus berupa kode milik seorang
   **master**.
4. Menyediakan menu **"Akun Existing"** di layar Tambah Agen — master memasukkan No. HP user yang
   **sudah pernah mendaftar mandiri sebelumnya**, lalu app memanggil endpoint baru
   `POST /hierarchy/agens/link` untuk menautkan user tersebut ke hierarki master (tanpa membuat
   akun baru, tanpa mengubah password).

Backend perlu disesuaikan agar field `referral_code` tersedia dan ditegakkan sesuai poin di atas,
serta menyediakan endpoint baru untuk poin 4.

**Scope**: kode referral **hanya dimiliki oleh user `hierarchy_level = 'master'`**. User dengan
`hierarchy_level = 'agen'` (baik dibuat lewat `/hierarchy/agens` maupun via registrasi mandiri
dengan kode referral) **tidak** mendapat kode referral sendiri — fitur rekrut berjenjang
(agen merekrut agen) **di luar scope** ini.

Hierarki user ada di `users.hierarchy_level` enum: `supermaster | master | agen | null`,
dengan relasi parent via `users.parent_id`.

---

## A. Skema database

### `users` — kolom baru
- `referral_code` (string, unik, nullable).
  - Format bebas (mis. 8 karakter alfanumerik uppercase), yang penting **unik per user**.
  - **Hanya diisi untuk user dengan `hierarchy_level = 'master'`**. Untuk user lain
    (`agen`, `supermaster`, `null`) kolom ini **tetap `null`**.
  - **Auto-generate** via observer pada model `User`:
    - Saat user baru dibuat dengan `hierarchy_level = 'master'`.
    - Saat `hierarchy_level` user yang sudah ada **diubah menjadi `master`** (mis. promosi oleh
      admin) dan belum punya `referral_code`.
    - Retry bila terjadi collision (kode harus unik).
  - **Backfill**: migration/seeder/console command untuk generate `referral_code` bagi semua user
    existing dengan `hierarchy_level = 'master'` yang belum punya.

(Opsional, untuk audit) `users.referred_by_user_id` (nullable, foreign key ke `users.id`) —
menyimpan siapa pemilik `referral_code` (master) yang dipakai saat agen ini dibuat/mendaftar.
Berguna untuk pelaporan, terlepas dari `parent_id` yang menentukan hierarki.

---

## B. Endpoint `/profile` dan `/login`
Tambahkan `referral_code` pada object `user` yang dikembalikan oleh:
- `GET /profile`
- `POST /login`
- `POST /login-pin`
- `POST /register` (response setelah berhasil daftar, termasuk dalam object `user`)

Nilainya `null`/tidak ada untuk user yang bukan `master` (mobile app hanya menampilkan kartu
"Kode Referral Saya" bila `hierarchy_level == 'master'` dan `referral_code` terisi).

```json
{
  "user": {
    "id": 123,
    "name": "...",
    "hierarchy_level": "master",
    "referral_code": "MDP7X2KQ",
    ...
  }
}
```

---

## C. Endpoint `POST /register` (registrasi mandiri)
Aplikasi mobile kini selalu mengirim field `referral_code` (wajib, tidak boleh kosong) pada body
request, contoh:

```json
{
  "name": "User 6789",
  "phone": "6281234566789",
  "referral_code": "MDP7X2KQ",
  ...
}
```

Perubahan validasi & logika:
1. **Validasi `referral_code` wajib** (`required`) dan **harus cocok** dengan `users.referral_code`
   milik user lain yang aktif **dengan `hierarchy_level = 'master'`**.
2. Bila kode tidak ditemukan/tidak valid (termasuk kode milik user yang bukan master, atau kode
   kosong/null) → tolak registrasi dengan pesan error yang jelas, contoh:
   ```json
   { "message": "Kode referral tidak valid.", "errors": { "referral_code": ["Kode referral tidak ditemukan."] } }
   ```
3. Bila valid → set pada user baru:
   - `parent_id` = id master pemilik `referral_code`.
   - `hierarchy_level` = `agen`.
   - (opsional) `referred_by_user_id` = id master pemilik `referral_code`.
   - `referral_code` user baru **tetap `null`** (sesuai scope: hanya master yang punya kode
     referral).

---

## D. Endpoint `POST /hierarchy/agens` (master menambah agen)
Aplikasi mobile kini mengirim tambahan field `referral_code` berisi **kode referral milik master
yang sedang login** (diambil dari profil master tersebut), contoh:

```json
{
  "name": "Agen Baru",
  "phone": "6281234567890",
  "password": "******",
  "referral_code": "MDP7X2KQ"
}
```

Endpoint ini sudah terautentikasi sebagai master (via Sanctum/Passport token), sehingga relasi
`parent_id` = master yang login **tetap menjadi sumber kebenaran utama** dan tidak boleh berubah
walau `referral_code` di body tidak ada/berbeda.

Perlakuan field `referral_code` di endpoint ini:
- **Opsional** — jika tidak dikirim, proses tetap berjalan seperti sekarang (agen baru otomatis
  `parent_id` = master yang login, `hierarchy_level = 'agen'`).
- Jika dikirim, gunakan untuk validasi konsistensi (opsional): pastikan `referral_code` tersebut
  memang milik master yang sedang login; jika tidak cocok, **abaikan saja** (jangan gagalkan
  request) — auth context tetap jadi acuan hierarki.
- Set `referred_by_user_id` agen baru (jika kolom tersedia) = id master yang login.
- Agen baru **tidak** mendapat `referral_code` sendiri (tetap `null`).

---

## E. Endpoint baru `POST /hierarchy/agens/link` (master menautkan akun existing)

Untuk kasus user yang **sudah pernah mendaftar mandiri** (sudah punya akun & password sendiri,
biasanya dengan `hierarchy_level = null` atau belum punya `parent_id`), master bisa
menautkannya ke hierarki tanpa membuat akun baru. Mobile app mengirim:

```json
{
  "phone": "6281234567890"
}
```

Endpoint terautentikasi sebagai master (via token), sehingga master yang login menjadi
`parent_id` tujuan. Logika:
1. Cari user berdasarkan `phone`. Jika tidak ditemukan → tolak dengan pesan, contoh:
   ```json
   { "message": "Nomor HP tidak ditemukan. Pastikan pengguna sudah mendaftar." }
   ```
2. Jika user ditemukan tapi **sudah punya `parent_id`** (sudah tergabung di hierarki agen/master
   lain) → tolak, contoh:
   ```json
   { "message": "Pengguna ini sudah terdaftar di bawah agen/master lain." }
   ```
3. Jika user adalah master/supermaster lain (`hierarchy_level` in `['master', 'supermaster']`) →
   tolak, tidak boleh ditautkan sebagai agen.
4. Jika valid → set pada user yang ditemukan:
   - `parent_id` = id master yang login.
   - `hierarchy_level` = `agen`.
   - (opsional) `referred_by_user_id` = id master yang login.
5. **Tidak mengubah** field lain milik user tersebut — terutama `password`, `name`, `email`,
   `balance`, dsb. User tetap login dengan akun & password lamanya, hanya posisinya di hierarki
   yang berubah.
6. Response sukses berisi `message`, contoh: `{ "message": "Agen berhasil ditambahkan." }`.

---

## Acceptance criteria
- Hanya user dengan `hierarchy_level = 'master'` yang memiliki `referral_code` unik, tersedia di
  response `/profile` dan `/login`; user lain (`agen`, `supermaster`, `null`) mengembalikan
  `referral_code = null`.
- `POST /register` menolak request tanpa `referral_code` atau dengan kode yang tidak ditemukan /
  bukan milik master, dan menetapkan `parent_id` + `hierarchy_level = 'agen'` user baru sesuai
  master pemilik kode saat valid. User baru tidak mendapat `referral_code` sendiri.
- `POST /hierarchy/agens` tetap berfungsi seperti semula; pengiriman `referral_code` (kode milik
  master) tidak mengubah hierarki dan tidak menggagalkan request bila tidak cocok. Agen baru tidak
  mendapat `referral_code` sendiri.
- User existing dengan `hierarchy_level = 'master'` sudah di-backfill `referral_code` lewat
  migration/seeder.
- `POST /hierarchy/agens/link` menautkan user existing (ditemukan via `phone`) ke hierarki master
  yang login (`parent_id` + `hierarchy_level = 'agen'`), menolak jika user tidak ditemukan, sudah
  punya `parent_id`, atau berstatus master/supermaster, dan tidak mengubah data lain milik user
  (password, dll).
