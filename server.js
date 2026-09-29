require('dotenv').config();
const express = require('express');
const cors = require('cors');
const { Pool } = require('pg');

const crypto = require('crypto');
const path = require('path');
const fs = require('fs');

const app = express();
app.use(cors());
app.use(express.json());

const PORT = process.env.PORT || 8080;

const auth = require('./server/auth');
const { requireAuth, requireRole, enforceTellerIdentity, hashPassword } = auth;
const registerAuthRoutes = require('./server/authRoutes');

// Refuse to boot with demo credentials — the app must never be reachable
// through a well-known PIN or an unsigned token.
const REQUIRED_SECRETS = ['AUTH_SECRET', 'DATABASE_URL', 'ADMIN_BOOTSTRAP_EMAIL', 'ADMIN_BOOTSTRAP_PASSWORD'];
const missing = REQUIRED_SECRETS.filter((k) => !process.env[k] || !String(process.env[k]).trim());
if (missing.length) {
  console.error(`Refusing to start: missing required secrets -> ${missing.join(', ')}`);
  console.error('Set them with `flyctl secrets set ...` (production) or a local .env (development).');
  process.exit(1);
}
if (['admin123', '1234', 'superadmin123'].includes(process.env.ADMIN_BOOTSTRAP_PASSWORD)) {
  console.error('Refusing to start: ADMIN_BOOTSTRAP_PASSWORD is a known default. Choose a real secret.');
  process.exit(1);
}

// WhitsunPay Config
const WHITSUNPAY_CONFIG = {
  baseUrl: process.env.WHITSUNPAY_BASE_URL || 'https://developer.whitsun.dev',
  clientId: process.env.WHITSUNPAY_CLIENT_ID,
  apiKey: process.env.WHITSUNPAY_API_KEY,
  webhookSecret: process.env.WHITSUNPAY_WEBHOOK_SECRET || '',
};
if (!WHITSUNPAY_CONFIG.clientId || !WHITSUNPAY_CONFIG.apiKey) {
  console.error('Refusing to start: WHITSUNPAY_CLIENT_ID and WHITSUNPAY_API_KEY must come from the environment.');
  process.exit(1);
}

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
registerAuthRoutes(app, pool);

// Deny by default: every /api route requires a valid signed token unless listed here.
app.use('/api', (req, res, next) => {
  if (auth.isPublicApiPath(req.path)) return next();
  return requireAuth(req, res, next);
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

    // No fabricated names: an unverifiable MSISDN returns no name at all.
    res.status(404).json({
      success: false,
      name: null,
      message: 'Could not verify the name for this number with the telco',
      network: net.network,
      provider: net.provider,
      label: net.label,
    });
  } catch (err) {
    res.status(502).json({
      success: false,
      name: null,
      message: 'Name verification service unavailable',
      network: net.network,
      provider: net.provider,
      label: net.label,
    });
  }
});

// ─── INITIATE MOMO PAYMENT ────────────────────────────
app.post('/api/payments/initiate', enforceTellerIdentity, async (req, res) => {
  const { amount, momoNumber, customerName } = req.body;
  // Teller identity and terminal always come from the verified session token.
  const tellerId = req.auth.userId;
  const posId = req.auth.role === 'TELLER' ? req.auth.posId : (req.body.posId || req.auth.posId);

  const parsedAmount = parseFloat(amount);
  if (!parsedAmount || parsedAmount <= 0) {
    return res.status(400).json({ error: 'Valid payment amount required' });
  }
  if (!momoNumber || momoNumber.replace(/\D/g, '').length < 9) {
    return res.status(400).json({ error: 'Valid Ghana phone number required' });
  }

  const net = detectNetwork(momoNumber);
  const msisdn = formatGhanaMsisdn(momoNumber);
  const idempotencyKey = String(req.headers['x-idempotency-key'] || req.body.idempotencyKey || req.body.reference || '').trim();
  const reference = idempotencyKey || `WP-${Date.now()}-${Math.floor(1000 + Math.random() * 9000)}`;
  const receiptNumber = `RCPT-${Math.floor(100000 + Math.random() * 900000)}`;
  const effectiveTeller = tellerId;
  const effectivePos = posId;
  if (!effectiveTeller || !effectivePos) {
    return res.status(403).json({ error: 'Session is not bound to a POS terminal' });
  }
  const txnId = `tx_${Date.now()}`;

  try {
    // 0. Idempotency check: if already initiated/recorded, return existing state
    if (idempotencyKey) {
      const existing = await pool.query(
        'SELECT * FROM transactions WHERE reference = $1 LIMIT 1',
        [idempotencyKey]
      );
      if (existing.rows.length > 0) {
        const row = existing.rows[0];
        return res.json({
          success: row.status !== 'FAILED',
          reference: row.reference,
          receiptNumber: row.receiptNumber,
          status: row.status,
          amount: row.amount,
          currency: 'GH₵',
          customerName: row.customerName,
          momoNumber: row.momoNumber,
          network: net.label,
          idempotent: true,
          message: 'Existing transaction record returned (Idempotent)',
        });
      }
    }

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
      customerName || null,
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
        customerName: customerName || null,
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
    const scoped = req.auth.role === 'TELLER';
    const localRes = await pool.query(
      scoped
        ? 'SELECT * FROM transactions WHERE reference = $1 AND "tellerId" = $2'
        : 'SELECT * FROM transactions WHERE reference = $1',
      scoped ? [cleanRef, req.auth.userId] : [cleanRef]
    );
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
    // Tellers are always scoped to their own ledger; admins may opt into the same view.
    const scopeToMe = req.auth.role === 'TELLER' || req.query.scope === 'me';
    const result = await pool.query(`
      SELECT t.id, t.reference, t."gatewayReference", t."tellerId", t."posId",
             t.network, t."momoNumber", t."customerName", t.amount, t.fee,
             t."totalCharged", t.status, t."failureReason", t."receiptNumber",
             t."createdAt", u.name as "tellerName", p.name as "posName"
      FROM transactions t
      LEFT JOIN users u ON t."tellerId" = u.id
      LEFT JOIN pos_terminals p ON t."posId" = p.id
      ${scopeToMe ? 'WHERE t."tellerId" = $1' : ''}
      ORDER BY t."createdAt" DESC
      LIMIT 100
    `, scopeToMe ? [req.auth.userId] : []);

    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ─── TELLERS & POS LIST ──────────────────────────────
app.get('/api/tellers', requireRole('ADMIN', 'SUPER_ADMIN'), async (req, res) => {
  try {
    const result = await pool.query('SELECT id, name, email, phone, role, "posId", active, "createdAt" FROM users ORDER BY "createdAt" ASC');
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Creates an account with a server-generated secret that is hashed at rest and
// returned exactly once. No shared default PIN is ever written to the database.
app.post('/api/tellers', requireRole('ADMIN', 'SUPER_ADMIN'), async (req, res) => {
  const { id, name, email, phone, role, posId } = req.body;
  if (!name || !email) {
    return res.status(400).json({ success: false, message: 'name and email are required' });
  }
  const tellerId = id || `usr_${crypto.randomUUID().slice(0, 8)}`;
  const tempSecret = crypto.randomBytes(9).toString('base64').replace(/[^A-Za-z0-9]/g, '').slice(0, 8) || 'Swag' + Date.now().toString(36);
  const normalised = ['ADMIN', 'SUPER_ADMIN'].includes(String(role).toUpperCase()) ? String(role).toUpperCase() : 'TELLER';
  try {
    // Editing an existing account must not reset its secret — that would let an
    // admin form save silently lock the teller out (or hand over a new password
    // nobody asked for). Only brand-new accounts receive a generated secret.
    const existing = await pool.query('SELECT id FROM users WHERE id = $1', [tellerId]);
    if (existing.rows.length > 0) {
      await pool.query(
        `UPDATE users SET name = $2, email = $3, phone = $4, role = $5, "posId" = $6, "updatedAt" = NOW()
         WHERE id = $1`,
        [tellerId, name, email, phone || '', normalised, posId || null]
      );
      return res.json({ success: true, id: tellerId, updated: true });
    }

    await pool.query(
      `INSERT INTO users (id, name, email, phone, pin, "pinHash", role, "posId", active, "createdAt", "updatedAt")
       VALUES ($1, $2, $3, $4, '', $5, $6, $7, 1, NOW(), NOW())`,
      [tellerId, name, email, phone || '', hashPassword(tempSecret), normalised, posId || null]
    );
    res.json({
      success: true,
      id: tellerId,
      tempSecret,
      warning: 'Share this secret once — it cannot be retrieved later.',
    });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
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

app.post('/api/pos', requireRole('ADMIN', 'SUPER_ADMIN'), async (req, res) => {
  const { id, code, name, location } = req.body;
  const posId = id || `pos_${Date.now()}`;
  const posCode = code || `POS-${Math.floor(1000 + Math.random() * 9000)}`;
  try {
    await pool.query(
      `INSERT INTO pos_terminals (id, code, name, location, active, "createdAt", "updatedAt")
       VALUES ($1, $2, $3, $4, 1, NOW(), NOW())
       ON CONFLICT (id) DO UPDATE SET code = $2, name = $3, location = $4`,
      [posId, posCode, name, location || 'Counter']
    );
    res.json({ success: true, id: posId });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ─── SETTLEMENTS & RECONCILIATION ─────────────────────
app.get('/api/settlements', requireRole('ADMIN', 'SUPER_ADMIN'), async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT 
        TO_CHAR("createdAt", 'YYYY-MM-DD') as date_str,
        COUNT(*) as "transactionCount",
        COALESCE(SUM(CASE WHEN status = 'SUCCESS' THEN amount ELSE 0 END), 0) as "totalCollected",
        COALESCE(SUM(CASE WHEN status = 'SUCCESS' THEN (amount - fee) ELSE 0 END), 0) as "totalSettled"
      FROM transactions
      GROUP BY TO_CHAR("createdAt", 'YYYY-MM-DD')
      ORDER BY date_str DESC
    `);

    const settlements = result.rows.map((row) => ({
      id: `SET-${row.date_str.replace(/-/g, '')}`,
      date: new Date(row.date_str).toISOString(),
      totalCollected: parseFloat(row.totalCollected),
      totalSettled: parseFloat(row.totalSettled),
      variance: 0.0,
      transactionCount: parseInt(row.transactionCount, 10),
      status: 'SETTLED',
      discrepancies: []
    }));

    if (settlements.length === 0) {
      const todayStr = new Date().toISOString().split('T')[0];
      settlements.push({
        id: `SET-${todayStr.replace(/-/g, '')}`,
        date: new Date().toISOString(),
        totalCollected: 0.0,
        totalSettled: 0.0,
        variance: 0.0,
        transactionCount: 0,
        status: 'SETTLED',
        discrepancies: []
      });
    }

    res.json(settlements);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ─── REFUND REQUESTS ─────────────────────────────────
app.get('/api/refunds', async (req, res) => {
  try {
    const scoped = req.auth.role === 'TELLER';
    const result = await pool.query(
      scoped
        ? 'SELECT * FROM refund_requests WHERE "tellerId" = $1 ORDER BY "createdAt" DESC'
        : 'SELECT * FROM refund_requests ORDER BY "createdAt" DESC',
      scoped ? [req.auth.userId] : []
    );
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/refunds', enforceTellerIdentity, async (req, res) => {
  const { reference, amount, reason, notes } = req.body;
  const tellerId = req.body.tellerId || req.auth.userId;
  const id = `REF-${Date.now()}`;
  try {
    // Teller name is resolved server-side; clients cannot forge who asked for the refund.
    const actorRes = await pool.query('SELECT name FROM users WHERE id = $1', [tellerId]);
    const actorName = actorRes.rows[0] ? actorRes.rows[0].name : 'Unknown user';

    // The ledger row comes from the reference, and a teller may only claim
    // against their own collections — never another teller's.
    const isTeller = req.auth.role === 'TELLER';
    const owned = await pool.query(
      isTeller
        ? 'SELECT id, amount, status FROM transactions WHERE reference = $1 AND "tellerId" = $2'
        : 'SELECT id, amount, status FROM transactions WHERE reference = $1',
      isTeller ? [reference, req.auth.userId] : [reference]
    );
    if (owned.rows.length === 0) {
      return res.status(404).json({ success: false, message: 'Unknown transaction reference' });
    }
    const txn = owned.rows[0];
    if (txn.status !== 'SUCCESS') {
      return res
        .status(409)
        .json({ success: false, message: `Only settled collections can be refunded (status: ${txn.status})` });
    }
    const refundAmount = parseFloat(amount);
    if (!refundAmount || refundAmount <= 0 || refundAmount > parseFloat(txn.amount)) {
      return res.status(400).json({ success: false, message: `Refund must be between 0 and ${txn.amount}` });
    }

    await pool.query(
      `INSERT INTO refund_requests (id, "transactionId", reference, amount, "tellerId", "tellerName", reason, notes, status)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, 'PENDING')`,
      [id, txn.id, reference, refundAmount, tellerId, actorName, reason, notes]
    );
    res.json({ success: true, id });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/refunds/:id/review', requireRole('ADMIN', 'SUPER_ADMIN'), async (req, res) => {
  const { id } = req.params;
  const { approve, rejectionReason } = req.body;
  const status = approve ? 'APPROVED' : 'REJECTED';

  try {
    // The reviewer is whoever the token belongs to — the client cannot name itself.
    const reviewerRes = await pool.query('SELECT name FROM users WHERE id = $1', [req.auth.userId]);
    const reviewerName = reviewerRes.rows[0] ? reviewerRes.rows[0].name : req.auth.userId;

    const refRes = await pool.query(
      'UPDATE refund_requests SET status = $1, "reviewedBy" = $2, "reviewedAt" = NOW(), "rejectionReason" = $3 WHERE id = $4 RETURNING *',
      [status, reviewerName, rejectionReason || null, id]
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
app.get('/api/audit-logs', requireRole('ADMIN', 'SUPER_ADMIN'), async (req, res) => {
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
