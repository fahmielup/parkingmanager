# Parking Manager PC App

Aplikasi desktop PC untuk urus resit parking dan menyimpan resit yang pelanggan hantar melalui WhatsApp.

## Ciri-ciri

- **Multi-User & Role** - Admin dan Cashier dengan kebenaran berbeza
- **Login Secured** - Kata laluan hash, kunci akaun selepas 3 percubaan gagal, session timeout 30 minit
- **Audit Log** - Rekod setiap tindakan pengguna (login, create, delete, backup)
- **Dashboard Pintar** - Statistik, graf hasil 30 hari, pecahan pelan bulanan vs harian
- **Buat Resit** - Cipta resit parking dengan kiraan automatik mengikut masa dan kadar
- **Pelan Bulanan / Harian** - Pilih sama ada customer adalah kereta bulanan atau harian
- **Resit WhatsApp** - Simpan gambar/PDF resit yang customer hantar di WhatsApp
- **Senarai Resit** - Carian, tapisan (pelan, status, sumber, tarikh), cetak, dan padam resit
- **Tetapan** - Konfigurasi nama syarikat, alamat, kadar default, dan lokasi simpan resit
- **Export CSV** - Eksport semua resit ke Excel/CSV
- **Backup & Restore** - Backup zip database, tetapan, dan fail resit
- **Cetak Resit** - Cetak resit dengan format kemas

## Akaun Default

- **admin** / admin
- **cashier** / cashier

*Wajib tukar kata laluan selepas pertama kali log masuk.*

## Cara Pasang & Jalankan

### Keperluan

- Python 3.8 atau lebih baharu

### Langkah-langkah

1. Buka terminal dalam folder projek:
   ```bash
   cd C:\Users\USER\CascadeProjects\parking-manager
   ```

2. Pasang Flask (sekali sahaja):
   ```bash
   pip install -r requirements.txt
   ```

3. Jalankan app:
   ```bash
   python app.py
   ```

4. Browser akan dibuka automatik ke `http://127.0.0.1:5000/`

## Struktur Projek

```
parking-manager/
  app.py              # Flask backend + SQLite
  requirements.txt    # Kebergantungan Python
  templates/
    index.html        # UI utama
  static/
    styles.css        # Styling
    app.js            # Frontend logic
  db/                 # Database SQLite (runtime)
  receipts/           # Fail resit WhatsApp (runtime)
  README.md
```

## Nota

- Data disimpan secara lokal dalam `db/parking.db` (SQLite).
- Fail resit WhatsApp disimpan mengikut struktur folder contoh anda:
  - Default: `receipts/MONTHLY/JUL 2026/<NO_KENDERAAN>_<TIMESTAMP>.jpg`
  - Anda boleh tukar lokasi asas dalam **Tetapan > Lokasi Simpan Resit** (contoh: `C:\Users\USER\Desktop\ALL RECEIPT`).
- App ini tidak menghantar data ke internet.
- Cuma Flask sahaja diperlukan sebagai kebergantungan luaran.
