# Sistem Informasi PT Golfzon Jakarta (Monolith Web Application)

Aplikasi terintegrasi untuk pengelolaan penyewaan arena simulator golf dan penjualan ritel unit simulator pada PT Golfzon Jakarta.

## Arsitektur Sistem
- **Model**: Monolith (Express.js backend melayani RESTful API sekaligus static frontend build).
- **Backend**: Node.js v20.x, Express.js, JWT Authentication, node-cron (Auto-cancel 30 Menit), mysql2 / pg.
- **Frontend**: Single Page Application (17 Pages), Tailwind CSS, Lucide Icons, Client Hash Router.
- **Database**: Skema SQL relational (MySQL 8.0 & PostgreSQL / Supabase ready).

## 5 Hak Akses Pengguna (Role-Based Access Control / RBAC)
1. **Pelanggan**: Booking multi-sesi kalender, QRIS full payment, E-Ticket, dan tiket komplain purnajual ritel.
2. **Kasir**: Terminal kasir POS ritel (QRIS / Debit / Cash), pemotongan otomatis batch FIFO stok gudang, cetak struk, dan pantauan jadwal lunas cabang.
3. **Karyawan**: Penanganan antrean helpdesk tiket (Open -> In Progress -> Closed) dan inspeksi klaim retur barang cacat (REPLACE / REPAIR / REJECTED).
4. **Admin (Multi-User)**: Manajemen kloter stok batch FIFO, master data cabang, ruangan, produk, pengguna RBAC, serta live JSON API audit logs.
5. **Pemilik (Owner)**: Mode Read-Only, Executive KPI Dashboard, rekapitulasi finansial sewa & ritel (ekspor CSV / cetak), dan audit trail.

## Fitur Utama
- **Multi-Sesi Booking**: Memesan beberapa sesi jam bermain sekaligus dengan urutan antrean First-In, First-Out (FIFO).
- **Auto-Cancel 30 Menit**: Slot waktu terkunci selama 30 menit. Jika pembayaran QRIS belum lunas saat timer habis, pesanan gugur otomatis dan dialihkan ke antrean berikutnya.
- **Kebijakan Non-Refundable**: Seluruh pembayaran berstatus lunas bersifat final jika terjadi pembatalan sepihak (*no-show*).
- **Manajemen Inventaris Batch FIFO**: Transaksi penjualan kasir otomatis memotong stok dari kloter masuk terlama.

## Cara Menjalankan Aplikasi Secara Lokal

### 1. Prasyarat
- Node.js v18+ atau v20 LTS
- MySQL (Laragon / XAMPP) atau PostgreSQL

### 2. Instalasi & Menjalankan Server
```bash
# Clone repository
git clone https://github.com/Hanifxys/golfzon-jakarta.git
cd golfzon-jakarta

# Install dependencies
npm install

# Setup environment variables
cp .env.example .env

# Jalankan server monolitik (Port 5000)
npm run dev
# atau untuk produksi:
npm start
```

Buka peramban di: `http://localhost:5000`


