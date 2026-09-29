// Auth contract tests: token integrity, password handling, and the deny-by-default
// middleware chain. These run offline — no database required.
//   node --test server/
const test = require('node:test');
const assert = require('node:assert');

process.env.AUTH_SECRET = process.env.AUTH_SECRET || 'test-secret-0123456789abcdef0123456789abcdef';
process.env.ADMIN_BOOTSTRAP_EMAIL = 'root@swagpay.test';
process.env.ADMIN_BOOTSTRAP_PASSWORD = 'bootstrap-secret-not-a-demo-value';

const auth = require('./auth');

test('access tokens round-trip and reject tampering', () => {
  const token = auth.createAccessToken({ id: 'usr_1', role: 'TELLER', posId: 'pos_01' }, 'dev-abc');
  const payload = auth.verifyToken(token, 'access');
  assert.equal(payload.uid, 'usr_1');
  assert.equal(payload.role, 'TELLER');
  assert.equal(payload.did, 'dev-abc');
  assert.equal(auth.verifyToken(token + 'tampered', 'access'), null);
  assert.equal(auth.verifyToken(token, 'refresh'), null, 'token type confusion must fail');
  assert.equal(auth.verifyToken('not.a.token', 'access'), null);
});

test('shaped client users still carry a server-side role in tokens', () => {
  // shapeUser() sends role:'admin' lowercase to the app; the token must keep the
  // canonical uppercase role or every requireRole() check silently fails.
  const shaped = { id: 'usr_admin', role: 'admin', dbRole: 'ADMIN', posId: null };
  const payload = auth.verifyToken(auth.createAccessToken(shaped, 'dev-1'), 'access');
  assert.equal(payload.role, 'ADMIN');
  const teller = auth.verifyToken(auth.createAccessToken({ id: 'u2', role: 'teller', dbRole: 'TELLER' }, 'dev-1'), 'access');
  assert.equal(teller.role, 'TELLER');
});

test('expired and malformed tokens are rejected', () => {  const body = Buffer.from(
    JSON.stringify({ uid: 'u', role: 'TELLER', typ: 'access', exp: Math.floor(Date.now() / 1000) - 1 })
  ).toString('base64url');
  // Even correctly signed, the expiry check must reject it: re-sign with the module secret.
  const signed = require('crypto')
    .createHmac('sha256', process.env.AUTH_SECRET)
    .update(body)
    .digest('base64url');
  assert.equal(auth.verifyToken(`${body}.${signed}`, 'access'), null, 'expired token must be rejected');
  assert.equal(auth.verifyToken(`${body}.nonsense`, 'access'), null, 'bad signature must be rejected');
});

test('scrypt hashes verify, legacy plaintext still accepted for migration', () => {
  const hash = auth.hashPassword('supplier-pass');
  assert.ok(hash.startsWith('scrypt$'));
  assert.ok(auth.verifyPassword(hash, 'supplier-pass'));
  assert.ok(!auth.verifyPassword(hash, 'wrong-pass'));
  assert.ok(auth.verifyPassword('legacy-plaintext-pin', 'legacy-plaintext-pin'));
  assert.ok(!auth.verifyPassword('legacy-plaintext-pin', 'other'));
});

test('middleware chain denies anonymous access and enforces roles', async () => {
  const express = require('express');
  const app = express();
  app.use(express.json());

  app.use('/api', (req, res, next) => {
    if (auth.isPublicApiPath(req.path)) return next();
    return auth.requireAuth(req, res, next);
  });
  app.get('/api/transactions', (req, res) => res.json({ userId: req.auth.userId, role: req.auth.role }));
  app.get('/api/audit-logs', auth.requireRole('ADMIN', 'SUPER_ADMIN'), (req, res) => res.json({ ok: true }));
  app.post('/api/auth/login', (req, res) => res.json({ public: true }));

  const server = await new Promise((resolve) => {
    const s = app.listen(0, () => resolve(s));
  });
  const base = `http://127.0.0.1:${server.address().port}`;
  const call = async (path, token) => {
    const headers = token ? { Authorization: `Bearer ${token}` } : {};
    const res = await fetch(base + path, { headers });
    return { status: res.status, body: await res.json().catch(() => null) };
  };

  try {
    const tellerToken = auth.createAccessToken({ id: 'usr_1', role: 'TELLER', posId: 'pos_01' }, 'dev-1');
    const adminToken = auth.createAccessToken({ id: 'usr_admin', role: 'ADMIN', posId: null }, 'dev-1');

    assert.equal((await call('/api/transactions')).status, 401, 'anonymous ledger read must be denied');
    assert.equal((await call('/api/transactions', 'garbage')).status, 401);

    const scoped = await call('/api/transactions', tellerToken);
    assert.equal(scoped.status, 200);
    assert.equal(scoped.body.userId, 'usr_1', 'handler receives the token identity, not a client-supplied one');

    assert.equal((await call('/api/audit-logs', tellerToken)).status, 403, 'teller must not reach admin surface');
    assert.equal((await call('/api/audit-logs', adminToken)).status, 200);
    const login = await fetch(`${base}/api/auth/login`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ identifier: 'x', password: 'y' }),
    });
    assert.equal(login.status, 200, 'login stays public');
  } finally {
    server.close();
  }
});

test('tellers cannot override their own identity on writes', () => {
  const express = require('express');
  const app = express();
  app.use(express.json());
  app.post('/api/payments/initiate', (req, res, next) => {
    req.auth = { userId: 'usr_real', role: 'TELLER', posId: 'pos_real' };
    auth.enforceTellerIdentity(req, res, next);
  }, (req, res) => res.json(req.body));

  return new Promise((resolve) => {
    const server = app.listen(0, async () => {
      const res = await fetch(`http://127.0.0.1:${server.address().port}/api/payments/initiate`, {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ amount: 10, tellerId: 'usr_victim', posId: 'pos_other' }),
      });
      const body = await res.json();
      server.close();
      assert.equal(body.tellerId, 'usr_real', 'spoofed tellerId must be overwritten by the session identity');
      resolve();
    });
  });
});
