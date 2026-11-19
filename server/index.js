const express = require('express');
const cors = require('cors');
const path = require('path');
const cron = require('node-cron');

const app = express();
const PORT = process.env.PORT || 5000;

// Middleware
app.use(cors());
app.use(express.json());

// In-Memory Fallback State (Simulasi / Development Mode jika belum konek DB)
let dbState = {
  branches: [
    { id: 'BR-JKT-RC', name: 'Jakarta - Hotel Ritz Carlton Kuningan', city: 'Jakarta Selatan', status: 'Aktif' },
    { id: 'BR-JKT-WJ', name: 'Jakarta - Jl. Wijaya', city: 'Jakarta Selatan', status: 'Aktif' },
    { id: 'BR-CLG-01', name: 'Cilegon', city: 'Banten', status: 'Aktif' },
    { id: 'BR-CKR-01', name: 'Cikarang', city: 'Jawa Barat', status: 'Aktif' }
  ],
  roomCategories: [
    { id: 'GDR', name: 'GDR (Golf Driving Range+)', rate: 250000, isVip: false },
    { id: 'ROUND', name: 'Round Room (18 Holes)', rate: 450000, isVip: false },
    { id: 'VIP', name: 'VIP Room', rate: 750000, isVip: true }
  ],
  reservations: [],
  products: [
    {
      id: 'PRD-01',
      sku: 'GZ-TVRX-01',
      name: 'Two Vision RX',
      price: 450000000,
      batches: [
        { batchCode: 'BATCH-2026-01', receivedDate: '2026-01-12', remainingQty: 2 },
        { batchCode: 'BATCH-2026-02', receivedDate: '2026-02-18', remainingQty: 3 }
      ]
    },
    {
      id: 'PRD-02',
      sku: 'GZ-T1NX-02',
      name: 'T1 NX',
      price: 320000000,
      batches: [
        { batchCode: 'BATCH-2026-01', receivedDate: '2026-01-15', remainingQty: 1 },
        { batchCode: 'BATCH-2026-02', receivedDate: '2026-02-20', remainingQty: 3 }
      ]
    }
  ],
  posInvoices: [],
  tickets: []
};

// ============================================================================
// 1. CRON JOB: AUTO-CANCEL 30 MENIT (PENCEGAH NO-SHOW)
// ============================================================================
cron.schedule('* * * * *', () => {
  const now = new Date();
  let cancelledCount = 0;

  dbState.reservations.forEach(res => {
    if (res.status === 'PENDING_PAYMENT') {
      const diffMinutes = (now - new Date(res.createdAt)) / (1000 * 60);
      if (diffMinutes >= 30) {
        res.status = 'EXPIRED';
        cancelledCount++;
      }
    }
  });

  if (cancelledCount > 0) {
    console.log(`[FIFO Auto-Cancel] ${cancelledCount} reservasi expired dan slot dikembalikan ke antrean.`);
  }
});

// ============================================================================
// 2. RESTful API ENDPOINTS
// ============================================================================
app.get('/api/health', (req, res) => {
  res.json({
    status: 'UP',
    system: 'PT Golfzon Jakarta Monolith API',
    timestamp: new Date().toISOString()
  });
});

// Master Cabang & Ruangan
app.get('/api/v1/branches', (req, res) => {
  res.json({ success: true, data: dbState.branches });
});

app.get('/api/v1/rooms', (req, res) => {
  res.json({ success: true, data: dbState.roomCategories });
});

// Reservasi Ruangan (Multi-Sesi & FIFO Lock)
app.post('/api/v1/reservations', (req, res) => {
  const { branchId, roomType, date, hours, customerName, totalAmount } = req.body;
  const bookingCode = `BK-GZ-${date.replace(/-/g, '')}-${Math.floor(100 + Math.random() * 899)}`;

  const newRes = {
    bookingCode,
    branchId,
    roomType,
    date,
    hours: hours || [],
    customerName: customerName || 'Pelanggan Walk-In',
    amount: totalAmount,
    status: 'PENDING_PAYMENT',
    createdAt: new Date().toISOString()
  };

  dbState.reservations.unshift(newRes);
  res.status(201).json({ success: true, data: newRes });
});

// Webhook Callback QRIS (Lunas)
app.post('/api/v1/webhooks/qris', (req, res) => {
  const { bookingCode } = req.body;
  const target = dbState.reservations.find(r => r.bookingCode === bookingCode);

  if (!target) {
    return res.status(404).json({ success: false, message: 'Booking tidak ditemukan' });
  }

  target.status = 'PAID';
  target.paidAt = new Date().toISOString();
  res.json({ success: true, message: 'Pembayaran QRIS lunas terkonfirmasi', data: target });
});

// Transaksi Kasir POS (Logika Batch FIFO Ritel)
app.post('/api/v1/pos/checkout', (req, res) => {
  const { customerName, cashierName, paymentMethod, items } = req.body;
  const invoiceNumber = `INV-${Date.now()}`;
  let grandTotal = 0;

  for (const item of items) {
    const prod = dbState.products.find(p => p.id === item.productId);
    if (!prod) continue;

    let remain = item.qty;
    // Sort batch berdasarkan receivedDate ascending (FIFO)
    prod.batches.sort((a, b) => a.receivedDate.localeCompare(b.receivedDate));

    for (const batch of prod.batches) {
      if (remain <= 0) break;
      if (batch.remainingQty > 0) {
        const take = Math.min(batch.remainingQty, remain);
        batch.remainingQty -= take;
        remain -= take;
      }
    }
    grandTotal += prod.price * item.qty;
  }

  const invoice = {
    invoiceNumber,
    customerName,
    cashierName: cashierName || 'Kasir',
    paymentMethod: paymentMethod || 'QRIS',
    items,
    grandTotal,
    date: new Date().toISOString()
  };

  dbState.posInvoices.unshift(invoice);
  res.status(201).json({ success: true, data: invoice });
});

// Helpdesk Tiket & Retur
app.post('/api/v1/tickets', (req, res) => {
  const { invoiceNumber, category, subject, description, customerName } = req.body;
  const ticketNumber = `TCK-${String(dbState.tickets.length + 1).padStart(3, '0')}`;

  const ticket = {
    ticketNumber,
    invoiceNumber,
    category,
    subject,
    description,
    customerName,
    status: 'Open',
    createdAt: new Date().toISOString()
  };

  dbState.tickets.unshift(ticket);
  res.status(201).json({ success: true, data: ticket });
});

// ============================================================================
// 3. STATIC SERVING FRONTEND (SINGLE-PAGE APPLICATION MONOLITH)
// ============================================================================
const publicPath = path.join(__dirname, '../public');
app.use(express.static(publicPath));

// Fallback untuk SPA Hash/History Routing
app.get('*', (req, res) => {
  res.sendFile(path.join(publicPath, 'index.html'));
});

// Jalankan Server
app.listen(PORT, () => {
  console.log(`=======================================================`);
  console.log(` PT GOLFZON JAKARTA - MONOLITH SERVER RUNNING`);
  console.log(` URL        : http://localhost:${PORT}`);
  console.log(` API Health : http://localhost:${PORT}/api/health`);
  console.log(` Environment: ${process.env.NODE_ENV || 'development'}`);
  console.log(`=======================================================`);
});
