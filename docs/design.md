# MODITEKH2H — Desktop/Web Design Spec

Status: Draft v1
Sumber referensi: `login.jpeg`, `dashboard.jpeg` (mockup web/desktop)
Lingkup: menurunkan bahasa desain dari 2 mockup tersebut menjadi spesifikasi desktop untuk **seluruh fitur yang sudah ada** di app mobile Flutter (`lib/`), sebagai acuan jika fitur-fitur tersebut dibangun ulang/di-port ke layout desktop (web/responsive Flutter web atau admin web terpisah).

---

## 1. Prinsip Desain

- **Layout**: shell desktop standar — sidebar kiri tetap (fixed) + topbar atas + area konten scrollable. Tidak ada bottom navigation di desktop (berbeda dari mobile `lib/bottombar/bottombar.dart`).
- **Kepadatan informasi lebih tinggi** dibanding mobile: gunakan grid multi-kolom, tabel untuk riwayat transaksi (bukan list card penuh seperti di mobile).
- **Kartu (card) sebagai unit utama**: saldo, status sistem, kategori layanan, bantuan — semua dibungkus card putih dengan shadow halus dan radius besar, konsisten dengan kedua mockup.
- **Konsisten dengan brand mobile**: font tetap keluarga **Gilroy** (Light/Medium/Bold/Black/Heavy/ExtraBold) sesuai `pubspec.yaml`, bukan font baru. Palet warna desktop adalah **ekstensi**, bukan pengganti, dari `lib/utils/color.dart`.

---

## 2. Design Tokens

### 2.1 Warna

Palet existing di `lib/utils/color.dart` (primaryBlue50–900, success/info/warning/error/grey 50–900) tetap dipakai sebagai semantic scale. Untuk shell desktop, kedua mockup menampilkan biru yang lebih jenuh/vivid dibanding `primaryBlue500 (#396eb0)`. Tambahkan token baru khusus desktop berikut (estimasi visual dari mockup — **perlu dikonfirmasi designer/asset Figma**, bukan hasil color-pick presisi):

| Token | Hex (approx) | Sumber/Penggunaan |
|---|---|---|
| `desktopNavyStart` | `#16215C` | Gradient awal panel kiri login |
| `desktopNavyEnd` | `#1F3A8F` | Gradient akhir panel kiri login |
| `desktopAccentBlue` | `#3D6BFF` | Highlight teks "Terpercaya", link aktif |
| `desktopPrimaryBtn` | `#3457D5` | Tombol primary ("Masuk", "Hubungi CS") |
| `desktopBalanceGradStart` | `#2952E3` | Gradient card "Saldo Anda" |
| `desktopBalanceGradEnd` | `#1C3FA0` | Gradient card "Saldo Anda" |
| `surfaceCard` | `#FFFFFF` | Semua card konten |
| `surfacePage` | `#F3F5F9` | Background halaman di luar card |
| `successBadgeBg` / `successBadgeFg` | `#E7F8EE` / `#16A34A` | Badge status "Berhasil", "Normal" |
| `dividerSubtle` | `grey200 (#a9a9a9)` @ 30% | Garis pemisah tabel/section |

Status/error/warning badge tetap pakai scale `success/info/warning/error` yang sudah ada — tidak perlu token baru.

### 2.2 Tipografi (desktop)

| Style | Font | Size | Penggunaan |
|---|---|---|---|
| `display` | Gilroy Bold | 28–32px | Headline "Selamat Datang Kembali", judul value-prop login |
| `h1` (page title) | Gilroy Bold | 22px | "Beranda", judul halaman sidebar |
| `h2` (card title) | Gilroy Bold | 16–18px | "Saldo Anda", "Riwayat Transaksi Terakhir" |
| `body` | Gilroy Medium | 14px | Label form, deskripsi card |
| `caption` | Gilroy Medium | 12px | Sub-label, timestamp, helper text |
| `button` | Gilroy Bold | 14–15px | Semua CTA |

### 2.3 Spacing & Radius

- Grid container max-width konten: `1280px`, padding luar `24–32px`.
- Sidebar width: `260px` fixed.
- Topbar height: `72px`.
- Card radius: `16px` (besar, sesuai kedua mockup), tombol radius `10–12px`, input field radius `10px`.
- Gap antar card di grid: `20–24px`.

---

## 3. Komponen Global

| Komponen | Spek | Mapping ke kode existing |
|---|---|---|
| **Sidebar nav** | Logo + nama app di atas, list item dengan ikon outline, item aktif = bg biru muda + teks `desktopAccentBlue`, item bawah berisi banner promosi referral | Pengganti `lib/bottombar/bottombar.dart` untuk desktop; item map ke halaman di §4 |
| **Topbar** | Judul halaman kiri; kanan: status CS online, ikon notifikasi + badge angka, avatar + nama + role | `lib/home/notifications.dart`, `lib/profile/profile.dart` |
| **Stat/Balance card** | Card gradient biru, label "Saldo Anda", nominal besar, ikon mata toggle visibility, 2 tombol CTA (`Isi Saldo`, `Transfer Saldo`) | `lib/home/home.dart` (saldo header), `lib/home/topup/*`, `lib/home/transfer/*` |
| **System status card** | Card terang dengan ilustrasi, badge status (Normal/Gangguan) dot hijau, CTA "Lihat Status Layanan" | Belum ada di mobile — fitur baru opsional, bisa diarahkan ke notifications/CS |
| **Service grid item** | Ikon kotak rounded berwarna pastel + label di bawah, grid 5 kolom per section (Prepaid / Postpaid) | `lib/home/ppob/*`, kategori di `lib/home/home.dart` (`_prettifyPpobCategory`) |
| **Section header** | Judul + deskripsi kecil kiri, link "Lihat Semua" kanan (biru) | `lib/home/seeallpayment.dart`, `lib/home/seealltransaction.dart` |
| **Transaction table** | Kolom: Tanggal, Produk (ikon+nama), Nomor Tujuan, Status (badge pill), Nominal, Saldo Akhir, chevron detail | `lib/home/transaction_detail.dart`, `lib/profile/historytransaction.dart` |
| **Help card** | Card dengan list channel (Live Chat status online, WhatsApp+jam operasional, Email) + CTA primary "Hubungi CS" | `lib/profile/helpsupport.dart`, `lib/profile/complaint_form_screen.dart` |
| **Auth split layout** | Panel kiri gradient navy dengan value prop + ilustrasi 3D + service icon row + status banner; panel kanan form auth pada background putih, max-width ~440px, centered | `lib/login/login.dart`, `lib/login/login_router.dart` |

---

## 4. Pemetaan Halaman: Existing Feature → Layout Desktop

### 4.1 Autentikasi (panel split, gaya `login.jpeg`)

| Sidebar/Route | File existing | Catatan desktop |
|---|---|---|
| Login (password) | `lib/login/login_with_password.dart` | Form sesuai mockup: Username/Email, Password (toggle show), checkbox "Ingat saya", link "Lupa password?", tombol primary "Masuk", divider "atau masuk dengan", tombol Google, link "Daftar Sekarang" |
| Login (PIN) | `lib/login/login_with_pin.dart` | Varian form: PIN pad ditengah panel kanan, tetap pakai panel kiri yang sama |
| Login OTP | `lib/login/login_otp_screen.dart` | Form OTP 6 digit menggantikan field password, CTA "Verifikasi" |
| Pilihan metode | `lib/login/auth_choice_screen.dart` | Tab/segmented control di atas form: Password / PIN / OTP |
| Register | `lib/login/register.dart` | Sama panel kiri, form kanan multi-step (data diri → setup PIN) |
| Setup profil | `lib/login/setupprofile.dart`, `upprofile.dart` | Step lanjutan dalam flow register |
| Setup PIN | `lib/login/setyourpin.dart`, `setup_pin_screen.dart`, `confirmpin.dart` | Numpad besar terpusat di panel kanan |
| Lupa password/PIN | `lib/login/forgot_password_screen.dart`, `forgot_pin_screen.dart` | Sama panel kiri, form reset di kanan |
| Bahasa | `lib/login/languagescreen.dart` | Modal/dropdown di topbar pra-login, bukan halaman penuh |

Panel kiri konten tetap sama untuk semua halaman auth: logo "MODITEKH2H — PPOB Solution", headline value-prop, 5 ikon layanan (Pulsa/Paket Data/Token Listrik/Game/E-Wallet), status banner "Transaksi Sedang Lancar", ilustrasi.

### 4.2 Dashboard / Beranda (gaya `dashboard.jpeg`)

Sumber: `lib/home/home.dart`

- **Balance card** kiri-atas: saldo + toggle visibility + CTA Isi Saldo → `lib/home/topup/topup_channel_screen.dart`, Transfer Saldo → `lib/home/transfer/transfermoney.dart`.
- **Status/promo carousel** kanan-atas (dot indicator) → bisa dipetakan ke `lib/promo/promo_screen.dart` sebagai banner ringkas + link "Lihat Semua".
- **Section "Prepaid"** grid 5 ikon (Pulsa, Paket Data, Token Listrik, Game, E-Wallet) → `lib/home/ppob/ppob_product_screen.dart`, `ppob_emoney_brand_screen.dart`, `ppob_topup_game_list_screen.dart`.
- **Section "Postpaid"** grid 4 ikon (PLN Pascabayar, PDAM, Tagihan Internet, BPJS) → `lib/home/ppob/ppob_postpaid_screen.dart`, `pdam_screen.dart`, `bpjs_screen.dart`.
- **"Lihat Semua" (Prepaid/Postpaid)** → `lib/home/ppob/ppob_all_services_screen.dart`, `lib/home/seeallpayment.dart`.
- **Riwayat Transaksi Terakhir** (tabel 5 baris + link Lihat Semua) → `lib/home/seealltransaction.dart`, `lib/home/transaction_detail.dart`, `lib/home/purchase_transaction_detail.dart`.
- **Butuh Bantuan?** card kanan-bawah → `lib/profile/helpsupport.dart`, `lib/analytics/chatscreen.dart` (Live Chat), `lib/analytics/chatround.dart`.
- **Banner referral** (sidebar bawah, "Ajak Teman, Dapat Komisi!") → fitur referral; lihat `docs/referral_code_backend_prompt.md`.

### 4.3 Sidebar lengkap (superset dari `dashboard.jpeg`, mencakup seluruh modul existing)

| Item sidebar | Sub-item / fitur existing |
|---|---|
| Beranda | `lib/home/home.dart` |
| Saldo | Isi Saldo (`topup/topup_channel_screen.dart`, `topupcard/topcard.dart`, `topupphone/topphone.dart`, `qris_screen.dart`), Transfer (`transfer/sendmoney.dart`, `bank_transfer_screen.dart`, `bank_transfer_inquiry_screen.dart`), Limit & Saldo (`home/limit/limit_screen.dart`) |
| Prepaid | Pulsa, Paket Data, Token Listrik, Game, E-Wallet — `home/ppob/*`, form di `ppob/components/ppob_cellular_form.dart`, `ppob_pln_form.dart`, `ppob_emoney_form.dart` |
| Postpaid | PLN Pascabayar, PDAM, Tagihan Internet, BPJS — `ppob/ppob_postpaid_screen.dart`, `pdam_screen.dart`, `pdam_inquiry_screen.dart`, `bpjs_screen.dart`, `bpjs_inquiry_screen.dart` |
| QRIS | Scan & Bayar (`home/qris/qris_scan_screen.dart`, `qris_customer_payment_screen.dart`), Daftar Merchant (`qris_merchant_register_screen.dart`, `qris_merchant_screen.dart`) |
| Scan & Pay | `home/scanpay/scan.dart`, `inputpin.dart` |
| Kartu (Card) | `card/mycard.dart`, `createxcard.dart`, riwayat in/out (`inouthistory.dart`, `inoutpayment.dart`, `inoutrequested.dart`, `inoutscheduled.dart`) |
| Request Pembayaran | `home/request/request.dart`, `requestpayment.dart`, `all.dart` |
| Riwayat Transaksi | `home/seealltransaction.dart`, `profile/historytransaction.dart`, struk (`widgets/universal_receipt.dart`, `print_receipt_page.dart`) |
| Promo | `promo/promo_screen.dart` |
| Bantuan / CS | `profile/helpsupport.dart`, `profile/complaint_form_screen.dart`, `complaint_history_screen.dart`, chat (`analytics/*`) |
| Notifikasi | `home/notifications.dart`, `profile/notification.dart` |
| Akun Saya | `profile/myprofile.dart`, `editprofile.dart`, `kyc_screen.dart`, `level_detail_screen.dart`, Agen (`add_agent_screen.dart`, `agent_management_screen.dart`) |
| Pengaturan | `profile/changepassword.dart`, `change_pin_screen.dart`, `language.dart`, `receipt_settings_screen.dart`, `legalandpolicy.dart` |
| Keluar | Logout — `providers/auth_provider.dart` |

Item yang **tidak ada** di mockup `dashboard.jpeg` tapi wajib ditambahkan di sidebar desktop karena sudah jadi fitur mobile: **QRIS**, **Scan & Pay**, **Kartu**, **Request Pembayaran**, **Promo**, **Akun Saya/Agen**. Susun sebagai grup collapsible agar sidebar tidak terlalu panjang (gunakan pattern "Prepaid ▾ / Postpaid ▾" yang sudah terlihat di mockup untuk grup lain juga).

### 4.4 Halaman lain (tidak tampil di mockup, ikut pola card/tabel yang sama)

- **Verifikasi/KYC** (`verification/indetyfiyverifiy.dart`, `scandone.dart`, `verificationdone.dart`, `profile/kyc_screen.dart`, `home/limit/merchant_kyc_screen.dart`) → wizard step di dalam card tengah, progress indicator horizontal.
- **Onboarding/splash** (`onbonding.dart`, `splashscreen.dart`) → tidak relevan untuk desktop shell (hanya dipakai first-load mobile); di web bisa diskip langsung ke halaman login.

---

## 5. Status & State Pola Visual

| State | Visual |
|---|---|
| Sukses (badge tabel) | Pill hijau muda bg, teks hijau tua, contoh: "Berhasil" |
| Sistem normal | Dot hijau + teks "Normal"/"Transaksi sedang lancar" |
| Notifikasi belum dibaca | Badge merah bulat angka di ikon bell |
| Empty state | Reuse `assets/lottie/empty_cart.json` di tengah card konten |
| Loading | Shimmer (`shimmer` package sudah dipakai di mobile) pada skeleton card/tabel |

---

## 6. Aset

- Ikon kategori layanan: gunakan set existing di `assets/icons/` dan logo provider/e-wallet di `images/provider_logos/`, `images/ewallet_logos/` — jangan buat ikon baru, cukup bungkus dalam container rounded pastel sesuai mockup.
- Ilustrasi 3D (panel login, status card dashboard) belum ada asetnya di repo — perlu request aset baru ke desainer atau pakai placeholder Lottie sementara.

---

## 7. Open Questions

1. Apakah desktop ini Flutter Web (reuse codebase mobile dengan breakpoint) atau aplikasi admin-web terpisah (React/Vue)? Menentukan apakah token di atas diimplementasikan sebagai `ThemeData` Flutter atau CSS variables.
2. Hex warna di §2.1 adalah estimasi visual dari JPEG — perlu file desain sumber (Figma/XD) untuk nilai pasti sebelum dikunci sebagai token final.
3. Apakah role "Admin" di topbar mockup berarti ada varian desktop khusus untuk role agen/admin (berbeda dari user biasa di mobile)?
