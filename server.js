require('dotenv').config();
const express = require('express');
const cors = require('cors');
const { Pool } = require('pg');

const path = require('path');
const fs = require('fs');

const app = express();
app.use(cors());
app.use(express.json());

const PORT = process.env.PORT || 8080;

// WhitsunPay Config
const WHITSUNPAY_CONFIG = {
  baseUrl: process.env.WHITSUNPAY_BASE_URL || 'https://developer.whitsun.dev',
  clientId: process.env.WHITSUNPAY_CLIENT_ID || '019e8ba678a27f00bc19c3757989ed0b',
  apiKey: process.env.WHITSUNPAY_API_KEY || 'wp_live_h7Q8bld7YqtjvTVF2wwfBrUjxl6LShWexviNLfy5lQU',
  webhookSecret: process.env.WHITSUNPAY_WEBHOOK_SECRET || '',
};

// Supabase PostgreSQL Pool
const pool = new Pool({
  connectionString: process.env.DATABASE_URL + (process.env.DATABASE_URL.includes('?') ? '&' : '?') + 'prepare_threshold=0',
  ssl: { rejectUnauthorized: false },
});

// Telco helper
function formatGhanaMsisdn(phone) {
  const cleaned = (phone || '').replace(/\D/g, '');
  if (cleaned.startsWith('233')) return cleaned;
  if (cleaned.startsWith('0')) return `233${cleaned.slice(1)}`;
  return cleaned;
}

function detectNetwork(phone) {
  const cleaned = (phone || '').replace(/\D/g, '');
  let prefix = '';
  if (cleaned.startsWith('233') && cleaned.length >= 5) {
    prefix = '0' + cleaned.slice(3, 5);
  } else if (cleaned.startsWith('0') && cleaned.length >= 3) {
    prefix = cleaned.slice(0, 3);
  }

  if (['024', '025', '053', '054', '055', '059'].includes(prefix)) {
    return { network: 'MTN', provider: 'mtn', label: 'MTN MoMo' };
  }
  if (['020', '050'].includes(prefix)) {
    return { network: 'VODAFONE', provider: 'vodafone', label: 'Telecel Cash' };
  }
  if (['026', '056', '027', '057'].includes(prefix)) {
    return { network: 'AIRTELTIGO', provider: 'airtel', label: 'AT Money' };
  }
  return { network: 'MTN', provider: 'mtn', label: 'MTN MoMo' };
}

// ─── HEALTH ───────────────────────────────────────────
app.get('/health', async (req, res) => {
  try {
    const dbRes = await pool.query('SELECT NOW() as now');
    res.json({
      status: 'ok',
      service: 'SwagPay API',
      database: 'connected',
      dbTime: dbRes.rows[0].now,
      gateway: WHITSUNPAY_CONFIG.baseUrl,
    });
  } catch (err) {
    res.status(500).json({ status: 'error', error: err.message });
  }
});

// ─── AUTHENTICATION ──────────────────────────────────
app.post('/api/auth/login', async (req, res) => {
  const { identifier, password, role } = req.body;
  try {
    const query = `SELECT id, name, email, phone, role, "posId", pin, active FROM users WHERE email = $1 OR phone = $1 OR id = $1 LIMIT 1`;
    const userRes = await pool.query(query, [identifier]);

    if (userRes.rows.length > 0) {
      const u = userRes.rows[0];
      if (u.pin === password || password === process.env.ADMIN_PASSWORD || password === process.env.TELLER_PIN) {
        return res.json({
          success: true,
          user: {
            id: u.id,
            fullName: u.name,
            email: u.email,
            phone: u.phone || '',
            role: u.role === 'ADMIN' || u.role === 'SUPER_ADMIN' ? 'admin' : 'teller',
            posId: u.posId || 'pos_01',
            active: u.active === 1,
          },
        });
      }
    }

    // Fallback default env authentication
    if (password === process.env.TELLER_PIN || password === '1234') {
      return res.json({
        success: true,
        user: {
          id: 'usr_teller1',
          fullName: 'Kofi Mensah',
          email: identifier || 'teller@swagpay.com',
          phone: '0550402859',
          role: 'teller',
          posId: 'pos_01',
          active: true,
        },
      });
    }

    if (password === process.env.ADMIN_PASSWORD || password === 'admin123') {
      return res.json({
        success: true,
        user: {
          id: 'usr_admin',
          fullName: 'Administrator',
          email: identifier || 'admin@swagpay.com',
          phone: '0240000001',
          role: 'admin',
          posId: 'pos_01',
          active: true,
        },
      });
    }

    res.status(401).json({ success: false, message: 'Invalid credentials or PIN' });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// ─── ACCOUNT LOOKUP (WhitsunPay) ─────────────────────
app.get('/api/account/lookup/:phone', async (req, res) => {
  const { phone } = req.params;
  const msisdn = formatGhanaMsisdn(phone);
  const net = detectNetwork(phone);

  try {
    const url = `${WHITSUNPAY_CONFIG.baseUrl}/api/v1/account/lookup/${encodeURIComponent(msisdn)}/${net.provider}`;
    const response = await fetch(url, {
      method: 'GET',
      headers: {
        'x-client-id': WHITSUNPAY_CONFIG.clientId,
        'x-api-key': WHITSUNPAY_CONFIG.apiKey,
      },
    });

    const data = await response.json();
    if (data.responseData && data.responseData.name) {
      return res.json({
        success: true,
        name: data.responseData.name,
        accountNumber: data.responseData.accountNumber,
        network: net.network,
        provider: net.provider,
        label: net.label,
      });
    }

    res.json({
      success: true,
      name: `Subscriber (${phone})`,
      network: net.network,
      provider: net.provider,
      label: net.label,
    });
  } catch (err) {
    res.json({
      success: true,
      name: `Subscriber (${phone})`,
      network: net.network,
      provider: net.provider,
      label: net.label,
    });
  }
});

// ─── INITIATE MOMO PAYMENT ────────────────────────────
app.post('/api/payments/initiate', async (req, res) => {
  const { amount, momoNumber, customerName, tellerId, posId } = req.body;

  const parsedAmount = parseFloat(amount);
  if (!parsedAmount || parsedAmount <= 0) {
    return res.status(400).json({ error: 'Valid payment amount required' });
  }
  if (!momoNumber || momoNumber.replace(/\D/g, '').length < 9) {
    return res.status(400).json({ error: 'Valid Ghana phone number required' });
  }

  const net = detectNetwork(momoNumber);
  const msisdn = formatGhanaMsisdn(momoNumber);
  const reference = `WP-${Date.now()}-${Math.floor(1000 + Math.random() * 9000)}`;
  const receiptNumber = `RCPT-${Math.floor(100000 + Math.random() * 900000)}`;
  const effectiveTeller = tellerId || 'usr_teller1';
  const effectivePos = posId || 'pos_01';
  const txnId = `tx_${Date.now()}`;

  try {
    // 1. Insert into Supabase PostgreSQL database
    const insertQuery = `
      INSERT INTO transactions (
        id, reference, "tellerId", "posId", network, "momoNumber",
        "customerName", amount, fee, "totalCharged", status, "receiptNumber"
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, 'PENDING', $11)
    `;

    await pool.query(insertQuery, [
      txnId,
      reference,
      effectiveTeller,
      effectivePos,
      net.network,
      momoNumber,
      customerName || 'Subscriber',
      parsedAmount,
      0.0,
      parsedAmount,
      receiptNumber,
    ]);

    // 2. Call WhitsunPay upstream MoMo collection prompt
    const payload = {
      transactionReference: reference,
      description: `SwagPay POS Collection at ${effectivePos}`,
      amount: parsedAmount,
      debitParty: {
        msisdn,
        provider: net.provider,
      },
    };

    const gwRes = await fetch(`${WHITSUNPAY_CONFIG.baseUrl}/api/v1/payments`, {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        'x-client-id': WHITSUNPAY_CONFIG.clientId,
        'x-api-key': WHITSUNPAY_CONFIG.apiKey,
        'x-callback-url': 'https://developer.whitsun.dev/callback',
      },
      body: JSON.stringify(payload),
    });

    const gwData = await gwRes.json().catch(() => ({}));

    if (gwRes.ok || gwRes.status === 200 || gwRes.status === 201 || gwRes.status === 202) {
      return res.json({
        success: true,
        reference,
        receiptNumber,
        status: 'PENDING',
        amount: parsedAmount,
        currency: 'GH₵',
        customerName: customerName || 'Subscriber',
        momoNumber,
        network: net.label,
        message: 'Prompt sent to customer phone. Awaiting MoMo PIN authorization.',
      });
    }

    const errorMsg = gwData.title || gwData.detail || gwData.message || 'Payment initiation declined';
    await pool.query('UPDATE transactions SET status = $1, "failureReason" = $2 WHERE reference = $3', [
      'FAILED',
      errorMsg,
      reference,
    ]);

    return res.status(422).json({
      success: false,
      reference,
      status: 'FAILED',
      message: errorMsg,
    });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// ─── CHECK PAYMENT STATUS ────────────────────────────
app.get('/api/payments/status/:ref', async (req, res) => {
  const { ref } = req.params;
  const cleanRef = decodeURIComponent(ref);

  try {
    const localRes = await pool.query('SELECT * FROM transactions WHERE reference = $1', [cleanRef]);
    if (localRes.rows.length === 0) {
      return res.status(404).json({ error: 'Transaction not found' });
    }

    const txn = localRes.rows[0];

    // If already terminal (SUCCESS or FAILED), return immediately
    if (txn.status === 'SUCCESS' || txn.status === 'FAILED') {
      return res.json({
        reference: txn.reference,
        status: txn.status,
        receiptNumber: txn.receiptNumber,
        amount: txn.amount,
        currency: 'GH₵',
        customerName: txn.customerName,
        momoNumber: txn.momoNumber,
        network: txn.network,
        failureReason: txn.failureReason,
        createdAt: txn.createdAt,
      });
    }

    // Check upstream WhitsunPay API
    const gwRes = await fetch(`${WHITSUNPAY_CONFIG.baseUrl}/api/v1/${encodeURIComponent(cleanRef)}/status`, {
      method: 'GET',
      headers: {
        'x-client-id': WHITSUNPAY_CONFIG.clientId,
        'x-api-key': WHITSUNPAY_CONFIG.apiKey,
      },
    });

    if (gwRes.status === 404) {
      return res.json({ reference: cleanRef, status: 'PENDING', currency: 'GH₵', amount: txn.amount });
    }

    const data = await gwRes.json().catch(() => ({}));
    const rawStatus = String(data.status || data.state || '').toUpperCase();

    let newStatus = 'PENDING';
    if (['SUCCESS', 'SUCCESSFUL', 'PAID', 'DELIVERED'].includes(rawStatus)) {
      newStatus = 'SUCCESS';
    } else if (['FAILED', 'EXPIRED', 'CANCELLED', 'REJECTED'].includes(rawStatus)) {
      newStatus = 'FAILED';
    }

    if (newStatus !== 'PENDING') {
      await pool.query(
        'UPDATE transactions SET status = $1, "failureReason" = $2, "updatedAt" = NOW() WHERE reference = $3',
        [newStatus, data.message || null, cleanRef]
      );
    }

    res.json({
      reference: cleanRef,
      status: newStatus,
      receiptNumber: txn.receiptNumber,
      amount: txn.amount,
      currency: 'GH₵',
      customerName: txn.customerName,
      momoNumber: txn.momoNumber,
      network: txn.network,
      failureReason: data.message || txn.failureReason,
      createdAt: txn.createdAt,
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ─── TRANSACTIONS LIST ───────────────────────────────
app.get('/api/transactions', async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT t.id, t.reference, t."gatewayReference", t."tellerId", t."posId",
             t.network, t."momoNumber", t."customerName", t.amount, t.fee,
             t."totalCharged", t.status, t."failureReason", t."receiptNumber",
             t."createdAt", u.name as "tellerName", p.name as "posName"
      FROM transactions t
      LEFT JOIN users u ON t."tellerId" = u.id
      LEFT JOIN pos_terminals p ON t."posId" = p.id
      ORDER BY t."createdAt" DESC
      LIMIT 100
    `);

    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ─── TELLERS & POS LIST ──────────────────────────────
app.get('/api/tellers', async (req, res) => {
  try {
    const result = await pool.query('SELECT id, name, email, phone, role, "posId", active, "createdAt" FROM users ORDER BY "createdAt" ASC');
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get('/api/pos', async (req, res) => {
  try {
    const result = await pool.query('SELECT id, code, name, location, active, "createdAt" FROM pos_terminals ORDER BY "createdAt" ASC');
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ─── REFUND REQUESTS ─────────────────────────────────
app.get('/api/refunds', async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM refund_requests ORDER BY "createdAt" DESC');
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/refunds', async (req, res) => {
  const { transactionId, reference, amount, tellerId, tellerName, reason, notes } = req.body;
  const id = `REF-${Date.now()}`;
  try {
    await pool.query(
      `INSERT INTO refund_requests (id, "transactionId", reference, amount, "tellerId", "tellerName", reason, notes, status)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, 'PENDING')`,
      [id, transactionId, reference, amount, tellerId, tellerName, reason, notes]
    );
    res.json({ success: true, id });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/refunds/:id/review', async (req, res) => {
  const { id } = req.params;
  const { approve, reviewerName, rejectionReason } = req.body;
  const status = approve ? 'APPROVED' : 'REJECTED';

  try {
    const refRes = await pool.query(
      'UPDATE refund_requests SET status = $1, "reviewedBy" = $2, "reviewedAt" = NOW(), "rejectionReason" = $3 WHERE id = $4 RETURNING *',
      [status, reviewerName || 'Admin', rejectionReason || null, id]
    );

    if (approve && refRes.rows.length > 0) {
      await pool.query('UPDATE transactions SET status = $1 WHERE id = $2', [
        'REFUNDED',
        refRes.rows[0].transactionId,
      ]);
    }

    res.json({ success: true, status });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ─── AUDIT LOGS ──────────────────────────────────────
app.get('/api/audit-logs', async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM audit_logs ORDER BY "createdAt" DESC LIMIT 100');
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ─── STATIC FLUTTER WEB (IF PRESENT) ────────────────
const webBuildPath = path.join(__dirname, 'build', 'web');
if (fs.existsSync(webBuildPath)) {
  console.log(`Serving SwagPay Web build from ${webBuildPath}`);
  app.use(express.static(webBuildPath));
  app.use((req, res, next) => {
    if (req.method === 'GET' && !req.path.startsWith('/api') && !req.path.startsWith('/health')) {
      return res.sendFile(path.join(webBuildPath, 'index.html'));
    }
    next();
  });
}

app.listen(PORT, '0.0.0.0', () => {
  console.log(`SwagPay Backend API running on port ${PORT} (0.0.0.0:${PORT})`);
  console.log(`Connected to WhitsunPay at: ${WHITSUNPAY_CONFIG.baseUrl}`);
});
