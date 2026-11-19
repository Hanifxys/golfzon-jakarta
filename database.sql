# =====================================================================
# SKEMA BASIS DATA: PT GOLFZON JAKARTA (HYBRID RENTAL & RETAIL)
# Kompatibel dengan MySQL 8.0 & PostgreSQL / Supabase
# =====================================================================

-- 1. TABEL PENGGUNA & ROLE RBAC
CREATE TABLE IF NOT EXISTS users (
  id VARCHAR(36) PRIMARY KEY,
  name VARCHAR(120) NOT NULL,
  email VARCHAR(120) UNIQUE NOT NULL,
  password VARCHAR(255) NOT NULL,
  phone VARCHAR(30),
  role ENUM('Pelanggan', 'Kasir', 'Karyawan', 'Admin', 'Pemilik') NOT NULL DEFAULT 'Pelanggan',
  branch_id VARCHAR(36) NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- 2. TABEL CABANG OUTLET
CREATE TABLE IF NOT EXISTS branches (
  id VARCHAR(36) PRIMARY KEY,
  name VARCHAR(120) NOT NULL,
  city VARCHAR(60) NOT NULL,
  address TEXT NOT NULL,
  open_time TIME NOT NULL DEFAULT '09:00:00',
  close_time TIME NOT NULL DEFAULT '22:00:00',
  status ENUM('Aktif', 'Nonaktif') NOT NULL DEFAULT 'Aktif',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 3. TABEL KATEGORI RUANGAN SIMULATOR
CREATE TABLE IF NOT EXISTS room_categories (
  id VARCHAR(36) PRIMARY KEY,
  name VARCHAR(120) NOT NULL,
  hourly_rate DECIMAL(12, 2) NOT NULL,
  description TEXT,
  badge VARCHAR(60),
  is_vip BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 4. TABEL RESERVASI RUANGAN & MULTI-SESI
CREATE TABLE IF NOT EXISTS reservations (
  booking_code VARCHAR(50) PRIMARY KEY,
  user_id VARCHAR(36) NOT NULL,
  customer_name VARCHAR(120) NOT NULL,
  branch_id VARCHAR(36) NOT NULL,
  room_category_id VARCHAR(36) NOT NULL,
  reservation_date DATE NOT NULL,
  start_hour TIME NOT NULL,
  end_hour TIME NOT NULL,
  sessions_count INT NOT NULL DEFAULT 1,
  sessions_detail JSON,
  total_amount DECIMAL(12, 2) NOT NULL,
  status ENUM('PENDING_PAYMENT', 'PAID', 'EXPIRED', 'CANCELLED') NOT NULL DEFAULT 'PENDING_PAYMENT',
  expires_at TIMESTAMP NOT NULL,
  paid_at TIMESTAMP NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id),
  FOREIGN KEY (branch_id) REFERENCES branches(id),
  FOREIGN KEY (room_category_id) REFERENCES room_categories(id)
);

-- 5. TABEL KATALOG PRODUK SIMULATOR RITEL
CREATE TABLE IF NOT EXISTS products (
  id VARCHAR(36) PRIMARY KEY,
  sku VARCHAR(50) UNIQUE NOT NULL,
  name VARCHAR(150) NOT NULL,
  tag VARCHAR(60),
  price DECIMAL(15, 2) NOT NULL,
  description TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 6. TABEL KLOTER STOK GUDANG (BATCH FIFO)
CREATE TABLE IF NOT EXISTS inventory_batches (
  id VARCHAR(36) PRIMARY KEY,
  product_id VARCHAR(36) NOT NULL,
  batch_code VARCHAR(60) NOT NULL,
  received_date DATE NOT NULL,
  initial_qty INT NOT NULL,
  remaining_qty INT NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE
);

-- 7. TABEL TRANSAKSI KASIR (POINT OF SALE / POS)
CREATE TABLE IF NOT EXISTS pos_invoices (
  invoice_number VARCHAR(50) PRIMARY KEY,
  date_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  branch_id VARCHAR(36) NOT NULL,
  customer_name VARCHAR(120) NOT NULL,
  cashier_id VARCHAR(36) NOT NULL,
  cashier_name VARCHAR(120) NOT NULL,
  payment_method ENUM('QRIS', 'Debit', 'Cash') NOT NULL DEFAULT 'QRIS',
  payment_detail VARCHAR(255),
  cash_received DECIMAL(15, 2) NULL,
  cash_change DECIMAL(15, 2) NULL,
  total_amount DECIMAL(15, 2) NOT NULL,
  FOREIGN KEY (branch_id) REFERENCES branches(id)
);

-- 8. TABEL DETAIL ITEM TRANSAKSI POS (PEMOTONGAN BATCH FIFO)
CREATE TABLE IF NOT EXISTS pos_invoice_items (
  id INT AUTO_INCREMENT PRIMARY KEY,
  invoice_number VARCHAR(50) NOT NULL,
  product_id VARCHAR(36) NOT NULL,
  batch_code_used VARCHAR(100) NOT NULL,
  quantity INT NOT NULL,
  unit_price DECIMAL(15, 2) NOT NULL,
  subtotal DECIMAL(15, 2) NOT NULL,
  FOREIGN KEY (invoice_number) REFERENCES pos_invoices(invoice_number) ON DELETE CASCADE,
  FOREIGN KEY (product_id) REFERENCES products(id)
);

-- 9. TABEL TIKET KOMPLAIN & RETUR PURNAJUAL
CREATE TABLE IF NOT EXISTS support_tickets (
  ticket_number VARCHAR(50) PRIMARY KEY,
  invoice_number VARCHAR(50) NOT NULL,
  user_id VARCHAR(36) NOT NULL,
  customer_name VARCHAR(120) NOT NULL,
  product_id VARCHAR(36) NOT NULL,
  category ENUM('RETUR_CACAT', 'KOMPLAIN') NOT NULL,
  subject VARCHAR(200) NOT NULL,
  description TEXT NOT NULL,
  status ENUM('Open', 'In Progress', 'Closed') NOT NULL DEFAULT 'Open',
  return_status VARCHAR(100) DEFAULT 'Bukan Retur Fisik',
  return_decision ENUM('PENDING', 'REPLACE', 'REPAIR', 'REJECTED', 'N/A') DEFAULT 'PENDING',
  resolution_note TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id)
);

-- 10. DATA BENIH AWAL (SEED DATA)
INSERT INTO branches (id, name, city, address, open_time, close_time, status) VALUES
('BR-JKT-RC', 'Jakarta - Hotel Ritz Carlton Kuningan', 'Jakarta Selatan', 'Jl. DR. Ide Anak Agung Gde Agung Kav.E.1.1 No.1, Kuningan', '09:00:00', '22:00:00', 'Aktif'),
('BR-JKT-WJ', 'Jakarta - Jl. Wijaya', 'Jakarta Selatan', 'Jl. Wijaya II No. 48, Kebayoran Baru', '09:00:00', '22:00:00', 'Aktif'),
('BR-CLG-01', 'Cilegon', 'Banten', 'Kawasan Industri & Komersial Cilegon Center', '10:00:00', '21:00:00', 'Aktif'),
('BR-CKR-01', 'Cikarang', 'Jawa Barat', 'Lippo Cikarang Boulevard No. 12', '10:00:00', '21:00:00', 'Aktif')
ON DUPLICATE KEY UPDATE name=VALUES(name);

INSERT INTO room_categories (id, name, hourly_rate, description, badge, is_vip) VALUES
('GDR', 'GDR (Golf Driving Range+)', 250000.00, 'Pelacakan presisi kecepatan, spin, & lintasan bola untuk latihan akurasi.', 'Driving Range', FALSE),
('ROUND', 'Round Room (18 Holes)', 450000.00, 'Simulasi 18 hole lapangan golf kelas dunia secara real-time.', '18 Holes', FALSE),
('VIP', 'VIP Room', 750000.00, 'Ruangan privat eksklusif dengan dual-plate swing sensor & lounge.', 'VIP Lounge', TRUE)
ON DUPLICATE KEY UPDATE hourly_rate=VALUES(hourly_rate);

INSERT INTO products (id, sku, name, tag, price, description) VALUES
('PRD-01', 'GZ-TVRX-01', 'Two Vision RX', 'Produk Unggulan', 450000000.00, 'Sistem simulator flagship generasi terbaru dengan Dual High-Speed Camera & Motion Plate.'),
('PRD-02', 'GZ-T1NX-02', 'T1 NX', 'Commercial Series', 320000000.00, 'Simulator performa tinggi untuk komersial indoor golf lounge dengan grafis 4K.'),
('PRD-03', 'GZ-VSTD-03', 'Vision Standar', 'Standard Edition', 260000000.00, 'Paket simulator standar untuk instalasi residensial maupun klub golf.'),
('PRD-04', 'GZ-GDR-04', 'GDR', 'Golf Driving Range+', 185000000.00, 'Unit khusus akademi dan driving range indoor dengan analisis swing detail.')
ON DUPLICATE KEY UPDATE price=VALUES(price);

INSERT INTO inventory_batches (id, product_id, batch_code, received_date, initial_qty, remaining_qty) VALUES
('BAT-01', 'PRD-01', 'BATCH-2026-01', '2026-01-12', 3, 2),
('BAT-02', 'PRD-01', 'BATCH-2026-02', '2026-02-18', 3, 3),
('BAT-03', 'PRD-02', 'BATCH-2026-01', '2026-01-15', 2, 1),
('BAT-04', 'PRD-02', 'BATCH-2026-02', '2026-02-20', 3, 3),
('BAT-05', 'PRD-03', 'BATCH-2026-01', '2026-01-20', 2, 2),
('BAT-06', 'PRD-04', 'BATCH-2026-01', '2026-01-10', 4, 2),
('BAT-07', 'PRD-04', 'BATCH-2026-02', '2026-02-25', 2, 2)
ON DUPLICATE KEY UPDATE remaining_qty=VALUES(remaining_qty);
