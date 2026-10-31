# Alur Reset Password via Link Email Firebase

Alur ini **tanpa OTP**: pengguna mencari akun, aplikasi menampilkan email resmi
yang tersamarkan, lalu Firebase mengirim tautan reset password ke email
tersebut. Kata sandi baru dibuat pada halaman reset Firebase, sehingga kata
sandi Firebase langsung berubah.

| Bagian | File |
| --- | --- |
| Cari akun & kirim tautan | `lib/features/authentication/presentation/pages/reset_password_page.dart` |
| Konfirmasi tautan terkirim | `lib/features/authentication/presentation/pages/reset_link_sent_page.dart` |
| Data antar-layar | `lib/features/authentication/presentation/models/reset_link_sent_args.dart` |
| Lookup akun & kirim tautan | `lib/data/services/password_reset_service.dart` |
| Model akun | `lib/data/models/reset_account.dart` |
| Route | `/reset-password`, `/reset-password/sent` |

## Alur

1. Pengguna mengetik email akun.
2. `findAccountByEmail()` mencari `public.profiles` dan mengambil `id`, `email`,
   `full_name`, `is_active`.
3. UI menampilkan email resmi dalam bentuk `f***n@gmail.com`.
4. Tombol **Kirim Link Reset** memanggil
   `FirebaseAuth.instance.sendPasswordResetEmail(email)`.
5. Pengguna membuka tautan, membuat kata sandi baru pada halaman Firebase.
6. Pengguna kembali ke aplikasi dan login dengan kata sandi baru.

Supabase hanya dipakai untuk lookup profil. Pengiriman email dan perubahan
kata sandi sepenuhnya ditangani Firebase Authentication.

---

## 1. Konfigurasi Firebase Console

1. **Authentication → Sign-in method → Email/Password**: aktifkan.
   Reset password hanya berlaku untuk akun dengan provider email/password.
2. **Authentication → Templates → Password reset**:
   - Aktifkan template.
   - Pastikan body memuat placeholder `%LINK%`.
   - Sesuaikan teks bahasa Indonesia.
3. **Authentication → Settings → Authorized domains**: tambahkan domain jika
   memakai action URL kustom.
4. Jika memakai action URL kustom, isi di template atau melalui
   `ActionCodeSettings` pada pemanggilan `sendPasswordResetEmail`.
5. Pastikan `google-services.json` / `GoogleService-Info.plist` yang dipakai
   berasal dari project Firebase yang sama.

Tidak perlu mengatur SMTP di Supabase atau Firebase Admin SDK. Firebase
mengirim email reset dengan infrastrukturnya sendiri.

### Template contoh

```html
<h2>Reset Password Telehealth</h2>
<p>Kami menerima permintaan reset password untuk akun ini.</p>
<p><a href="%LINK%">Buat kata sandi baru</a></p>
<p>Jika Anda tidak meminta reset password, abaikan email ini.</p>
```

---

## 2. Lookup akun di Supabase

Langkah pencarian membaca `public.profiles` dari Flutter:

```sql
select id, email, full_name, is_active
from public.profiles
where lower(email) = lower($1);
```

Skema demo `supabase/02_profiles_auth_sync.sql` mengizinkan `select` untuk
`anon`. Untuk produksi:

- pindahkan lookup ke Edge Function yang hanya mengembalikan email tersamarkan,
- batasi policy RLS, dan
- tambahkan rate limit untuk mencegah account enumeration.

Pastikan kolom `profiles.email` sama dengan email akun Firebase. Jika berbeda,
Firebase tidak akan menemukan akun saat `sendPasswordResetEmail` dipanggil.

---

## 3. Perilaku aplikasi

- `sendPasswordResetEmail` dipanggil hanya setelah akun ditemukan di `profiles`.
- Email yang dipakai adalah **email resmi dari database**, bukan input ulang
  pengguna.
- Layar berikutnya menampilkan instruksi dan tombol **Kirim Ulang Tautan**.
- Tautan Firebase bersifat sekali pakai dan memiliki masa berlaku.
- Jika pengguna membatalkan, tidak ada sesi autentikasi yang tertinggal karena
  aplikasi tidak membuat sesi selama proses ini.

---

## 4. Pengujian manual

- [ ] Email terdaftar → akun ditemukan → email tersamarkan tampil.
- [ ] Email tidak terdaftar → pesan "Akun tidak ditemukan".
- [ ] Akun dengan `is_active = false` tidak dapat direset.
- [ ] Tekan **Kirim Link Reset** → layar konfirmasi tampil.
- [ ] Email masuk (cek juga Spam/Promosi).
- [ ] Klik tautan → halaman reset Firebase terbuka.
- [ ] Simpan kata sandi baru → login di aplikasi berhasil.
- [ ] Password lama tidak dapat dipakai lagi.
- [ ] Tombol **Kirim Ulang Tautan** berfungsi.

Jika email tidak masuk:

1. Cek **Authentication → Templates** apakah template Password reset aktif.
2. Cek status pengiriman di Firebase Console (Authentication → Users / Usage).
3. Pastikan akun benar-benar memakai provider email/password.
4. Periksa folder spam dan konfigurasi domain pengirim.

---

## 5. Opsi lanjutan: reset di dalam aplikasi

Jika nanti ingin pengguna membuat kata sandi tanpa keluar ke browser:

1. Kirim dengan `ActionCodeSettings(handleCodeInApp: true, ...)`.
2. Tangkap deep link dan ambil parameter `oobCode`.
3. Verifikasi dengan `verifyPasswordResetCode(oobCode)`.
4. Simpan dengan `confirmPasswordReset(code: oobCode, newPassword: ...)`.

Ini memerlukan konfigurasi deep link Android/iOS dan tidak diperlukan untuk
alur link-hosted saat ini.

## 6. Keamanan

- Jangan kirim tautan reset ke email yang diketik ulang pengguna; gunakan email
  resmi dari `profiles`.
- Jangan tampilkan email lengkap di UI.
- Jangan menyimpan kata sandi di tabel Supabase.
- Batasi akses `profiles` dan tambahkan rate limit pada pencarian akun.
- Tautan reset hanya melindungi akun sekuat keamanan email pemiliknya.
